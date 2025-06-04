import UIKit

class VideoInfoViewController: UIViewController {
    private let videoInfo: VideoInfo
    private var imageView: UIImageView!
    private var titleLabel: UILabel!
    private var descriptionLabel: UILabel!
    private var durationLabel: UILabel!
    private var openButton: UIButton!
    
    init(videoInfo: VideoInfo) {
        self.videoInfo = videoInfo
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadThumbnail()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 41/255, green: 38/255, blue: 49/255, alpha: 1.0)
        
        // Container for content
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Thumbnail image
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        // Title label
        titleLabel = UILabel()
        titleLabel.text = videoInfo.title
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Duration label
        durationLabel = UILabel()
        durationLabel.text = formatDuration(videoInfo.duration)
        durationLabel.textColor = UIColor(red: 167/255, green: 137/255, blue: 253/255, alpha: 1.0)
        durationLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(durationLabel)
        
        // Description label
        descriptionLabel = UILabel()
        descriptionLabel.text = videoInfo.description
        descriptionLabel.textColor = UIColor.lightGray
        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descriptionLabel)
        
        // Open in YouTube button
        openButton = UIButton(type: .system)
        openButton.setTitle("Open in YouTube App", for: .normal)
        openButton.backgroundColor = UIColor(red: 167/255, green: 137/255, blue: 253/255, alpha: 1.0)
        openButton.setTitleColor(.white, for: .normal)
        openButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        openButton.layer.cornerRadius = 12
        openButton.addTarget(self, action: #selector(openInYouTube), for: .primaryActionTriggered)
        openButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(openButton)
        
        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.lightGray, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .primaryActionTriggered)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(closeButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 800),
            containerView.heightAnchor.constraint(lessThanOrEqualToConstant: 600),
            
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 300),
            imageView.heightAnchor.constraint(equalToConstant: 169), // 16:9 aspect ratio
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            durationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            durationLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 30),
            durationLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            openButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
            openButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            openButton.widthAnchor.constraint(equalToConstant: 250),
            openButton.heightAnchor.constraint(equalToConstant: 50),
            
            closeButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
            closeButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 100),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Set preferred focus
        preferredFocusEnvironments = [openButton]
    }
    
    private func loadThumbnail() {
        guard let thumbnailURLString = videoInfo.thumbnailURL,
              let url = URL(string: thumbnailURLString) else {
            imageView.image = UIImage(systemName: "play.rectangle.fill")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.imageView.image = image
                }
            }
        }.resume()
    }
    
    private func formatDuration(_ duration: String) -> String {
        // Convert ISO 8601 duration (PT4M13S) to readable format (4:13)
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?"
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = duration as NSString
        let results = regex?.firstMatch(in: duration, range: NSRange(location: 0, length: nsString.length))
        
        guard let match = results else { return duration }
        
        let hours = match.range(at: 1).location != NSNotFound ? nsString.substring(with: match.range(at: 1)) : "0"
        let minutes = match.range(at: 2).location != NSNotFound ? nsString.substring(with: match.range(at: 2)) : "0"
        let seconds = match.range(at: 3).location != NSNotFound ? nsString.substring(with: match.range(at: 3)) : "0"
        
        if hours != "0" {
            return "\(hours):\(String(format: "%02d", Int(minutes) ?? 0)):\(String(format: "%02d", Int(seconds) ?? 0))"
        } else {
            return "\(minutes):\(String(format: "%02d", Int(seconds) ?? 0))"
        }
    }
    
    @objc private func openInYouTube() {
        let youtubeAppURL = URL(string: "youtube://watch?v=\(videoInfo.id)")
        let youtubeWebURL = URL(string: "https://www.youtube.com/watch?v=\(videoInfo.id)")
        
        if let appURL = youtubeAppURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = youtubeWebURL {
            UIApplication.shared.open(webURL)
        }
        
        dismiss(animated: true)
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // Apple TV focus management
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [openButton]
    }
} 