import UIKit
// import XCDYouTubeKit // No longer used, switched to YouTubePlayerService
import AVKit // For AVPlayerViewController
// No RevenueCat needed here directly unless checking subscription for individual videos



// Updated ConcertVideo struct to match Airtable and include id
struct ConcertVideo: Codable {
    let id: String // Airtable record ID
    let fields: ConcertVideoFields

    // Helper to get title and URL directly
    var videoTitle: String? { fields.videoTItle }
    var youtubeURL: String? { fields.youtubeUrl }
}

struct ConcertVideoFields: Codable {
    let videoTItle: String? // Field ID: fldwFg4q0ukNcWGI3
    let youtubeUrl: String? // Field ID: fldc4EdP5RvR3UzdG
    // The 'concert' field (fldBzu2kVWl9vKQJd) is used for filtering, not directly in the struct
}

// Response structure for Airtable API
struct ConcertVideoResponse: Codable {
    let records: [ConcertVideo]
}

@objc class SingleConcertViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, AVPlayerViewControllerDelegate {
    @objc var venueName: String! // To be set by presenting VC for the title
    @objc var artistName: String! // To be set by presenting VC
    @objc var concertRecordId: String! // To be set by presenting VC, used for fetching
    @objc var largeImageURL: String? // To be set by presenting VC for the hero background
    @objc var eventDescription: String? // To be set by presenting VC for the description
    @objc var eventYear: String? // To be set by presenting VC for the year

    var videos: [ConcertVideo] = []

    // MARK: - UI Elements
    
