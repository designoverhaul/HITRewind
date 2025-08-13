import UIKit
import RevenueCat

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

        // Restore Purchases button
        let restorePurchasesButton = UIButton(type: .custom)
        restorePurchasesButton.setTitle("Restore Purchases", for: .normal)
        restorePurchasesButton.setTitleColor(.white, for: .normal)
        restorePurchasesButton.setTitleColor(.black, for: .focused)
        restorePurchasesButton.backgroundColor = UIColor(hex: "#8B5CF6")
        restorePurchasesButton.layer.cornerRadius = 12
        restorePurchasesButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        restorePurchasesButton.addTarget(self, action: #selector(restorePurchasesButtonTapped), for: .primaryActionTriggered)
        restorePurchasesButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(restorePurchasesButton)

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

            // Restore Purchases button - now the bottom element
            restorePurchasesButton.topAnchor.constraint(equalTo: contactSupportLabel.bottomAnchor, constant: 40),
            restorePurchasesButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            restorePurchasesButton.widthAnchor.constraint(equalToConstant: 300),
            restorePurchasesButton.heightAnchor.constraint(equalToConstant: 50),
            restorePurchasesButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Add a gear icon to the top right, if this view controller were embedded in a UINavigationController
        // For tvOS, a more common pattern is to have settings as a main tab, as implemented.
        // If a gear icon is truly needed in the top-right of THIS specific view:
        // let gearButton = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"), style: .plain, target: self, action: #selector(settingsButtonTapped))
        // self.navigationItem.rightBarButtonItem = gearButton
        // However, this view controller is not currently in a navigation stack by default.
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        // Focus gained - button gets focused
        if let nextFocusedButton = context.nextFocusedView as? UIButton {
            coordinator.addCoordinatedAnimations({
                nextFocusedButton.backgroundColor = .yellow
                nextFocusedButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }, completion: nil)
        }
        
        // Focus lost - button loses focus
        if let previouslyFocusedButton = context.previouslyFocusedView as? UIButton {
            coordinator.addCoordinatedAnimations({
                previouslyFocusedButton.backgroundColor = UIColor(hex: "#8B5CF6")
                previouslyFocusedButton.transform = CGAffineTransform.identity
            }, completion: nil)
        }
    }

    @objc func settingsButtonTapped() {
        // Handle settings button tap
        print("Settings button tapped")
    }

    @objc func restorePurchasesButtonTapped() {
        print("[DEBUG] Restore Purchases button tapped")
        
        Purchases.shared.restorePurchases { [weak self] customerInfo, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[DEBUG] Restore purchases error: \(error.localizedDescription)")
                    self?.showAlert(title: "Error", message: "Failed to restore purchases: \(error.localizedDescription)")
                } else if let customerInfo = customerInfo {
                    print("[DEBUG] Restore purchases successful")
                    print("[DEBUG] Active subscriptions: \(customerInfo.activeSubscriptions)")
                    print("[DEBUG] All entitlements: \(customerInfo.entitlements.all.keys)")
                    
                    let hasActiveSubscription = !customerInfo.activeSubscriptions.isEmpty
                    let hasLifetimePurchase = customerInfo.entitlements.all.values.contains { entitlement in
                        entitlement.productIdentifier == "hitrewind_ifetime_subscription" && entitlement.isActive
                    }
                    
                    if hasActiveSubscription || hasLifetimePurchase {
                        self?.showAlert(title: "Success", message: "Your purchases have been restored!")
                    } else {
                        self?.showAlert(title: "No Purchases Found", message: "No previous purchases were found to restore.")
                    }
                } else {
                    self?.showAlert(title: "Error", message: "An unknown error occurred while restoring purchases.")
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
} 