import UIKit
import AVKit
import AVFoundation
import XCDYouTubeKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBarController()
    }
    
    private func setupTabBarController() {
        // Create the tab bar controller
        let tabBarController = UITabBarController()
        
        // Create Music Videos tab (your existing screen)
        let musicVideosController = PlayListViewController()
        musicVideosController.tabBarItem = UITabBarItem(
            title: "Top 100 Videos",
            image: UIImage(systemName: "play.rectangle.fill"),
            tag: 0
        )
        
        // Create Live Shows tab (Artist-based screen)
        let liveShowsController = LiveShowsTabViewController()
        liveShowsController.tabBarItem = UITabBarItem(
            title: "Live Shows", 
            image: UIImage(systemName: "music.mic"),
            tag: 1
        )
        
        // Create Search tab
        let searchController = SearchViewController()
        searchController.tabBarItem = UITabBarItem(
            title: "Search",
            image: UIImage(systemName: "magnifyingglass"),
            tag: 2
        )
        
        // Add controllers to tab bar
        tabBarController.viewControllers = [musicVideosController, liveShowsController, searchController]
        
        // Set up the tab bar appearance for tvOS
        tabBarController.tabBar.isTranslucent = true
        tabBarController.tabBar.barTintColor = UIColor.black.withAlphaComponent(0.8)
        tabBarController.tabBar.tintColor = UIColor.white
        
        // Add as child view controller
        addChild(tabBarController)
        tabBarController.view.frame = view.bounds
        view.addSubview(tabBarController.view)
        tabBarController.didMove(toParent: self)
    }
}

// MARK: - Live Shows Controller with Category Grid
class LiveShowsTabViewController: UIViewController {
    
    // MARK: - Properties
    private var categories: [Category] = []
    private var categoryTableView: UITableView!
    private var categoryCollectionView: UICollectionView!
    private var loadingIndicator: UIActivityIndicatorView!
    private var selectedCategoryIndex: Int?
    
    // State management for sidebar content
    private var isShowingArtists: Bool = false
    private var selectedCategory: Category?
    private var currentArtists: [String] = []
    private var currentVideos: [LiveShowVideo] = []
    private var isShowingVideos: Bool = false
    private var selectedArtist: String?
    private var selectedBannerIndex: Int?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showLoadingIndicator()
        fetchCategories()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // MTV logo imageView setup (exact same as Music Videos)
        let imageView = UIImageView(image: UIImage(named: "logoVector"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        // Category sidebar tableView setup (same structure as playlist sidebar)
        categoryTableView = UITableView()
        categoryTableView.dataSource = self
        categoryTableView.delegate = self
        categoryTableView.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
        categoryTableView.backgroundColor = .clear
        view.addSubview(categoryTableView)
        categoryTableView.cellLayoutMarginsFollowReadableWidth = false
        categoryTableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Collection view for category banners (when showing categories) or videos (when showing videos)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 40
        layout.minimumLineSpacing = 40
        layout.itemSize = CGSize(width: 495, height: 204) // Two columns: (990+40)/2 = 495 width each
        
        // Center the items horizontally (like justify-content: center)
        // Calculate the available width: collection view width - (2 items * item width) - inter-item spacing
        // Collection view width = screen width - sidebar width - margins
        let screenWidth = UIScreen.main.bounds.width
        let sidebarWidth: CGFloat = 400 + 70 // sidebar width + margin
        let rightMargin: CGFloat = 20
        let collectionViewWidth = screenWidth - sidebarWidth - rightMargin
        let totalItemsWidth: CGFloat = (2 * 495) + 40 // 2 items + spacing between them
        let horizontalPadding = max(CGFloat(0), (collectionViewWidth - totalItemsWidth) / 2)
        layout.sectionInset = UIEdgeInsets(top: 20, left: horizontalPadding, bottom: 20, right: horizontalPadding)
        
        categoryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        categoryCollectionView.backgroundColor = .clear
        categoryCollectionView.dataSource = self
        categoryCollectionView.delegate = self
        categoryCollectionView.register(CategoryBannerCell.self, forCellWithReuseIdentifier: "CategoryBannerCell")
        categoryCollectionView.register(LiveShowVideoCell.self, forCellWithReuseIdentifier: "LiveShowVideoCell")
        view.addSubview(categoryCollectionView)
        categoryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Layout constraints - sidebar positioned closer to logo
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 152),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            imageView.widthAnchor.constraint(equalToConstant: 98),
            imageView.heightAnchor.constraint(equalToConstant: 77),
            
            categoryTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -51),
            categoryTableView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 50),
            categoryTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            categoryTableView.widthAnchor.constraint(equalToConstant: 400),
            
            categoryCollectionView.leadingAnchor.constraint(equalTo: categoryTableView.trailingAnchor, constant: 70),
            categoryCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            categoryCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            categoryCollectionView.bottomAnchor.constraint(equalTo: categoryTableView.bottomAnchor)
        ])
    }
    
    // MARK: - Collection View Layout Management
    private func updateCollectionViewLayout(forVideos: Bool) {
        guard let flowLayout = categoryCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        
        // Calculate collection view width for centering
        let screenWidth = UIScreen.main.bounds.width
        let sidebarWidth: CGFloat = 400 + 70 // sidebar width + margin
        let rightMargin: CGFloat = 20
        let collectionViewWidth = screenWidth - sidebarWidth - rightMargin
        
        if forVideos {
            // Video layout: similar to Music Videos screen
            flowLayout.itemSize = CGSize(width: 340, height: 320) // Height increased for metadata
            flowLayout.minimumInteritemSpacing = 20
            flowLayout.minimumLineSpacing = 40
            
            // Center video items (3 columns)
            let itemsPerRow: CGFloat = 3
            let totalItemsWidth: CGFloat = (itemsPerRow * 340) + ((itemsPerRow - 1) * 20) // 3 items + spacing between them
            let horizontalPadding = max(CGFloat(0), (collectionViewWidth - totalItemsWidth) / 2)
            flowLayout.sectionInset = UIEdgeInsets(top: 20, left: horizontalPadding, bottom: 20, right: horizontalPadding)
        } else {
            // Category banner layout
            flowLayout.itemSize = CGSize(width: 495, height: 204)
            flowLayout.minimumInteritemSpacing = 40
            flowLayout.minimumLineSpacing = 40
            
            // Center banner items (2 columns)
            let totalItemsWidth: CGFloat = (2 * 495) + 40 // 2 items + spacing between them
            let horizontalPadding = max(CGFloat(0), (collectionViewWidth - totalItemsWidth) / 2)
            flowLayout.sectionInset = UIEdgeInsets(top: 20, left: horizontalPadding, bottom: 20, right: horizontalPadding)
        }
        
        categoryCollectionView.collectionViewLayout.invalidateLayout()
    }
    
    // MARK: - Data Fetching
    private func fetchCategories() {
        sortAndArrangeCategories { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let categories):
                self.categories = categories
                DispatchQueue.main.async {
                    self.categoryTableView.reloadData()
                    self.categoryCollectionView.reloadData()
                    self.hideLoadingIndicator()
                    
                    // Don't auto-select any category - let user choose from banner area
                    // Sidebar starts with placeholder message
                }
            case .failure(let error):
                print("Error fetching categories: \(error)")
                self.hideLoadingIndicator()
            }
        }
    }
    
    private func fetchVideosForArtist(artistName: String) {
        print("🎬 Fetching videos for artist: \(artistName)")
        showLoadingIndicator()
        fetchLiveShowVideos(artistName: artistName) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let videos):
                print("✅ Successfully fetched \(videos.count) videos for \(artistName)")
                self.currentVideos = videos
                self.isShowingVideos = true
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                    self.updateCollectionViewLayout(forVideos: true)
                    self.categoryCollectionView.reloadData()
                    print("🔄 Collection view reloaded with \(videos.count) videos")
                }
            case .failure(let error):
                print("❌ Error fetching videos for artist \(artistName): \(error)")
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                }
            }
        }
    }
    
    // MARK: - Loading Indicator
    private func showLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func hideLoadingIndicator() {
        loadingIndicator?.stopAnimating()
        loadingIndicator?.removeFromSuperview()
    }
}

