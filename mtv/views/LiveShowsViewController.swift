// #error("This is the LiveShowsViewController being compiled!") // Removed for debugging

import UIKit
// import XCDYouTubeKit // Removed
import YouTubeKit // Added
import AVKit
import RevenueCat

class LiveShowsViewController: UIViewController, AVPlayerViewControllerDelegate {
    
    // MARK: - Properties
    
    // Custom colors
    private let purpleColor = UIColor(red: 167/255, green: 137/255, blue: 253/255, alpha: 1.0)  // #A789FD
    private let darkGrayColor = UIColor(red: 41/255, green: 38/255, blue: 49/255, alpha: 1.0)   // #292631
    
    private var artists: [Playlist] = []
    private var selectedArtistIndex: Int?
    private var visibleVideoIndices: [Int] = []
    private var lastSelectedArtistIndex: IndexPath?
    private var isSubscribed: Bool = false
    
    // Store last focused index paths
    private var lastFocusedArtistIndexPath: IndexPath?
    private var lastFocusedVideoIndexPath: IndexPath?
    
    private var artistTableView: UITableView!
    private var purchaseButton: UIButton!
    private var artistVideosCollectionView: UICollectionView!
    private var loadingIndicator: UIActivityIndicatorView!
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("LiveShowsViewController viewDidLoad CALLED - THIS IS THE ONE!")
        setupUI()
        showLoadingIndicator()
        fetchArtists()
        checkSubscriptionStatus()
        
        // Add observer for subscription status change
        NotificationCenter.default.addObserver(self, selector: #selector(subscriptionStatusChanged), name: Notification.Name("SubscriptionStatusChanged"), object: nil)
        
        print("LiveShowsViewController loaded. Delegate is: \(String(describing: artistVideosCollectionView.delegate))")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        checkSubscriptionStatus {
            // After subscription status is updated
            if let lastSelectedIndex = self.lastSelectedArtistIndex {
                self.artistTableView.scrollToRow(at: lastSelectedIndex, at: .middle, animated: false)
                self.artistVideosCollectionView.reloadData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.artistTableView.selectRow(at: lastSelectedIndex, animated: false, scrollPosition: .none)
                    self.selectedArtistIndex = lastSelectedIndex.row
                    self.updateUIForSelectedArtist()
                }
            } else {
                // Try to select the first available artist
                self.selectFirstAvailableArtist()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Ensure the table view has laid out its cells
        artistTableView.layoutIfNeeded()
        // Update focus after view has appeared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
        }
    }
    
