import UIKit
// import XCDYouTubeKit // Replaced with YouTubeKit
import YouTubeKit // Added for the new YouTube player
import AVKit
// import RevenueCat // Temporarily commented out

// MARK: - YouTubeVideoQuality

// struct YouTubeVideoQuality { ... } // Removed duplicate definition

// MARK: - Concert Banner Models
struct Concert: Codable {
    let id: String
    let fields: ConcertFields
}

struct ConcertFields: Codable {
    let venueName: String?
    let artistName: String?
    let eventYear: String?
    let bannerImage: [BannerImageAttachment]?
    let largeImage: [BannerImageAttachment]?
    let eventDescription: String?
    let concertVideos: [String]?
    
    enum CodingKeys: String, CodingKey {
        case venueName = "venueName"
        case artistName = "artistName"
        case eventYear = "eventYear"
        case bannerImage = "bannerImage"
        case largeImage = "largeImage"
        case eventDescription = "eventDescription"
        case concertVideos = "Concert Videos"
    }
}

struct BannerImageAttachment: Codable {
    let url: String
    let filename: String?
    let width: Int?
    let height: Int?
}

struct ConcertResponse: Codable {
    let records: [Concert]
}

// MARK: - Legendary Show Models
struct LegendaryShow: Codable {
    let id: String
    let fields: LegendaryShowFields
}

struct LegendaryShowFields: Codable {
    let title: String?
    let artist: String?
    let year: String?
    let url: String?
    let thumbnail: String?
    
    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case artist = "Artist"
        case year = "Year"
        case url = "URL"
        case thumbnail = "thumbnail"
    }
}

struct LegendaryShowResponse: Codable {
    let records: [LegendaryShow]
}

