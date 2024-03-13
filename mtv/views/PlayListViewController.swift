import UIKit
import XCDYouTubeKit
import AVKit

class PlayListViewController: UIViewController, AVPlayerViewControllerDelegate {
    private var playlists: [Playlist] = []
    private var selectedPlaylistIndex: Int?
    
    private var playlistTableView: UITableView!
    private var playlistImagesCollectionView: UICollectionView!
    
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
        
        // Add the playlistTableView
        playlistTableView = UITableView()
        playlistTableView.dataSource = self
        playlistTableView.delegate = self
        playlistTableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlaylistCell")
        view.addSubview(playlistTableView)
        
        playlistTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playlistTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playlistTableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            playlistTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            playlistTableView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.25)
        ])
        
        // Add the playlistImagesCollectionView
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 20
        layout.itemSize = CGSize(width: 350, height: 250) // Adjust as needed

        playlistImagesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        playlistImagesCollectionView.backgroundColor = .clear
        playlistImagesCollectionView.dataSource = self
        playlistImagesCollectionView.delegate = self
        
        // Register the PlaylistImageCell class
        playlistImagesCollectionView.register(PlaylistImageCell.self, forCellWithReuseIdentifier: "PlaylistCell")
        view.addSubview(playlistImagesCollectionView)

        playlistImagesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playlistImagesCollectionView.leadingAnchor.constraint(equalTo: playlistTableView.trailingAnchor, constant: 40),
            playlistImagesCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playlistImagesCollectionView.topAnchor.constraint(equalTo: playlistTableView.topAnchor),
            playlistImagesCollectionView.bottomAnchor.constraint(equalTo: playlistTableView.bottomAnchor)
        ])
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
        mtv.fetchPlaylists(apiKey: apiKey, baseURLString: playListUrl) { [weak self] result in
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath)

        // Configure the cell content here
        cell.textLabel?.text = String(playlists[indexPath.row].fields.year)
        cell.textLabel?.font = UIFont(name: "sf_pro-regular", size: 26) ?? UIFont.systemFont(ofSize: 26, weight: .bold)
        cell.layer.cornerRadius = 10
        cell.clipsToBounds = true

        // Set the background color for hovered state
        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor.black
        cell.selectedBackgroundView = bgColorView

        // Set the border color and width for selected state
        cell.layer.borderWidth = 0 // reset previous border width
        cell.layer.borderColor = UIColor.clear.cgColor

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            guard let nextFocusedIndexPath = context.nextFocusedIndexPath else { return }
            guard let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath else { return }

            // Enlarge the next focused cell
            if let nextFocusedCell = collectionView.cellForItem(at: nextFocusedIndexPath) as? PlaylistImageCell {
                coordinator.addCoordinatedAnimations({
                    nextFocusedCell.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                }, completion: nil)
            }

            // Shrink the previously focused cell
            if let previouslyFocusedCell = collectionView.cellForItem(at: previouslyFocusedIndexPath) as? PlaylistImageCell {
                coordinator.addCoordinatedAnimations({
                    previouslyFocusedCell.transform = CGAffineTransform.identity
                }, completion: nil)
            }
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
        
        // Reload collection view
        playlistImagesCollectionView.reloadData()
    }
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let deselectedCell = tableView.cellForRow(at: indexPath)
        deselectedCell?.layer.borderWidth = 0 // Reset border width
        deselectedCell?.layer.borderColor = UIColor.clear.cgColor
    }

    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let nextFocusedIndexPath = context.nextFocusedIndexPath {
            if let nextFocusedCell = tableView.cellForRow(at: nextFocusedIndexPath) {
                nextFocusedCell.contentView.backgroundColor = UIColor(hex: "#A789FD")
            }
        }
        if let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath {
            if let previouslyFocusedCell = tableView.cellForRow(at: previouslyFocusedIndexPath) {
                previouslyFocusedCell.contentView.backgroundColor = UIColor.clear
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }
}

extension PlayListViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
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

        if let videoID = extractYouTubeVideoID(from: videoURL ?? "") {
        
            playVideo(videoIdentifier: videoID)
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
        cell.yearLabel.text = nil
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
            cell.yearLabel.text = playlists[selectedPlaylistIndex ?? 0].fields.artistNames?[indexPath.item]
            
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
