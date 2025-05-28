import UIKit
import RevenueCat
import XCDYouTubeKit
import AVKit

class PlayListViewController: UIViewController, AVPlayerViewControllerDelegate {

    // MARK: - Properties

    // Custom patterns to work around window.location.hostname.split error
    private let safeCustomPatterns = [
        "\\b[cs]\\s*&&\\s*[adf]\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
        "\\b[a-zA-Z0-9]+\\s*&&\\s*[a-zA-Z0-9]+\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
        "(?:\\b|[^a-zA-Z0-9$])([a-zA-Z0-9$]{2})\\s*=\\s*function\\(\\s*a\\s*\\)\\s*\\{\\s*a\\s*=\\s*a\\.split\\(\\s*\"\"\\s*\\)"
    ]

    private var playlists: [Playlist] = []
    private var selectedPlaylistIndex: Int?
    private var visibleVideoIndices: [Int] = []
    private var lastSelectedYearIndex: IndexPath?
    private var isSubscribed: Bool = false

    // Store last focused index paths
    private var lastFocusedYearIndexPath: IndexPath?
    private var lastFocusedVideoIndexPath: IndexPath?

    private var playlistTableView: UITableView!
    private var playlistImagesCollectionView: UICollectionView!
    private var loadingIndicator: UIActivityIndicatorView!

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showLoadingIndicator()
        fetchPlaylists()
        checkSubscriptionStatus()

