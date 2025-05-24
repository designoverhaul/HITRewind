import UIKit
import XCDYouTubeKit
import AVKit

class SearchViewController: UIViewController {
    
    // MARK: - UI Elements
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for artists..."
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = UIColor(hex: "#A789FD")
        searchBar.barTintColor = .black
        searchBar.backgroundColor = .black
        
        // Customize text field appearance
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = .white
            textField.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            textField.layer.cornerRadius = 12
            textField.layer.borderWidth = 1
            textField.layer.borderColor = UIColor(hex: "#A789FD").cgColor
            textField.font = UIFont.systemFont(ofSize: 18)
        }
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Search Artists"
        label.font = UIFont.boldSystemFont(ofSize: 32)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 500, height: 140)
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 20
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
    
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Search for your favorite artists above"
        label.font = UIFont.systemFont(ofSize: 18)
        label.textColor = .lightGray
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Properties
    private var searchResults: [SearchResult] = []
    private var searchTimer: Timer?
    private let searchService = SearchService.shared
    
    // Custom patterns to work around window.location.hostname.split error (same as PlayListViewController)
    private let safeCustomPatterns = [
        "\\b[cs]\\s*&&\\s*[adf]\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
        "\\b[a-zA-Z0-9]+\\s*&&\\s*[a-zA-Z0-9]+\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
        "(?:\\b|[^a-zA-Z0-9$])([a-zA-Z0-9$]{2})\\s*=\\s*function\\(\\s*a\\s*\\)\\s*\\{\\s*a\\s*=\\s*a\\.split\\(\\s*\"\"\\s*\\)"
    ]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupSearchBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Set focus to search bar initially
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(titleLabel)
        view.addSubview(searchBar)
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)
        view.addSubview(emptyStateLabel)
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            searchBar.heightAnchor.constraint(equalToConstant: 60),
            
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
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
        instructionLabel.isHidden = true
        collectionView.isHidden = true
    }
    
    private func hideLoadingState() {
        loadingIndicator.stopAnimating()
    }
    
    private func updateUI() {
        collectionView.reloadData()
        
        if searchResults.isEmpty {
            if searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                // Show instruction if no search text
                instructionLabel.isHidden = false
                emptyStateLabel.isHidden = true
                collectionView.isHidden = true
            } else {
                // Show empty state if search returned no results
                emptyStateLabel.isHidden = false
                instructionLabel.isHidden = true
                collectionView.isHidden = true
            }
        } else {
            instructionLabel.isHidden = true
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
        
        getVideoWithFixedPatterns(videoIdentifier: videoId) { [weak self] video, error in
            DispatchQueue.main.async {
                if let video = video, let streamURL = video.streamURL {
                    let player = AVPlayer(url: streamURL)
                    let playerViewController = AVPlayerViewController()
                    playerViewController.player = player
                    playerViewController.delegate = self
                    
                    self?.present(playerViewController, animated: true) {
                        player.play()
                    }
                } else {
                    self?.showErrorAlert(message: "Failed to load video")
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
    
    private func getVideoWithFixedPatterns(videoIdentifier: String, completion: @escaping (XCDYouTubeVideo?, Error?) -> Void) {
        XCDYouTubeClient.default().getVideoWithIdentifier(videoIdentifier) { video, error in
            if let error = error as NSError?, error.code == XCDYouTubeErrorCode.useCipherSignature.rawValue {
                // Apply custom patterns if signature error occurs
                XCDYouTubeClient.default().setLanguageIdentifier("en")
                for pattern in self.safeCustomPatterns {
                    XCDYouTubeClient.default().setCustomPatternMatching(pattern, forKey: "patternMatchingKey")
                }
                
                XCDYouTubeClient.default().getVideoWithIdentifier(videoIdentifier, completion: completion)
            } else {
                completion(video, error)
            }
        }
    }
    
    // MARK: - Focus Management
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if searchResults.isEmpty {
            return [searchBar]
        } else {
            return [collectionView]
        }
    }
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Cancel previous timer
        searchTimer?.invalidate()
        
        // Start new timer with 0.5 second delay to avoid too many API calls
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.performSearch(query: searchText)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let text = searchBar.text {
            performSearch(query: text)
        }
    }
}

// MARK: - UICollectionViewDataSource
extension SearchViewController: UICollectionViewDataSource {
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
extension SearchViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let result = searchResults[indexPath.item]
        playVideo(with: result.url)
    }
}

// MARK: - AVPlayerViewControllerDelegate
extension SearchViewController: AVPlayerViewControllerDelegate {
    func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        // Handle player dismissal if needed
    }
} 