// MARK: - TableView DataSource & Delegate (Sidebar)
extension LiveShowsTabViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isShowingArtists {
            return currentArtists.count + 1 // +1 for back button
        } else {
            return 0 // No content when no category selected
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        
        if isShowingArtists {
            if indexPath.row == 0 {
                // Back button
                cell.textLabel?.text = "← Back to Categories"
                cell.textLabel?.textColor = UIColor(hex: "#A789FD")
                cell.textLabel?.font = UIFont.systemFont(ofSize: 22, weight: .medium)
            } else {
                // Artist name
                let artistIndex = indexPath.row - 1
                cell.textLabel?.text = currentArtists[artistIndex]
                cell.textLabel?.textColor = .white
                cell.textLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
            }
        }
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        // Custom selection background for artist cells and back button
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(hex: "#A789FD")
        cell.selectedBackgroundView = backgroundView
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Clear previous selection borders
        if let previousSelectedIndex = selectedCategoryIndex,
           let previousSelectedCell = tableView.cellForRow(at: IndexPath(row: previousSelectedIndex, section: 0)) {
            previousSelectedCell.layer.borderWidth = 0
        }
        
        // Set border for currently selected cell (matching Music Videos screen)
        if let selectedCell = tableView.cellForRow(at: indexPath) {
            selectedCell.layer.borderWidth = 2
            selectedCell.layer.borderColor = UIColor(hex: "#A789FD").cgColor
        }
        
        if isShowingArtists {
            if indexPath.row == 0 {
                // Back button pressed - return to categories
                isShowingArtists = false
                isShowingVideos = false
                selectedCategory = nil
                selectedArtist = nil
                currentArtists = []
                currentVideos = []
                selectedCategoryIndex = nil // Reset selection
                selectedBannerIndex = nil // Reset banner selection
                categoryTableView.reloadData()
                categoryCollectionView.reloadData()
                updateCollectionViewLayout(forVideos: false)
            } else {
                // Artist selected - load their videos
                let artistIndex = indexPath.row - 1
                selectedArtist = currentArtists[artistIndex]
                fetchVideosForArtist(artistName: selectedArtist!)
                print("Selected artist: \(selectedArtist!)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let deselectedCell = tableView.cellForRow(at: indexPath)
        deselectedCell?.layer.borderWidth = 0
        deselectedCell?.layer.borderColor = UIColor.clear.cgColor
    }
    
    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if let nextFocusedIndexPath = context.nextFocusedIndexPath {
                if let nextFocusedCell = tableView.cellForRow(at: nextFocusedIndexPath) {
                    nextFocusedCell.contentView.backgroundColor = UIColor(hex: "#A789FD")
                    nextFocusedCell.contentView.transform = CGAffineTransform.identity
                }
            }
            if let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath {
                if let previouslyFocusedCell = tableView.cellForRow(at: previouslyFocusedIndexPath) {
                    previouslyFocusedCell.contentView.backgroundColor = UIColor.clear
                    previouslyFocusedCell.contentView.transform = CGAffineTransform.identity
                }
            }
        }, completion: nil)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - CollectionView DataSource & Delegate
extension LiveShowsTabViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isShowingVideos {
            return currentVideos.count
        } else {
            return categories.count // Show all categories as banners
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isShowingVideos {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LiveShowVideoCell", for: indexPath) as! LiveShowVideoCell
            let video = currentVideos[indexPath.item]
            cell.configure(with: video)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryBannerCell", for: indexPath) as! CategoryBannerCell
            let category = categories[indexPath.item]
            let isSelected = selectedBannerIndex == indexPath.item
            cell.configure(with: category, isSelected: isSelected)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isShowingVideos {
            // Video selected - play the video
            let selectedVideo = currentVideos[indexPath.item]
            playLiveShowVideo(url: selectedVideo.fields.url)
        } else {
            // Banner selected - switch sidebar to show artists for this category
            let selectedCategoryData = categories[indexPath.item]
            selectedCategory = selectedCategoryData
            selectedBannerIndex = indexPath.item // Track selected banner
            currentArtists = selectedCategoryData.fields.artistNames ?? []
            isShowingArtists = true
            
            // Update collection view to show selected state
            categoryCollectionView.reloadData()
            
            // Update sidebar to show artists
            categoryTableView.reloadData()
            
            // Auto-select the back button initially
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let backButtonIndexPath = IndexPath(row: 0, section: 0)
                self.categoryTableView.selectRow(at: backButtonIndexPath, animated: false, scrollPosition: .none)
            }
            
            print("Selected category: \(selectedCategoryData.fields.categoryName)")
            print("Artists: \(currentArtists)")
        }
    }
    
    // MARK: - Video Playback
    private func playLiveShowVideo(url: String) {
        // Extract YouTube video ID from URL
        let videoIdentifier = extractVideoIdentifier(from: url)
        
        guard !videoIdentifier.isEmpty else {
            print("Could not extract video identifier from URL: \(url)")
            return
        }
        
        playVideoWithIdentifier(videoIdentifier: videoIdentifier)
    }
    
    private func extractVideoIdentifier(from url: String) -> String {
        // Extract YouTube video ID from various URL formats
        if let range = url.range(of: "v=") {
            let startIndex = range.upperBound
            let substring = String(url[startIndex...])
            let endIndex = substring.firstIndex(of: "&") ?? substring.endIndex
            return String(substring[..<endIndex])
        } else if let range = url.range(of: "youtu.be/") {
            let startIndex = range.upperBound
            let substring = String(url[startIndex...])
            let endIndex = substring.firstIndex(of: "?") ?? substring.endIndex
            return String(substring[..<endIndex])
        }
        return ""
    }
    
    private func playVideoWithIdentifier(videoIdentifier: String) {
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        let playerViewController = AVPlayerViewController()
        
        XCDYouTubeClient.default().getVideoWithIdentifier(videoIdentifier) { [weak self] (video: XCDYouTubeVideo?, error: Error?) in
            loadingIndicator.stopAnimating()
            loadingIndicator.removeFromSuperview()
            
            guard let video = video else {
                print("YouTube video loading error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let streamURLs = video.streamURLs
            guard let streamURL = (streamURLs[XCDYouTubeVideoQualityHTTPLiveStreaming] ??
                                   streamURLs[YouTubeVideoQuality.hd720] ??
                                   streamURLs[YouTubeVideoQuality.medium360] ??
                                   streamURLs[YouTubeVideoQuality.small240]) else {
                print("No suitable stream URL quality found")
                return
            }
            
            DispatchQueue.main.async {
                let player = AVPlayer(url: streamURL)
                playerViewController.player = player
                self?.present(playerViewController, animated: true) {
                    player.play()
                }
            }
        }
    }
}

// MARK: - Live Show Video Cell
class LiveShowVideoCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let yearLabel = UILabel()
    private let durationLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
        
        // Image view setup
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        // Title label setup
        titleLabel.textColor = .white
        titleLabel.font = UIFont(name: "sf_pro-bold", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Year label setup (left aligned)
        yearLabel.textColor = UIColor(hex: "#A789FD")
        yearLabel.font = UIFont(name: "sf_pro-regular", size: 21) ?? UIFont.systemFont(ofSize: 21, weight: .regular)
        yearLabel.textAlignment = .left
        yearLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(yearLabel)
        
        // Duration label setup (right aligned)
        durationLabel.textColor = UIColor(hex: "#A789FD")
        durationLabel.font = UIFont(name: "sf_pro-regular", size: 21) ?? UIFont.systemFont(ofSize: 21, weight: .regular)
        durationLabel.textAlignment = .right
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(durationLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Image view
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            imageView.heightAnchor.constraint(equalToConstant: 191), // Standard YouTube thumbnail aspect ratio
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            
            // Year and Duration on same line
            yearLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            yearLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            yearLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            durationLabel.centerYAnchor.constraint(equalTo: yearLabel.centerYAnchor),
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])
    }
    
    func configure(with video: LiveShowVideo) {
        titleLabel.text = video.fields.title
        yearLabel.text = video.fields.year
        durationLabel.text = video.fields.videoLength ?? ""
        
        // Load video thumbnail
        if let imageURL = URL(string: video.fields.videoImage) {
            URLSession.shared.dataTask(with: imageURL) { [weak self] data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.imageView.image = image
                    }
                }
            }.resume()
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                // Only scale and glow the image, not the text
                self.imageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.imageView.layer.shadowColor = UIColor(hex: "#A789FD").cgColor
                self.imageView.layer.shadowOffset = CGSize(width: 0, height: 0)
                self.imageView.layer.shadowOpacity = 0.8
                self.imageView.layer.shadowRadius = 10
            } else {
                self.imageView.transform = .identity
                self.imageView.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}