        // Add observer for subscription status change
        NotificationCenter.default.addObserver(self, selector: #selector(subscriptionStatusChanged), name: Notification.Name("SubscriptionStatusChanged"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        checkSubscriptionStatus {
            // After subscription status is updated
            if let lastSelectedIndex = self.lastSelectedYearIndex {
                self.playlistTableView.scrollToRow(at: lastSelectedIndex, at: .middle, animated: false)
                self.playlistImagesCollectionView.reloadData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.playlistTableView.selectRow(at: lastSelectedIndex, animated: false, scrollPosition: .none)
                    self.selectedPlaylistIndex = lastSelectedIndex.row
                    self.updateUIForSelectedPlaylist()
                }
            } else {
                // Try to select the first available playlist
                self.selectFirstAvailablePlaylist()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Ensure the table view has laid out its cells
        playlistTableView.layoutIfNeeded()
        // Update focus after view has appeared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
        }
    }


    // MARK: - Focus Management

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let lastFocusedVideoIndexPath = lastFocusedVideoIndexPath,
           let videoCell = playlistImagesCollectionView.cellForItem(at: lastFocusedVideoIndexPath) {
            return [videoCell]
        } else if let lastFocusedYearIndexPath = lastFocusedYearIndexPath,
                  let yearCell = playlistTableView.cellForRow(at: lastFocusedYearIndexPath) {
            return [yearCell]
        } else if let firstAvailableIndex = lastSelectedYearIndex,
                  let firstYearCell = playlistTableView.cellForRow(at: firstAvailableIndex) {
            return [firstYearCell]
        } else {
            return [] // No fallback focus on purchaseButton
        }
    }

    class FocusableButton: UIButton {
        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            super.didUpdateFocus(in: context, with: coordinator)
            
            coordinator.addCoordinatedAnimations({
                if self.isFocused {
                    self.backgroundColor = UIColor(hex: "#A789FD")
                    self.layer.cornerRadius = 15.0 // Set desired corner radius
                    self.layer.masksToBounds = true
                    self.setTitleColor(UIColor.black, for: .normal) // Change text color to black when focused
                } else {
                    self.backgroundColor = UIColor.black
                    self.layer.cornerRadius = 0.0
                    self.layer.masksToBounds = false
                    self.setTitleColor(UIColor(hex: "#A789FD"), for: .normal) // Revert text color to white when not focused
                }
            }, completion: nil)
        }
    }

    
    //      UIColor(hex: "#A789FD")

    private func setupUI() {
        view.backgroundColor = .black

        // MTV logo imageView setup
        let imageView = UIImageView(image: UIImage(named: "logoVector"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        // Playlist tableView setup
        playlistTableView = UITableView()
        playlistTableView.dataSource = self
        playlistTableView.delegate = self
        playlistTableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlaylistYear")
        view.addSubview(playlistTableView)
        playlistTableView.cellLayoutMarginsFollowReadableWidth = false
        playlistTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 152),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            imageView.widthAnchor.constraint(equalToConstant: 98),
            imageView.heightAnchor.constraint(equalToConstant: 77),
            playlistTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -51),
            playlistTableView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 50), // Adjusted spacing
            playlistTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            playlistTableView.widthAnchor.constraint(equalToConstant: 400)
        ])

        // Playlist images collectionView setup
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 32
        layout.itemSize = CGSize(width: 408, height: 288)

        playlistImagesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        playlistImagesCollectionView.backgroundColor = .clear
        playlistImagesCollectionView.dataSource = self
        playlistImagesCollectionView.delegate = self
        playlistImagesCollectionView.register(PlaylistImageCell.self, forCellWithReuseIdentifier: "PlaylistCell")
        view.addSubview(playlistImagesCollectionView)
        playlistImagesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playlistImagesCollectionView.leadingAnchor.constraint(equalTo: playlistTableView.trailingAnchor, constant: 70),
            playlistImagesCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playlistImagesCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            playlistImagesCollectionView.bottomAnchor.constraint(equalTo: playlistTableView.bottomAnchor)
        ])
    }

    // MARK: - Subscription Management

    private func checkSubscriptionStatus(completion: (() -> Void)? = nil) {
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            guard let self = self else { return }

            if let customerInfo = customerInfo {
                let activeEntitlements = customerInfo.entitlements.all.filter { $0.value.isActive }
                if !activeEntitlements.isEmpty {
                    self.isSubscribed = true
                } else {
                    self.isSubscribed = false
                }
            } else if let error = error {
                print("Error fetching customer info: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    @objc private func subscriptionStatusChanged() {
        checkSubscriptionStatus {
            self.updateUIForSelectedPlaylist()
        }
    }

    private func updateUIForSelectedPlaylist() {
        guard selectedPlaylistIndex != nil else {
            playlistImagesCollectionView.isHidden = true
            return
        }

        // Always show videos
        playlistImagesCollectionView.isHidden = false
        updateVisibleVideoIndices()
        playlistImagesCollectionView.reloadData()
    }

    private func selectFirstAvailablePlaylist() {
        // Try to select the first unlocked playlist
        for (index, playlist) in playlists.enumerated() {
            if isSubscribed || !(playlist.fields.isLocked ?? false) {
                selectedPlaylistIndex = index
                lastSelectedYearIndex = IndexPath(row: index, section: 0)
                lastFocusedYearIndexPath = lastSelectedYearIndex // Update the last focused year index path
                playlistTableView.selectRow(at: lastSelectedYearIndex, animated: false, scrollPosition: .none)
                updateUIForSelectedPlaylist()
                return
            }
        }
        // No available playlists
        selectedPlaylistIndex = nil
        lastSelectedYearIndex = nil
        lastFocusedYearIndexPath = nil
        updateUIForSelectedPlaylist()
    }

    // MARK: - Data Fetching

    func fetchPlaylists() {
        sortAndArrangePlaylists(apiKey: apiKey, baseURLString: playListUrl) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let playlists):
                self.playlists = playlists
                DispatchQueue.main.async {
                    self.playlistTableView.reloadData()
                    self.hideLoadingIndicator()

                    if !self.playlists.isEmpty {
                        // Automatically select the first available playlist if no selection has been made before
                        if self.selectedPlaylistIndex == nil {
                            self.selectFirstAvailablePlaylist()
                            // Ensure the first year is focused
                            self.lastFocusedYearIndexPath = self.lastSelectedYearIndex
                        }
                    }
                }
            case .failure(let error):
                print("Error fetching playlists: \(error)")
                self.hideLoadingIndicator()
            }
        }
    }

    private func updateVisibleVideoIndices() {
        guard let selectedPlaylistIndex = selectedPlaylistIndex else {
            visibleVideoIndices = []
            return
        }

        // Check if the selected playlist has visibility flags for its videos
        visibleVideoIndices = playlists[selectedPlaylistIndex].fields.isVisible.enumerated().compactMap { index, isVisible in
            isVisible ?? false ? index : nil
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
        loadingIndicator.stopAnimating()
        loadingIndicator.removeFromSuperview()
    }

    // MARK: - Video Playback

    // Helper method to get video with fixed patterns to avoid the hostname.split error
    private func getVideoWithFixedPatterns(videoIdentifier: String, completion: @escaping (XCDYouTubeVideo?, Error?) -> Void) {
        XCDYouTubeClient.default().getVideoWithIdentifier(
            videoIdentifier, 
            cookies: nil, 
            customPatterns: safeCustomPatterns, 
            completionHandler: completion
        )
    }

    func playVideoPlaylist(videoIdentifiers: [String], currentIndex: Int = 0) {
        guard currentIndex < videoIdentifiers.count else {
            return
        }
        
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        let playerViewController = AVPlayerViewController()
        playerViewController.delegate = self
        
        let currentVideoIdentifier = videoIdentifiers[currentIndex]
        
        print("Starting YouTube video playback for ID: \(currentVideoIdentifier)")
        
        // Use our local method instead of the extension
        getVideoWithFixedPatterns(videoIdentifier: currentVideoIdentifier) { [weak self, playerViewController] (video: XCDYouTubeVideo?, error: Error?) in
            loadingIndicator.stopAnimating()
            loadingIndicator.removeFromSuperview()

            if let error = error {
                print("YouTube playback error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("Error details: \(nsError.userInfo)")
                }
                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                return
            }
            
            guard let video = video else {
                print("YouTube video object is nil but no error reported")
                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                return
            }
            
            print("Got video with title: \(video.title)")
            print("Stream URLs available: \(video.streamURLs.keys)")
            
            let streamURLs = video.streamURLs
            if let streamURL = (streamURLs[XCDYouTubeVideoQualityHTTPLiveStreaming] ??
                                streamURLs[YouTubeVideoQuality.hd720] ??
                                streamURLs[YouTubeVideoQuality.medium360] ??
                                streamURLs[YouTubeVideoQuality.small240]) {
                
                print("Selected stream URL: \(streamURL)")

                DispatchQueue.main.async {
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController.player = avPlayer
                    self?.present(playerViewController, animated: true) {
                        avPlayer.play()
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: nil) { [weak self] _ in
                            playerViewController.dismiss(animated: true) {
                                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                            }
                        }
                    }
                }
            } else {
                print("No suitable stream URL found")
                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                return
            }
        }
    }

    func playVideo(videoIdentifier: String?) {
        guard let videoIdentifier = videoIdentifier else { return }
        
        let playerViewController = AVPlayerViewController()
        playerViewController.delegate = self
        
        print("Starting single YouTube video playback for ID: \(videoIdentifier)")

        DispatchQueue.main.async {
            self.present(playerViewController, animated: true, completion: nil)
        }
        
        // Use our local method instead of the extension
        getVideoWithFixedPatterns(videoIdentifier: videoIdentifier) { [weak playerViewController] (video: XCDYouTubeVideo?, error: Error?) in
            if let error = error {
                print("YouTube playback error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("Error details: \(nsError.userInfo)")
                }
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                }
                return
            }
            
            guard let video = video else {
                print("YouTube video object is nil but no error reported")
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                }
                return
            }
            
            print("Got video with title: \(video.title)")
            
            let streamURLs = video.streamURLs
            if let streamURL = (streamURLs[XCDYouTubeVideoQualityHTTPLiveStreaming] ??
                                streamURLs[YouTubeVideoQuality.hd720] ??
                                streamURLs[YouTubeVideoQuality.medium360] ??
                                streamURLs[YouTubeVideoQuality.small240]) {
                
                print("Selected stream URL: \(streamURL)")
                
                DispatchQueue.main.async {
                    playerViewController?.player?.automaticallyWaitsToMinimizeStalling = false
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController?.player = avPlayer
                    avPlayer.play()
                }
            } else {
                print("No suitable stream URL found")
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
        print("Play video ends")
    }
}

