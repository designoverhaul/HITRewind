
import Foundation
import UIKit
import RevenueCat

class PurchasesViewController: UIViewController, PurchasesDelegate {

    private var purchaseButton: UIButton!
    private var noThanksButton: UIButton!
    private var offeringLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        Purchases.shared.delegate = self
        setupUI()
        fetchOfferings()
        fetchCustomerInfo()
    }

    private func setupUI() {
        // Stack View to hold the three lines of text
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .leading  // Align text to the left
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // First Line
        let firstLineLabel = UILabel()
        firstLineLabel.text = "🔓 Unlock all years"
        firstLineLabel.textColor = UIColor(hex: "#A789FD")
        firstLineLabel.font = UIFont.boldSystemFont(ofSize: 25)
        stackView.addArrangedSubview(firstLineLabel)

        // Second Line
        let secondLineLabel = UILabel()
        secondLineLabel.text = "🚫 No subscription"
        secondLineLabel.textColor = UIColor(hex: "#A789FD")
        secondLineLabel.font = UIFont.boldSystemFont(ofSize: 25)
        stackView.addArrangedSubview(secondLineLabel)

        // Third Line
        let thirdLineLabel = UILabel()
        thirdLineLabel.text = "🚫 No ads"
        thirdLineLabel.textColor = UIColor(hex: "#A789FD")
        thirdLineLabel.font = UIFont.boldSystemFont(ofSize: 25)
        stackView.addArrangedSubview(thirdLineLabel)

        // Add the stack view to the view
        view.addSubview(stackView)

        // Icon ImageView
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(named: "mtv_logo")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconImageView)

        // Offering Label
        offeringLabel = UILabel()
        offeringLabel.textColor = UIColor(hex: "#DCD2FF")
        offeringLabel.font = UIFont.boldSystemFont(ofSize: 26)
        offeringLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(offeringLabel)

        // Purchase Button
        purchaseButton = UIButton(type: .custom)
        purchaseButton.setTitle("Purchase", for: .normal)
        purchaseButton.setTitleColor(.white, for: .normal)
        purchaseButton.backgroundColor = .clear
        purchaseButton.layer.cornerRadius = 15
        purchaseButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        purchaseButton.addTarget(self, action: #selector(purchaseButtonTapped), for: .primaryActionTriggered)
        purchaseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(purchaseButton)

        // "No Thanks" Button Styled as Text
         noThanksButton = UIButton(type: .custom)
        noThanksButton.setTitle("No Thanks", for: .normal)
        noThanksButton.setTitleColor(.white, for: .normal)
        noThanksButton.backgroundColor = .black  // Set initial background to white
        noThanksButton.layer.cornerRadius = 15
        noThanksButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        noThanksButton.addTarget(self, action: #selector(noThanksButtonTapped), for: .primaryActionTriggered)
        noThanksButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(noThanksButton)

        // Constraints
        NSLayoutConstraint.activate([
            // Icon ImageView Constraints - Center horizontally, above the stack view
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.bottomAnchor.constraint(equalTo: stackView.topAnchor, constant: -5),  // Adjusted spacing
            iconImageView.widthAnchor.constraint(equalToConstant: 600),  // Fixed width
            iconImageView.heightAnchor.constraint(equalTo: iconImageView.widthAnchor, multiplier: 0.5),  // Adjust the multiplier to control the aspect ratio

            // Stack View Constraints - Center vertically and horizontally, align text to left
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),

            // Offering Label Constraints
            offeringLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            offeringLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 40),

            // Purchase Button Constraints
            purchaseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            purchaseButton.topAnchor.constraint(equalTo: offeringLabel.bottomAnchor, constant: 20),
            purchaseButton.widthAnchor.constraint(equalToConstant: 400),
            purchaseButton.heightAnchor.constraint(equalToConstant: 60),

            // "No Thanks" Button Constraints
            noThanksButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noThanksButton.topAnchor.constraint(equalTo: purchaseButton.bottomAnchor, constant: 20),
            noThanksButton.widthAnchor.constraint(equalToConstant: 400),
            noThanksButton.heightAnchor.constraint(equalToConstant: 60),
        ])
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        // Focus gained
        if let nextFocusedButton = context.nextFocusedView as? UIButton {
            coordinator.addCoordinatedAnimations({
                nextFocusedButton.backgroundColor = .yellow
                nextFocusedButton.setTitleColor(.black, for: .normal)

            }, completion: nil)
        }

        // Focus lost
        if let previouslyFocusedButton = context.previouslyFocusedView as? UIButton {
            coordinator.addCoordinatedAnimations({
                if previouslyFocusedButton == self.purchaseButton {
                    // Change the purchase button appearance back when focus is lost
                    previouslyFocusedButton.backgroundColor = .clear
                    previouslyFocusedButton.setTitleColor(.white, for: .normal)
                } else if previouslyFocusedButton == self.noThanksButton {
                    // Change the no thanks button appearance back when focus is lost
                    
                    previouslyFocusedButton.backgroundColor = .clear
                    previouslyFocusedButton.setTitleColor(.white, for: .normal)
                }
            }, completion: nil)
        }
    }

    @objc private func noThanksButtonTapped() {
        // Dismiss the current PurchasesViewController and go back to PlayListViewController
        self.dismiss(animated: true, completion: nil)
    }