// Function to fetch concerts from Concerts table
func fetchConcerts(apiKey: String, baseURLString: String, completion: @escaping (Result<[Concert], Error>) -> Void) {
    guard let url = URL(string: baseURLString) else {
        print("🎪 CONCERTS DEBUG: Failed to create URL")
        completion(.failure(NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }
    
    print("🎪 CONCERTS DEBUG: Final URL: \(url)")
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("🎪 CONCERTS DEBUG: Network error: \(error)")
            completion(.failure(error))
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🎪 CONCERTS DEBUG: HTTP Status: \(httpResponse.statusCode)")
        }
        
        guard let data = data else {
            print("🎪 CONCERTS DEBUG: No data received")
            completion(.failure(NSError(domain: "DataError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            return
        }
        
        print("🎪 CONCERTS DEBUG: Received data length: \(data.count)")
        
        do {
            let decoder = JSONDecoder()
            let concertResponse = try decoder.decode(ConcertResponse.self, from: data)
            let concerts = concertResponse.records
            print("🎪 CONCERTS DEBUG: Successfully decoded \(concerts.count) concerts")
            
            // Print details of each concert for debugging
            for (index, concert) in concerts.enumerated() {
                print("🎪 CONCERTS DEBUG: Concert \(index): \(concert.fields.venueName ?? "No venue"), Artist: \(concert.fields.artistName ?? "No artist")")
            }
            
            completion(.success(concerts))
        } catch {
            print("🎪 CONCERTS DEBUG: Decoding error: \(error)")
            completion(.failure(error))
        }
    }.resume()
}

// Function to fetch legendary shows from separate table
func fetchLegendaryShows(apiKey: String, baseURLString: String, completion: @escaping (Result<[LegendaryShow], Error>) -> Void) {
    // No filter needed since this is a dedicated legendary shows table
    guard let url = URL(string: baseURLString) else {
        print("🌟 LEGENDARY DEBUG: Failed to create URL")
        completion(.failure(NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }
    
    print("🌟 LEGENDARY DEBUG: Final URL: \(url)")
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("🌟 LEGENDARY DEBUG: Network error: \(error)")
            completion(.failure(error))
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🌟 LEGENDARY DEBUG: HTTP Status: \(httpResponse.statusCode)")
        }
        
        guard let data = data else {
            print("🌟 LEGENDARY DEBUG: No data received")
            completion(.failure(NSError(domain: "DataError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            return
        }
        
        print("🌟 LEGENDARY DEBUG: Received data length: \(data.count)")
        
        // Print raw JSON for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🌟 LEGENDARY DEBUG: Raw JSON response: \(jsonString)")
        }
        
        do {
            let decoder = JSONDecoder()
            let legendaryShowResponse = try decoder.decode(LegendaryShowResponse.self, from: data)
            let legendaryShows = legendaryShowResponse.records
            print("🌟 LEGENDARY DEBUG: Successfully decoded \(legendaryShows.count) shows")
            
            // Print details of each show for debugging
            for (index, show) in legendaryShows.enumerated() {
                print("🌟 LEGENDARY DEBUG: Show \(index): \(show.fields.title ?? "No title"), Artist: \(show.fields.artist ?? "No artist")")
            }
            
            completion(.success(legendaryShows))
        } catch {
            print("🌟 LEGENDARY DEBUG: Decoding error: \(error)")
            completion(.failure(error))
        }
    }.resume()
}

class LegendaryShowsViewController: UIViewController, AVPlayerViewControllerDelegate {
    
    // MARK: - Properties
    
    // Custom colors
    private let purpleColor = UIColor(red: 167/255, green: 137/255, blue: 253/255, alpha: 1.0)  // #A789FD
    private let darkGrayColor = UIColor(red: 41/255, green: 38/255, blue: 49/255, alpha: 1.0)   // #292631
    
    private var legendaryShows: [LegendaryShow] = []
    private var concerts: [Concert] = []
    private var collectionView: UICollectionView!
    private var bannerScrollView: UIScrollView!
    private var loadingIndicator: UIActivityIndicatorView!
    
    // Subscription management properties
    // private var isSubscribed: Bool = false // Temporarily commented out
    private var isSubscribed: Bool = true // Assume subscribed for debugging
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showLoadingIndicator()
        fetchConcerts()
        fetchLegendaryShows()
        // checkSubscriptionStatus() // Temporarily commented out
        print("LegendaryShowsViewController: checkSubscriptionStatus bypassed.")
        
        // Add observer for subscription status change
        // NotificationCenter.default.addObserver(self, selector: #selector(subscriptionStatusChanged), name: Notification.Name("SubscriptionStatusChanged"), object: nil) // Temporarily commented out
        
        // Add observer for banner selection (for tvOS compatibility)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBannerSelection(_:)),
            name: NSNotification.Name("BannerSelected"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // checkSubscriptionStatus() // Temporarily commented out
        print("LegendaryShowsViewController: viewWillAppear - subscription check bypassed.")
        isSubscribed = true // Assume subscribed
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // MTV logo imageView setup (same positioning as search screen)
        let imageView = UIImageView(image: UIImage(named: "logoVector"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        // Banner carousel setup - horizontal scrolling (will be added to a scroll view that scrolls with content)
        bannerScrollView = UIScrollView()
        bannerScrollView.backgroundColor = .clear
        bannerScrollView.showsHorizontalScrollIndicator = false
        bannerScrollView.showsVerticalScrollIndicator = false
        bannerScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Main content scroll view to contain both banner and collection view
        let mainScrollView = UIScrollView()
        mainScrollView.backgroundColor = .clear
        mainScrollView.showsHorizontalScrollIndicator = false
        mainScrollView.showsVerticalScrollIndicator = true
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainScrollView)
        
        // Container view for all scrollable content
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.addSubview(contentView)
        
        // Add banner scroll view to content view
        contentView.addSubview(bannerScrollView)
        
        // Collection view setup - 3 columns, full width
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 30
        layout.minimumLineSpacing = 40
        
        // Calculate item size for 4 columns using full width
        let screenWidth = UIScreen.main.bounds.width
        let totalHorizontalPadding: CGFloat = 80 // 40 on each side (reduced for full width)
        let totalSpacing: CGFloat = 3 * 30 // 3 spaces between 4 items
        let availableWidth = screenWidth - totalHorizontalPadding - totalSpacing
        let itemWidth = availableWidth / 4
        let itemHeight: CGFloat = 380 // Increased from 320 to provide more space for text
        
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        layout.sectionInset = UIEdgeInsets(top: 20, left: 40, bottom: 20, right: 40)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(LegendaryShowCell.self, forCellWithReuseIdentifier: "LegendaryShowCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(collectionView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Logo (same as search screen)
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 152),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            imageView.widthAnchor.constraint(equalToConstant: 98),
            imageView.heightAnchor.constraint(equalToConstant: 77),
            
            // Main scroll view
            mainScrollView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 30),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Content view within scroll view
            contentView.topAnchor.constraint(equalTo: mainScrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: mainScrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: mainScrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor),
            
            // Banner carousel (left-aligned with videos, scrolls with content)
            bannerScrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            bannerScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40), // Left-aligned with collection view
            bannerScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bannerScrollView.heightAnchor.constraint(equalToConstant: 280), // Height for banner images (10% larger: 231pt + padding)
            
            // Collection View (positioned below banner carousel within content)
            collectionView.topAnchor.constraint(equalTo: bannerScrollView.bottomAnchor, constant: 30),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 2000) // Fixed height for collection view content
        ])
    }
    
    // MARK: - Data Fetching
    
    private func fetchConcerts() {
        print("🎪 LegendaryShowsViewController: Starting to fetch concerts for banner carousel")
        
        MTV_Music_Videos.fetchConcerts(apiKey: apiKey, baseURLString: concertsUrl) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let concerts):
                print("🎪 LegendaryShowsViewController: Successfully fetched \(concerts.count) concerts")
                self.concerts = concerts
                DispatchQueue.main.async {
                    self.setupBannerCarousel()
                }
            case .failure(let error):
                print("🎪 LegendaryShowsViewController: Error fetching concerts: \(error)")
            }
        }
    }
    
    private func fetchLegendaryShows() {
        print("🌟 LegendaryShowsViewController: Starting to fetch legendary shows")
        
        MTV_Music_Videos.fetchLegendaryShows(apiKey: apiKey, baseURLString: legendaryShowsUrl) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let shows):
                print("🌟 LegendaryShowsViewController: Successfully fetched \(shows.count) legendary shows")
                self.legendaryShows = shows
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                    self.hideLoadingIndicator()
                }
            case .failure(let error):
                print("🌟 LegendaryShowsViewController: Error fetching legendary shows: \(error)")
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                }
            }
        }
    }
    
    // MARK: - Banner Carousel Setup
    
    private func setupBannerCarousel() {
        // Clear existing banner views
        bannerScrollView.subviews.forEach { $0.removeFromSuperview() }
        
        let bannerHeight: CGFloat = 231 // Increased by 10% from 210 to 231
        let bannerSpacing: CGFloat = 20
        var currentX: CGFloat = 0
        
        for (index, concert) in concerts.enumerated() {
            guard let bannerImages = concert.fields.bannerImage,
                  let firstBanner = bannerImages.first else { continue }
            
            // Create banner image view - no container, just the image
            let bannerImageView = FocusableBannerImageView()
            bannerImageView.contentMode = .scaleAspectFill
            bannerImageView.clipsToBounds = true
            bannerImageView.backgroundColor = UIColor.black.withAlphaComponent(0.1)
            bannerImageView.translatesAutoresizingMaskIntoConstraints = false
            bannerImageView.tag = index // For tap handling
            
            // Add tap gesture to banner
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(bannerTapped(_:)))
            bannerImageView.addGestureRecognizer(tapGesture)
            bannerImageView.isUserInteractionEnabled = true
            
            bannerScrollView.addSubview(bannerImageView)
            
            // Calculate banner width maintaining aspect ratio (banner images are 2108x556)
            let aspectRatio: CGFloat = 2108.0 / 556.0
            let bannerWidth = bannerHeight * aspectRatio
            
            // Position banner image
            NSLayoutConstraint.activate([
                bannerImageView.leadingAnchor.constraint(equalTo: bannerScrollView.leadingAnchor, constant: currentX),
                bannerImageView.topAnchor.constraint(equalTo: bannerScrollView.topAnchor, constant: 10),
                bannerImageView.widthAnchor.constraint(equalToConstant: bannerWidth),
                bannerImageView.heightAnchor.constraint(equalToConstant: bannerHeight)
            ])
            
            // Load banner image
            loadBannerImage(from: firstBanner.url, into: bannerImageView)
            
            currentX += bannerWidth + bannerSpacing
        }
        
        // Set scroll view content size
        bannerScrollView.contentSize = CGSize(width: max(currentX - bannerSpacing, 0), height: bannerHeight + 20)
    }
    
    private func loadBannerImage(from urlString: String, into imageView: UIImageView) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    imageView.image = image
                }
            }
        }.resume()
    }
    
    @objc private func handleBannerSelection(_ notification: Notification) {
        print("🎪 ===== NOTIFICATION BANNER SELECTION =====")
        guard let userInfo = notification.userInfo,
              let bannerTag = userInfo["bannerTag"] as? Int else {
            print("🎪 ❌ No banner tag in notification")
            return
        }
        
        print("🎪 Banner selected via notification - tag: \(bannerTag)")
        navigateToSingleConcert(bannerIndex: bannerTag)
    }
    
    @objc private func bannerTapped(_ gesture: UITapGestureRecognizer) {
        print("🎪 ===== BANNER TAP DETECTED =====")
        print("🎪 Gesture view: \(gesture.view?.description ?? "nil")")
        print("🎪 Gesture state: \(gesture.state.rawValue)")
        
        guard let imageView = gesture.view else {
            print("🎪 ❌ No gesture view found")
            return
        }
        
        print("🎪 Image view tag: \(imageView.tag)")
        print("🎪 Concerts count: \(concerts.count)")
        
        guard imageView.tag < concerts.count else {
            print("🎪 ❌ Tag \(imageView.tag) is out of bounds for concerts array")
            return
        }
        
        print("🎪 ✅ Banner tapped - calling navigateToSingleConcert")
        navigateToSingleConcert(bannerIndex: imageView.tag)
    }
    
    private func navigateToSingleConcert(bannerIndex: Int) {
        guard bannerIndex < concerts.count else {
            print("🎪 ❌ Banner index \(bannerIndex) out of bounds")
            return
        }

        let selectedConcert = concerts[bannerIndex]
        print("🎪 ✅ Navigating to concert: \(selectedConcert.fields.venueName ?? "Unknown")")
        print("🎪 Concert data: venueName=\(selectedConcert.fields.venueName ?? "nil"), artistName=\(selectedConcert.fields.artistName ?? "nil")")

        // --- ATTEMPT 1: NSClassFromString with the most likely module name ---
        let targetClassName = "MTV_Music_Videos.SingleConcertViewController"
        print("🎪 Trying NSClassFromString with target: \(targetClassName)...")
        
        var singleConcertVC: UIViewController?

        if let vcClass = NSClassFromString(targetClassName) as? UIViewController.Type {
            singleConcertVC = vcClass.init()
            print("🎪 ✅ Successfully created instance using: \(targetClassName)")
        } else {
            print("🎪 ❌ Failed with \(targetClassName). Trying other NSClassFromString variations...")
            // Debug known classes to find working module pattern
            print("🎪 DEBUG: Testing known classes to find working module pattern:")
            let testClasses = [
                "UIViewController",
                "LegendaryShowsViewController", 
                "mtv.LegendaryShowsViewController",
                "MTV_Music_Videos.LegendaryShowsViewController"
            ]
            for testClass in testClasses {
                if NSClassFromString(testClass) != nil {
                    print("🎪 DEBUG: ✅ Found: \(testClass)")
                } else {
                    print("🎪 DEBUG: ❌ Not found: \(testClass)")
                }
            }
            
            // Try other possible class names
            let possibleClassNames = [
                "SingleConcertViewController",                   // Just class name
                "mtv.SingleConcertViewController",              // Module.Class format
                "MTV Music Videos.SingleConcertViewController", // Space module name
                "_TtC3mtv25SingleConcertViewController",         // Swift mangled name pattern
                "_TtC17MTV_Music_Videos25SingleConcertViewController" // Mangled with module
            ]
            for className in possibleClassNames {
                if className == targetClassName { continue } // Skip if already tried
                print("🎪 Trying class name: \(className)")
                if let vcClassFallback = NSClassFromString(className) as? UIViewController.Type {
                    singleConcertVC = vcClassFallback.init()
                    print("🎪 ✅ Successfully created instance using: \(className)")
                    break
                }
            }
        }
        
        guard let concertVC = singleConcertVC else {
            print("🎪 ❌ Could not create SingleConcertViewController with any class name via NSClassFromString.")
            // Fallback 1: Storyboard (with try-catch AND identifier check)
            print("🎪 Trying storyboard instantiation as fallback 1...")
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            // Check if the identifier exists before trying to instantiate
            if (storyboard.value(forKey: "identifierToNibNameMap") as? [String: Any])?.keys.contains("SingleConcertViewController") == true {
                do {
                    let storyboardVC = storyboard.instantiateViewController(withIdentifier: "SingleConcertViewController")
                    print("🎪 ✅ Created from storyboard!")
                    
                    storyboardVC.setValue(selectedConcert.fields.venueName, forKey: "venueName")
                    storyboardVC.setValue(selectedConcert.fields.artistName, forKey: "artistName")
                    storyboardVC.setValue(selectedConcert.id, forKey: "concertRecordId")
                    storyboardVC.setValue(selectedConcert.fields.eventDescription, forKey: "eventDescription")
                    storyboardVC.setValue(selectedConcert.fields.eventYear, forKey: "eventYear")
                    if let largeImages = selectedConcert.fields.largeImage, let firstLargeImage = largeImages.first {
                        storyboardVC.setValue(firstLargeImage.url, forKey: "largeImageURL")
                    }
                    storyboardVC.modalPresentationStyle = .fullScreen
                    present(storyboardVC, animated: true)
                    return
                } catch {
                    print("🎪 ❌ Storyboard instantiation failed WITH an identifier but caught error: \(error)")
                }
            } else {
                print("🎪 ❌ Storyboard identifier 'SingleConcertViewController' NOT FOUND in Main.storyboard.")
            }

            // Fallback 2: Bundle ID check
            print("🎪 Trying bundle-based class name as fallback 2...")
            if let bundle = Bundle.main.infoDictionary,
               let bundleId = bundle["CFBundleIdentifier"] as? String {
                print("🎪 DEBUG: Bundle ID: \(bundleId)")
                let bundleClassNames = [
                    "\(bundleId).SingleConcertViewController",
                    "mtv.SingleConcertViewController" 
                ]
                for bundleClassName in bundleClassNames {
                    print("🎪 Trying bundle-based class name: \(bundleClassName)")
                    if let vcClass = NSClassFromString(bundleClassName) as? UIViewController.Type {
                        let bundleVC = vcClass.init()
                        print("🎪 ✅ Success with bundle-based name: \(bundleClassName)")
                        bundleVC.setValue(selectedConcert.fields.venueName, forKey: "venueName")
                        bundleVC.setValue(selectedConcert.fields.artistName, forKey: "artistName")
                        bundleVC.setValue(selectedConcert.id, forKey: "concertRecordId")
                        bundleVC.setValue(selectedConcert.fields.eventDescription, forKey: "eventDescription")
                        bundleVC.setValue(selectedConcert.fields.eventYear, forKey: "eventYear")
                        if let largeImages = selectedConcert.fields.largeImage, let firstLargeImage = largeImages.first {
                            bundleVC.setValue(firstLargeImage.url, forKey: "largeImageURL")
                        }
                        bundleVC.modalPresentationStyle = .fullScreen
                        present(bundleVC, animated: true)
                        return
                    }
                }
            }
            
            // Fallback 3: Manual Screen (Ultimate Fallback)
            print("🎪 Creating manual concert screen as ultimate fallback...")
            let manualVC = UIViewController()
            manualVC.view.backgroundColor = .black
            manualVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            
            // Create the same UI as SingleConcertViewController manually
            
            // Hero background image
            let heroBackgroundImageView = UIImageView()
            heroBackgroundImageView.contentMode = .scaleAspectFill
            heroBackgroundImageView.clipsToBounds = true
            heroBackgroundImageView.translatesAutoresizingMaskIntoConstraints = false
            manualVC.view.addSubview(heroBackgroundImageView)
            
            // Gradient overlay
            let gradientOverlay = UIView()
            gradientOverlay.translatesAutoresizingMaskIntoConstraints = false
            manualVC.view.addSubview(gradientOverlay)
            
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor.black.withAlphaComponent(0.3).cgColor,
                UIColor.black.withAlphaComponent(0.8).cgColor
            ]
            gradientLayer.locations = [0.0, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            gradientOverlay.layer.addSublayer(gradientLayer)
            
            // Logo
            let logoImageView = UIImageView(image: UIImage(named: "logoVector"))
            logoImageView.contentMode = .scaleAspectFill
            logoImageView.translatesAutoresizingMaskIntoConstraints = false
            manualVC.view.addSubview(logoImageView)
            
            // Container for text elements
            let heroTextContainer = UIView()
            heroTextContainer.translatesAutoresizingMaskIntoConstraints = false
            manualVC.view.addSubview(heroTextContainer)
            
            // Artist name label (purple)
            let artistNameLabel = UILabel()
            artistNameLabel.textColor = UIColor(red: 167/255, green: 137/255, blue: 253/255, alpha: 1.0)
            artistNameLabel.font = UIFont.systemFont(ofSize: 32, weight: .semibold)
            artistNameLabel.textAlignment = .left
            artistNameLabel.numberOfLines = 1
            artistNameLabel.text = selectedConcert.fields.artistName
            artistNameLabel.translatesAutoresizingMaskIntoConstraints = false
            heroTextContainer.addSubview(artistNameLabel)
            
            // Venue name label (white, bold)
            let venueNameLabel = UILabel()
            venueNameLabel.textColor = .white
            venueNameLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
            venueNameLabel.textAlignment = .left
            venueNameLabel.numberOfLines = 2
            venueNameLabel.text = selectedConcert.fields.venueName
            venueNameLabel.translatesAutoresizingMaskIntoConstraints = false
            heroTextContainer.addSubview(venueNameLabel)
            
            // Event description label
            let eventDescriptionLabel = UILabel()
            eventDescriptionLabel.textColor = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 1.0)
            eventDescriptionLabel.font = UIFont.systemFont(ofSize: 24, weight: .regular)
            eventDescriptionLabel.textAlignment = .left
            eventDescriptionLabel.numberOfLines = 0
            eventDescriptionLabel.text = selectedConcert.fields.eventDescription ?? "An unforgettable concert experience."
            eventDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
            heroTextContainer.addSubview(eventDescriptionLabel)
            
            // Five star rating
            let starsStackView = UIStackView()
            starsStackView.axis = .horizontal
            starsStackView.distribution = .fillEqually
            starsStackView.spacing = 8
            starsStackView.translatesAutoresizingMaskIntoConstraints = false
            
            for _ in 0..<5 {
                let starImageView = UIImageView(image: UIImage(systemName: "star.fill"))
                starImageView.tintColor = .white
                starImageView.contentMode = .scaleAspectFit
                starImageView.translatesAutoresizingMaskIntoConstraints = false
                starsStackView.addArrangedSubview(starImageView)
            }
            heroTextContainer.addSubview(starsStackView)
            
            // Layout constraints
            NSLayoutConstraint.activate([
                // Hero background - full screen
                heroBackgroundImageView.topAnchor.constraint(equalTo: manualVC.view.topAnchor),
                heroBackgroundImageView.leadingAnchor.constraint(equalTo: manualVC.view.leadingAnchor),
                heroBackgroundImageView.trailingAnchor.constraint(equalTo: manualVC.view.trailingAnchor),
                heroBackgroundImageView.heightAnchor.constraint(equalTo: manualVC.view.heightAnchor, multiplier: 0.7),
                
                // Gradient overlay - same as background
                gradientOverlay.topAnchor.constraint(equalTo: heroBackgroundImageView.topAnchor),
                gradientOverlay.leadingAnchor.constraint(equalTo: heroBackgroundImageView.leadingAnchor),
                gradientOverlay.trailingAnchor.constraint(equalTo: heroBackgroundImageView.trailingAnchor),
                gradientOverlay.bottomAnchor.constraint(equalTo: heroBackgroundImageView.bottomAnchor),
                
                // Logo - top left
                logoImageView.leadingAnchor.constraint(equalTo: manualVC.view.leadingAnchor, constant: 152),
                logoImageView.topAnchor.constraint(equalTo: manualVC.view.safeAreaLayoutGuide.topAnchor, constant: 40),
                logoImageView.widthAnchor.constraint(equalToConstant: 98),
                logoImageView.heightAnchor.constraint(equalToConstant: 77),
                
                // Hero text container - centered vertically on left side
                heroTextContainer.centerYAnchor.constraint(equalTo: heroBackgroundImageView.centerYAnchor),
                heroTextContainer.leadingAnchor.constraint(equalTo: manualVC.view.leadingAnchor, constant: 152),
                heroTextContainer.widthAnchor.constraint(equalTo: manualVC.view.widthAnchor, multiplier: 0.5),
                
                // Artist name - top of container
                artistNameLabel.topAnchor.constraint(equalTo: heroTextContainer.topAnchor),
                artistNameLabel.leadingAnchor.constraint(equalTo: heroTextContainer.leadingAnchor),
                artistNameLabel.trailingAnchor.constraint(equalTo: heroTextContainer.trailingAnchor),
                
                // Venue name - below artist
                venueNameLabel.topAnchor.constraint(equalTo: artistNameLabel.bottomAnchor, constant: 8),
                venueNameLabel.leadingAnchor.constraint(equalTo: heroTextContainer.leadingAnchor),
                venueNameLabel.trailingAnchor.constraint(equalTo: heroTextContainer.trailingAnchor),
                
                // Description - below venue
                eventDescriptionLabel.topAnchor.constraint(equalTo: venueNameLabel.bottomAnchor, constant: 12),
                eventDescriptionLabel.leadingAnchor.constraint(equalTo: heroTextContainer.leadingAnchor),
                eventDescriptionLabel.trailingAnchor.constraint(equalTo: heroTextContainer.trailingAnchor),
                
                // Stars - below description
                starsStackView.topAnchor.constraint(equalTo: eventDescriptionLabel.bottomAnchor, constant: 8),
                starsStackView.leadingAnchor.constraint(equalTo: heroTextContainer.leadingAnchor),
                starsStackView.widthAnchor.constraint(equalToConstant: 200),
                starsStackView.heightAnchor.constraint(equalToConstant: 24),
                starsStackView.bottomAnchor.constraint(equalTo: heroTextContainer.bottomAnchor)
            ])
            
            // Load hero image if available
            if let largeImages = selectedConcert.fields.largeImage,
               let firstLargeImage = largeImages.first,
               let imageURL = URL(string: firstLargeImage.url) {
                
                URLSession.shared.dataTask(with: imageURL) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            heroBackgroundImageView.image = image
                            gradientLayer.frame = gradientOverlay.bounds
                        }
                    }
                }.resume()
            }
            
            // Update gradient frame
            DispatchQueue.main.async {
                gradientLayer.frame = gradientOverlay.bounds
            }
            
            print("🎪 ✅ Manual concert screen created successfully!")
            present(manualVC, animated: true)
            return
        }
        
        // Set the concert data properties using setValue (key-value coding)
        concertVC.setValue(selectedConcert.fields.venueName, forKey: "venueName")
        concertVC.setValue(selectedConcert.fields.artistName, forKey: "artistName")
        concertVC.setValue(selectedConcert.id, forKey: "concertRecordId")
        concertVC.setValue(selectedConcert.fields.eventDescription, forKey: "eventDescription")
        concertVC.setValue(selectedConcert.fields.eventYear, forKey: "eventYear")
        print("🎪 ✅ Set basic properties")
        
        // Set the large image URL if available
        if let largeImages = selectedConcert.fields.largeImage,
           let firstLargeImage = largeImages.first {
            concertVC.setValue(firstLargeImage.url, forKey: "largeImageURL")
            print("🎪 ✅ Set large image URL: \(firstLargeImage.url)")
        }
        
        // Present the SingleConcert screen
        concertVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        print("🎪 About to present SingleConcertViewController...")
        
        present(concertVC, animated: true) {
            print("🎪 ✅ Successfully navigated to SingleConcert screen for: \(selectedConcert.fields.venueName ?? "Unknown")")
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
        loadingIndicator?.stopAnimating()
        loadingIndicator?.removeFromSuperview()
    }
    
    // MARK: - YouTube Playlist Support
    
    private func isPlaylistURL(_ url: String) -> Bool {
        return url.contains("playlist?list=") || url.contains("&list=")
    }
    
    private func extractPlaylistId(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else {
            return nil
        }
        
        return queryItems.first(where: { $0.name == "list" })?.value
    }
    
    private func fetchPlaylistVideoIds(playlistId: String, completion: @escaping ([String]) -> Void) {
        // YouTube Data API key - you'll need to add this to your constants
        let apiKey = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE" // Use your existing YouTube API key
        let urlString = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=\(playlistId)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("🌟 Invalid YouTube API URL")
            completion([])
            return
        }
        
        print("🌟 Fetching playlist videos from: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("🌟 Error fetching playlist: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("🌟 No data received from YouTube API")
                completion([])
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["items"] as? [[String: Any]] {
                    
                    let videoIds = items.compactMap { item -> String? in
                        guard let snippet = item["snippet"] as? [String: Any],
                              let resourceId = snippet["resourceId"] as? [String: Any],
                              let videoId = resourceId["videoId"] as? String else {
                            return nil
                        }
                        return videoId
                    }
                    
                    print("🌟 Successfully extracted \(videoIds.count) video IDs from playlist")
                    completion(videoIds)
                } else {
                    print("🌟 Failed to parse YouTube API response")
                    completion([])
                }
            } catch {
                print("🌟 Error parsing YouTube API response: \(error)")
                completion([])
            }
        }.resume()
    }
    
    // MARK: - Video Playback
    
    private func playVideo(with url: String) {
        // Check if this is a playlist URL
        if isPlaylistURL(url) {
            playPlaylist(with: url)
        } else {
            playSingleVideo(with: url)
        }
    }
    
    private func playPlaylist(with url: String) {
        guard let playlistId = extractPlaylistId(from: url) else {
            print("🌟 Could not extract playlist ID from URL: \(url)")
            return
        }
        
        print("🌟 Playing playlist with ID: \(playlistId)")
        
        // Show loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        fetchPlaylistVideoIds(playlistId: playlistId) { [weak self] videoIds in
            DispatchQueue.main.async {
                loadingIndicator.stopAnimating()
                loadingIndicator.removeFromSuperview()
                
                if videoIds.isEmpty {
                    print("🌟 No videos found in playlist")
                    return
                }
                
                print("🌟 Starting playlist playback with \(videoIds.count) videos")
                self?.playVideoPlaylist(videoIdentifiers: videoIds)
            }
        }
    }
    
    private func playSingleVideo(with url: String) {
        guard let videoId = extractVideoId(from: url) else {
            print("🌟 Invalid video URL: \(url)")
            // Consider showing an alert for invalid video ID format here
            let alert = UIAlertController(title: "Playback Error", message: "Invalid video URL format.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        let playerViewController = AVPlayerViewController()
        playerViewController.modalPresentationStyle = .fullScreen
        playerViewController.delegate = self
        
        print("🌟 LegendaryShowsViewController: Requesting stream from YouTubePlayerService for ID: \(videoId)")
        
        YouTubePlayerService.shared.getPlayableStreamURL(for: videoId) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                loadingIndicator.stopAnimating()
                loadingIndicator.removeFromSuperview()
                
                switch result {
                case .success(let streamURL):
                    print("🌟 LegendaryShowsViewController: YouTubePlayerService returned URL: \(streamURL) for video ID: \(videoId)")
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController.player = avPlayer
                    self.present(playerViewController, animated: true) {
                        print("✅ LegendaryShowsViewController: AVPlayerViewController presented for video ID: \(videoId)")
                        avPlayer.play()
                        print("▶️ LegendaryShowsViewController: avPlayer.play() called for video ID: \(videoId)")
                    }
                case .failure(let error):
                    print("🚫 LegendaryShowsViewController: YouTubePlayerService failed for video ID \(videoId). Error: \(error.localizedDescription)")
                    let alert = UIAlertController(title: "Playback Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    // MARK: - Playlist Playback (adapted from PlayListViewController)
    
    func playVideoPlaylist(videoIdentifiers: [String], currentIndex: Int = 0) {
        guard currentIndex < videoIdentifiers.count else {
            print("🌟 Playlist finished - all videos played")
            return
        }
        
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        let playerViewController = AVPlayerViewController()
        playerViewController.modalPresentationStyle = .fullScreen
        playerViewController.delegate = self
        
        let currentVideoIdentifier = videoIdentifiers[currentIndex]
        
        print("🌟 LegendaryShowsViewController (Playlist): Requesting stream from YouTubePlayerService for ID: \(currentVideoIdentifier)")

        YouTubePlayerService.shared.getPlayableStreamURL(for: currentVideoIdentifier) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                loadingIndicator.stopAnimating()
                loadingIndicator.removeFromSuperview()

                switch result {
                case .success(let streamURL):
                    print("🌟 LegendaryShowsViewController (Playlist): YouTubePlayerService returned URL: \(streamURL) for video ID: \(currentVideoIdentifier)")
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController.player = avPlayer
                    
                    self.present(playerViewController, animated: true) {
                        print("✅ LegendaryShowsViewController (Playlist): AVPlayerViewController presented for video ID: \(currentVideoIdentifier)")
                        avPlayer.play()
                        print("▶️ LegendaryShowsViewController (Playlist): avPlayer.play() called for video ID: \(currentVideoIdentifier)")
                        
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main) { [weak self, weak playerViewController] _ in
                            NotificationCenter.default.removeObserver(self as Any, name: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem)
                            playerViewController?.dismiss(animated: true) {
                                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                            }
                        }
                    }
                case .failure(let error):
                    print("🚫 LegendaryShowsViewController (Playlist): YouTubePlayerService failed for video ID \(currentVideoIdentifier). Error: \(error.localizedDescription)")
                    let alert = UIAlertController(title: "Playback Error", message: "Video \(currentVideoIdentifier) is unplayable: \(error.localizedDescription). Skipping to next.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                        self.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                    }))
                    self.present(alert, animated: true, completion: nil)
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
    
    // MARK: - Subscription Management
    
    private func checkSubscriptionStatus() {
        // Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in // Temporarily commented out
        //     guard let self = self else { return }

        //     if let customerInfo = customerInfo {
        //         let activeEntitlements = customerInfo.entitlements.all.filter { $0.value.isActive }
        //         if !activeEntitlements.isEmpty {
        //             self.isSubscribed = true
        //             print("🌟 LegendaryShowsViewController: User is subscribed")
        //         } else {
        //             self.isSubscribed = false
        //             print("🌟 LegendaryShowsViewController: User is not subscribed")
        //         }
        //     } else if let error = error {
        //         print("🌟 LegendaryShowsViewController: Error fetching customer info: \(error.localizedDescription)")
        //         self.isSubscribed = false
        //     }
        // }
        print("LegendaryShowsViewController: checkSubscriptionStatus called - Bypassed, assuming subscribed.")
        isSubscribed = true // Assume subscribed
    }
    
    @objc private func subscriptionStatusChanged() {
        // checkSubscriptionStatus() // Temporarily commented out
        print("LegendaryShowsViewController: subscriptionStatusChanged called - Bypassed.")
        isSubscribed = true // Assume subscribed
    }
    
    @objc private func navigateToPurchases() {
        // let purchasesViewController = PurchasesViewController() // Temporarily commented out
        // purchasesViewController.modalPresentationStyle = .fullScreen
        // present(purchasesViewController, animated: true, completion: nil)
        print("LegendaryShowsViewController: navigateToPurchases called - Bypassed.")
        // Optionally, show an alert that this feature is temporarily disabled
        let alert = UIAlertController(title: "Temporarily Disabled", message: "Access to the subscription screen is temporarily disabled for debugging.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Collection View Data Source

extension LegendaryShowsViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return legendaryShows.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LegendaryShowCell", for: indexPath) as? LegendaryShowCell else {
            return UICollectionViewCell()
        }
        
        let show = legendaryShows[indexPath.item]
        cell.configure(with: show)
        return cell
    }
}

// MARK: - Collection View Delegate

extension LegendaryShowsViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedShow = legendaryShows[indexPath.item]
        // requireSubscription(on: self) { [weak self] isSubscribed in // Temporarily commented out
        //     guard let self = self, isSubscribed else { return }
        //     if let url = selectedShow.fields.url {
        //         print("🌟 LegendaryShowsViewController: User subscribed, playing video: \(selectedShow.fields.title ?? "Unknown")")
        //         self.playVideo(with: url)
        //     }
        // }
        print("LegendaryShowsViewController: collectionView.didSelectItemAt - Bypassing requireSubscription.")
        if let url = selectedShow.fields.url {
            print("🌟 LegendaryShowsViewController: Playing video (subscription check bypassed): \(selectedShow.fields.title ?? "Unknown")")
            self.playVideo(with: url)
        }
    }
}

// MARK: - Legendary Show Cell

class LegendaryShowCell: UICollectionViewCell {
    // Container for thumbnail to allow glow without clipping
    private let thumbnailContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Title, artist, and year labels below the thumbnail
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        // Use system bold font directly instead of trying to load Anton-Regular
        label.font = UIFont.systemFont(ofSize: 27, weight: .bold)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private let artistLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hex: "#A789FD")
        label.font = UIFont.systemFont(ofSize: 25, weight: .semibold)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private let yearLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hex: "#A789FD")
        label.font = UIFont.systemFont(ofSize: 25, weight: .semibold)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupCell() {
        contentView.clipsToBounds = false
        layer.masksToBounds = false
        // Thumbnail container for glow
        contentView.addSubview(thumbnailContainer)
        thumbnailContainer.addSubview(imageView)
        // Remove overlay and move all meta below image
        contentView.addSubview(titleLabel)
        contentView.addSubview(artistLabel)
        contentView.addSubview(yearLabel)
        NSLayoutConstraint.activate([
            // Thumbnail container (for glow)
            thumbnailContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            thumbnailContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            thumbnailContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            thumbnailContainer.heightAnchor.constraint(equalTo: thumbnailContainer.widthAnchor, multiplier: 9.0/16.0),
            // Image view inside container
            imageView.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor),
            // Title label below thumbnail
            titleLabel.topAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            // Artist label below title
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            artistLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            artistLabel.trailingAnchor.constraint(lessThanOrEqualTo: yearLabel.leadingAnchor, constant: -8),
            // Year label inline with artist label, right-aligned
            yearLabel.centerYAnchor.constraint(equalTo: artistLabel.centerYAnchor),
            yearLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            yearLabel.leadingAnchor.constraint(greaterThanOrEqualTo: artistLabel.trailingAnchor, constant: 8),
            // Bottom constraint for cell - reduced since no two-line titles
            artistLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -5)
        ])
        // Compression/hugging priorities
        artistLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        artistLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        yearLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        yearLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        // Clear content for reuse
        titleLabel.text = nil
        artistLabel.text = nil
        yearLabel.text = nil
        thumbnailContainer.transform = .identity
        thumbnailContainer.layer.shadowOpacity = 0
    }
    func configure(with show: LegendaryShow) {
        titleLabel.text = show.fields.title ?? "Unknown Title"
        artistLabel.text = show.fields.artist ?? "Unknown Artist"
        artistLabel.isHidden = false
        yearLabel.text = show.fields.year ?? ""
        imageView.image = UIImage(systemName: "play.rectangle.fill")
        if let thumbnail = show.fields.thumbnail, !thumbnail.isEmpty {
            loadThumbnailFromURL(thumbnail)
        } else if let url = show.fields.url {
            if url.contains("playlist?list=") || url.contains("&list=") {
                if let playlistId = extractPlaylistIdFromURL(url) {
                    fetchPlaylistThumbnail(playlistId: playlistId)
                }
            } else if let videoId = extractVideoIdFromURL(url) {
                let thumbnailURL = "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
                loadThumbnailFromURL(thumbnailURL)
            }
        }
    }
    private func loadThumbnailFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.imageView.image = image
                }
            }
        }.resume()
    }
    private func fetchPlaylistThumbnail(playlistId: String) {
        let apiKey = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
        let urlString = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=1&playlistId=\(playlistId)&key=\(apiKey)"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]],
               let firstItem = items.first,
               let snippet = firstItem["snippet"] as? [String: Any],
               let resourceId = snippet["resourceId"] as? [String: Any],
               let videoId = resourceId["videoId"] as? String {
                let thumbnailURL = "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
                DispatchQueue.main.async {
                    self?.loadThumbnailFromURL(thumbnailURL)
                }
            }
        }.resume()
    }
    private func extractVideoIdFromURL(_ url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else { return nil }
        return queryItems.first(where: { $0.name == "v" })?.value
    }
    private func extractPlaylistIdFromURL(_ url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else { return nil }
        return queryItems.first(where: { $0.name == "list" })?.value
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.contentView.backgroundColor = UIColor(hex: "292631")
                self.contentView.layer.cornerRadius = 10
                self.contentView.layer.masksToBounds = true
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } else {
                self.contentView.backgroundColor = .clear
                self.contentView.layer.cornerRadius = 0
                self.contentView.layer.masksToBounds = false
                self.transform = CGAffineTransform.identity
            }
        }, completion: nil)
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        titleLabel.text = nil
        artistLabel.text = nil
        yearLabel.text = nil
        // Reset overlay background
        thumbnailContainer.transform = .identity
        thumbnailContainer.layer.shadowOpacity = 0
    }
    func hideArtistLabel() {
        artistLabel.isHidden = true
        // Optionally, adjust constraints if hiding the label affects layout significantly,
        // though for a simple hide, it might not be necessary if the space just remains empty.
    }
}

