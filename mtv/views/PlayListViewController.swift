import UIKit
// import RevenueCat // Temporarily commented out
import AVKit
import YouTubeKit

class PlayListViewController: UIViewController, AVPlayerViewControllerDelegate {

    // MARK: - Properties

    private var playlists: [Playlist] = []
    private var selectedPlaylistIndex: Int?
    private var visibleVideoIndices: [Int] = []
    private var lastSelectedYearIndex: IndexPath?
    // private var isSubscribed: Bool = false // Temporarily commented out
    private var isSubscribed: Bool = true // Assume subscribed for debugging

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
        // checkSubscriptionStatus() // Temporarily commented out
        print("PlayListViewController: checkSubscriptionStatus bypassed.")

        // Add observer for subscription status change
        // NotificationCenter.default.addObserver(self, selector: #selector(subscriptionStatusChanged), name: Notification.Name("SubscriptionStatusChanged"), object: nil) // Temporarily commented out
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // checkSubscriptionStatus { // Temporarily commented out
        // After subscription status is updated
        print("PlayListViewController: viewWillAppear - subscription check bypassed.")
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
        // } // End of commented out checkSubscriptionStatus completion
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
        // Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in // Temporarily commented out
        //     guard let self = self else { return }

        //     if let customerInfo = customerInfo {
        //         let activeEntitlements = customerInfo.entitlements.all.filter { $0.value.isActive }
        //         if !activeEntitlements.isEmpty {
        //             self.isSubscribed = true
        //         } else {
        //             self.isSubscribed = false
        //         }
        //     } else if let error = error {
        //         print("Error fetching customer info: \(error.localizedDescription)")
        //     }
        //     DispatchQueue.main.async {
        //         completion?()
        //     }
        // }
        print("PlayListViewController: checkSubscriptionStatus called - Bypassed, assuming subscribed.")
        isSubscribed = true // Assume subscribed
        DispatchQueue.main.async {
            completion?()
        }
    }

    @objc private func subscriptionStatusChanged() {
        // checkSubscriptionStatus { // Temporarily commented out
        //     self.updateUIForSelectedPlaylist()
        // }
        print("PlayListViewController: subscriptionStatusChanged called - Bypassed.")
        isSubscribed = true // Assume subscribed
        self.updateUIForSelectedPlaylist()
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
            // if isSubscribed || !(playlist.fields.isLocked ?? false) { // Original logic
            if true { // Simplified for debugging: assume all playlists are available
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
                
                // DEBUG: Log video IDs for each playlist to see what data we have
                for (playlistIndex, playlist) in playlists.enumerated() {
                    print("🎵 DEBUG PlayList \(playlistIndex): \(playlist.fields.title) (Year: \(playlist.fields.year))")
                    if let videoIds = playlist.fields.mtvVideos {
                        print("   📹 Total video entries: \(videoIds.count)")
                        let validVideoIds = videoIds.filter { !$0.isEmpty }
                        let emptyVideoIds = videoIds.filter { $0.isEmpty }
                        print("   ✅ Valid video IDs: \(validVideoIds.count)")
                        print("   ❌ Empty video IDs: \(emptyVideoIds.count)")
                        
                        // Show first few valid video IDs as examples
                        for (index, videoId) in videoIds.prefix(10).enumerated() {
                            if !videoId.isEmpty {
                                print("   ✅ Index \(index): \(videoId)")
                            } else {
                                print("   ❌ Index \(index): (empty)")
                            }
                        }
                        if videoIds.count > 10 {
                            let remainingValid = videoIds.dropFirst(10).filter { !$0.isEmpty }.count
                            let remainingEmpty = videoIds.dropFirst(10).filter { $0.isEmpty }.count
                            print("   ... and \(videoIds.count - 10) more entries (\(remainingValid) valid, \(remainingEmpty) empty)")
                        }
                    } else {
                        print("   ❌ No mtvVideos field found")
                    }
                }
                
                DispatchQueue.main.async {
                    self.playlistTableView.reloadData()
                    self.playlistImagesCollectionView.reloadData()
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
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                }
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

    // This is the method for playing a single video, which can be kept or removed if not used directly.
    // func playSingleVideoWithYouTubeKit(videoIdentifier: String) { ... current playVideoWithYouTubeKit logic ... }

    // New method to play a playlist of videos sequentially using YouTubeKit
    func playVideoPlaylist(videoIdentifiers: [String], currentIndex: Int = 0) {
        guard currentIndex < videoIdentifiers.count else {
            print("🌟 PlayListViewController: Playlist finished - all videos played")
            return
        }

        let currentVideoIdentifier = videoIdentifiers[currentIndex]
        guard !currentVideoIdentifier.isEmpty, currentVideoIdentifier != "placeholderVideoID" else { // Added check for placeholder
            print("🌟 PlayListViewController: Empty or placeholder video ID ('\(currentVideoIdentifier)') at index \(currentIndex), skipping.")
            // Skip to next video
            DispatchQueue.main.async {
                self.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
            }
            return
        }

        print("🌟 PlayListViewController: Requesting stream from YouTubePlayerService for ID: \(currentVideoIdentifier)")

        let loadingIndicatorView = UIActivityIndicatorView(style: .large)
        loadingIndicatorView.color = .white
        loadingIndicatorView.center = self.view.center
        self.view.addSubview(loadingIndicatorView)
        loadingIndicatorView.startAnimating()

        let playerViewController = AVPlayerViewController()
        playerViewController.delegate = self
        playerViewController.modalPresentationStyle = .fullScreen

        YouTubePlayerService.shared.getPlayableStreamURL(for: currentVideoIdentifier) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                loadingIndicatorView.stopAnimating()
                loadingIndicatorView.removeFromSuperview()

                switch result {
                case .success(let streamURL):
                    print("🌟 PlayListViewController (Playlist): YouTubePlayerService returned URL: \(streamURL) for video ID: \(currentVideoIdentifier)")
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
                    print("🚫 PlayListViewController (Playlist): YouTubePlayerService failed for video ID \(currentVideoIdentifier). Error: \(error.localizedDescription)")
                    let alert = UIAlertController(title: "Playback Error", message: "Video \(currentVideoIdentifier) is unplayable: \(error.localizedDescription). Skipping to next.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                        self.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    // The method previously named playVideoWithYouTubeKit can be removed if playVideoPlaylist covers all needs,
    // or renamed if it serves a distinct purpose for single video play.
    // For now, I'll assume playVideoPlaylist is the primary method to be called from didSelectItemAt.
    // The old playVideoWithYouTubeKit method is effectively replaced by the logic within playVideoPlaylist.

    func playVideo(videoIdentifier: String?) {
        // Check subscription status before playing
        print("Play video starts")
        // requireSubscription(on: self) { [weak self] isSubscribed in // Temporarily commented out
        //     guard let self = self, isSubscribed else {
        //         // Handle not subscribed case if necessary, perhaps by returning or showing a message
        //         return
        //     }
            
        //     guard let videoIdentifier = videoIdentifier, !videoIdentifier.isEmpty else {
        //         print("Video identifier is nil or empty.")
        //         // Handle invalid video identifier, perhaps show an alert
        //         return
        //     }
            
        //     self.playVideoPlaylist(videoIdentifiers: [videoIdentifier], currentIndex: 0)
        // }
        print("PlayListViewController: playVideo - Bypassing requireSubscription.")
        guard let videoIdentifier = videoIdentifier, !videoIdentifier.isEmpty else {
            print("Video identifier is nil or empty.")
            return
        }
        self.playVideoPlaylist(videoIdentifiers: [videoIdentifier], currentIndex: 0)
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
        // Store last focused index path for videos
        lastFocusedVideoIndexPath = indexPath

        if collectionView == playlistImagesCollectionView {
            guard let selectedPlaylistIndex = selectedPlaylistIndex, selectedPlaylistIndex < playlists.count else { return }
            let playlist = playlists[selectedPlaylistIndex]
            let videoIndexInVisible = indexPath.item // Index in the currently visible (and potentially filtered) set of videos

            // Ensure videoIndexInVisible is valid for visibleVideoIndices
            guard videoIndexInVisible < visibleVideoIndices.count else {
                print("Error: videoIndexInVisible is out of bounds for visibleVideoIndices.")
                return
            }
            let actualVideoIndex = visibleVideoIndices[videoIndexInVisible] // Actual index in the full video list for the playlist

            // Use mtvVideos which should contain the YouTube video IDs
            guard let allVideoIds = playlist.fields.mtvVideos, !allVideoIds.isEmpty else {
                print("Error: No video IDs found in playlist.fields.mtvVideos.")
                return
            }

            // Ensure actualVideoIndex is valid for allVideoIds
            guard actualVideoIndex < allVideoIds.count else {
                print("Error: actualVideoIndex is out of bounds for allVideoIds.")
                return
            }
            
            // Get the specific video ID for the selected video
            let selectedVideoId = allVideoIds[actualVideoIndex]
            guard !selectedVideoId.isEmpty else {
                print("PlayListViewController: Selected video has empty ID at index \(actualVideoIndex), skipping.")
                return
            }

            print("PlayListViewController: collectionView.didSelectItemAt - Bypassing requireSubscription.")
            // Play only the selected single video instead of the entire playlist
            self.playVideoPlaylist(videoIdentifiers: [selectedVideoId], currentIndex: 0)
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
