
import Foundation
import UIKit
import RevenueCat

class PurchasesViewController: UIViewController, PurchasesDelegate {

    private var purchaseButton: UIButton!
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
        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = "Subscribe for Lifetime"
        titleLabel.textColor = .yellow
        titleLabel.font = UIFont.boldSystemFont(ofSize: 36)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Icon ImageView
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(named: "mtv_logo")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconImageView)

        // Offering Label
        offeringLabel = UILabel()
        offeringLabel.textColor = UIColor(hex: "#A789FD")
        offeringLabel.font = UIFont.boldSystemFont(ofSize: 26)
        offeringLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(offeringLabel)

        // Purchase Button
        purchaseButton = UIButton(type: .system)
        purchaseButton.setTitle("Subscribe Now", for: .normal)
        purchaseButton.setTitleColor(.black, for: .normal)
        purchaseButton.backgroundColor = .yellow
        purchaseButton.layer.cornerRadius = 15
        purchaseButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        purchaseButton.addTarget(self, action: #selector(purchaseButtonTapped), for: .primaryActionTriggered)
        purchaseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(purchaseButton)

        // Constraints
        NSLayoutConstraint.activate([
            // Icon ImageView Constraints
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -20),
            iconImageView.widthAnchor.constraint(equalToConstant: 200),
            iconImageView.heightAnchor.constraint(equalToConstant: 200),

            // Title Label Constraints
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),

            // Offering Label Constraints
            offeringLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            offeringLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),

            // Purchase Button Constraints
            purchaseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            purchaseButton.topAnchor.constraint(equalTo: offeringLabel.bottomAnchor, constant: 20),
            purchaseButton.widthAnchor.constraint(equalToConstant: 400),
            purchaseButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

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
            let offeringText = "\(package.storeProduct.localizedTitle) - $ \(package.storeProduct.price)"
            offeringLabel.text = offeringText
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