// MARK: - Focusable Banner Image View

class FocusableBannerImageView: UIImageView {
    
    override var canBecomeFocused: Bool {
        return true
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                // Scale up and add highlight when focused
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.layer.borderWidth = 3.0
                self.layer.borderColor = UIColor.white.cgColor
                // Bring to front with high z-index
                self.layer.zPosition = 1000
                print("🎪 Banner image focused - tag: \(self.tag)")
            } else {
                // Scale back down and remove highlight when not focused
                self.transform = CGAffineTransform.identity
                self.layer.borderWidth = 0.0
                self.layer.borderColor = UIColor.clear.cgColor
                // Reset z-index
                self.layer.zPosition = 0
                print("🎪 Banner image unfocused - tag: \(self.tag)")
            }
        }, completion: nil)
    }
    
    // Override pressesBegan to handle the select button press on tvOS
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        print("🎪 ===== PRESS DETECTED ON BANNER =====")
        print("🎪 Banner image tag: \(self.tag)")
        
        for press in presses {
            print("🎪 Press type: \(press.type.rawValue)")
            
            if press.type == .select {
                print("🎪 SELECT PRESS on banner with tag: \(self.tag)")
                
                // Send notification that this banner was selected
                NotificationCenter.default.post(
                    name: NSNotification.Name("BannerSelected"),
                    object: nil,
                    userInfo: ["bannerTag": self.tag]
                )
                
                return // Don't call super if we handled it
            }
        }
        
        super.pressesBegan(presses, with: event)
    }
}

// UIColor hex extension is already defined in ViewController.swift 