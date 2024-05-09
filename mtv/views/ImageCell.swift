import UIKit

class PlaylistImageCell: UICollectionViewCell {
    // ImageView for displaying the playlist image
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    // Label for displaying the title
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "sf_pro-bold", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .regular)
        label.textAlignment = .left
        return label
    }()
    
    // Label for displaying the year
    let artistNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hex: "#A789FD")
        label.font = UIFont(name: "sf_pro-regular", size: 21) ?? UIFont.systemFont(ofSize: 21, weight: .regular)
        label.textAlignment = .center
        return label
    }()
    
    // Label for displaying the duration
    let durationLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hex: "#A789FD")
        label.font = UIFont(name: "sf_pro-regular", size: 18) ?? UIFont.systemFont(ofSize: 18, weight: .regular)
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }
    
    private func setupUI() {
        // Add imageView to the cell
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -80)
        ])
        imageView.layer.cornerRadius = 8 // Adjust the corner radius as needed
        imageView.layer.masksToBounds = true
        
        // Add titleLabel to the left of the cell
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10)
        ])
        
        // Add artistNameLabel to the left of the cell with fixed width
        addSubview(artistNameLabel)
        artistNameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            artistNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            artistNameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            artistNameLabel.widthAnchor.constraint(equalToConstant: 260) // Fixed width constraint
        ])
        artistNameLabel.textAlignment = .left
        // Add durationLabel to the right of the cell
        addSubview(durationLabel)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            durationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            durationLabel.centerYAnchor.constraint(equalTo: artistNameLabel.centerYAnchor)
        ])
    }

}

