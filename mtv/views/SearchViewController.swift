import UIKit
// import XCDYouTubeKit // Removed
import YouTubeKit // Added
import AVKit
import RevenueCat

class SearchViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UITextFieldDelegate {
    
    // MARK: - UI Elements
    private let searchTextField: FocusableSearchTextField = {
        let textField = FocusableSearchTextField()
        textField.placeholder = "Search"
        textField.textColor = .white
        textField.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor(hex: "#A789FD").cgColor
        textField.font = UIFont.systemFont(ofSize: 18)
        textField.textAlignment = .left
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.attributedPlaceholder = NSAttributedString(
            string: "Search",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        )
        return textField
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Search"
        label.font = UIFont.boldSystemFont(ofSize: 32)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 30
        layout.minimumLineSpacing = 40
        // Calculate item size for 4 columns using full width
        let screenWidth = UIScreen.main.bounds.width
        let totalHorizontalPadding: CGFloat = 80 // 40 on each side
        let totalSpacing: CGFloat = 3 * 30 // 3 spaces between 4 items
        let availableWidth = screenWidth - totalHorizontalPadding - totalSpacing
        let itemWidth = availableWidth / 4
        let itemHeight: CGFloat = 380 // Match LegendaryShowsViewController
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
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
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "logoVector"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Properties
    private var searchResults: [SearchResult] = []
    private var searchTimer: Timer?
    private let searchService = SearchService.shared
    private var isSubscribed: Bool = false
    
    // MARK: - Lifecycle
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // Custom initialization if needed for tvOS
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // Custom initialization if needed for tvOS
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Add logo to the top left
        view.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 152),
            logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            logoImageView.widthAnchor.constraint(equalToConstant: 98),
            logoImageView.heightAnchor.constraint(equalToConstant: 77)
        ])
        
        view.addSubview(titleLabel)
        view.addSubview(searchTextField)
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            searchTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            searchTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            searchTextField.widthAnchor.constraint(equalToConstant: 600),
            searchTextField.heightAnchor.constraint(equalToConstant: 60),
            
            collectionView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        setupCollectionView()
        setupSearchTextField()
        checkSubscriptionStatus()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Set focus to search bar initially
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }
    
    // MARK: - Setup
    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    private func setupSearchTextField() {
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)
    }
    
    // MARK: - Search Methods
    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            updateUI()
            return
        }
        
        showLoadingState()
        
        searchService.searchArtists(query: query) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoadingState()
                
                switch result {
                case .success(let results):
                    self?.searchResults = results
                    self?.updateUI()
                case .failure(let error):
                    print("Search error: \(error)")
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
    
    // MARK: - Video Playback
    private func playVideo(with url: String) {
        guard let videoId = extractVideoId(from: url) else {
            showErrorAlert(message: "Invalid video URL")
            return
        }

        print("SearchViewController: Requesting stream from YouTubePlayerService for ID: \(videoId)")
        let loadingIndicatorView = UIActivityIndicatorView(style: .large)
        loadingIndicatorView.color = .white
        loadingIndicatorView.center = self.view.center
        self.view.addSubview(loadingIndicatorView)
        loadingIndicatorView.startAnimating()

        let playerViewController = AVPlayerViewController()
        playerViewController.delegate = self
        playerViewController.modalPresentationStyle = .fullScreen

        YouTubePlayerService.shared.getPlayableStreamURL(for: videoId) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                loadingIndicatorView.stopAnimating()
                loadingIndicatorView.removeFromSuperview()

                switch result {
                case .success(let streamURL):
                    print("SearchViewController: YouTubePlayerService returned URL: \(streamURL) for video ID: \(videoId)")
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController.player = avPlayer
                    self.present(playerViewController, animated: true) {
                        avPlayer.play()
                    }
                case .failure(let error):
                    print("🚫 SearchViewController: YouTubePlayerService failed for video ID \(videoId). Error: \(error.localizedDescription)")
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }

    private func handlePotentialPlaylist(with url: String) {
        if isPlaylistURL(url) {
            playPlaylist(with: url)
        } else {
            playVideo(with: url) // This is for single videos
        }
    }

    private func isPlaylistURL(_ url: String) -> Bool {
        return url.contains("playlist?list=") || url.contains("&list=")
    }

    private func playPlaylist(with url: String) {
        guard let playlistId = extractPlaylistId(from: url) else {
            print("🌟 Could not extract playlist ID from URL: \(url)")
            showErrorAlert(message: "Invalid playlist URL.")
            return
        }
        
        print("🌟 Playing playlist with ID: \(playlistId)")
        
        let loadingIndicatorView = UIActivityIndicatorView(style: .large)
        loadingIndicatorView.color = .white
        loadingIndicatorView.center = view.center
        self.view.addSubview(loadingIndicatorView)
        loadingIndicatorView.startAnimating()
        
        fetchPlaylistVideoIds(playlistId: playlistId) { [weak self] videoIds in
            DispatchQueue.main.async {
                loadingIndicatorView.stopAnimating()
                loadingIndicatorView.removeFromSuperview()
                
                if videoIds.isEmpty {
                    print("🌟 No videos found in playlist")
                    self?.showErrorAlert(message: "No videos found in the playlist.")
                    return
                }
                
                print("🌟 Starting playlist playback with \(videoIds.count) videos")
                self?.playVideoPlaylist(videoIdentifiers: videoIds)
            }
        }
    }
    
    private func extractPlaylistId(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "list" })?.value
    }

    private func fetchPlaylistVideoIds(playlistId: String, completion: @escaping ([String]) -> Void) {
        // Using the API key found in LegendaryShowsViewController
        let apiKey = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
        let urlString = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=\(playlistId)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("🌟 Invalid YouTube API URL for playlist items")
            completion([])
            return
        }
        
        print("🌟 Fetching playlist videos from: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("🌟 Error fetching playlist items: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("🌟 No data received from YouTube API for playlist items")
                completion([])
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["items"] as? [[String: Any]] {
                    
                    let videoIds = items.compactMap { item -> String? in
                        guard let snippet = item["snippet"] as? [String: Any],
                              let resourceId = snippet["resourceId"]as? [String: Any],
                              let videoId = resourceId["videoId"] as? String else {
                            return nil
                        }
                        return videoId
                    }
                    print("🌟 Successfully extracted \(videoIds.count) video IDs from playlist")
                    completion(videoIds)
                } else {
                    print("🌟 Failed to parse YouTube API response for playlist items")
                    completion([])
                }
            } catch {
                print("🌟 Error parsing YouTube API response for playlist items: \(error.localizedDescription)")
                completion([])
            }
        }.resume()
    }

    func playVideoPlaylist(videoIdentifiers: [String], currentIndex: Int = 0) {
        guard currentIndex < videoIdentifiers.count else {
            print("🌟 Playlist finished - all videos played")
            return
        }
        
        let loadingIndicatorView = UIActivityIndicatorView(style: .large)
        loadingIndicatorView.color = .white
        loadingIndicatorView.center = view.center
        self.view.addSubview(loadingIndicatorView)
        loadingIndicatorView.startAnimating()
        
        let playerViewController = AVPlayerViewController()
        playerViewController.delegate = self
        playerViewController.modalPresentationStyle = .fullScreen
        
        let currentVideoIdentifier = videoIdentifiers[currentIndex]
        
        print("SearchViewController (Playlist): Requesting stream from YouTubePlayerService for ID: \(currentVideoIdentifier)")
        
        YouTubePlayerService.shared.getPlayableStreamURL(for: currentVideoIdentifier) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                loadingIndicatorView.stopAnimating()
                loadingIndicatorView.removeFromSuperview()

                switch result {
                case .success(let streamURL):
                    print("SearchViewController (Playlist): YouTubePlayerService returned URL: \(streamURL) for video ID: \(currentVideoIdentifier)")
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController.player = avPlayer
                    self.present(playerViewController, animated: true) {
                        avPlayer.play()
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main) { [weak self, weak playerViewController] _ in
                            NotificationCenter.default.removeObserver(self as Any, name: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem)
                            playerViewController?.dismiss(animated: true) {
                                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                            }
                        }
                    }
                case .failure(let error):
                    print("🚫 SearchViewController (Playlist): YouTubePlayerService failed for video ID \(currentVideoIdentifier). Error: \(error.localizedDescription)")
                    let alert = UIAlertController(title: "Playback Error", message: "Video \(currentVideoIdentifier) is unplayable: \(error.localizedDescription). Skipping to next.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                        self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                    }))
                    self.present(alert, animated: true, completion: nil)
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
    
    // MARK: - Focus Management
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
    
    // MARK: - Subscription Management
    private func checkSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            if let customerInfo = customerInfo {
                self?.isSubscribed = customerInfo.entitlements["lifetime"]?.isActive == true
            } else {
                self?.isSubscribed = false
            }
        }
    }
    
    private func navigateToPurchases() {
        let purchasesViewController = PurchasesViewController()
        purchasesViewController.modalPresentationStyle = .fullScreen
        present(purchasesViewController, animated: true, completion: nil)
    }
}

// MARK: - UICollectionViewDataSource
extension SearchViewController {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchResultCell", for: indexPath) as! SearchResultCell
        cell.searchResult = searchResults[indexPath.item]
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension SearchViewController {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedResult = searchResults[indexPath.item]
        
        requireSubscription(on: self) { [weak self] isSubscribed in
            guard let self = self, isSubscribed else { return }
            
            let videoURL = selectedResult.url // url is not optional
            switch selectedResult.type {
            case .video:
                self.handlePotentialPlaylist(with: videoURL)
            case .mtvVideo: // Assuming mtvVideo can also be a playlist or single video
                self.handlePotentialPlaylist(with: videoURL)
            // No default needed if all enum cases are handled
            }
        }
    }
}

// MARK: - AVPlayerViewControllerDelegate
extension SearchViewController: AVPlayerViewControllerDelegate {
    // Methods not available on tvOS
}

// MARK: - UITextFieldDelegate
extension SearchViewController {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text {
            performSearch(query: text)
        }
        return true
    }
} 