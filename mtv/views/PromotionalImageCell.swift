import UIKit

public class PromotionalImageCell: UICollectionViewCell {
    public let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill // Or .scaleAspectFit, depending on your needs
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 0 // Remove border radius from banners
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    // Add a trailing margin view
    private let marginView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private var marginWidthConstraint: NSLayoutConstraint!
    
    // Add a leading margin view
    private let leftMarginView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private var leftMarginWidthConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(leftMarginView)
        contentView.addSubview(imageView)
        contentView.addSubview(marginView)
        NSLayoutConstraint.activate([
            leftMarginView.topAnchor.constraint(equalTo: contentView.topAnchor),
            leftMarginView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leftMarginView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leftMarginView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.trailingAnchor.constraint(equalTo: marginView.leadingAnchor),
            marginView.topAnchor.constraint(equalTo: contentView.topAnchor),
            marginView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            marginView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        leftMarginWidthConstraint = leftMarginView.widthAnchor.constraint(equalToConstant: 0)
        leftMarginWidthConstraint.isActive = true
        marginWidthConstraint = marginView.widthAnchor.constraint(equalToConstant: 0)
        marginWidthConstraint.isActive = true
        // Remove any background color or corner radius from cell/contentView
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.layer.cornerRadius = 0
        self.contentView.layer.cornerRadius = 0
        // Allow overflow for scaling
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setRightMargin(_ width: CGFloat) {
        marginWidthConstraint.constant = width
    }
    
    public func setLeftMargin(_ width: CGFloat) {
        leftMarginWidthConstraint.constant = width
    }
} 