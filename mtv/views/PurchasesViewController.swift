import Foundation
import UIKit
import RevenueCat

class PurchasesViewController: UIViewController, PurchasesDelegate {

    private var monthlyButton: UIButton!
    private var yearlyButton: UIButton!
    private var noThanksButton: UIButton!

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
        firstLineLabel.font = UIFont.boldSystemFont(ofSize: 31)
        stackView.addArrangedSubview(firstLineLabel)

        // Second Line
        let secondLineLabel = UILabel()
        secondLineLabel.text = "🔓 Unlock all artists"
        secondLineLabel.textColor = UIColor(hex: "#A789FD")
        secondLineLabel.font = UIFont.boldSystemFont(ofSize: 31)
        stackView.addArrangedSubview(secondLineLabel)

        // Third Line
        let thirdLineLabel = UILabel()
        thirdLineLabel.text = "🚫 No ads"
        thirdLineLabel.textColor = UIColor(hex: "#A789FD")
        thirdLineLabel.font = UIFont.boldSystemFont(ofSize: 31)
        stackView.addArrangedSubview(thirdLineLabel)

        // Fourth Line
        let fourthLineLabel = UILabel()
        fourthLineLabel.text = " ✅ Travel back in time"
        fourthLineLabel.textColor = UIColor(hex: "#A789FD")
        fourthLineLabel.font = UIFont.boldSystemFont(ofSize: 31)
        stackView.addArrangedSubview(fourthLineLabel)


        // Add the stack view to the view
        view.addSubview(stackView)

