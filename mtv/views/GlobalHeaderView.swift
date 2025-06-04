import UIKit

/// Global header component used across ALL view controllers in the app
/// Ensures consistent navigation bar, logo placement, and title styling
class GlobalHeaderView: UIView {
    
    // MARK: - UI Elements
    private let logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "logoVector"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 32, weight: .regular)
        label.textColor = .white
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Background view that creates the navigation bar area
    private let navigationBarBackground: UIView = {
        let view = UIView()
        view.backgroundColor = .clear // Transparent but provides structure
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Properties
    var title: String? {
        didSet {
            titleLabel.text = title
            titleLabel.isHidden = title == nil || title!.isEmpty
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGlobalHeader()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlobalHeader()
    }
    
    // MARK: - Setup
    private func setupGlobalHeader() {
        backgroundColor = .clear
        
        // Add all components
        addSubview(navigationBarBackground)
        addSubview(logoImageView)
        addSubview(titleLabel)
        
        // EXACT positioning used across ALL view controllers
        NSLayoutConstraint.activate([
            // Navigation bar background
            navigationBarBackground.topAnchor.constraint(equalTo: topAnchor),
            navigationBarBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            navigationBarBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            navigationBarBackground.heightAnchor.constraint(equalToConstant: 140),
            
            // MTV Logo - EXACTLY as positioned in LegendaryShowsViewController and other screens
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 152),
            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            logoImageView.widthAnchor.constraint(equalToConstant: 98),
            logoImageView.heightAnchor.constraint(equalToConstant: 77),
            
            // Title positioning - below logo to avoid overlap
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            // Header view total height
            heightAnchor.constraint(equalToConstant: 140)
        ])
        
        // Initially hide title - shown when set
        titleLabel.isHidden = true
    }
    
    // MARK: - Public Interface
    
    /// Bottom anchor for positioning content below the header
    var contentBottomAnchor: NSLayoutYAxisAnchor {
        return bottomAnchor
    }
    
    /// Set the title text
    func setTitle(_ title: String?) {
        self.title = title
    }
    
    /// Set custom title font
    func setTitleFont(_ font: UIFont) {
        titleLabel.font = font
    }
    
    /// Hide the title label
    func hideTitle() {
        titleLabel.isHidden = true
    }
    
    /// Show the title label (if title is set)
    func showTitle() {
        titleLabel.isHidden = (title == nil || title!.isEmpty)
    }
    
    /// Update logo image if needed
    func setLogo(_ image: UIImage?) {
        logoImageView.image = image
    }
}

// MARK: - UIViewController Extension for Easy Header Setup
extension UIViewController {
    
    /// Add the global header to any view controller
    /// Returns the header view for further customization if needed
    @discardableResult
    func addGlobalHeader(title: String? = nil) -> GlobalHeaderView {
        let headerView = GlobalHeaderView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(headerView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        if let title = title {
            headerView.setTitle(title)
        }
        
        return headerView
    }
} 