// MARK: - Category Banner Cell
class CategoryBannerCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private var category: Category?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.layer.cornerRadius = 15
        contentView.clipsToBounds = true
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    func configure(with category: Category, isSelected: Bool = false) {
        // Store the category for glow color determination
        self.category = category
        
        // Load category image from Airtable
        if let attachments = category.fields.categoryImage,
           let firstAttachment = attachments.first,
           let imageURL = URL(string: firstAttachment.url) {
            
            URLSession.shared.dataTask(with: imageURL) { [weak self] data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.imageView.image = image
                    }
                }
            }.resume()
        } else {
            // Fallback gradient background
            imageView.image = nil
            imageView.backgroundColor = UIColor(hex: category.fields.color ?? "#6640C6")
        }
        
        // Set selection border
        if isSelected {
            contentView.layer.borderWidth = 3
            contentView.layer.borderColor = UIColor(hex: "#A789FD").cgColor
        } else {
            contentView.layer.borderWidth = 0
            contentView.layer.borderColor = UIColor.clear.cgColor
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                
                // Determine glow color based on category name
                var glowColor = "#A789FD" // Default purple
                if let categoryName = self.category?.fields.categoryName.lowercased() {
                    if categoryName.contains("epic shows") {
                        glowColor = "#AAF159" // Green glow for Epic Shows
                    } else if categoryName.contains("venues") {
                        glowColor = "#3A8FE4" // Blue glow for Venues
                    }
                }
                
                self.layer.shadowColor = UIColor(hex: glowColor).cgColor
                self.layer.shadowOffset = CGSize(width: 0, height: 0)
                self.layer.shadowOpacity = 0.8
                self.layer.shadowRadius = 10
            } else {
                self.transform = .identity
                self.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}