//    @objc private func noThanksButtonTapped() {
//        self.navigationController?.popViewController(animated: true)
//        // Navigate to PlayListViewController
////        let playListViewController = PlayListViewController()
////        self.navigationController?.pushViewController(playListViewController, animated: true)
////        
////        playListViewController.modalPresentationStyle = .fullScreen
////        present(playListViewController, animated: true, completion: nil)
//    }
    private func fetchOfferings() {
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            if let error = error {
                self?.showAlert(title: "Error", message: error.localizedDescription)
            } else if let offerings = offerings, let currentOffering = offerings.current {
                DispatchQueue.main.async {
                    self?.displayOffering(offering: currentOffering)
                }
            } else {
                self?.showAlert(title: "No Offerings", message: "No offerings are currently available.")
            }
        }
    }

    private func displayOffering(offering: Offering) {
        if let package = offering.availablePackages.first {
            let currencyCode = package.storeProduct.currencyCode ?? "$"
            let formattedPrice = (currencyCode == "USD") ? "$\(package.storeProduct.price)" : "\(currencyCode) \(package.storeProduct.price)"
            let offeringText = "Hit Rewind Unlocked - \(formattedPrice)"

           
            offeringLabel.text = offeringText
        }
    }

    @objc private func purchaseButtonTapped() {
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            if let error = error {
                self?.showAlert(title: "Error", message: error.localizedDescription)
            } else if let offerings = offerings, let currentOffering = offerings.current, let package = currentOffering.availablePackages.first {
                Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
                    if let error = error {
                        self?.showAlert(title: "Purchase Failed", message: error.localizedDescription)
                    } else if userCancelled {
                        self?.showAlert(title: "Purchase Cancelled", message: "You cancelled the purchase.")
                    } else if let customerInfo = customerInfo {
                        print("Purchase successful: \(customerInfo)")

                        // Notify PlaylistViewController that the subscription has changed
                        NotificationCenter.default.post(name: Notification.Name("SubscriptionStatusChanged"), object: nil)

                        self?.showAlert(title: "Purchase Successful", message: "Thank you for your purchase!")
                        // Dismiss the view separately after showing the alert
                        self?.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }

    private func fetchCustomerInfo() {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            if let error = error {
                self.showAlert(title: "Error", message: error.localizedDescription)
            } else if let customerInfo = customerInfo {
                print("Customer info fetched: \(customerInfo)")
            }
        }
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        print("Customer info updated: \(customerInfo)")
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

