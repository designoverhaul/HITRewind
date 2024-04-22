import UIKit
import XCDYouTubeKit
import AVKit

class PlayListViewController: UIViewController, AVPlayerViewControllerDelegate {
    private var playlists: [Playlist] = []
    private var selectedPlaylistIndex: Int?
    
    private var playlistTableView: UITableView!
    private var playlistImagesCollectionView: UICollectionView!
    private var selectedYearLabel: UILabel!
    private var loadingIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showLoadingIndicator() // Show loading indicator
        fetchPlaylists()
    }


        private func selectFirstPlaylist() {
            guard !playlists.isEmpty else { 
                print("empty playlist")
                return }
            print("Not empty playlist")
            selectedPlaylistIndex = 0
            let indexPath = IndexPath(row: 0, section: 0)
            tableView(playlistTableView, didSelectRowAt: indexPath) // Call didSelectRowAt method manually
        }

    private func setupUI() {
        view.backgroundColor = .black

        // Add the asset image view
        let imageView = UIImageView(image: UIImage(named: "mtv_logo"))
        imageView.contentMode = .scaleAspectFill // Adjust content mode to fill the frame
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        selectedYearLabel = UILabel()
        selectedYearLabel.textColor = UIColor(hex: "#FFF61D")
        selectedYearLabel.font = UIFont(name: "inter", size: 43) ?? UIFont.systemFont(ofSize: 43, weight: .heavy)
        selectedYearLabel.textAlignment = .right // Align the text to the right
        selectedYearLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectedYearLabel)

        // Add constraints for imageView and selectedYearLabel
        NSLayoutConstraint.activate([
            // Constraints for imageView
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 52),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 66),
            imageView.widthAnchor.constraint(equalToConstant: 145),
            imageView.heightAnchor.constraint(equalToConstant: 115),
            
            // Constraints for selectedYearLabel
            selectedYearLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 50),
            selectedYearLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -2.2),
        ])
        
        // Add the playlistTableView
        playlistTableView = UITableView()
        playlistTableView.dataSource = self
        playlistTableView.delegate = self
        playlistTableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlaylistYear")
        view.addSubview(playlistTableView)

        playlistTableView.cellLayoutMarginsFollowReadableWidth = false

        playlistTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // Constraints for playlistTableView
            playlistTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor,constant: -51), // Align with the right edge of the imageView
            playlistTableView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 30), // Align playlistTableView's top with imageView's top
            playlistTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            playlistTableView.widthAnchor.constraint(equalToConstant: 400) // Adjust width as needed
        ])

        // Add the playlistImagesCollectionView
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 40
        layout.itemSize = CGSize(width: 340, height: 240) // Adjust as needed

        playlistImagesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        playlistImagesCollectionView.backgroundColor = .clear
        playlistImagesCollectionView.dataSource = self
        playlistImagesCollectionView.delegate = self

        // Register the PlaylistImageCell class
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

    func playVideoPlaylist(videoIdentifiers: [String], currentIndex: Int = 0) {
        guard currentIndex < videoIdentifiers.count else {
            // All videos in the playlist have been played
            return
        }

        let playerViewController = AVPlayerViewController()
        playerViewController.delegate = self

        let currentVideoIdentifier = videoIdentifiers[currentIndex]

        XCDYouTubeClient.default().getVideoWithIdentifier(currentVideoIdentifier) { [weak self, playerViewController] (video: XCDYouTubeVideo?, error: Error?) in
            guard let streamURLs = video?.streamURLs else {
                // Unable to retrieve stream URLs for the current video
                // Proceed to play the next video in the playlist
                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                return
            }

            guard let streamURL = (streamURLs[XCDYouTubeVideoQualityHTTPLiveStreaming] ??
                                   streamURLs[YouTubeVideoQuality.hd720] ??
                                   streamURLs[YouTubeVideoQuality.medium360] ??
                                   streamURLs[YouTubeVideoQuality.small240]) else {
                // Unable to find a suitable stream URL for the current video
                // Proceed to play the next video in the playlist
                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                return
            }

            DispatchQueue.main.async {
                let avPlayer = AVPlayer(url: streamURL)
                playerViewController.player = avPlayer
                self?.present(playerViewController, animated: true) {
                    avPlayer.play()

                    // Observe playback status to detect when the current video finishes
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: nil) { [weak self] _ in
                        // Dismiss the player view controller
                        playerViewController.dismiss(animated: true) {
                            // Play the next video in the playlist
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
        print("Play video ends ")
    }
    
    private func showLoadingIndicator() {
        // Create and configure the loading indicator
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        
        // Position the loading indicator in the center of the view
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func hideLoadingIndicator() {
        // Stop and remove the loading indicator from the view
        loadingIndicator.stopAnimating()
        loadingIndicator.removeFromSuperview()
    }

    private func fetchPlaylists() {
        fetchThePlaylists(apiKey: apiKey, baseURLString: playListUrl) { [weak self] result in
            switch result {
            case .success(let playlists):
                self?.playlists = playlists
                if self?.playlists.isEmpty == false {
                    self?.selectedPlaylistIndex = 0
                    DispatchQueue.main.async {
                        self?.playlistTableView.reloadData()
                        self?.playlistImagesCollectionView.reloadData()
                        self?.hideLoadingIndicator() // Hide loading indicator after playlists are fetched
                        self?.selectFirstPlaylist() // Call selectFirstPlaylist() after playlists are fetched
                    }
                }
            case .failure(let error):
                print("Error fetching playlists: \(error)")
                self?.hideLoadingIndicator() // Hide loading indicator if there's an error
            }
        }
    }
}

extension PlayListViewController: UITableViewDataSource, UITableViewDelegate {
  
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistYear", for: indexPath)

        // Configure the cell content here
        cell.textLabel?.text = String(playlists[indexPath.row].fields.year)
        cell.textLabel?.font = UIFont(name: "sf_pro-regular", size: 26) ?? UIFont.systemFont(ofSize: 26, weight: .bold)
        cell.layer.cornerRadius = 10
      

        // Set the background color for hovered state
        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor.black
        cell.selectedBackgroundView = bgColorView

        // Set the border color and width for selected state
        cell.layer.borderWidth = 0 // reset previous border width
        cell.layer.borderColor = UIColor.clear.cgColor
    
        return cell
    }

   
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Clear border from previously selected cell
        if let previousSelectedIndex = selectedPlaylistIndex,
           let previousSelectedCell = tableView.cellForRow(at: IndexPath(row: previousSelectedIndex, section: 0)) {
            previousSelectedCell.layer.borderWidth = 0
        }
        
        // Apply border to newly selected cell
        if let selectedCell = tableView.cellForRow(at: indexPath) {
            selectedCell.layer.borderWidth = 2
            selectedCell.layer.borderColor = UIColor(hex: "#A789FD")?.cgColor
        }

        // Update selected index
        selectedPlaylistIndex = indexPath.row
        
        // Update selected year label
        selectedYearLabel.text = String(playlists[indexPath.row].fields.year)
        
        // Reload collection view
        playlistImagesCollectionView.reloadData()
    }
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let deselectedCell = tableView.cellForRow(at: indexPath)
        deselectedCell?.layer.borderWidth = 0 // Reset border width
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


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }
    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        guard let nextFocusedIndexPath = context.nextFocusedIndexPath else { return }
        guard let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath else { return }

        // Enlarge the next focused cell
        if let nextFocusedCell = collectionView.cellForItem(at: nextFocusedIndexPath) as? PlaylistImageCell {
            coordinator.addCoordinatedAnimations({
                nextFocusedCell.backgroundColor = UIColor(hex: "292631")
                nextFocusedCell.layer.cornerRadius = 10
                nextFocusedCell.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            // Set green background color
            }, completion: nil)
        }

        // Shrink the previously focused cell
        if let previouslyFocusedCell = collectionView.cellForItem(at: previouslyFocusedIndexPath) as? PlaylistImageCell {
            coordinator.addCoordinatedAnimations({
                previouslyFocusedCell.transform = CGAffineTransform.identity
                previouslyFocusedCell.backgroundColor = .clear // Clear previous background color
            }, completion: nil)
        }
    }

}