// MARK: - Live Show Video Model
struct LiveShowVideo {
    let id: String
    let fields: LiveShowVideoFields
}

struct LiveShowVideoFields {
    let title: String
    let year: String
    let url: String
    let videoImage: String
    let videoLength: String?
    let artistName: [String]?
}

// MARK: - Video Fetching Function
func fetchLiveShowVideos(artistName: String, completion: @escaping (Result<[LiveShowVideo], Error>) -> Void) {
    // First, find the artist in the Artists table
    let filterFormula = "{artistName} = '\(artistName)'"
    let encodedFormula = filterFormula.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let urlString = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/Artists?filterByFormula=\(encodedFormula)"
    
    print("🔍 Finding artist in Artists table...")
    print("🔍 API URL: \(urlString)")
    print("🔍 Filter formula: \(filterFormula)")
    
    guard let url = URL(string: urlString) else {
        print("❌ Invalid URL: \(urlString)")
        completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ Network error: \(error)")
            completion(.failure(error))
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 HTTP Status: \(httpResponse.statusCode)")
        }
        
        guard let data = data else {
            print("❌ No data received")
            completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
            return
        }
        
        print("📥 Received artist data: \(data.count) bytes")
        
        do {
            let artistResponse = try JSONDecoder().decode(ArtistAirtableResponse.self, from: data)
            print("✅ Successfully decoded \(artistResponse.records.count) artist records")
            
            guard let artistRecord = artistResponse.records.first else {
                print("❌ No artist found with name: \(artistName)")
                completion(.success([])) // Return empty array if artist not found
                return
            }
            
            print("✅ Found artist: \(artistRecord.fields.artistName ?? "Unknown")")
            print("🎬 Artist has \(artistRecord.fields.videoURLs?.count ?? 0) videos")
            
            // Convert the artist's video data to LiveShowVideo objects
            let videos = convertArtistDataToVideos(artist: artistRecord)
            print("✅ Converted to \(videos.count) LiveShowVideo objects")
            completion(.success(videos))
            
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw JSON: \(jsonString)")
            }
            completion(.failure(error))
        }
    }.resume()
}