    // MARK: - Focus Management
    
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let lastFocusedVideoIndexPath = lastFocusedVideoIndexPath,
           let videoCell = artistVideosCollectionView.cellForItem(at: lastFocusedVideoIndexPath) {
            return [videoCell]
        } else if let lastFocusedArtistIndexPath = lastFocusedArtistIndexPath,
                  let artistCell = artistTableView.cellForRow(at: lastFocusedArtistIndexPath) {
            return [artistCell]
        } else if let firstAvailableIndex = lastSelectedArtistIndex,
                  let firstArtistCell = artistTableView.cellForRow(at: firstAvailableIndex) {
            return [firstArtistCell]
        } else {
            return [purchaseButton] // Fallback focus
        }
    }
    
    class FocusableButton: UIButton {
        // Get reference to the purple color from the parent class
        private let purpleColor = UIColor(red: 167/255, green: 137/255, blue: 253/255, alpha: 1.0)
        
        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            super.didUpdateFocus(in: context, with: coordinator)
            
            coordinator.addCoordinatedAnimations({
                if self.isFocused {
                    self.backgroundColor = self.purpleColor
                    self.layer.cornerRadius = 8.0
                    self.layer.masksToBounds = true
                    self.setTitleColor(.black, for: .normal)
                } else {
                    self.backgroundColor = .black
                    self.layer.cornerRadius = 0.0
                    self.layer.masksToBounds = false
                    self.setTitleColor(self.purpleColor, for: .normal)
                }
            }, completion: nil)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // MTV logo imageView setup
        let imageView = UIImageView(image: UIImage(named: "logoVector"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        purchaseButton = FocusableButton(type: .custom)
        purchaseButton.setTitle("🔓 Unlock All Music", for: .normal)
        purchaseButton.setTitleColor(.white, for: .normal)
        purchaseButton.backgroundColor = .black
        
        // Set semibold font
        purchaseButton.titleLabel?.font = UIFont.systemFont(ofSize: 25, weight: .semibold)
        
        // Update to use UIButton.Configuration on tvOS 15.0+
        if #available(tvOS 15.0, *) {
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
            configuration.titleAlignment = .leading
            purchaseButton.configuration = configuration
        } else {
            // Fall back to deprecated method for older versions
            #if compiler(>=5.5)
            // Suppress the deprecation warning with @available
            @available(tvOS, deprecated: 15.0, message: "Use UIButton.Configuration instead")
            func setButtonContentEdgeInsets() {
                purchaseButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
                purchaseButton.contentHorizontalAlignment = .left
            }
            setButtonContentEdgeInsets()
            #else
            purchaseButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
            purchaseButton.contentHorizontalAlignment = .left
            #endif
        }
        
        purchaseButton.addTarget(self, action: #selector(navigateToPurchases), for: .primaryActionTriggered)
        purchaseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(purchaseButton)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 112),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 66),
            imageView.widthAnchor.constraint(equalToConstant: 145),
            imageView.heightAnchor.constraint(equalToConstant: 115),
            purchaseButton.heightAnchor.constraint(equalToConstant: 50),
            purchaseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 51),
            purchaseButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20)
        ])
        
        // Artist tableView setup
        artistTableView = UITableView()
        artistTableView.dataSource = self
        artistTableView.delegate = self
        artistTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ArtistCell")
        view.addSubview(artistTableView)
        artistTableView.cellLayoutMarginsFollowReadableWidth = false
        artistTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            artistTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 80),
            artistTableView.topAnchor.constraint(equalTo: purchaseButton.bottomAnchor, constant: 30),
            artistTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            artistTableView.widthAnchor.constraint(equalToConstant: 400)
        ])
        
        // Artist videos collectionView setup
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 40
        layout.itemSize = CGSize(width: 340, height: 240)
        
        artistVideosCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        artistVideosCollectionView.backgroundColor = .clear
        artistVideosCollectionView.dataSource = self
        artistVideosCollectionView.delegate = self
        artistVideosCollectionView.register(PlaylistImageCell.self, forCellWithReuseIdentifier: "PlaylistCell")
        view.addSubview(artistVideosCollectionView)
        artistVideosCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            artistVideosCollectionView.leadingAnchor.constraint(equalTo: artistTableView.trailingAnchor, constant: 70),
            artistVideosCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            artistVideosCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            artistVideosCollectionView.bottomAnchor.constraint(equalTo: artistTableView.bottomAnchor)
        ])
    }
    
    // MARK: - Subscription Management
    
    private func checkSubscriptionStatus(completion: (() -> Void)? = nil) {
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            guard let self = self else { return }
            if let customerInfo = customerInfo {
                let activeEntitlements = customerInfo.entitlements.all.filter { $0.value.isActive }
                self.isSubscribed = !activeEntitlements.isEmpty
                DispatchQueue.main.async {
                    self.purchaseButton.setTitle(self.isSubscribed ? "👍 Unlocked" : "🔓 Unlock All Music", for: .normal)
                    self.purchaseButton.isEnabled = !self.isSubscribed
                    completion?()
                }
            } else {
                self.isSubscribed = false
                DispatchQueue.main.async {
                    self.purchaseButton.setTitle("🔓 Unlock All Music", for: .normal)
                    self.purchaseButton.isEnabled = true
                    completion?()
                }
            }
        }
    }
    
    @objc private func subscriptionStatusChanged() {
        checkSubscriptionStatus {
            DispatchQueue.main.async {
                self.artistTableView.reloadData()
                self.updateUIForSelectedArtist()
            }
        }
    }
    
    private func updateUIForSelectedArtist() {
        guard selectedArtistIndex != nil else {
            artistVideosCollectionView.isHidden = true
            return
        }
        
        // Always show videos
        artistVideosCollectionView.isHidden = false
        updateVisibleVideoIndices()
        artistVideosCollectionView.reloadData()
    }
    
    private func selectFirstAvailableArtist() {
        print("LiveShowsViewController: Attempting to select first available artist from \(artists.count) artists")
        // Try to select the first unlocked artist
        for (index, artist) in artists.enumerated() {
            // if isSubscribed || !(artist.fields.isLocked ?? false) { // Original logic
            if true { // Simplified for debugging: assume all artists are available
                print("LiveShowsViewController: Selected artist at index \(index): \(artist.fields.title)")
                selectedArtistIndex = index
                lastSelectedArtistIndex = IndexPath(row: index, section: 0)
                lastFocusedArtistIndexPath = lastSelectedArtistIndex // Update the last focused artist index path
                artistTableView.selectRow(at: lastSelectedArtistIndex, animated: false, scrollPosition: .none)
                updateUIForSelectedArtist()
                return
            }
        }
        // No available artists
        print("LiveShowsViewController: No available artists found")
        selectedArtistIndex = nil
        lastSelectedArtistIndex = nil
        lastFocusedArtistIndexPath = nil
        updateUIForSelectedArtist()
    }
    
    @objc private func navigateToPurchases() {
        let purchasesViewController = PurchasesViewController()
        purchasesViewController.modalPresentationStyle = .fullScreen
        present(purchasesViewController, animated: true, completion: nil)
    }
    
    // MARK: - Data Fetching
    
    func fetchArtists() {
        print("🚨🚨🚨 LIVE SHOWS PAGE: fetchArtists() method called 🚨🚨🚨")
        print("🎵 LiveShowsViewController: Starting to fetch artists from \(liveShowsUrl)")
        
        // Fetch directly without using sortAndArrangePlaylists to avoid year-based sorting
        fetchLiveShowsAlphabetically(apiKey: apiKey, baseURLString: liveShowsUrl) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let artists):
                print("🎵 LiveShowsViewController: Successfully fetched \(artists.count) artists")
                
                // Debug: Print the alphabetically sorted order (should already be sorted by the fetch function)
                print("🚨🚨🚨 LIVE SHOWS ALPHABETICAL ORDER 🚨🚨🚨")
                for (index, artist) in artists.enumerated() {
                    print("🎤 \(index + 1). \(artist.fields.title)")
                }
                
                self.artists = artists
                DispatchQueue.main.async {
                    self.artistTableView.reloadData()
                    self.hideLoadingIndicator()
                    
                    if !self.artists.isEmpty {
                        print("LiveShowsViewController: Artists array is not empty, selecting first available artist")
                        // Automatically select the first available artist if no selection has been made before
                        if self.selectedArtistIndex == nil {
                            self.selectFirstAvailableArtist()
                            // Ensure the first artist is focused
                            self.lastFocusedArtistIndexPath = self.lastSelectedArtistIndex
                        }
                    } else {
                        print("LiveShowsViewController: Artists array is empty")
                    }
                }
            case .failure(let error):
                print("LiveShowsViewController: Error fetching artists: \(error)")
                self.hideLoadingIndicator()
            }
        }
    }
    
    private func updateVisibleVideoIndices() {
        guard let selectedArtistIndex = selectedArtistIndex else {
            print("LiveShowsViewController: No artist selected, clearing visible video indices")
            visibleVideoIndices = []
            return
        }
        
        print("LiveShowsViewController: Updating visible video indices for artist at index \(selectedArtistIndex)")
        
        // Check if the selected artist has visibility flags for its videos
        visibleVideoIndices = artists[selectedArtistIndex].fields.isVisible.enumerated().compactMap { index, isVisible in
            isVisible ?? false ? index : nil
        }
        
        print("LiveShowsViewController: Found \(visibleVideoIndices.count) visible videos")
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
        DispatchQueue.main.async {
            self.loadingIndicator.stopAnimating()
            self.loadingIndicator.removeFromSuperview()
        }
    }
    
    // MARK: - Video Playback
    
    // Refactored: This method now only fetches the stream URL and uses a completion handler.
    // It no longer presents the AVPlayerViewController itself.
    // Updated completion to return Result<URL, YouTubePlayerError> for better error handling
    private func getVideoWithFixedPatterns(videoIdentifier: String, completion: @escaping (Result<URL, YouTubePlayerError>) -> Void) {
        print("LiveShowsViewController: Requesting stream from YouTubePlayerService for ID: \(videoIdentifier)")
        YouTubePlayerService.shared.getPlayableStreamURL(for: videoIdentifier, completion: completion)
    }

    // MARK: - Video Playback (Single Video)
    func playVideo(videoIdentifier: String) {
        showLoadingIndicator() // Show loading indicator when starting video playback
        getVideoWithFixedPatterns(videoIdentifier: videoIdentifier) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoadingIndicator() // Hide loading indicator once URL is fetched (or fails)
                guard let self = self else { return }
                
                switch result {
                case .success(let url):
                    print("LiveShowsViewController: Presenting player for single video ID: \(videoIdentifier) with URL: \(url)")
                    let playerViewController = AVPlayerViewController()
                    playerViewController.delegate = self
                    playerViewController.modalPresentationStyle = .fullScreen // Set before presenting
                    let player = AVPlayer(url: url)
                    playerViewController.player = player
                    self.present(playerViewController, animated: true) {
                        print("✅ LiveShowsViewController: AVPlayerViewController presented for video ID: \(videoIdentifier)")
                        player.play()
                        print("▶️ LiveShowsViewController: avPlayer.play() called for video ID: \(videoIdentifier)")
                    }
                case .failure(let error):
                    print("🚫 LiveShowsViewController: No video URL found for identifier \(videoIdentifier) after fetching. Error: \(error.localizedDescription)")
                    let alert = UIAlertController(title: "Playback Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    // MARK: - Playlist Playback
    func playVideoPlaylist(videoIdentifiers: [String], currentIndex: Int = 0) {
        guard currentIndex < videoIdentifiers.count else {
            print("LiveShowsViewController: Playlist finished - all videos played")
            return
        }
        
        let currentVideoIdentifier = videoIdentifiers[currentIndex]
        print("LiveShowsViewController: Playing video \(currentIndex + 1)/\(videoIdentifiers.count) from playlist: \(currentVideoIdentifier)")

        showLoadingIndicator() // Show loading indicator for each video in playlist

        getVideoWithFixedPatterns(videoIdentifier: currentVideoIdentifier) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoadingIndicator() // Hide loading indicator for each video
                guard let self = self else { return }
                
                switch result {
                case .success(let url):
                    print("LiveShowsViewController: Presenting player for playlist video ID: \(currentVideoIdentifier) with URL: \(url)")
                    let playerViewController = AVPlayerViewController()
                    playerViewController.delegate = self
                    playerViewController.modalPresentationStyle = .fullScreen // Set before presenting
                    let player = AVPlayer(url: url)
                    playerViewController.player = player
                    self.present(playerViewController, animated: true) {
                        print("✅ LiveShowsViewController (Playlist): AVPlayerViewController presented for video ID: \(currentVideoIdentifier)")
                        player.play()
                        print("▶️ LiveShowsViewController (Playlist): avPlayer.play() called for video ID: \(currentVideoIdentifier)")
                        
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self, weak playerViewController] _ in
                            NotificationCenter.default.removeObserver(self as Any, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
                            
                            playerViewController?.dismiss(animated: true) {
                                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                            }
                        }
                    }
                case .failure(let error):
                    print("🚫 LiveShowsViewController: No video URL found for identifier \(currentVideoIdentifier) in playlist. Error: \(error.localizedDescription). Skipping.")
                    let alert = UIAlertController(title: "Playback Error", message: "Video \(currentVideoIdentifier) is unplayable: \(error.localizedDescription). Skipping to next.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                        self.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource and UITableViewDelegate

extension LiveShowsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("LiveShowsViewController: tableView numberOfRowsInSection called, returning \(artists.count)")
        return artists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ArtistCell", for: indexPath)
        let artist = artists[indexPath.row]
        let artistName = artist.fields.title
        let lockIcon = (!isSubscribed && artist.fields.isLocked == true) ? " 🔒" : ""
        cell.textLabel?.text = isSubscribed ? artistName : artistName + lockIcon
        cell.textLabel?.font = UIFont(name: "sf_pro-regular", size: 30) ?? UIFont.systemFont(ofSize: 30, weight: .bold)
        cell.layer.cornerRadius = 10
        // Set default text color to white
        cell.textLabel?.textColor = .white
        // If this cell is selected, set text color to black
        if tableView.indexPathForSelectedRow == indexPath {
            cell.textLabel?.textColor = .black
        }
        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor.black
        cell.selectedBackgroundView = bgColorView
        cell.layer.borderWidth = 0
        cell.layer.borderColor = UIColor.clear.cgColor
        print("LiveShowsViewController: Configured cell for artist at index \(indexPath.row): \(artistName)")
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let previousSelectedIndex = selectedArtistIndex,
           let previousSelectedCell = tableView.cellForRow(at: IndexPath(row: previousSelectedIndex, section: 0)) {
            previousSelectedCell.layer.borderWidth = 0
            // Reset text color to white for previously selected cell
            previousSelectedCell.textLabel?.textColor = .white
        }
        if let selectedCell = tableView.cellForRow(at: indexPath) {
            selectedCell.layer.borderWidth = 2
            selectedCell.layer.borderColor = purpleColor.cgColor
            // Set text color to black for selected cell
            selectedCell.textLabel?.textColor = .black
        }
        selectedArtistIndex = indexPath.row
        lastSelectedArtistIndex = indexPath // Update last selected index
        // Always show videos, regardless of lock status
        artistVideosCollectionView.isHidden = false
        updateVisibleVideoIndices()
        artistVideosCollectionView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let deselectedCell = tableView.cellForRow(at: indexPath)
        deselectedCell?.layer.borderWidth = 0
        deselectedCell?.layer.borderColor = UIColor.clear.cgColor
        // Reset text color to white for deselected cell
        deselectedCell?.textLabel?.textColor = .white
    }
    
    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if let nextFocusedIndexPath = context.nextFocusedIndexPath {
                self.lastFocusedArtistIndexPath = nextFocusedIndexPath
                if let nextFocusedCell = tableView.cellForRow(at: nextFocusedIndexPath) {
                    nextFocusedCell.contentView.backgroundColor = self.purpleColor
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

extension LiveShowsViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("LiveShowsViewController: collectionView numberOfItemsInSection called, returning \(visibleVideoIndices.count)")
        return visibleVideoIndices.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaylistCell", for: indexPath) as? PlaylistImageCell else {
            print("LiveShowsViewController: Failed to dequeue PlaylistCell")
            return UICollectionViewCell()
        }
        
        guard let selectedArtistIndex = selectedArtistIndex, selectedArtistIndex < artists.count else {
            print("LiveShowsViewController: No valid artist selected for collection view cell")
            return cell
        }
        
        let visibleIndex = visibleVideoIndices[indexPath.item]
        print("LiveShowsViewController: Configuring cell for video at visible index \(visibleIndex)")
        
        if let videoURL = artists[selectedArtistIndex].fields.videoUrls?[visibleIndex],
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
            
            // Set title and year (from the Front Row project, we display title, year, and duration)
            cell.titleLabel.text = artists[selectedArtistIndex].fields.videoTitles?[visibleIndex]
            
            // Set year in the artist name label (repurposing the label for year)
            if let videoYears = artists[selectedArtistIndex].fields.artistNames?[visibleIndex] {
                cell.artistNameLabel.text = videoYears
            }
            
            // Get video duration
            getVideoDuration(videoUrl: videoURL) { duration in
                DispatchQueue.main.async {
                    cell.durationLabel.text = duration
                }
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        lastFocusedVideoIndexPath = indexPath // Store last focused video
        
        if collectionView == artistVideosCollectionView {
            guard let selectedArtistIndex = selectedArtistIndex else { return }
            let artist = artists[selectedArtistIndex]
            let videoIndex = visibleVideoIndices[indexPath.item]
            let video = artist.fields.videos[videoIndex]
            let videoId = video.fields.video_id

            requireSubscription(on: self) { [weak self] isSubscribed in
                guard let self = self, isSubscribed else { return }
                if artist.fields.isPlaylist ?? false {
                    let allVideoIds = artist.fields.videos.map { $0.fields.video_id }
                    let currentVideoIndexInPlaylist = allVideoIds.firstIndex(of: videoId) ?? 0
                    self.playVideoPlaylist(videoIdentifiers: allVideoIds, currentIndex: currentVideoIndexInPlaylist)
                } else {
                    self.playVideo(videoIdentifier: videoId)
                }
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
        guard let selectedArtistIndex = selectedArtistIndex, selectedArtistIndex < artists.count else {
            return []
        }
        
        let videoUrls = artists[selectedArtistIndex].fields.videoUrls ?? []
        let currentVideoIndex = visibleVideoIndices[selectedIndexPath.item]
        let totalVideos = videoUrls.count
        
        let startIndex = currentVideoIndex
        var endIndex = startIndex + totalVideos
        
        if endIndex > totalVideos {
            endIndex = totalVideos
        }
        
        var playlist: [String] = []
        for index in startIndex..<endIndex {
            if let videoID = extractYouTubeVideoID(from: videoUrls[index % totalVideos]) {
                playlist.append(videoID)
            }
        }
        
        return playlist
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let padding: CGFloat = 50
        return UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
    }
}

// MARK: - Helper Methods

extension LiveShowsViewController {
    func getVideoDuration(videoUrl: String, completion: @escaping (String) -> Void) {
        // Implement your method to get video duration
        // Call completion(durationString)
        completion("3:45") // Placeholder implementation
    }
} 