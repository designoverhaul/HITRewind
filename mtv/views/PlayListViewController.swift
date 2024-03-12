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
        fetchPlaylists()
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
            playlistTableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            playlistTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            playlistTableView.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        // Add the playlistImagesCollectionView
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 20
        layout.itemSize = CGSize(width: 150, height: 150) // Adjust as needed

        playlistImagesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        playlistImagesCollectionView.backgroundColor = .clear
        playlistImagesCollectionView.dataSource = self
        playlistImagesCollectionView.delegate = self
        
        // Register the PlaylistImageCell class
        playlistImagesCollectionView.register(PlaylistImageCell.self, forCellWithReuseIdentifier: "PlaylistCell")
        view.addSubview(playlistImagesCollectionView)

        playlistImagesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playlistImagesCollectionView.leadingAnchor.constraint(equalTo: playlistTableView.trailingAnchor, constant: 20),
            playlistImagesCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playlistImagesCollectionView.topAnchor.constraint(equalTo: playlistTableView.topAnchor),
            playlistImagesCollectionView.bottomAnchor.constraint(equalTo: playlistTableView.bottomAnchor)
        ])
    }
    private func fetchPlaylists() {
        
        
        
        mtv.fetchPlaylists(apiKey: apiKey, baseURLString: playListUrl) { [weak self] result in
            switch result {
                case .success(let playlists):
                    self?.playlists = playlists
                    if self?.playlists.isEmpty==false{
                        self?.selectedPlaylistIndex=0
                    }
                    DispatchQueue.main.async {
                        self?.playlistTableView.reloadData()
                        self?.playlistImagesCollectionView.reloadData()
                    }
                case .failure(let error):
                    print("Error fetching playlists: \(error)")
            }
        }
    }
    
}

extension PlayListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath)

        // Configure the cell content here
        cell.textLabel?.text = String(playlists[indexPath.row].fields.year)
        cell.textLabel?.font = UIFont(name: "sf_pro-regular", size: 28) ?? UIFont.systemFont(ofSize: 20, weight: .bold)
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedCell = tableView.cellForRow(at: indexPath)
        selectedCell?.layer.borderWidth = 2
        selectedCell?.layer.borderColor = UIColor(hex: "#A789FD")?.cgColor

        // Fetch the selected playlist details
        let selectedPlaylist = playlists[indexPath.row]
        

        // Perform the necessary actions with the selected playlist
        // For example, you can update UI, fetch additional data, etc.
        // Here, we'll reload the collection view to show images related to the selected playlist
        DispatchQueue.main.async {
            self.selectedPlaylistIndex = indexPath.row
            self.playlistImagesCollectionView.reloadData()
        }
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
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let selectedPlaylistIndex = selectedPlaylistIndex, selectedPlaylistIndex < playlists.count else {
            return 0
        }
        return playlists[selectedPlaylistIndex].fields.videoUrls?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaylistCell", for: indexPath) as? PlaylistImageCell else {
            return UICollectionViewCell()
        }

        // Configure the cell content here
        if let videoURL = playlists[selectedPlaylistIndex ?? 0].fields.videoUrls?[indexPath.item],
           let videoID = extractYouTubeVideoID(from: videoURL) {
            let thumbnailURLString = "https://i.ytimg.com/vi/\(videoID)/sddefault.jpg"
            if let url = URL(string: thumbnailURLString) {
                cell.imageView.load(url: url)
            }
            
            cell.titleLabel.text = playlists[selectedPlaylistIndex ?? 0].fields.title // Use appropriate title from playlist model
            cell.yearLabel.text = "\(playlists[selectedPlaylistIndex ?? 0].fields.year)" // Use appropriate year from playlist model
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