    // Logo (same as other screens)
    private let logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "logoVector"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // Hero background image
    private let heroBackgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // Gradient overlay to ensure text readability
    private let gradientOverlay: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Artist name label (now appears first)
    private let artistNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 167/255, green: 137/255, blue: 253/255, alpha: 1.0) // Purple color
        label.font = UIFont.systemFont(ofSize: 32, weight: .semibold)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Venue name label (now appears second)
    private let venueNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        label.textAlignment = .left
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Event description label (now appears third)
    private let eventDescriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 1.0) // Bright grey color
        label.font = UIFont.systemFont(ofSize: 24, weight: .regular)
        label.textAlignment = .left
        label.numberOfLines = 0 // Allow unlimited lines for natural text flow
        label.lineBreakMode = .byWordWrapping // Use word wrapping instead of truncating
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Five star rating display using SF symbols
    private let starsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create five star images using SF symbols
        for _ in 0..<5 {
            let starImageView = UIImageView(image: UIImage(systemName: "star.fill"))
            starImageView.tintColor = .white
            starImageView.contentMode = .scaleAspectFit
            starImageView.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(starImageView)
        }
        
        return stackView
    }()
    
    // Container view to hold and center the hero text elements
    private let heroTextContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var collectionView: UICollectionView!
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // Custom patterns for XCDYouTubeKit - NO LONGER NEEDED
    // private let safeCustomPatterns = [
    //     "\\b[cs]\\s*&&\\s*[adf]\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\((",
    //     "\\b[a-zA-Z0-9]+\\s*&&\\s*[a-zA-Z0-9]+\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\((",
    //     "(?:\\b|[^a-zA-Z0-9$])([a-zA-Z0-9$]{2})\\s*=\\s*function\\(\\s*a\\s*\\)\\s*\\{\\s*a\\s*=\\s*a\\.split\\(\\s*\"\"\\s*\\)"
    // ]



    // MARK: - Debug Initialization
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        print("🔍 DEBUG: SingleConcertViewController INIT called")
        print("🔍 DEBUG: nibName: \(nibNameOrNil ?? "nil"), bundle: \(nibBundleOrNil?.description ?? "nil")")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("🔍 DEBUG: SingleConcertViewController INIT from coder called")
    }
    
    deinit {
        // Clean up any notification observers
        NotificationCenter.default.removeObserver(self)
        print("🔍 DEBUG: SingleConcertViewController deinit - cleaned up observers")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // COMPREHENSIVE DEBUG LOGGING
        print("🔍 DEBUG: ==========================================")
        print("🔍 DEBUG: SingleConcertViewController viewDidLoad STARTED")
        print("🔍 DEBUG: ==========================================")
        print("🔍 DEBUG: venueName: \(venueName ?? "NIL")")
        print("🔍 DEBUG: artistName: \(artistName ?? "NIL")")
        print("🔍 DEBUG: concertRecordId: \(concertRecordId ?? "NIL")")
        print("🔍 DEBUG: largeImageURL: \(largeImageURL ?? "NIL")")
        print("🔍 DEBUG: navigationController: \(navigationController?.description ?? "NIL")")
        print("🔍 DEBUG: View bounds: \(view.bounds)")
        print("🔍 DEBUG: View frame: \(view.frame)")
        print("🔍 DEBUG: Screen bounds: \(UIScreen.main.bounds)")
        print("🔍 DEBUG: Safe area insets: \(view.safeAreaInsets)")
        
        view.backgroundColor = .black
        print("🔍 DEBUG: Set view backgroundColor to black")
        
        setupHeroSection() // Setup the new Netflix-style hero section
        print("🔍 DEBUG: Hero section setup completed")
        
        setupCollectionView() // Setup collection view (positioned below hero)
        print("🔍 DEBUG: Collection view setup completed")
        
        setupLoadingIndicator()
        print("🔍 DEBUG: Loading indicator setup completed")

        if let venue = venueName {
            print("🔍 DEBUG: About to fetch videos for venue: \(venue)")
            fetchConcertVideos(forVenueName: venue)
        } else {
            print("🔍 DEBUG: ❌ ERROR: venueName not set for SingleConcertViewController")
        }
        
        print("🔍 DEBUG: viewDidLoad COMPLETED")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🔍 DEBUG: SingleConcertViewController viewWillAppear")
        
        // Hide the navigation bar for full-screen experience
        navigationController?.setNavigationBarHidden(true, animated: animated)
        print("🔍 DEBUG: Navigation bar hidden")
        
        // Hide the tab bar for full-screen experience
        tabBarController?.tabBar.isHidden = true
        print("🔍 DEBUG: Tab bar hidden")
        
        print("🔍 DEBUG: View hierarchy at viewWillAppear:")
        debugViewHierarchy(view: view, level: 0)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("🔍 DEBUG: SingleConcertViewController viewWillDisappear")
        
        // Show the navigation bar when leaving this screen
        navigationController?.setNavigationBarHidden(false, animated: animated)
        print("🔍 DEBUG: Navigation bar restored")
        
        // Show the tab bar when leaving this screen
        tabBarController?.tabBar.isHidden = false
        print("🔍 DEBUG: Tab bar restored")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔍 DEBUG: SingleConcertViewController viewDidAppear")
        print("🔍 DEBUG: Final view bounds: \(view.bounds)")
        print("🔍 DEBUG: Final safe area insets: \(view.safeAreaInsets)")
        print("🔍 DEBUG: Hero background frame: \(heroBackgroundImageView.frame)")
        print("🔍 DEBUG: Logo frame: \(logoImageView.frame)")
        print("🔍 DEBUG: Hero text container frame: \(heroTextContainer.frame)")
        print("🔍 DEBUG: Artist label frame: \(artistNameLabel.frame)")
        print("🔍 DEBUG: Venue label frame: \(venueNameLabel.frame)")
        print("🔍 DEBUG: Event description label frame: \(eventDescriptionLabel.frame)")
        print("🔍 DEBUG: Stars stack view frame: \(starsStackView.frame)")
        print("🔍 DEBUG: Event description text: '\(eventDescriptionLabel.text ?? "NIL")'")
        
        if let collection = collectionView {
            print("🔍 DEBUG: Collection view frame: \(collection.frame)")
            print("🔍 DEBUG: Collection view bounds: \(collection.bounds)")
            print("🔍 DEBUG: Collection view.isHidden: \(collection.isHidden)")
            print("🔍 DEBUG: Collection view.alpha: \(collection.alpha)")
            print("🔍 DEBUG: Collection view dataSource: \(collection.dataSource != nil)")
            print("🔍 DEBUG: Collection view delegate: \(collection.delegate != nil)")
            print("🔍 DEBUG: Collection view numberOfSections: \(collection.numberOfSections)")
            if collection.numberOfSections > 0 {
                print("🔍 DEBUG: Collection view numberOfItems in section 0: \(collection.numberOfItems(inSection: 0))")
            }
            print("🔍 DEBUG: Videos array count in viewDidAppear: \(videos.count)")
            print("🔍 DEBUG: Videos array isEmpty in viewDidAppear: \(videos.isEmpty)")
        }
        
        // Debug entire view hierarchy
        print("🔍 DEBUG: ==========================================")
        print("🔍 DEBUG: COMPLETE VIEW HIERARCHY")
        print("🔍 DEBUG: ==========================================")
        debugViewHierarchyDetailed(view: view, level: 0)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update gradient layer frame
        if let gradientLayer = gradientOverlay.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = gradientOverlay.bounds
        }
    }
    
    private func debugViewHierarchy(view: UIView, level: Int) {
        let indent = String(repeating: "  ", count: level)
        print("🔍 DEBUG: \(indent)- \(type(of: view)) frame: \(view.frame) hidden: \(view.isHidden) alpha: \(view.alpha)")
        for subview in view.subviews {
            debugViewHierarchy(view: subview, level: level + 1)
        }
    }
    
    private func debugViewHierarchyDetailed(view: UIView, level: Int) {
        let indent = String(repeating: "  ", count: level)
        print("🔍 DEBUG: \(indent)- \(type(of: view)) frame: \(view.frame) hidden: \(view.isHidden) alpha: \(view.alpha)")
        for subview in view.subviews {
            debugViewHierarchyDetailed(view: subview, level: level + 1)
        }
    }
    
    // MARK: - Navigation Management
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        
        for press in presses {
            if press.type == .menu {
                print("🚀 DEBUG: ==========================================")
                print("🚀 DEBUG: MENU BUTTON PRESSED ON SINGLE CONCERT")
                print("🚀 DEBUG: ==========================================")
                print("🚀 DEBUG: navigationController exists: \(navigationController != nil)")
                print("🚀 DEBUG: navigationController view controllers count: \(navigationController?.viewControllers.count ?? 0)")
                
                // IMPORTANT: Check if we have a presented view controller (like video player)
                // If so, let it handle the menu press first instead of dismissing ourselves
                if let presentedVC = presentedViewController {
                    print("🚀 DEBUG: 🎬 Video player or other VC is presented (\(type(of: presentedVC))), letting it handle menu press")
                    // Don't handle the menu press ourselves - let the presented VC handle it
                    // This ensures the video player dismisses itself and returns to SingleConcertViewController
                    handled = false
                } else {
                    if let navController = navigationController {
                        print("🚀 DEBUG: Navigation controller view controllers:")
                        for (index, vc) in navController.viewControllers.enumerated() {
                            print("🚀 DEBUG:   [\(index)]: \(type(of: vc))")
                        }
                    }
                    
                    // Handle back navigation - ensure we go back to Epic Shows screen
                    if let navController = navigationController, navController.viewControllers.count > 1 {
                        print("🚀 DEBUG: ✅ Popping view controller from navigation stack")
                        DispatchQueue.main.async {
                            navController.popViewController(animated: true)
                        }
                        handled = true
                    } else if presentingViewController != nil {
                        print("🚀 DEBUG: ⚠️ Presented modally - dismissing")
                        DispatchQueue.main.async {
                            self.dismiss(animated: true, completion: nil)
                        }
                        handled = true
                    } else {
                        print("🚀 DEBUG: ❌ No clear navigation path - attempting to find parent")
                        // Try to find the tab bar controller and switch to Music Videos tab
                        if let tabBarController = findTabBarController() {
                            print("🚀 DEBUG: Found tab bar controller - switching to Music Videos tab")
                            DispatchQueue.main.async {
                                tabBarController.selectedIndex = 1 // Music Videos is now at index 1
                            }
                            handled = true
                        }
                    }
                    
                    print("🚀 DEBUG: Back navigation initiated (handled: \(handled))")
                }
                
                if handled {
                    return // Don't call super if we handled it
                }
            }
        }
        
        // Only call super if we didn't handle the menu press
        super.pressesBegan(presses, with: event)
    }
    
    // Helper method to find the tab bar controller
    private func findTabBarController() -> UITabBarController? {
        var current: UIViewController? = self
        while current != nil {
            if let tabBarController = current as? UITabBarController {
                return tabBarController
            }
            current = current?.parent
        }
        
        // Also check via the window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return findTabBarControllerInHierarchy(view: window.rootViewController)
        }
        
        return nil
    }
    
    private func findTabBarControllerInHierarchy(view: UIViewController?) -> UITabBarController? {
        guard let view = view else { return nil }
        
        if let tabBarController = view as? UITabBarController {
            return tabBarController
        }
        
        for child in view.children {
            if let found = findTabBarControllerInHierarchy(view: child) {
                return found
            }
        }
        
        return nil
    }
    
    // MARK: - UI Setup
    
    private func setupHeroSection() {
        print("🔍 DEBUG: setupHeroSection STARTED")
        
        // Add hero background image
        view.addSubview(heroBackgroundImageView)
        
        // Add gradient overlay for text readability
        view.addSubview(gradientOverlay)
        setupGradientOverlay()
        
        // Add logo
        view.addSubview(logoImageView)
        
        // Add container for hero text elements
        view.addSubview(heroTextContainer)
        
        // Add artist, venue, description labels and stars to the container
        heroTextContainer.addSubview(artistNameLabel)
        heroTextContainer.addSubview(venueNameLabel)
        heroTextContainer.addSubview(eventDescriptionLabel)
        heroTextContainer.addSubview(starsStackView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Hero background image - covers top portion of screen (reduced from 60% to 50%)
            heroBackgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            heroBackgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            heroBackgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heroBackgroundImageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5), // 50% of screen height
            
            // Gradient overlay matches hero background
            gradientOverlay.topAnchor.constraint(equalTo: heroBackgroundImageView.topAnchor),
            gradientOverlay.leadingAnchor.constraint(equalTo: heroBackgroundImageView.leadingAnchor),
            gradientOverlay.trailingAnchor.constraint(equalTo: heroBackgroundImageView.trailingAnchor),
            gradientOverlay.bottomAnchor.constraint(equalTo: heroBackgroundImageView.bottomAnchor),
            
            // Logo - same position as other screens
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 152),
            logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            logoImageView.widthAnchor.constraint(equalToConstant: 98),
            logoImageView.heightAnchor.constraint(equalToConstant: 77),
            
            // Hero text container - positioned lower in the hero section to give space above artist name
            heroTextContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            heroTextContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            heroTextContainer.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 60), // 60pt margin below logo
            
            // Artist name - at the top of the container
            artistNameLabel.topAnchor.constraint(equalTo: heroTextContainer.topAnchor),
            artistNameLabel.leadingAnchor.constraint(equalTo: heroTextContainer.leadingAnchor),
            artistNameLabel.trailingAnchor.constraint(equalTo: heroTextContainer.trailingAnchor),
            
            // Venue name - below artist name
            venueNameLabel.topAnchor.constraint(equalTo: artistNameLabel.bottomAnchor, constant: 8),
            venueNameLabel.leadingAnchor.constraint(equalTo: heroTextContainer.leadingAnchor),
            venueNameLabel.trailingAnchor.constraint(equalTo: heroTextContainer.trailingAnchor),
            
            // Event description - below venue name, 50% width to prevent hyphenation
            eventDescriptionLabel.topAnchor.constraint(equalTo: venueNameLabel.bottomAnchor, constant: 12),
            eventDescriptionLabel.leadingAnchor.constraint(equalTo: heroTextContainer.leadingAnchor),
            eventDescriptionLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            
            // Stars stack view - positioned right below description with minimal spacing
            starsStackView.topAnchor.constraint(equalTo: eventDescriptionLabel.bottomAnchor, constant: 8),
            starsStackView.leadingAnchor.constraint(equalTo: heroTextContainer.leadingAnchor),
            starsStackView.widthAnchor.constraint(equalToConstant: 200), // Fixed width for 5 stars
            starsStackView.heightAnchor.constraint(equalToConstant: 24), // Fixed height for star icons
            starsStackView.bottomAnchor.constraint(equalTo: heroTextContainer.bottomAnchor)
        ])
        
        // Set the content (in order: artist, venue, description)
        artistNameLabel.text = artistName
        
        // Create attributed string for venue name (bold) + event year (regular)
        let attributedVenueText = NSMutableAttributedString()
        
        // Add venue name with bold font
        if let venue = venueName {
            // Use system bold font directly instead of trying to load Anton-Regular
            let boldFont = UIFont.systemFont(ofSize: 48, weight: .bold)
            
            let venueAttributes: [NSAttributedString.Key: Any] = [
                .font: boldFont,
                .foregroundColor: UIColor.white
            ]
            attributedVenueText.append(NSAttributedString(string: venue, attributes: venueAttributes))
        }
        
        // Add event year with regular font
        if let year = eventYear, !year.isEmpty {
            let regularFont = UIFont.systemFont(ofSize: 48, weight: .regular)
            let yearAttributes: [NSAttributedString.Key: Any] = [
                .font: regularFont,
                .foregroundColor: UIColor.white
            ]
            attributedVenueText.append(NSAttributedString(string: " \(year)", attributes: yearAttributes))
        }
        
        venueNameLabel.attributedText = attributedVenueText
        
        // Set description text with no-hyphenation attributes
        let descriptionText = eventDescription ?? "Event details will be available soon"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.hyphenationFactor = 0.0 // Disable hyphenation completely
        paragraphStyle.lineBreakMode = .byWordWrapping // Break at word boundaries only
        paragraphStyle.lineBreakStrategy = .hangulWordPriority // Prioritize whole words
        
        let descriptionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .regular),
            .foregroundColor: UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        
        eventDescriptionLabel.attributedText = NSAttributedString(string: descriptionText, attributes: descriptionAttributes)
        
        // Debug the content being set
        print("🔍 DEBUG: Setting hero content:")
        print("🔍 DEBUG: Artist: \(artistName ?? "NIL")")
        print("🔍 DEBUG: Venue: \(venueName ?? "NIL")")
        print("🔍 DEBUG: Year: \(eventYear ?? "NIL")")
        print("🔍 DEBUG: Description: \(eventDescription ?? "NIL")")
        
        // Load the large hero image if available
        if let imageURLString = largeImageURL, let imageURL = URL(string: imageURLString) {
            print("🔍 DEBUG: Loading hero image from: \(imageURLString)")
            loadHeroImage(from: imageURL)
        } else {
            print("🔍 DEBUG: No largeImageURL provided, using default background")
            heroBackgroundImageView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        }
        
        print("🔍 DEBUG: setupHeroSection COMPLETED")
    }
    
    private func setupGradientOverlay() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.3).cgColor, // Top - lighter
            UIColor.black.withAlphaComponent(0.8).cgColor  // Bottom - darker for text
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        
        gradientOverlay.layer.addSublayer(gradientLayer)
        
        // Update gradient frame when layout changes
        DispatchQueue.main.async {
            gradientLayer.frame = self.gradientOverlay.bounds
        }
    }
    
    private func loadHeroImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("🔍 DEBUG: Error loading hero image: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("🔍 DEBUG: Failed to create image from data")
                return
            }
            
            DispatchQueue.main.async {
                print("🔍 DEBUG: ✅ Hero image loaded successfully")
                self?.heroBackgroundImageView.image = image
            }
        }.resume()
    }

    private func setupCollectionView() {
        print("🔍 DEBUG: setupCollectionView STARTED")
        
        let layout = UICollectionViewFlowLayout()
        // 4-column grid layout
        let screenWidth = UIScreen.main.bounds.width
        let totalHorizontalPadding: CGFloat = 80 // 40 on each side
        let totalSpacing: CGFloat = 3 * 30 // 3 spaces between 4 items
        let availableWidth = screenWidth - totalHorizontalPadding - totalSpacing
        let itemWidth = availableWidth / 4 // 4 columns
        let itemHeight: CGFloat = 320 // Reduced from 360 to reduce bottom padding
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        layout.minimumInteritemSpacing = 30
        layout.minimumLineSpacing = 40
        layout.sectionInset = UIEdgeInsets(top: 40, left: 40, bottom: 20, right: 40)
        
        print("🔍 DEBUG: Layout configured - itemSize: \(layout.itemSize), spacing: \(layout.minimumInteritemSpacing)")

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        print("🔍 DEBUG: ✅ Collection view created with layout: \(layout)")
        
        collectionView.backgroundColor = .clear
        print("🔍 DEBUG: ✅ Background color set to clear")
        
        collectionView.dataSource = self
        print("🔍 DEBUG: ✅ DataSource set to: \(self)")
        
        collectionView.delegate = self
        print("🔍 DEBUG: ✅ Delegate set to: \(self)")
        
        collectionView.register(LegendaryShowCell.self, forCellWithReuseIdentifier: "VideoCell")
        print("🔍 DEBUG: ✅ Cell registered: LegendaryShowCell with identifier 'VideoCell'")
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        print("🔍 DEBUG: ✅ Auto layout constraints disabled")
        
        view.addSubview(collectionView)
        print("🔍 DEBUG: ✅ Collection view added to view hierarchy")
        
        print("🔍 DEBUG: Collection view properties after creation:")
        print("🔍 DEBUG:   - Frame: \(collectionView.frame)")
        print("🔍 DEBUG:   - Bounds: \(collectionView.bounds)")
        print("🔍 DEBUG:   - isHidden: \(collectionView.isHidden)")
        print("🔍 DEBUG:   - alpha: \(collectionView.alpha)")
        print("🔍 DEBUG:   - superview: \(collectionView.superview != nil)")
        
        print("🔍 DEBUG: Collection view created and added to view")

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: heroBackgroundImageView.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        print("🔍 DEBUG: Collection view constraints activated")
        print("🔍 DEBUG: setupCollectionView COMPLETED")
    }

    private func setupLoadingIndicator() {
        print("🔍 DEBUG: setupLoadingIndicator STARTED")
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        print("🔍 DEBUG: Loading indicator setup completed")
    }

    private func fetchConcertVideos(forVenueName venueName: String) {
        print("🔍 DEBUG: ==========================================")
        print("🔍 DEBUG: fetchConcertVideos STARTED")
        print("🔍 DEBUG: ==========================================")
        print("🔍 DEBUG: Venue name: '\(venueName)'")
        
        loadingIndicator.startAnimating()
        print("🔍 DEBUG: Loading indicator started")
        
        // Filter by concert name (venueName) as in Airtable and use Grid view to maintain order
        let encodedFilter = "({concert} = \"\(venueName)\")".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/tbloVr52R37ZRNLFS?filterByFormula=\(encodedFilter)&view=Grid%20view"
        
        print("🔍 DEBUG: Filter: \(encodedFilter)")
        print("🔍 DEBUG: URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("🔍 DEBUG: ❌ ERROR: Invalid URL for fetching concert videos")
            DispatchQueue.main.async { self.loadingIndicator.stopAnimating() }
            return
        }

        var request = URLRequest(url: url)
        // Replace YOUR_API_KEY with your actual Airtable API key
        // It's better to store API keys securely, e.g., in a configuration file not committed to repo
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") // Assuming apiKey is globally available or passed
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔍 DEBUG: API request configured, starting network call...")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            print("🔍 DEBUG: Network response received")
            
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                print("🔍 DEBUG: Loading indicator stopped")
            }

            if let error = error {
                print("🔍 DEBUG: ❌ Network error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔍 DEBUG: ❌ No HTTP response")
                return
            }
            
            print("🔍 DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("🔍 DEBUG: ❌ Non-200 HTTP response. Status: \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("🔍 DEBUG: Airtable Error Response: \(errorString)")
                }
                return
            }

            guard let data = data else {
                print("🔍 DEBUG: ❌ No data received")
                return
            }
            
            print("🔍 DEBUG: ✅ Data received, size: \(data.count) bytes")
            
            // Log raw JSON for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 DEBUG: Raw JSON Response: \(jsonString)")
            }

            do {
                let decoder = JSONDecoder()
                let videoResponse = try decoder.decode(ConcertVideoResponse.self, from: data)
                print("🔍 DEBUG: ✅ JSON decoded successfully")
                print("🔍 DEBUG: Number of videos found: \(videoResponse.records.count)")
                
                // Add extensive debugging before setting videos
                print("🔍 DEBUG: ==========================================")
                print("🔍 DEBUG: ABOUT TO SET VIDEOS ARRAY")
                print("🔍 DEBUG: ==========================================")
                print("🔍 DEBUG: Current videos array count: \(self?.videos.count ?? -1)")
                print("🔍 DEBUG: About to set videos array to: \(videoResponse.records.count) items")
                
                self?.videos = videoResponse.records
                
                print("🔍 DEBUG: ✅ Videos array updated!")
                print("🔍 DEBUG: New videos array count: \(self?.videos.count ?? -1)")
                print("🔍 DEBUG: Videos array isEmpty: \(self?.videos.isEmpty ?? true)")
                
                // Log each video for debugging
                for (index, video) in videoResponse.records.enumerated() {
                    print("🔍 DEBUG: Video \(index): ID=\(video.id), Title=\(video.videoTitle ?? "NIL"), URL=\(video.youtubeURL ?? "NIL")")
                }
                
                // Additional debugging to verify the videos array is properly set
                print("🔍 DEBUG: ==========================================")
                print("🔍 DEBUG: VERIFICATION AFTER SETTING VIDEOS")
                print("🔍 DEBUG: ==========================================")
                if let strongSelf = self {
                    print("🔍 DEBUG: strongSelf.videos.count: \(strongSelf.videos.count)")
                    print("🔍 DEBUG: strongSelf.videos.isEmpty: \(strongSelf.videos.isEmpty)")
                    if !strongSelf.videos.isEmpty {
                        print("🔍 DEBUG: First video title: \(strongSelf.videos.first?.videoTitle ?? "NIL")")
                        print("🔍 DEBUG: Last video title: \(strongSelf.videos.last?.videoTitle ?? "NIL")")
                    }
                } else {
                    print("🔍 DEBUG: ❌ self is nil!")
                }
                
                DispatchQueue.main.async {
                    print("🔍 DEBUG: ==========================================")
                    print("🔍 DEBUG: RELOADING COLLECTION VIEW")
                    print("🔍 DEBUG: ==========================================")
                    print("🔍 DEBUG: On main thread: \(Thread.isMainThread)")
                    print("🔍 DEBUG: Collection view exists: \(self?.collectionView != nil)")
                    
                    guard let self = self else {
                        print("🔍 DEBUG: ❌ self is nil in main async block")
                        return
                    }
                    
                    print("🔍 DEBUG: Collection view frame before reload: \(self.collectionView.frame)")
                    print("🔍 DEBUG: Collection view bounds before reload: \(self.collectionView.bounds)")
                    print("🔍 DEBUG: Collection view is hidden: \(self.collectionView.isHidden)")
                    print("🔍 DEBUG: Collection view alpha: \(self.collectionView.alpha)")
                    print("🔍 DEBUG: Collection view dataSource set: \(self.collectionView.dataSource != nil)")
                    print("🔍 DEBUG: Collection view delegate set: \(self.collectionView.delegate != nil)")
                    print("🔍 DEBUG: Videos count before reload: \(self.videos.count)")
                    
                    print("🔍 DEBUG: About to call reloadData()...")
                    self.collectionView.reloadData()
                    print("🔍 DEBUG: ✅ reloadData() called")
                    
                    if self.videos.isEmpty {
                        print("🔍 DEBUG: ⚠️ No videos found for this concert")
                    } else {
                        print("🔍 DEBUG: ✅ Collection view reloaded with \(self.videos.count) videos")
                    }
                    
                    // Additional debugging - check if reloadData actually calls numberOfItemsInSection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🔍 DEBUG: ==========================================")
                        print("🔍 DEBUG: POST-RELOAD CHECK (after 0.5s)")
                        print("🔍 DEBUG: ==========================================")
                        print("🔍 DEBUG: Collection view numberOfSections: \(self.collectionView.numberOfSections)")
                        if self.collectionView.numberOfSections > 0 {
                            print("🔍 DEBUG: Collection view numberOfItemsInSection 0: \(self.collectionView.numberOfItems(inSection: 0))")
                        }
                        print("🔍 DEBUG: Collection view visible cells count: \(self.collectionView.visibleCells.count)")
                        print("🔍 DEBUG: Collection view frame after reload: \(self.collectionView.frame)")
                        print("🔍 DEBUG: Collection view content size: \(self.collectionView.contentSize)")
                        print("🔍 DEBUG: Collection view content offset: \(self.collectionView.contentOffset)")
                        
                        // Force layout if needed
                        print("🔍 DEBUG: Forcing layout update...")
                        self.collectionView.setNeedsLayout()
                        self.collectionView.layoutIfNeeded()
                        
                        // Check again after layout
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            print("🔍 DEBUG: After forced layout - visible cells: \(self.collectionView.visibleCells.count)")
                            print("🔍 DEBUG: After forced layout - content size: \(self.collectionView.contentSize)")
                        }
                    }
                }
            } catch {
                print("🔍 DEBUG: ❌ JSON decoding error: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    print("🔍 DEBUG: Decoding error details: \(decodingError)")
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                     print("🔍 DEBUG: Problematic JSON: \(jsonString)")
                }
            }
        }.resume()
        
        print("🔍 DEBUG: Network request started")
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("🔍 DEBUG: ==========================================")
        print("🔍 DEBUG: numberOfItemsInSection CALLED")
        print("🔍 DEBUG: ==========================================")
        print("🔍 DEBUG: Collection view: \(collectionView)")
        print("🔍 DEBUG: Collection view bounds: \(collectionView.bounds)")
        print("🔍 DEBUG: Section: \(section)")
        print("🔍 DEBUG: videos.count: \(videos.count)")
        print("🔍 DEBUG: videos.isEmpty: \(videos.isEmpty)")
        
        if !videos.isEmpty {
            print("🔍 DEBUG: First video in numberOfItemsInSection: \(videos.first?.videoTitle ?? "NIL")")
        } else {
            print("🔍 DEBUG: ⚠️ Videos array is EMPTY in numberOfItemsInSection")
        }
        
        print("🔍 DEBUG: Returning count: \(videos.count)")
        return videos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("🔍 DEBUG: ==========================================")
        print("🔍 DEBUG: cellForItemAt CALLED")
        print("🔍 DEBUG: ==========================================")
        print("🔍 DEBUG: IndexPath: \(indexPath)")
        print("🔍 DEBUG: Row: \(indexPath.item), Section: \(indexPath.section)")
        print("🔍 DEBUG: videos.count in cellForItemAt: \(videos.count)")
        
        guard indexPath.item < videos.count else {
            print("🔍 DEBUG: ❌ ERROR: IndexPath.item (\(indexPath.item)) >= videos.count (\(videos.count))")
            return UICollectionViewCell()
        }
        
        print("🔍 DEBUG: About to dequeue cell with identifier 'VideoCell'")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as! LegendaryShowCell
        print("🔍 DEBUG: ✅ Cell dequeued successfully: \(type(of: cell))")
        
        let video = videos[indexPath.item]
        print("🔍 DEBUG: Video at index \(indexPath.item):")
        print("🔍 DEBUG:   - ID: \(video.id)")
        print("🔍 DEBUG:   - Title: \(video.videoTitle ?? "NIL")")
        print("🔍 DEBUG:   - URL: \(video.youtubeURL ?? "NIL")")
        
        print("🔍 DEBUG: About to configure cell...")
        
        // Create a mock LegendaryShow object to configure the cell
        let mockShow = LegendaryShow(
            id: video.id,
            fields: LegendaryShowFields(
                title: video.videoTitle, // Use actual video title from Concert Videos table
                artist: "", // Empty artist field since individual videos don't need artist display
                year: "", // No year for individual videos
                url: video.youtubeURL
            )
        )
        
        print("🔍 DEBUG: Calling cell.configure with mockShow...")
        cell.configure(with: mockShow)
        print("🔍 DEBUG: ✅ Cell.configure completed")
        
        // Hide the artist label for individual video cells since we don't need it
        print("🔍 DEBUG: Calling cell.hideArtistLabel...")
        cell.hideArtistLabel()
        print("🔍 DEBUG: ✅ Cell.hideArtistLabel completed")
        
        print("🔍 DEBUG: ✅ Cell fully configured for row \(indexPath.item)")
        print("🔍 DEBUG: Returning cell: \(type(of: cell))")
        return cell
    }
    // Helper to extract YouTube Video ID (copied from LegendaryShowCell)
    private func extractVideoIdFromURL(_ url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else { return nil }
        return queryItems.first(where: { $0.name == "v" })?.value
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let video = videos[indexPath.item]
        guard let youtubeURLString = video.youtubeURL, let videoId = extractVideoIdFromURL(youtubeURLString) else {
            print("Error: Invalid YouTube URL or Video ID for selected video.")
            // Optionally show an alert to the user
            let alert = UIAlertController(title: "Playback Error", message: "Could not play this video.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        // Video selected - require subscription before playing
        requireSubscription(on: self) { [weak self] isSubscribed in
            guard let self = self else { return }
            if isSubscribed {
                // Start playing from the selected video index to enable auto-play for subsequent videos
                self.playYouTubeVideo(identifier: videoId, currentIndex: indexPath.item)
            } else {
                // Paywall will be shown by requireSubscription
            }
        }
    }
    
    // MARK: - Collection View Focus Handling
    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // Focus handling is already implemented in LegendaryShowCell's didUpdateFocus method
        // No additional handling needed here as the cell handles its own focus effects
    }
    
    // MARK: - YouTube Playback Logic (adapted from other view controllers)
    private func playYouTubeVideo(identifier: String, currentIndex: Int = 0) {
        let playerViewController = AVPlayerViewController()
        playerViewController.delegate = self
        
        let videoLoadingIndicator = UIActivityIndicatorView(style: .large)
        videoLoadingIndicator.color = .white
        videoLoadingIndicator.center = view.center
        view.addSubview(videoLoadingIndicator)
        videoLoadingIndicator.startAnimating()

        let videoTitle = currentIndex < videos.count ? videos[currentIndex].videoTitle ?? "Unknown" : "Unknown"
        print("🌟 Playing video \(currentIndex + 1)/\(videos.count): \(videoTitle) using YouTubePlayerService")

        // Use YouTubePlayerService
        YouTubePlayerService.shared.getPlayableStreamURL(for: identifier) { [weak self, playerViewController, weak videoLoadingIndicator] result in
            DispatchQueue.main.async {
                videoLoadingIndicator?.stopAnimating()
                videoLoadingIndicator?.removeFromSuperview()
            }

            guard let strongSelf = self else { return }

            switch result {
            case .success(let streamURL):
                print("🌟 YouTubePlayerService returned URL: \(streamURL) for video ID: \(identifier)")
                DispatchQueue.main.async {
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController.player = avPlayer
                    strongSelf.present(playerViewController, animated: true) {
                        avPlayer.play()
                        strongSelf.setupAutoPlayForNextVideo(player: avPlayer, currentIndex: currentIndex, playerViewController: playerViewController)
                    }
                }
            case .failure(let error):
                print("🚫 YouTubePlayerService failed for video ID \(identifier). Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if currentIndex < strongSelf.videos.count - 1 {
                        print("🌟 Current video failed, trying next video...")
                        strongSelf.playNextVideo(fromIndex: currentIndex)
                    } else {
                        let alert = UIAlertController(title: "Playback Error", message: "Failed to load video. \(error.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        strongSelf.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Auto-Play Functionality
    
    private func setupAutoPlayForNextVideo(player: AVPlayer, currentIndex: Int, playerViewController: AVPlayerViewController) {
        guard let playerItem = player.currentItem else { return }
        
        // Remove any existing observers to prevent duplicates
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        // Add observer for when the video ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                
                print("🌟 Video \(currentIndex + 1) finished playing")
                
                // Check if there's a next video to play
                let nextIndex = currentIndex + 1
                if nextIndex < strongSelf.videos.count {
                    print("🌟 Auto-playing next video: \(nextIndex + 1)/\(strongSelf.videos.count)")
                    
                    // Dismiss current player and play next video
                    playerViewController.dismiss(animated: true) {
                        strongSelf.playNextVideo(fromIndex: currentIndex)
                    }
                } else {
                    print("🌟 Reached end of concert videos. No more videos to play.")
                    // Just dismiss the player - we've reached the end
                    playerViewController.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    private func playNextVideo(fromIndex currentIndex: Int) {
        let nextIndex = currentIndex + 1
        guard nextIndex < videos.count else {
            print("🌟 No more videos to play")
            return
        }
        
        let nextVideo = videos[nextIndex]
        guard let nextVideoURLString = nextVideo.youtubeURL,
              let nextVideoId = extractVideoIdFromURL(nextVideoURLString) else {
            print("🌟 Invalid URL for next video, skipping...")
            // Try to play the video after this one
            playNextVideo(fromIndex: nextIndex)
            return
        }
        
        // Play the next video
        playYouTubeVideo(identifier: nextVideoId, currentIndex: nextIndex)
    }

     // Make sure PlaylistImageCell is adapted for focus if needed for tvOS
     // (e.g., by overriding didUpdateFocus or using UICollectionViewDelegateFocus callbacks)
}

// Ensure apiKey is accessible here, either passed in or defined globally/in constants
// For example:
// let apiKey = "YOUR_AIRTABLE_API_KEY" 
// It's best practice to not hardcode API keys directly in source files.
// Consider using a Constants file or build configurations.

// Note: The PlaylistImageCell is reused. If its layout (e.g., artistNameLabel)
// isn't suitable for ConcertVideo, you might need a new dedicated cell
// or adjust PlaylistImageCell to be more flexible.
// For now, artistNameLabel is hidden in cellForItemAt.

// Commenting out the duplicate struct instead of deleting to be safe for the LLM applying the edit.
// struct ConcertVideo {
//     let videoTItle: String
//     let youtubeUrl: String
//     // Add other fields as needed (e.g., thumbnail)
// } 