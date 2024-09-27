import UIKit
import RevenueCat
import XCDYouTubeKit
import AVKit

class PlayListViewController: UIViewController, AVPlayerViewControllerDelegate {

    // MARK: - Properties

    private var playlists: [Playlist] = []
    private var selectedPlaylistIndex: Int?
    private var visibleVideoIndices: [Int] = []
    private var lastSelectedYearIndex: IndexPath?
    private var isSubscribed: Bool = false

    // Store last focused index paths
    private var lastFocusedYearIndexPath: IndexPath?
    private var lastFocusedVideoIndexPath: IndexPath?

    private var playlistTableView: UITableView!
    private var lockMessageLabel: UILabel!
    private var purchaseButton: UIButton!
    private var playlistImagesCollectionView: UICollectionView!
    private var selectedYearLabel: UILabel!
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
            return [purchaseButton] // Fallback focus
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
        let imageView = UIImageView(image: UIImage(named: "mtv_logo"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        selectedYearLabel = UILabel()
        selectedYearLabel.textColor = UIColor(hex: "#A789FD")
        selectedYearLabel.font = UIFont(name: "inter", size: 43) ?? UIFont.systemFont(ofSize: 43, weight: .light)
        selectedYearLabel.textAlignment = .right
        selectedYearLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectedYearLabel)

        purchaseButton = FocusableButton(type: .custom)
        purchaseButton.setTitle("🔓 Unlock All Years", for: .normal)
        purchaseButton.setTitleColor(.white, for: .normal)
        purchaseButton.backgroundColor = .black

        // Set the font to bold using the same font
        if let font = UIFont(name: "Inter", size: 25) {
            let fontDescriptor = font.fontDescriptor.withSymbolicTraits(.traitBold)
            if let boldFontDescriptor = fontDescriptor {
                purchaseButton.titleLabel?.font = UIFont(descriptor: boldFontDescriptor, size: 28)
            } else {
                purchaseButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
            }
        } else {
            purchaseButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
        }

        purchaseButton.contentHorizontalAlignment = .left
        purchaseButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20) // Added right padding
        purchaseButton.addTarget(self, action: #selector(navigateToPurchases), for: .primaryActionTriggered)
        purchaseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(purchaseButton)


           NSLayoutConstraint.activate([
               // ... your existing constraints for purchaseButton ...
               purchaseButton.heightAnchor.constraint(equalToConstant: 50),
               purchaseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 51),
               purchaseButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20)
           ])

        // Lock message label setup
        lockMessageLabel = UILabel()
        lockMessageLabel.textColor = .white
        lockMessageLabel.font = UIFont.systemFont(ofSize: 30, weight: .bold)
        lockMessageLabel.textAlignment = .center
        lockMessageLabel.numberOfLines = 0
        lockMessageLabel.text = "This playlist is locked. Please subscribe to watch it."
        lockMessageLabel.isHidden = true
        lockMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lockMessageLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 52),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 66),
            imageView.widthAnchor.constraint(equalToConstant: 145),
            imageView.heightAnchor.constraint(equalToConstant: 115),
            selectedYearLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 50),
            selectedYearLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -32.5),

            purchaseButton.heightAnchor.constraint(equalToConstant: 50),
            purchaseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 51),
            purchaseButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),

            lockMessageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            lockMessageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            lockMessageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            lockMessageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Playlist tableView setup
        playlistTableView = UITableView()
        playlistTableView.dataSource = self
        playlistTableView.delegate = self
        playlistTableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlaylistYear")
        view.addSubview(playlistTableView)
        playlistTableView.cellLayoutMarginsFollowReadableWidth = false
        playlistTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playlistTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -51),
            playlistTableView.topAnchor.constraint(equalTo: purchaseButton.bottomAnchor, constant: 30),
            playlistTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            playlistTableView.widthAnchor.constraint(equalToConstant: 400)
        ])

        // Playlist images collectionView setup
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 40
        layout.itemSize = CGSize(width: 340, height: 240)

        playlistImagesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        playlistImagesCollectionView.backgroundColor = .clear
        playlistImagesCollectionView.dataSource = self
        playlistImagesCollectionView.delegate = self
        playlistImagesCollectionView.register(PlaylistImageCell.self, forCellWithReuseIdentifier: "PlaylistCell")
        playlistImagesCollectionView.isHidden = true // Initially hidden
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
                    DispatchQueue.main.async {
                        self.purchaseButton.setTitle("👍 Unlocked", for: .normal)
                        
                        self.purchaseButton.isEnabled = false
                    }
                } else {
                    self.isSubscribed = false
                    DispatchQueue.main.async {
                        self.purchaseButton.setTitle("🔓 Unlock All Years", for: .normal)
                        
                        self.purchaseButton.isEnabled = true
                    }
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
        guard let selectedPlaylistIndex = selectedPlaylistIndex else {
            // No playlist selected, hide collection view and lock message
            playlistImagesCollectionView.isHidden = true
            lockMessageLabel.isHidden = true
            selectedYearLabel.text = ""
            return
        }

        let selectedPlaylist = playlists[selectedPlaylistIndex]
        let yearText = String(selectedPlaylist.fields.year)
        selectedYearLabel.text = yearText // No lock icon when subscribed

        if isSubscribed {
            // User is subscribed, show videos
            lockMessageLabel.isHidden = true
            playlistImagesCollectionView.isHidden = false
            updateVisibleVideoIndices()
            playlistImagesCollectionView.reloadData()
        } else {
            if selectedPlaylist.fields.isLocked ?? false {
                // Playlist is locked, show lock message
                lockMessageLabel.isHidden = false
                playlistImagesCollectionView.isHidden = true
            } else {
                // Playlist is unlocked, show videos
                lockMessageLabel.isHidden = true
                playlistImagesCollectionView.isHidden = false
                updateVisibleVideoIndices()
                playlistImagesCollectionView.reloadData()
            }
        }
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

    @objc private func navigateToPurchases() {
        // Save the currently focused index paths before navigating to the payment screen
        lastSelectedYearIndex = playlistTableView.indexPathForSelectedRow

        let purchasesViewController = PurchasesViewController()
        purchasesViewController.modalPresentationStyle = .fullScreen
        present(purchasesViewController, animated: true, completion: nil)
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

        XCDYouTubeClient.default().getVideoWithIdentifier(currentVideoIdentifier) { [weak self, playerViewController] (video: XCDYouTubeVideo?, error: Error?) in
            loadingIndicator.stopAnimating()
            loadingIndicator.removeFromSuperview()

            guard let streamURLs = video?.streamURLs else {
                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                return
            }

            guard let streamURL = (streamURLs[XCDYouTubeVideoQualityHTTPLiveStreaming] ??
                                   streamURLs[YouTubeVideoQuality.hd720] ??
                                   streamURLs[YouTubeVideoQuality.medium360] ??
                                   streamURLs[YouTubeVideoQuality.small240]) else {
                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                return
            }

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
        }
    }

    func playVideo(videoIdentifier: String?) {
        let playerViewController = AVPlayerViewController()
        playerViewController.delegate = self

        DispatchQueue.main.async {
            self.present(playerViewController, animated: true, completion: nil)
        }

        XCDYouTubeClient.default().getVideoWithIdentifier(videoIdentifier) { [weak playerViewController] (video: XCDYouTubeVideo?, error: Error?) in
            if let streamURLs = video?.streamURLs,
               let streamURL = (streamURLs[XCDYouTubeVideoQualityHTTPLiveStreaming] ??
                                streamURLs[YouTubeVideoQuality.hd720] ??
                                streamURLs[YouTubeVideoQuality.medium360] ??
                                streamURLs[YouTubeVideoQuality.small240]) {

                DispatchQueue.main.async {
                    playerViewController?.player?.automaticallyWaitsToMinimizeStalling = false
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController?.player = avPlayer
                    avPlayer.play()
                }
            } else {
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
        let lockIcon = (!isSubscribed && playlist.fields.isLocked == true) ? " 🔒" : ""
        cell.textLabel?.text = isSubscribed ? yearText : yearText + lockIcon
        cell.textLabel?.font = UIFont(name: "sf_pro-regular", size: 26) ?? UIFont.systemFont(ofSize: 26, weight: .bold)
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
            selectedCell.layer.borderColor = UIColor(hex: "#A789FD")?.cgColor
        }
        selectedPlaylistIndex = indexPath.row
        lastSelectedYearIndex = indexPath // Update last selected index

        let selectedPlaylist = playlists[indexPath.row]
        let yearText = String(selectedPlaylist.fields.year)
        selectedYearLabel.text = yearText // No lock icon when subscribed

        if isSubscribed {
            // User is subscribed, show videos
            lockMessageLabel.isHidden = true
            playlistImagesCollectionView.isHidden = false
            updateVisibleVideoIndices()
            playlistImagesCollectionView.reloadData()
        } else {
            if selectedPlaylist.fields.isLocked ?? false {
                // Playlist is locked, navigate to purchases screen
                lockMessageLabel.isHidden = true
                playlistImagesCollectionView.isHidden = true
                navigateToPurchases()
            } else {
                // Playlist is unlocked, show videos
                lockMessageLabel.isHidden = true
                playlistImagesCollectionView.isHidden = false
                updateVisibleVideoIndices()
                playlistImagesCollectionView.reloadData()
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
            getVideoDuration(videoUrl: videoURL) { duration in
                DispatchQueue.main.async {
                    cell.durationLabel.text = duration
                }
            }
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

        let videoURL = playlists[selectedPlaylistIndex].fields.videoUrls?[visibleVideoIndices[indexPath.item]]

        if extractYouTubeVideoID(from: videoURL ?? "") != nil {
            let playlist = generatePlaylistFromSelectedVideo(selectedIndexPath: indexPath)
            playVideoPlaylist(videoIdentifiers: playlist)
        } else {
            print("Invalid YouTube video URL \(String(describing: videoURL))")
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

    func getVideoDuration(videoUrl: String, completion: @escaping (String) -> Void) {
        // Implement your method to get video duration
        // Call completion(durationString)
        completion("3:45") // Placeholder implementation
    }
}

// MARK: - UIColor Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgb & 0x0000FF) / 255.0,
                  alpha: 1.0)
    }
}

// MARK: - YouTubeVideoQuality

struct YouTubeVideoQuality {
    static let hd720 = NSNumber(value: XCDYouTubeVideoQuality.HD720.rawValue)
    static let medium360 = NSNumber(value: XCDYouTubeVideoQuality.medium360.rawValue)
    static let small240 = NSNumber(value: XCDYouTubeVideoQuality.small240.rawValue)
}

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
