import Foundation
import UIKit
import RevenueCat

class PurchasesViewController: UIViewController, PurchasesDelegate {

    private var purchaseButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        Purchases.shared.delegate = self
        setupUI()
        fetchOfferings()
        fetchCustomerInfo()
    }

    private func setupUI() {
        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = "Subscribe for Lifetime"
        titleLabel.textColor = .yellow
        titleLabel.font = UIFont.boldSystemFont(ofSize: 36)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle Label
        let subtitleLabel = UILabel()
        subtitleLabel.text = "In HitRewind, Just for $10"
        subtitleLabel.textColor = UIColor(hex: "#A789FD")
        subtitleLabel.font = UIFont.systemFont(ofSize: 28)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Icon ImageView
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(named: "mtv_logo") // Use any icon that suits your design
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconImageView)

        // Purchase Button
        purchaseButton = UIButton(type: .system)
        purchaseButton?.setTitle("Subscribe Now", for: .normal)
        purchaseButton?.setTitleColor(.black, for: .normal)
        purchaseButton?.backgroundColor = .yellow
        purchaseButton?.layer.cornerRadius = 15
        purchaseButton?.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        purchaseButton?.addTarget(self, action: #selector(purchaseButtonTapped), for: .touchUpInside)
        purchaseButton?.translatesAutoresizingMaskIntoConstraints = false
        if let purchaseButton = purchaseButton {
            view.addSubview(purchaseButton)
        }

        // Constraints
        NSLayoutConstraint.activate([
            // Icon ImageView Constraints
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -20),
            iconImageView.widthAnchor.constraint(equalToConstant: 200),
            iconImageView.heightAnchor.constraint(equalToConstant: 200),

            // Title Label Constraints
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),

            // Subtitle Label Constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Purchase Button Constraints
            purchaseButton?.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            purchaseButton?.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            purchaseButton?.widthAnchor.constraint(equalToConstant: 300),
            purchaseButton?.heightAnchor.constraint(equalToConstant: 60)
        ].compactMap { $0 })
    }

    private func fetchOfferings() {
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            if let error = error {
                self?.showAlert(title: "Error", message: error.localizedDescription)
            } else if let offerings = offerings, let currentOffering = offerings.current {
                print("Offerings fetched: \(currentOffering)")
                DispatchQueue.main.async {
                    self?.displayOffering(offering: currentOffering)
                }
            } else {
                self?.showAlert(title: "No Offerings", message: "No offerings are currently available.")
            }
        }
    }

    private func displayOffering(offering: Offering) {
        // Display offering details on the UI
        if let package = offering.availablePackages.first {
            purchaseButton?.setTitle("Subscribe for \(package.storeProduct.localizedTitle) - \(package.storeProduct.price)", for: .normal)
        }
    }

    @objc private func purchaseButtonTapped() {
        print("Clicked on purchases")
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
                        self?.showAlert(title: "Purchase Successful", message: "Thank you for your purchase!")
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

