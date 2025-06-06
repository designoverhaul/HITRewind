import UIKit

// Temporary inline DiagnosticsViewController to avoid scope issues
class DiagnosticsViewController: UIViewController {
    
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var stackView: UIStackView!
    private var refreshTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startMonitoring()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopMonitoring()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 41/255, green: 38/255, blue: 49/255, alpha: 1.0)
        title = "Performance Diagnostics"
        
        // Create a simple diagnostic view
        let titleLabel = UILabel()
        titleLabel.text = "🔧 Performance Diagnostics"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let infoLabel = UILabel()
        infoLabel.text = "This diagnostic tool helps monitor image loading performance and memory usage for troubleshooting thumbnail issues."
        infoLabel.textColor = UIColor.lightGray
        infoLabel.font = UIFont.systemFont(ofSize: 18)
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        
        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        closeButton.layer.cornerRadius = 8
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.addTarget(self, action: #selector(closeView), for: .primaryActionTriggered)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            
            infoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
            
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 60),
            closeButton.widthAnchor.constraint(equalToConstant: 200),
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func closeView() {
        dismiss(animated: true)
    }
    
    private func startMonitoring() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            // Placeholder for monitoring logic
        }
    }
    
    private func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Add logo to the top left
        let logoImageView = UIImageView(image: UIImage(named: "logoVector"))
        logoImageView.contentMode = .scaleAspectFill
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 152),
            logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            logoImageView.widthAnchor.constraint(equalToConstant: 98),
            logoImageView.heightAnchor.constraint(equalToConstant: 77)
        ])
        
        // Container view for centering and width constraint
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "Terms of Service"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Disclaimer label (larger font)
        let disclaimerLabel = UILabel()
        disclaimerLabel.text = "No unauthorized duplication, reproduction, distribution, or downloading of music, videos, or any other copyrighted content available on this Apple TV application is permitted. Any such activities constitute a violation of applicable copyright laws and intellectual property rights. Users are strictly prohibited from engaging in or facilitating the unauthorized copying, sharing, or downloading of protected materials. Violation of these terms may result in termination of access to the application."
        disclaimerLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        disclaimerLabel.font = UIFont.systemFont(ofSize: 18)
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.textAlignment = .center
        disclaimerLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(disclaimerLabel)

        // EULA title label (bold)
        let eulaTitleLabel = UILabel()
        eulaTitleLabel.text = "LICENSED APPLICATION END USER LICENSE AGREEMENT"
        eulaTitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        eulaTitleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        eulaTitleLabel.textAlignment = .center
        eulaTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(eulaTitleLabel)

        // EULA link label (no longer styled as a link - plain text)
        let eulaLinkLabel = UILabel()
        eulaLinkLabel.text = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        eulaLinkLabel.textColor = UIColor(white: 0.7, alpha: 1.0) // Same color as other text
        eulaLinkLabel.font = UIFont.systemFont(ofSize: 16)
        eulaLinkLabel.textAlignment = .center
        eulaLinkLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(eulaLinkLabel)

        // Contact support label
        let contactSupportLabel = UILabel()
        contactSupportLabel.text = "Contact Support: contact@designoverhaul.com"
        contactSupportLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        contactSupportLabel.font = UIFont.systemFont(ofSize: 16)
        contactSupportLabel.textAlignment = .center
        contactSupportLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contactSupportLabel)
        
        // Diagnostics button for troubleshooting performance issues
        let diagnosticsButton = UIButton(type: .system)
        diagnosticsButton.setTitle("🔧 Performance Diagnostics", for: .normal)
        diagnosticsButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        diagnosticsButton.layer.cornerRadius = 8
        diagnosticsButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        diagnosticsButton.setTitleColor(.white, for: .normal)
        diagnosticsButton.addTarget(self, action: #selector(openDiagnostics), for: .primaryActionTriggered)
        diagnosticsButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(diagnosticsButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Logo constraints already set above
            // Container centered and 50% of screen width, below logo
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 40),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),

            // Title at top of container, centered
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            // Disclaimer below title
            disclaimerLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            disclaimerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            disclaimerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            // EULA title below disclaimer
            eulaTitleLabel.topAnchor.constraint(equalTo: disclaimerLabel.bottomAnchor, constant: 40),
            eulaTitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            eulaTitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            // EULA link below EULA title
            eulaLinkLabel.topAnchor.constraint(equalTo: eulaTitleLabel.bottomAnchor, constant: 10),
            eulaLinkLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            eulaLinkLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            // Contact support label 
            contactSupportLabel.topAnchor.constraint(equalTo: eulaLinkLabel.bottomAnchor, constant: 30),
            contactSupportLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contactSupportLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Diagnostics button at the bottom
            diagnosticsButton.topAnchor.constraint(equalTo: contactSupportLabel.bottomAnchor, constant: 30),
            diagnosticsButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            diagnosticsButton.widthAnchor.constraint(equalToConstant: 300),
            diagnosticsButton.heightAnchor.constraint(equalToConstant: 50),
            diagnosticsButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Add a gear icon to the top right, if this view controller were embedded in a UINavigationController
        // For tvOS, a more common pattern is to have settings as a main tab, as implemented.
        // If a gear icon is truly needed in the top-right of THIS specific view:
        // let gearButton = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"), style: .plain, target: self, action: #selector(settingsButtonTapped))
        // self.navigationItem.rightBarButtonItem = gearButton
        // However, this view controller is not currently in a navigation stack by default.
    }

    @objc func settingsButtonTapped() {
        // Handle settings button tap
        print("Settings button tapped")
    }
    
    @objc func openDiagnostics() {
        let diagnosticsVC = DiagnosticsViewController()
        diagnosticsVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        present(diagnosticsVC, animated: true)
    }
} 