extension PlayListViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func generatePlaylistFromSelectedVideo(selectedIndexPath: IndexPath) -> [String] {
        guard let selectedPlaylistIndex = selectedPlaylistIndex, selectedPlaylistIndex < playlists.count else {
            return []
        }

        let videoUrls = playlists[selectedPlaylistIndex].fields.videoUrls ?? []
        let currentVideoIndex = selectedIndexPath.item
        let totalVideos = videoUrls.count

        // Determine the start and end indices for the playlist
        let startIndex = currentVideoIndex
        var endIndex = startIndex + totalVideos

        // If the end index exceeds the total number of videos, wrap around to the beginning
        if endIndex > totalVideos {
            endIndex = totalVideos
        }

        // Create the playlist by appending videos from the start till the end
        var playlist: [String] = []
        for index in startIndex..<endIndex {
            playlist.append(extractYouTubeVideoID(from: videoUrls[index % totalVideos]) ?? "")
        }

        return playlist
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
           // Adjust the content inset to provide padding on the left and right
           let padding: CGFloat = 50 // Adjust as needed
           return UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
       }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let selectedPlaylistIndex = selectedPlaylistIndex, selectedPlaylistIndex < playlists.count else {
            return 0
        }
        return playlists[selectedPlaylistIndex].fields.videoUrls?.count ?? 0
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedPlaylistIndex = selectedPlaylistIndex, selectedPlaylistIndex < playlists.count else {
            return
        }

        let videoURL = playlists[selectedPlaylistIndex].fields.videoUrls?[indexPath.item]

        if extractYouTubeVideoID(from: videoURL ?? "") != nil {
            let playlist = generatePlaylistFromSelectedVideo(selectedIndexPath: indexPath)
            playVideoPlaylist(videoIdentifiers: playlist)
        } else {
            print("Invalid YouTube video URL \(String(describing: videoURL))")
        }
    }


    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaylistCell", for: indexPath) as? PlaylistImageCell else {
            return UICollectionViewCell()
        }

        // Reset the cell's content before configuring it
        cell.imageView.image = nil
        cell.titleLabel.text = nil
        cell.artistNameLabel.text = nil
        cell.durationLabel.text = nil

        // Configure the cell content here
        if let videoURL = playlists[selectedPlaylistIndex ?? 0].fields.videoUrls?[indexPath.item],
           
            let videoID = extractYouTubeVideoID(from: videoURL) {
           
            let thumbnailURLString = "https://i.ytimg.com/vi/\(videoID)/mqdefault.jpg"
        
            if let url = URL(string: thumbnailURLString) {
                // Asynchronously load the image
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            cell.imageView.image = image
                        }
                    }
                }.resume()
            }
            
            cell.titleLabel.text = playlists[selectedPlaylistIndex ?? 0].fields.videoTitles?[indexPath.item] // Use appropriate title from playlist model
            cell.artistNameLabel.text = playlists[selectedPlaylistIndex ?? 0].fields.artistNames?[indexPath.item]
            
            getVideoDuration(videoUrl: videoURL) { duration in
                DispatchQueue.main.async {
                    cell.durationLabel.text = duration
                }
            }
        }

        return cell
    }

}

extension UIImageView {
    func load(url: URL) {
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.image = image
                }
            }
        }
    }
}


// Utility function to extract YouTube video ID from URL
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

// Extension to load image from URL asynchronously


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
struct YouTubeVideoQuality {
        static let hd720 = NSNumber(value: XCDYouTubeVideoQuality.HD720.rawValue)

        static let medium360 = NSNumber(value: XCDYouTubeVideoQuality.medium360.rawValue)
        static let small240 = NSNumber(value: XCDYouTubeVideoQuality.small240.rawValue)
    }