// Helper function to format duration from seconds to "1hr 34min" format
func formatDuration(_ durationString: String?) -> String {
    guard let durationString = durationString,
          let totalSeconds = Int(durationString) else {
        return ""
    }
    
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    
    if hours > 0 {
        if minutes > 0 {
            return "\(hours)hr \(minutes)min"
        } else {
            return "\(hours)hr"
        }
    } else {
        return "\(minutes)min"
    }
}

// Helper function to convert artist data to video objects
func convertArtistDataToVideos(artist: ArtistRecord) -> [LiveShowVideo] {
    guard let videoURLs = artist.fields.videoURLs,
          let videoTitles = artist.fields.videoTitle,
          let videoYears = artist.fields.videoYear,
          let videoThumbnails = artist.fields.videoThumbnail else {
        return []
    }
    
    var videos: [LiveShowVideo] = []
    let artistName = artist.fields.artistName ?? "Unknown Artist"
    let videoDurations = artist.fields.videoDuration
    
    // Create video objects from the parallel arrays
    let count = min(videoURLs.count, min(videoTitles.count, min(videoYears.count, videoThumbnails.count)))
    
    for i in 0..<count {
        // Get duration for this video if available
        let duration = (videoDurations != nil && i < videoDurations!.count) ? videoDurations![i] : nil
        let formattedDuration = formatDuration(duration)
        
        let video = LiveShowVideo(
            id: "\(artist.id)_\(i)", // Generate a unique ID
            fields: LiveShowVideoFields(
                title: videoTitles[i],
                year: videoYears[i], 
                url: videoURLs[i],
                videoImage: videoThumbnails[i],
                videoLength: formattedDuration.isEmpty ? nil : formattedDuration,
                artistName: [artistName] // Use the actual artist name
            )
        )
        videos.append(video)
    }
    
    // Sort videos by year (newest first)
    videos.sort { video1, video2 in
        let year1 = Int(video1.fields.year) ?? 0
        let year2 = Int(video2.fields.year) ?? 0
        return year1 > year2 // Descending order (newest first)
    }
    
    return videos
}

// MARK: - Artist Airtable Response Models
struct ArtistAirtableResponse: Codable {
    let records: [ArtistRecord]
}

struct ArtistRecord: Codable {
    let id: String
    let fields: ArtistFields
}

struct ArtistFields: Codable {
    let artistName: String?
    let videoURLs: [String]?
    let videoTitle: [String]?
    let videoYear: [String]?
    let videoThumbnail: [String]?
    let videoDuration: [String]?
    
    enum CodingKeys: String, CodingKey {
        case artistName = "artistName"
        case videoURLs = "VideoURLs"
        case videoTitle = "VideoTitle"
        case videoYear = "VideoYear"
        case videoThumbnail = "videoThumbnail"
        case videoDuration = "videoDuration"
    }
}

// MARK: - Live Show Video Airtable Response Models (keeping for compatibility)
struct LiveShowVideoAirtableResponse: Codable {
    let records: [LiveShowVideoRecord]
}

struct LiveShowVideoRecord: Codable {
    let id: String
    let fields: LiveShowVideoRecordFields
}

struct LiveShowVideoRecordFields: Codable {
    let title: String?
    let year: String?
    let url: String?
    let videoImage: String?
    let videoLength: String?
    let artistName: [String]?
    
    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case year = "Year"
        case url = "URL"
        case videoImage = "videoImage"
        case videoLength = "videoLength"
        case artistName = "artistName"
    }
}

// MARK: - Category Model & API Functions
struct Category {
    let id: String
    let fields: CategoryFields
}

struct CategoryFields {
    let categoryName: String
    let categoryImage: [CategoryAttachment]?
    let color: String?
    let artistNames: [String]?
}

struct CategoryAttachment {
    let id: String
    let url: String
    let filename: String
}

