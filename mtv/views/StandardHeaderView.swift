import UIKit

class StandardHeaderView: UIView {
    
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
    
    // MARK: - Properties
    var title: String? {
        didSet {
            titleLabel.text = title
            titleLabel.isHidden = title == nil
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(logoImageView)
        addSubview(titleLabel)
        
        // Standard positioning used across all view controllers
        NSLayoutConstraint.activate([
            // Logo constraints - consistent across all screens
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 152),
            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            logoImageView.widthAnchor.constraint(equalToConstant: 98),
            logoImageView.heightAnchor.constraint(equalToConstant: 77),
            
            // Title label constraints - positioned for screens that need titles
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            // Set the height of this header view to accommodate logo + some spacing
            heightAnchor.constraint(equalToConstant: 117) // 40 (top) + 77 (logo height) = 117
        ])
        
        // Initially hide title label - will be shown when title is set
        titleLabel.isHidden = true
    }
    
    // MARK: - Public Methods
    
    /// Returns the bottom anchor of the logo for positioning content below the header
    var contentTopAnchor: NSLayoutYAxisAnchor {
        return logoImageView.bottomAnchor
    }
    
    /// Updates the title with optional custom font and size
    func setTitle(_ title: String?, font: UIFont? = nil) {
        self.title = title
        if let font = font {
            titleLabel.font = font
        }
    }
    
    /// Hides the title label (useful for screens that don't need titles)
    func hideTitle() {
        titleLabel.isHidden = true
    }
    
    /// Shows the title label
    func showTitle() {
        titleLabel.isHidden = title == nil ? true : false
    }
} 