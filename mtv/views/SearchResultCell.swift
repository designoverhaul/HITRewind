import UIKit

class SearchResultCell: UICollectionViewCell {
    
    // MARK: - UI Elements
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = UIColor.darkGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        // 30% smaller than 38: use 27
        if let customFont = UIFont(name: "Anton-Regular", size: 27) {
            label.font = customFont
        } else {
            print("⚠️ Anton-Regular font not found, using system bold.")
            label.font = UIFont.systemFont(ofSize: 27, weight: .bold)
        }
        label.textAlignment = .left
        label.numberOfLines = 2
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
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        view.layer.cornerRadius = 15
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.clear.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let thumbnailContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Properties
    var searchResult: SearchResult? {
        didSet {
            configure()
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    // MARK: - Setup
    private func setupCell() {
        contentView.clipsToBounds = false
        layer.masksToBounds = false
        // Thumbnail container for glow
        contentView.addSubview(thumbnailContainer)
        thumbnailContainer.addSubview(thumbnailImageView)
        // Meta info below image
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
            thumbnailImageView.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor),
            // Title label below thumbnail
            titleLabel.topAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            // Artist label below title
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            artistLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            artistLabel.trailingAnchor.constraint(lessThanOrEqualTo: yearLabel.leadingAnchor, constant: -8),
            artistLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
            // Year label inline with artist label, right-aligned
            yearLabel.centerYAnchor.constraint(equalTo: artistLabel.centerYAnchor),
            yearLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            yearLabel.leadingAnchor.constraint(greaterThanOrEqualTo: artistLabel.trailingAnchor, constant: 8),
            // Bottom constraint for cell
            artistLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
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
    
    private func configure() {
        guard let result = searchResult else { return }
        
        titleLabel.text = result.title
        artistLabel.text = result.artistName
        yearLabel.text = result.year
        
        // Load thumbnail image
        loadImage(from: result.videoImage)
    }
    
    private func loadImage(from urlString: String) {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            thumbnailImageView.image = UIImage(systemName: "photo")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.thumbnailImageView.image = image
            }
        }.resume()
    }
    
    // MARK: - Focus Management
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
    
    override var canBecomeFocused: Bool {
        return true
    }
    
    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        titleLabel.text = nil
        artistLabel.text = nil
        yearLabel.text = nil
    }
}

 