// MARK: - UITableViewDataSource and UITableViewDelegate

extension PlayListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistYear", for: indexPath)
        let playlist = playlists[indexPath.row]
        let yearText = String(playlist.fields.year)
        cell.textLabel?.text = yearText
        cell.textLabel?.font = UIFont(name: "sf_pro-regular", size: 30) ?? UIFont.systemFont(ofSize: 30, weight: .bold)
        cell.layer.cornerRadius = 10

        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor.black
        cell.selectedBackgroundView = bgColorView
        cell.layer.borderWidth = 0
        cell.layer.borderColor = UIColor.clear.cgColor

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let previousSelectedIndex = selectedPlaylistIndex,
           let previousSelectedCell = tableView.cellForRow(at: IndexPath(row: previousSelectedIndex, section: 0)) {
            previousSelectedCell.layer.borderWidth = 0
        }
        if let selectedCell = tableView.cellForRow(at: indexPath) {
            selectedCell.layer.borderWidth = 2
            selectedCell.layer.borderColor = UIColor(hex: "#A789FD").cgColor
        }
        selectedPlaylistIndex = indexPath.row
        lastSelectedYearIndex = indexPath // Update last selected index

        // Always show videos, regardless of lock status
        playlistImagesCollectionView.isHidden = false
        updateVisibleVideoIndices()
        playlistImagesCollectionView.reloadData()
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let deselectedCell = tableView.cellForRow(at: indexPath)
        deselectedCell?.layer.borderWidth = 0
        deselectedCell?.layer.borderColor = UIColor.clear.cgColor
    }

    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if let nextFocusedIndexPath = context.nextFocusedIndexPath {
                self.lastFocusedYearIndexPath = nextFocusedIndexPath
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
}

