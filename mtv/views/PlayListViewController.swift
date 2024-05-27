import UIKit
import XCDYouTubeKit
import AVKit

class PlayListViewController: UIViewController, AVPlayerViewControllerDelegate {
    private var playlists: [Playlist] = []
    private var selectedPlaylistIndex: Int?
    private var visibleVideoIndices: [Int] = []

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
            return
        }
        print("Not empty playlist")
        selectedPlaylistIndex = 0
        let indexPath = IndexPath(row: 0, section: 0)
        tableView(playlistTableView, didSelectRowAt: indexPath) // Call didSelectRowAt method manually
    }

    private func setupUI() {
        view.backgroundColor = .black

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

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 52),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 66),
            imageView.widthAnchor.constraint(equalToConstant: 145),
            imageView.heightAnchor.constraint(equalToConstant: 115),
            selectedYearLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 50),
            selectedYearLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -2.2),
        ])
        
        playlistTableView = UITableView()
        playlistTableView.dataSource = self
        playlistTableView.delegate = self
        playlistTableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlaylistYear")
        view.addSubview(playlistTableView)
        playlistTableView.cellLayoutMarginsFollowReadableWidth = false
        playlistTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playlistTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -51),
            playlistTableView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 30),
            playlistTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            playlistTableView.widthAnchor.constraint(equalToConstant: 400)
        ])

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

    private func fetchPlaylists() {
        sortAndArrangePlaylists(apiKey: apiKey, baseURLString: playListUrl) { [weak self] result in
            switch result {
            case .success(let playlists):
                self?.playlists = playlists
                if self?.playlists.isEmpty == false {
                    self?.selectedPlaylistIndex = 0
                    DispatchQueue.main.async {
                        self?.playlistTableView.reloadData()
                        self?.updateVisibleVideoIndices()
                        self?.playlistImagesCollectionView.reloadData()
                        self?.hideLoadingIndicator()
                        self?.selectFirstPlaylist()
                    }
                }
            case .failure(let error):
                print("Error fetching playlists: \(error)")
                self?.hideLoadingIndicator()
            }
        }
    }

    private func updateVisibleVideoIndices() {
        guard let selectedPlaylistIndex = selectedPlaylistIndex else {
            visibleVideoIndices = []
            return
        }

        visibleVideoIndices = playlists[selectedPlaylistIndex].fields.isVisible.enumerated().compactMap { index, isVisible in
            isVisible ?? false ? index : nil
        }
    }
}

extension PlayListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if let nextFocusedIndexPath = context.nextFocusedIndexPath {
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
}

extension PlayListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistYear", for: indexPath)
        cell.textLabel?.text = String(playlists[indexPath.row].fields.year)
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
        selectedYearLabel.text = String(playlists[indexPath.row].fields.year)
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
}

extension PlayListViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
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

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return visibleVideoIndices.count
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

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaylistCell", for: indexPath) as? PlaylistImageCell else {
            return UICollectionViewCell()
        }

        guard let selectedPlaylistIndex = selectedPlaylistIndex, selectedPlaylistIndex < playlists.count else {
            return cell
        }

        let visibleIndex = visibleVideoIndices[indexPath.item]

        if let videoURL = playlists[selectedPlaylistIndex].fields.videoUrls?[visibleIndex], let videoID = extractYouTubeVideoID(from: videoURL) {
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