// Function to fetch and arrange categories from Airtable
func sortAndArrangeCategories(completion: @escaping (Result<[Category], Error>) -> Void) {
    guard let url = URL(string: "https://api.airtable.com/v0/appxCBIOkiJEZiph7/Category") else {
        completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
            return
        }
        
        do {
            let airtableResponse = try JSONDecoder().decode(CategoryAirtableResponse.self, from: data)
            let categories = airtableResponse.records.map { record in
                Category(
                    id: record.id,
                    fields: CategoryFields(
                        categoryName: record.fields.categoryName ?? "Unknown Category",
                        categoryImage: record.fields.categoryImage?.map { attachment in
                            CategoryAttachment(
                                id: attachment.id,
                                url: attachment.url,
                                filename: attachment.filename
                            )
                        },
                        color: record.fields.color,
                        artistNames: record.fields.artistNames
                    )
                )
            }
            completion(.success(categories))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}

// MARK: - Airtable Response Models
struct CategoryAirtableResponse: Codable {
    let records: [CategoryRecord]
}

struct CategoryRecord: Codable {
    let id: String
    let fields: CategoryRecordFields
}

struct CategoryRecordFields: Codable {
    let categoryName: String?
    let categoryImage: [CategoryAttachmentRecord]?
    let color: String?
    let artistNames: [String]?
    
    enum CodingKeys: String, CodingKey {
        case categoryName = "CategoryName"
        case categoryImage = "CategoryImage"
        case color = "Color"
        case artistNames = "ArtistNames"
    }
}

struct CategoryAttachmentRecord: Codable {
    let id: String
    let url: String
    let filename: String
}

// MARK: - Search Models and Service
struct SearchResult {
    let id: String
    let title: String
    let artistName: String
    let year: String
    let url: String
    let videoImage: String
    let type: SearchResultType
    let matchType: SearchMatchType
    let relevanceScore: Int
}

enum SearchResultType {
    case video
    case mtvVideo
}

enum SearchMatchType {
    case artistName
    case songTitle
    case both
}

struct SearchResponse: Codable {
    let records: [SearchRecord]
}

struct SearchRecord: Codable {
    let id: String
    let fields: SearchFields
}

struct SearchFields: Codable {
    let title: String?
    let artistName: String?
    let year: String?
    let url: String?
    let videoImage: String?
    
    var Title: String? { return title }
    var Year: String? { return year }
    var URL: String? { return url }
    
    private enum CodingKeys: String, CodingKey {
        case title = "title"
        case artistName = "artistName"
        case year = "year"
        case url = "url"
        case videoImage = "videoImage"
        case Title = "Title"
        case Year = "Year"
        case URL = "URL"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = (try? container.decode(String.self, forKey: .title)) ?? 
                (try? container.decode(String.self, forKey: .Title))
        
        if let artistNameString = try? container.decode(String.self, forKey: .artistName) {
            artistName = artistNameString
        } else if let artistNameArray = try? container.decode([String].self, forKey: .artistName) {
            artistName = artistNameArray.first
        } else {
            artistName = nil
        }
        
        if let yearInt = try? container.decode(Int.self, forKey: .year) {
            year = String(yearInt)
        } else if let yearString = try? container.decode(String.self, forKey: .year) {
            year = yearString
        } else if let yearString = try? container.decode(String.self, forKey: .Year) {
            year = yearString
        } else {
            year = nil
        }
        
        url = (try? container.decode(String.self, forKey: .url)) ?? 
              (try? container.decode(String.self, forKey: .URL))
        
        videoImage = try? container.decode(String.self, forKey: .videoImage)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(artistName, forKey: .artistName)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(videoImage, forKey: .videoImage)
    }
}

class SearchService {
    static let shared = SearchService()
    private let apiKey = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
    private let baseId = "appxCBIOkiJEZiph7"
    
    private init() {}
    
    func searchArtists(query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        let group = DispatchGroup()
        var allResults: [SearchResult] = []
        var searchError: Error?
        
        group.enter()
        searchInVideosTable(query: query) { result in
            switch result {
            case .success(let results):
                allResults.append(contentsOf: results)
            case .failure(let error):
                searchError = error
            }
            group.leave()
        }
        
        group.enter()
        searchInMTvVideosTable(query: query) { result in
            switch result {
            case .success(let results):
                allResults.append(contentsOf: results)
            case .failure(let error):
                if searchError == nil {
                    searchError = error
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let error = searchError {
                completion(.failure(error))
            } else {
                // Sort by relevance score (descending), then by artist name (ascending)
                let sortedResults = allResults.sorted { result1, result2 in
                    if result1.relevanceScore != result2.relevanceScore {
                        return result1.relevanceScore > result2.relevanceScore
                    }
                    return result1.artistName < result2.artistName
                }
                completion(.success(sortedResults))
            }
        }
    }
    
    private func searchInVideosTable(query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        // Search both artist names and song titles with OR condition
        let formula = "OR(FIND(UPPER('\(query)'), UPPER(ARRAYJOIN({artistName}, ', '))), FIND(UPPER('\(query)'), UPPER({title})))"
        let urlString = "https://api.airtable.com/v0/\(baseId)/Videos?filterByFormula=\(formula.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        performSearch(urlString: urlString, type: .video, query: query, completion: completion)
    }
    
    private func searchInMTvVideosTable(query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        // Search both artist names and song titles with OR condition
        let formula = "OR(FIND(UPPER('\(query)'), UPPER({artistName})), FIND(UPPER('\(query)'), UPPER({Title})))"
        let urlString = "https://api.airtable.com/v0/\(baseId)/MTvVideos?filterByFormula=\(formula.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        performSearch(urlString: urlString, type: .mtvVideo, query: query, completion: completion)
    }
    
    private func performSearch(urlString: String, type: SearchResultType, query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        print("🌐 API URL (\(type)): \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        print("🚀 Making API request to: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error (\(type)): \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status (\(type)): \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ No data received (\(type))")
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                }
                return
            }
            
            print("📥 Received \(data.count) bytes (\(type))")
            
            do {
                let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
                print("📊 Decoded \(searchResponse.records.count) records (\(type))")
                
                let results = searchResponse.records.compactMap { record -> SearchResult? in
                    guard let title = record.fields.title ?? record.fields.Title,
                          let artistName = record.fields.artistName,
                          let year = record.fields.year ?? record.fields.Year,
                          let url = record.fields.url ?? record.fields.URL else {
                        print("⚠️ Skipping record \(record.id) - missing required fields")
                        return nil
                    }
                    
                    // Determine match type and relevance score
                    let upperQuery = query.uppercased()
                    let upperArtist = artistName.uppercased()
                    let upperTitle = title.uppercased()
                    
                    let artistMatches = upperArtist.contains(upperQuery)
                    let titleMatches = upperTitle.contains(upperQuery)
                    
                    let matchType: SearchMatchType
                    var relevanceScore = 0
                    
                    if artistMatches && titleMatches {
                        matchType = .both
                        relevanceScore = 100 // Highest priority
                    } else if artistMatches {
                        matchType = .artistName
                        relevanceScore = 80
                        // Bonus for exact match or match at beginning
                        if upperArtist == upperQuery {
                            relevanceScore = 95
                        } else if upperArtist.hasPrefix(upperQuery) {
                            relevanceScore = 90
                        }
                    } else if titleMatches {
                        matchType = .songTitle
                        relevanceScore = 60
                        // Bonus for exact match or match at beginning
                        if upperTitle == upperQuery {
                            relevanceScore = 85
                        } else if upperTitle.hasPrefix(upperQuery) {
                            relevanceScore = 75
                        }
                    } else {
                        matchType = .songTitle // Default fallback
                        relevanceScore = 50
                    }
                    
                    print("✅ Created result: \(artistName) - \(title) (Match: \(matchType), Score: \(relevanceScore))")
                    return SearchResult(
                        id: record.id,
                        title: title,
                        artistName: artistName,
                        year: year,
                        url: url,
                        videoImage: record.fields.videoImage ?? "",
                        type: type,
                        matchType: matchType,
                        relevanceScore: relevanceScore
                    )
                }
                
                print("🎯 Final results count (\(type)): \(results.count)")
                
                DispatchQueue.main.async {
                    completion(.success(results))
                }
            } catch {
                print("❌ JSON decode error (\(type)): \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON (\(type)): \(jsonString)")
                }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

// MARK: - Search Result Cell
class SearchResultCell: UICollectionViewCell {
    
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = UIColor.darkGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "sf_pro-bold", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let artistLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "sf_pro-regular", size: 21) ?? UIFont.systemFont(ofSize: 21, weight: .regular)
        label.textColor = UIColor(hex: "#A789FD")
        label.numberOfLines = 1
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let yearLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "sf_pro-regular", size: 21) ?? UIFont.systemFont(ofSize: 21, weight: .regular)
        label.textColor = UIColor(hex: "#A789FD")
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let typeIndicator: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "sf_pro-regular", size: 21) ?? UIFont.systemFont(ofSize: 21, weight: .regular)
        label.textColor = UIColor(hex: "#A789FD")
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    var searchResult: SearchResult? {
        didSet {
            configure()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
        
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(artistLabel)
        contentView.addSubview(yearLabel)
        contentView.addSubview(typeIndicator)
        
        NSLayoutConstraint.activate([
            // Thumbnail takes full width at top, 16:9 aspect ratio
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 242), // 430 * (9/16) ≈ 242 for 16:9 ratio
            
            // Title below thumbnail
            titleLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            
            // Artist below title
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            artistLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            artistLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            
            // Year and Type indicator on same line at bottom
            yearLabel.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 2),
            yearLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            yearLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            typeIndicator.centerYAnchor.constraint(equalTo: yearLabel.centerYAnchor),
            typeIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])
    }
    
    private func configure() {
        guard let result = searchResult else { return }
        
        titleLabel.text = result.title
        artistLabel.text = result.artistName
        yearLabel.text = result.year
        typeIndicator.text = result.type == .video ? "Live" : "Top 100"
        
        loadImage(from: result.videoImage)
    }
    
    private func loadImage(from urlString: String) {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            thumbnailImageView.image = UIImage(systemName: "photo")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.thumbnailImageView.image = image
            }
        }.resume()
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                // Only scale and glow the thumbnail, not the text (like Live Shows)
                self.thumbnailImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.thumbnailImageView.layer.shadowColor = UIColor(hex: "#A789FD").cgColor
                self.thumbnailImageView.layer.shadowOffset = CGSize(width: 0, height: 0)
                self.thumbnailImageView.layer.shadowOpacity = 0.8
                self.thumbnailImageView.layer.shadowRadius = 10
            } else {
                self.thumbnailImageView.transform = .identity
                self.thumbnailImageView.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
    
    override var canBecomeFocused: Bool {
        return true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        titleLabel.text = nil
        artistLabel.text = nil
        yearLabel.text = nil
        typeIndicator.text = nil
    }
}