// MARK: - UICollectionViewDataSource and UICollectionViewDelegateFlowLayout

extension PlayListViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return visibleVideoIndices.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaylistCell", for: indexPath) as? PlaylistImageCell else {
            return UICollectionViewCell()
        }

        guard let selectedPlaylistIndex = selectedPlaylistIndex, selectedPlaylistIndex < playlists.count else {
            return cell
        }

        let visibleIndex = visibleVideoIndices[indexPath.item]

        if let videoURL = playlists[selectedPlaylistIndex].fields.videoUrls?[visibleIndex],
           let videoID = extractYouTubeVideoID(from: videoURL) {
            let thumbnailURLString = "https://i.ytimg.com/vi/\(videoID)/mqdefault.jpg"
            if let url = URL(string: thumbnailURLString) {
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            cell.imageView.image = image
                        }
                    }
                }.resume()
            }
            cell.titleLabel.text = playlists[selectedPlaylistIndex].fields.videoTitles?[visibleIndex]
            cell.artistNameLabel.text = playlists[selectedPlaylistIndex].fields.artistNames?[visibleIndex]
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let previouslySelectedIndexPath = collectionView.indexPathsForSelectedItems?.first {
            if let previouslySelectedCell = collectionView.cellForItem(at: previouslySelectedIndexPath) as? PlaylistImageCell {
                previouslySelectedCell.transform = CGAffineTransform.identity
                previouslySelectedCell.backgroundColor = .clear
            }
        }

        guard let selectedPlaylistIndex = selectedPlaylistIndex, selectedPlaylistIndex < playlists.count else {
            return
        }

        requireSubscription(on: self) { [weak self] isSubscribed in
            guard let self = self, isSubscribed else { return }
            let videoURL = self.playlists[selectedPlaylistIndex].fields.videoUrls?[self.visibleVideoIndices[indexPath.item]]
            if self.extractYouTubeVideoID(from: videoURL ?? "") != nil {
                let playlist = self.generatePlaylistFromSelectedVideo(selectedIndexPath: indexPath)
                self.playVideoPlaylist(videoIdentifiers: playlist)
            } else {
                print("Invalid YouTube video URL \(String(describing: videoURL))")
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if let nextFocusedIndexPath = context.nextFocusedIndexPath {
                self.lastFocusedVideoIndexPath = nextFocusedIndexPath
                if let nextFocusedCell = collectionView.cellForItem(at: nextFocusedIndexPath) as? PlaylistImageCell {
                    nextFocusedCell.backgroundColor = UIColor(hex: "292631")
                    nextFocusedCell.layer.cornerRadius = 10
                    nextFocusedCell.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                }
            }
            if let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath {
                if let previouslyFocusedCell = collectionView.cellForItem(at: previouslyFocusedIndexPath) as? PlaylistImageCell {
                    previouslyFocusedCell.backgroundColor = .clear
                    previouslyFocusedCell.transform = CGAffineTransform.identity
                }
            }
        }, completion: nil)
    }

    func generatePlaylistFromSelectedVideo(selectedIndexPath: IndexPath) -> [String] {
        guard let selectedPlaylistIndex = selectedPlaylistIndex, selectedPlaylistIndex < playlists.count else {
            return []
        }

        let videoUrls = playlists[selectedPlaylistIndex].fields.videoUrls ?? []
        let currentVideoIndex = visibleVideoIndices[selectedIndexPath.item]
        let totalVideos = videoUrls.count

        let startIndex = currentVideoIndex
        var endIndex = startIndex + totalVideos

        if endIndex > totalVideos {
            endIndex = totalVideos
        }

        var playlist: [String] = []
        for index in startIndex..<endIndex {
            playlist.append(extractYouTubeVideoID(from: videoUrls[index % totalVideos]) ?? "")
        }

        return playlist
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let padding: CGFloat = 50
        return UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
    }
}

// MARK: - Helper Methods

extension PlayListViewController {
    func extractYouTubeVideoID(from videoURL: String) -> String? {
        guard let url = URL(string: videoURL),
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return nil
        }

        for queryItem in queryItems {
            if queryItem.name.lowercased() == "v" {
                return queryItem.value
            }
        }

        return nil
    }
}
