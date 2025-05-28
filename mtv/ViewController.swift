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
            title: "Live", 
            image: UIImage(systemName: "music.mic"),
            tag: 1
        )
        
        // Create Legendary Shows tab
        let legendaryShowsController = LegendaryShowsViewController()
        legendaryShowsController.tabBarItem = UITabBarItem(
            title: "Legendary Shows",
            image: UIImage(systemName: "star.fill"),
            tag: 2
        )
        
        // Create Search tab
        let searchController = SearchViewController(nibName: nil, bundle: nil)
        searchController.tabBarItem = UITabBarItem(
            title: "Search",
            image: UIImage(systemName: "magnifyingglass"),
            tag: 3
        )
        
        // Create Settings tab
        let settingsController = SettingsViewController()
        settingsController.tabBarItem = UITabBarItem(
            title: nil,
            image: nil,
            selectedImage: nil
        )
        // Use only the gear emoji as the tab bar item
        settingsController.tabBarItem.title = "⚙️"
        
        // Add controllers to tab bar (Legendary Shows after Live Shows)
        tabBarController.viewControllers = [musicVideosController, liveShowsController, legendaryShowsController, searchController, settingsController]
        
        // Set up the tab bar appearance for tvOS
        tabBarController.tabBar.isTranslucent = true
        tabBarController.tabBar.barTintColor = UIColor.black.withAlphaComponent(0.8)
        tabBarController.tabBar.tintColor = UIColor.white
        
        // Add as child view controller
        addChild(tabBarController)
        tabBarController.view.frame = view.bounds
        // Offset the tab bar to the right to avoid overlapping the logo
        let leftMargin: CGFloat = 250 // Adjust as needed to match logo width + padding
        let tabBarHeight = tabBarController.tabBar.frame.height
        let tabBarY = tabBarController.tabBar.frame.origin.y
        let tabBarWidth = view.bounds.width - leftMargin
        tabBarController.tabBar.frame = CGRect(x: leftMargin, y: tabBarY, width: tabBarWidth, height: tabBarHeight)
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
                    // Pre-select the Pop category if available
                    if let popIndex = self.categories.firstIndex(where: { $0.fields.categoryName.lowercased().contains("pop") }) {
                        self.selectedCategory = self.categories[popIndex]
                        self.selectedBannerIndex = popIndex
                        let unsortedArtists = self.selectedCategory?.fields.artistNames ?? []
                        self.currentArtists = unsortedArtists.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                        self.isShowingArtists = true
                        self.categoryTableView.reloadData()
                        self.categoryCollectionView.reloadData()
                        // Auto-select the back button initially
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            let backButtonIndexPath = IndexPath(row: 0, section: 0)
                            self.categoryTableView.selectRow(at: backButtonIndexPath, animated: false, scrollPosition: .none)
                        }
                    }
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
    
    // Handle remote back/menu button to show category grid
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu || $0.type == .playPause }) {
            // If currently showing artists or videos, go back to category grid
            if isShowingArtists || isShowingVideos {
                isShowingArtists = false
                isShowingVideos = false
                selectedCategory = nil
                selectedArtist = nil
                currentArtists = []
                currentVideos = []
                selectedCategoryIndex = nil
                selectedBannerIndex = nil
                categoryTableView.reloadData()
                categoryCollectionView.reloadData()
                updateCollectionViewLayout(forVideos: false)
                return // Don't call super, we handled it
            }
        }
        super.pressesBegan(presses, with: event)
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
                cell.textLabel?.text = "Back to Categories ->"
                cell.textLabel?.textColor = UIColor(hex: "#A789FD")
                cell.textLabel?.font = UIFont.systemFont(ofSize: 25, weight: .medium)
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
                    // Check if this is the "Back to Categories" button (row 0 when showing artists)
                    if self.isShowingArtists && nextFocusedIndexPath.row == 0 {
                        // Special styling for back button: black text on purple background
                        nextFocusedCell.contentView.backgroundColor = UIColor(hex: "#A789FD")
                        nextFocusedCell.textLabel?.textColor = .black
                    } else {
                        // Normal styling for artist names
                        nextFocusedCell.contentView.backgroundColor = UIColor(hex: "#A789FD")
                        nextFocusedCell.textLabel?.textColor = .white
                    }
                    nextFocusedCell.contentView.transform = CGAffineTransform.identity
                }
            }
            if let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath {
                if let previouslyFocusedCell = tableView.cellForRow(at: previouslyFocusedIndexPath) {
                    previouslyFocusedCell.contentView.backgroundColor = UIColor.clear
                    // Restore original text color
                    if self.isShowingArtists && previouslyFocusedIndexPath.row == 0 {
                        // Back button: restore purple text
                        previouslyFocusedCell.textLabel?.textColor = UIColor(hex: "#A789FD")
                    } else {
                        // Artist names: restore white text
                        previouslyFocusedCell.textLabel?.textColor = .white
                    }
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
            // Video selected - require subscription before playing
            let selectedVideo = currentVideos[indexPath.item]
            requireSubscription(on: self) { [weak self] isSubscribed in
                guard let self = self else { return }
                if isSubscribed {
                    self.playLiveShowVideo(url: selectedVideo.fields.url)
                } else {
                    // Paywall will be shown by requireSubscription
                }
            }
        } else {
            // Banner selected - switch sidebar to show artists for this category
            let selectedCategoryData = categories[indexPath.item]
            selectedCategory = selectedCategoryData
            selectedBannerIndex = indexPath.item // Track selected banner
            
            // Sort artists alphabetically before displaying
            let unsortedArtists = selectedCategoryData.fields.artistNames ?? []
            currentArtists = unsortedArtists.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            
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
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            
            // Year and Duration on same line
            yearLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
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

// MARK: - Focusable Search TextField
class FocusableSearchTextField: UITextField {
    
    override var canBecomeFocused: Bool {
        return true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextField()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextField()
    }
    
    private func setupTextField() {
        // Remove all default borders and styling
        borderStyle = .none
        layer.masksToBounds = true
        
        // Ensure no internal views or borders
        leftView = nil
        rightView = nil
        leftViewMode = .never
        rightViewMode = .never
        
        // Clear any default appearance
        clearButtonMode = .never
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                // Focused state: brighter purple background and centered glowing border
                self.backgroundColor = UIColor(hex: "#A789FD").withAlphaComponent(0.3)
                self.layer.borderColor = UIColor(hex: "#A789FD").cgColor
                self.layer.borderWidth = 3
                self.layer.shadowColor = UIColor(hex: "#A789FD").cgColor
                self.layer.shadowOffset = CGSize.zero  // Center the glow
                self.layer.shadowOpacity = 0.8
                self.layer.shadowRadius = 15
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } else {
                // Unfocused state: return to original styling
                self.backgroundColor = UIColor.black.withAlphaComponent(0.8)
                self.layer.borderColor = UIColor(hex: "#A789FD").cgColor
                self.layer.borderWidth = 1
                self.layer.shadowOpacity = 0
                self.transform = CGAffineTransform.identity
            }
        }, completion: nil)
    }
    
    // Add proper text padding without using leftView
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 20, dy: 0)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 20, dy: 0)
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 20, dy: 0)
    }
    
    // Override to ensure no internal drawing
    override func draw(_ rect: CGRect) {
        // Don't call super.draw to avoid any default rendering
        // The background and border are handled by layer properties
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