        // Icon ImageView
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(named: "logoVector")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconImageView)

        // Monthly Button
        monthlyButton = UIButton(type: .custom)
        monthlyButton.setTitle("Monthly - $2.99/month", for: .normal)
        monthlyButton.setTitleColor(.white, for: .normal)
        monthlyButton.backgroundColor = .clear
        monthlyButton.layer.cornerRadius = 12
        monthlyButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        monthlyButton.addTarget(self, action: #selector(monthlyButtonTapped), for: .primaryActionTriggered)
        monthlyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(monthlyButton)

        // Yearly Button
        yearlyButton = UIButton(type: .custom)
        yearlyButton.setTitle("Yearly - $24.99/year (Save 30%)", for: .normal)
        yearlyButton.setTitleColor(.white, for: .normal)
        yearlyButton.backgroundColor = .clear
        yearlyButton.layer.cornerRadius = 12
        yearlyButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        yearlyButton.addTarget(self, action: #selector(yearlyButtonTapped), for: .primaryActionTriggered)
        yearlyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(yearlyButton)

        // "No Thanks" Button
        noThanksButton = UIButton(type: .custom)
        noThanksButton.setTitle("No thanks", for: .normal)
        noThanksButton.setTitleColor(.white, for: .normal)
        noThanksButton.backgroundColor = .black
        noThanksButton.layer.cornerRadius = 12
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

            // Monthly Button Constraints
            monthlyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            monthlyButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 40),
            monthlyButton.widthAnchor.constraint(equalToConstant: 400),
            monthlyButton.heightAnchor.constraint(equalToConstant: 60),

            // Yearly Button Constraints
            yearlyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            yearlyButton.topAnchor.constraint(equalTo: monthlyButton.bottomAnchor, constant: 20),
            yearlyButton.widthAnchor.constraint(equalToConstant: 400),
            yearlyButton.heightAnchor.constraint(equalToConstant: 60),

            // "No Thanks" Button Constraints
            noThanksButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noThanksButton.topAnchor.constraint(equalTo: yearlyButton.bottomAnchor, constant: 20),
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
                previouslyFocusedButton.backgroundColor = .clear
                previouslyFocusedButton.setTitleColor(.white, for: .normal)
            }, completion: nil)
        }
    }

    @objc private func monthlyButtonTapped() {
        purchaseSubscription(identifier: "monthlyUnlock")
    }

    @objc private func yearlyButtonTapped() {
        purchaseSubscription(identifier: "yearlyUnlock")
    }

    @objc private func noThanksButtonTapped() {
        // Dismiss the current PurchasesViewController and go back to PlayListViewController
        self.dismiss(animated: true, completion: nil)
    }

    private func fetchOfferings() {
        print("DEBUG: Starting to fetch offerings")
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            if let error = error {
                print("DEBUG: Error fetching offerings:", error)
                self?.showAlert(title: "Error", message: error.localizedDescription)
            } else if let offerings = offerings {
                print("DEBUG: All offerings:", offerings.all)
                print("DEBUG: Current offering identifier:", offerings.current?.identifier ?? "none")
                print("DEBUG: Available packages:", offerings.current?.availablePackages.map { $0.identifier } ?? [])
                if let currentOffering = offerings.current {
                    DispatchQueue.main.async {
                        self?.displayOffering(offering: currentOffering)
                    }
                } else {
                    print("DEBUG: No current offering available")
                }
            } else {
                print("DEBUG: No offerings available at all")
                self?.showAlert(title: "No Offerings", message: "No offerings are currently available.")
            }
        }
    }

    private func displayOffering(offering: Offering) {
        // Find monthly and yearly packages
        let monthlyPackage = offering.availablePackages.first { $0.identifier == "monthlyUnlock" }
        let yearlyPackage = offering.availablePackages.first { $0.identifier == "yearlyUnlock" }
        
        // Update monthly button
        if let monthlyPackage = monthlyPackage {
            let currencyCode = monthlyPackage.storeProduct.currencyCode ?? "$"
            let formattedPrice = (currencyCode == "USD") ? "$\(monthlyPackage.storeProduct.price)" : "\(currencyCode) \(monthlyPackage.storeProduct.price)"
            monthlyButton.setTitle("Monthly - \(formattedPrice)/month", for: .normal)
        }
        
        // Update yearly button
        if let yearlyPackage = yearlyPackage {
            let currencyCode = yearlyPackage.storeProduct.currencyCode ?? "$"
            let formattedPrice = (currencyCode == "USD") ? "$\(yearlyPackage.storeProduct.price)" : "\(currencyCode) \(yearlyPackage.storeProduct.price)"
            yearlyButton.setTitle("Yearly - \(formattedPrice)/year (Save 30%)", for: .normal)
        }
    }

    private func purchaseSubscription(identifier: String) {
        print("DEBUG: Starting purchase for identifier:", identifier)
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            if let error = error {
                print("DEBUG: Error getting offerings for purchase:", error)
                self?.showAlert(title: "Error", message: error.localizedDescription)
                return
            }
            
            print("DEBUG: Purchase - All offerings:", offerings?.all ?? [:])
            print("DEBUG: Purchase - Current offering:", offerings?.current?.identifier ?? "none")
            print("DEBUG: Purchase - Available packages:", offerings?.current?.availablePackages.map { $0.identifier } ?? [])
            
            guard let offerings = offerings,
                  let currentOffering = offerings.current,
                  let package = currentOffering.availablePackages.first(where: { $0.identifier == identifier }) else {
                print("DEBUG: Purchase - Failed to find package. Offerings nil:", offerings == nil)
                print("DEBUG: Purchase - Current offering nil:", offerings?.current == nil)
                print("DEBUG: Purchase - Package not found in:", offerings?.current?.availablePackages.map { $0.identifier } ?? [])
                self?.showAlert(title: "Error", message: "Selected subscription package not found")
                return
            }

            print("DEBUG: Found package:", package.identifier, "proceeding with purchase")
            Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
                if let error = error {
                    print("DEBUG: Purchase failed with error:", error)
                    self?.showAlert(title: "Purchase Failed", message: error.localizedDescription)
                } else if userCancelled {
                    print("DEBUG: Purchase cancelled by user")
                    self?.showAlert(title: "Purchase Cancelled", message: "You cancelled the purchase.")
                } else if customerInfo != nil {
                    print("DEBUG: Purchase successful")
                    NotificationCenter.default.post(name: Notification.Name("SubscriptionStatusChanged"), object: nil)
                    self?.showAlert(title: "Purchase Successful", message: "Thank you for your purchase!")
                    self?.dismiss(animated: true, completion: nil)
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