// MARK: - Search View Controller
class SearchViewController: UIViewController {
    
    private let searchTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Search for artists..."
        textField.textColor = UIColor.white
        textField.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor(hex: "#A789FD").cgColor
        textField.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1)) // Left padding
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // Ensure placeholder text is also visible
        textField.attributedPlaceholder = NSAttributedString(
            string: "Search for artists...",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        )
        
        return textField
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Search Artists"
        label.font = UIFont.boldSystemFont(ofSize: 32)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 450, height: 320)  // 4 columns with metadata below thumbnails
        layout.minimumLineSpacing = 20  // Space below each video
        layout.minimumInteritemSpacing = 10  // Space between columns
        layout.sectionInset = UIEdgeInsets(top: 20, left: 40, bottom: 20, right: 40)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(SearchResultCell.self, forCellWithReuseIdentifier: "SearchResultCell")
        collectionView.remembersLastFocusedIndexPath = true
        return collectionView
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = UIColor(hex: "#A789FD")
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No results found"
        label.font = UIFont.systemFont(ofSize: 20)
        label.textColor = .lightGray
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    

    
    private var searchResults: [SearchResult] = []
    private var searchTimer: Timer?
    private let searchService = SearchService.shared
    
    private let safeCustomPatterns = [
        "\\b[cs]\\s*&&\\s*[adf]\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
        "\\b[a-zA-Z0-9]+\\s*&&\\s*[a-zA-Z0-9]+\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
        "(?:\\b|[^a-zA-Z0-9$])([a-zA-Z0-9$]{2})\\s*=\\s*function\\(\\s*a\\s*\\)\\s*\\{\\s*a\\s*=\\s*a\\.split\\(\\s*\"\"\\s*\\)"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupSearchTextField()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // MTV logo imageView setup (same as other screens)
        let logoImageView = UIImageView(image: UIImage(named: "logoVector"))
        logoImageView.contentMode = .scaleAspectFill
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        
        view.addSubview(titleLabel)
        view.addSubview(searchTextField)
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 152),
            logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            logoImageView.widthAnchor.constraint(equalToConstant: 98),
            logoImageView.heightAnchor.constraint(equalToConstant: 77),
            
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            searchTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            searchTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            searchTextField.widthAnchor.constraint(equalToConstant: 500),
            searchTextField.heightAnchor.constraint(equalToConstant: 44),
            
            collectionView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    private func setupSearchTextField() {
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)
    }
    
    private func performSearch(query: String) {
        print("🔍 Search triggered with query: '\(query)'")
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔍 Empty query, clearing results")
            searchResults = []
            updateUI()
            return
        }
        
        print("🔍 Starting search for: '\(query)'")
        showLoadingState()
        
        searchService.searchArtists(query: query) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoadingState()
                
                switch result {
                case .success(let results):
                    print("✅ Search successful! Found \(results.count) results")
                    for (index, result) in results.enumerated() {
                        print("  \(index + 1). \(result.artistName) - \(result.title) (\(result.type))")
                    }
                    self?.searchResults = results
                    self?.updateUI()
                case .failure(let error):
                    print("❌ Search error: \(error)")
                    self?.searchResults = []
                    self?.updateUI()
                    self?.showErrorAlert(message: "Failed to search. Please try again.")
                }
            }
        }
    }
    
    private func showLoadingState() {
        loadingIndicator.startAnimating()
        emptyStateLabel.isHidden = true
        collectionView.isHidden = true
    }
    
    private func hideLoadingState() {
        loadingIndicator.stopAnimating()
    }
    
    private func updateUI() {
        collectionView.reloadData()
        
        if searchResults.isEmpty {
            if searchTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                emptyStateLabel.isHidden = true
                collectionView.isHidden = true
            } else {
                emptyStateLabel.isHidden = false
                collectionView.isHidden = true
            }
        } else {
            emptyStateLabel.isHidden = true
            collectionView.isHidden = false
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func playVideo(with url: String) {
        guard let videoId = extractVideoId(from: url) else {
            showErrorAlert(message: "Invalid video URL")
            return
        }
        
        getVideoWithFixedPatterns(videoIdentifier: videoId) { [weak self] video, error in
            DispatchQueue.main.async {
                if let video = video, let streamURL = video.streamURL {
                    let player = AVPlayer(url: streamURL)
                    let playerViewController = AVPlayerViewController()
                    playerViewController.player = player
                    
                    self?.present(playerViewController, animated: true) {
                        player.play()
                    }
                } else {
                    self?.showErrorAlert(message: "Failed to load video")
                }
            }
        }
    }
    
    private func extractVideoId(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else {
            return nil
        }
        
        return queryItems.first(where: { $0.name == "v" })?.value
    }
    
    private func getVideoWithFixedPatterns(videoIdentifier: String, completion: @escaping (XCDYouTubeVideo?, Error?) -> Void) {
        XCDYouTubeClient.default().getVideoWithIdentifier(videoIdentifier) { video, error in
            if let error = error as NSError?, error.code == -1000 { // Use numeric error code instead
                // Custom pattern methods are not available on tvOS
                // XCDYouTubeClient.default().setLanguageIdentifier("en")
                // for pattern in self.safeCustomPatterns {
                //     XCDYouTubeClient.default().setCustomPatternMatching(pattern, forKey: "patternMatchingKey")
                // }
                
                XCDYouTubeClient.default().getVideoWithIdentifier(videoIdentifier, completionHandler: completion)
            } else {
                completion(video, error)
            }
        }
    }
    
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if searchResults.isEmpty {
            return [searchTextField]
        } else {
            return [collectionView]
        }
    }
    
    @objc private func searchTextChanged(_ textField: UITextField) {
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            if let text = textField.text {
                self?.performSearch(query: text)
            }
        }
    }
}

extension SearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text {
            performSearch(query: text)
        }
        return true
    }
}

extension SearchViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchResultCell", for: indexPath) as! SearchResultCell
        cell.searchResult = searchResults[indexPath.item]
        return cell
    }
}

extension SearchViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let result = searchResults[indexPath.item]
        playVideo(with: result.url)
    }
}

// AVPlayerViewControllerDelegate methods are not available on tvOS

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        // If scanning fails, default to clear color
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            self.init(red: 0, green: 0, blue: 0, alpha: 0)
            return
        }

        self.init(red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgb & 0x0000FF) / 255.0,
                  alpha: 1.0)
    }
} 
