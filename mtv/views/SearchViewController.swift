import UIKit
import XCDYouTubeKit
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
    
    // Custom patterns to work around window.location.hostname.split error (same as PlayListViewController)
    private let safeCustomPatterns = [
        "\\b[cs]\\s*&&\\s*[adf]\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
        "\\b[a-zA-Z0-9]+\\s*&&\\s*[a-zA-Z0-9]+\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
        "(?:\\b|[^a-zA-Z0-9$])([a-zA-Z0-9$]{2})\\s*=\\s*function\\(\\s*a\\s*\\)\\s*\\{\\s*a\\s*=\\s*a\\.split\\(\\s*\"\"\\s*\\)"
    ]
    
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
        
        getVideoWithFixedPatterns(videoIdentifier: videoId) { [weak self] video, error in
            DispatchQueue.main.async {
                if let video = video, let streamURL = video.streamURL {
                    let player = AVPlayer(url: streamURL)
                    let playerViewController = AVPlayerViewController()
                    playerViewController.player = player
                    
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
            if let error = error as NSError?, error.code == -1000 { // Use numeric error code instead of useCipherSignature
                XCDYouTubeClient.default().getVideoWithIdentifier(videoIdentifier, completionHandler: completion)
            } else {
                completion(video, error)
            }
        }
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
    
    private func checkSubscriptionStatus(completion: (() -> Void)? = nil) {
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            guard let self = self else { return }
            if let customerInfo = customerInfo {
                let activeEntitlements = customerInfo.entitlements.all.filter { $0.value.isActive }
                self.isSubscribed = !activeEntitlements.isEmpty
            } else {
                self.isSubscribed = false
            }
            completion?()
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
        requireSubscription(on: self) { [weak self] (isSubscribed: Bool) in
            guard let self = self, isSubscribed else { return }
            let result = self.searchResults[indexPath.item]
            self.playVideo(with: result.url)
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