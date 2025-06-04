import Foundation
import UIKit
// import RevenueCat // Temporarily commented out

class PurchasesViewController: UIViewController /*, PurchasesDelegate // Temporarily commented out */ {

    private var monthlyButton: UIButton!
    private var yearlyButton: UIButton!
    private var noThanksButton: UIButton!
    private var weeklyButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Set background image
        if let bgImage = UIImage(named: "background") {
            let bgImageView = UIImageView(image: bgImage)
            bgImageView.contentMode = .scaleAspectFill
            bgImageView.translatesAutoresizingMaskIntoConstraints = false
            view.insertSubview(bgImageView, at: 0)
            NSLayoutConstraint.activate([
                bgImageView.topAnchor.constraint(equalTo: view.topAnchor),
                bgImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                bgImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bgImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        } else {
            view.backgroundColor = .black
        }
        // Purchases.shared.delegate = self // Temporarily commented out
        print("PurchasesViewController: RevenueCat delegate assignment bypassed.")
        setupUI()
        // fetchOfferings() // Temporarily commented out
        // fetchCustomerInfo() // Temporarily commented out
        print("PurchasesViewController: RevenueCat fetchOfferings and fetchCustomerInfo bypassed.")
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
        firstLineLabel.text = ""
        firstLineLabel.textColor = UIColor(hex: "#A789FD")
        firstLineLabel.font = UIFont.boldSystemFont(ofSize: 31)
        stackView.addArrangedSubview(firstLineLabel)

        // Second Line
        let secondLineLabel = UILabel()
        secondLineLabel.text = "🔓 Unlock all music"
        secondLineLabel.textColor = UIColor(hex: "#A789FD")
        secondLineLabel.font = UIFont.boldSystemFont(ofSize: 31)
        stackView.addArrangedSubview(secondLineLabel)

        // New Third Line: Unlock all categories
        let unlockCategoriesLabel = UILabel()
        unlockCategoriesLabel.text = "🔓 Unlock all categories"
        unlockCategoriesLabel.textColor = UIColor(hex: "#A789FD")
        unlockCategoriesLabel.font = UIFont.boldSystemFont(ofSize: 31)
        stackView.addArrangedSubview(unlockCategoriesLabel)

        // Third Line (now fourth)
        let thirdLineLabel = UILabel()
        thirdLineLabel.text = "🚫 No ads"
        thirdLineLabel.textColor = UIColor(hex: "#A789FD")
        thirdLineLabel.font = UIFont.boldSystemFont(ofSize: 31)
        stackView.addArrangedSubview(thirdLineLabel)

        // Fourth Line (now fifth)
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

        // Weekly Button
        weeklyButton = UIButton(type: .custom)
        weeklyButton.setTitle("Weekly - $3.99/week", for: .normal)
        weeklyButton.setTitleColor(.white, for: .normal)
        weeklyButton.backgroundColor = .clear
        weeklyButton.layer.cornerRadius = 12
        weeklyButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        weeklyButton.addTarget(self, action: #selector(weeklyButtonTapped), for: .primaryActionTriggered)
        weeklyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(weeklyButton)

        // Monthly Button
        monthlyButton = UIButton(type: .custom)
        monthlyButton.setTitle("Monthly - $6.99/month", for: .normal)
        monthlyButton.setTitleColor(.white, for: .normal)
        monthlyButton.backgroundColor = .clear
        monthlyButton.layer.cornerRadius = 12
        monthlyButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        monthlyButton.addTarget(self, action: #selector(monthlyButtonTapped), for: .primaryActionTriggered)
        monthlyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(monthlyButton)

        // Yearly Button
        yearlyButton = UIButton(type: .custom)
        yearlyButton.setTitle("Yearly - $44.99/year (Save 30%)", for: .normal)
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

            // Weekly Button Constraints
            weeklyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            weeklyButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 40),
            weeklyButton.widthAnchor.constraint(equalToConstant: 400),
            weeklyButton.heightAnchor.constraint(equalToConstant: 60),

            // Monthly Button Constraints
            monthlyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            monthlyButton.topAnchor.constraint(equalTo: weeklyButton.bottomAnchor, constant: 20),
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
        // purchaseSubscription(identifier: "monthlyUnlock") // Temporarily commented out
        print("PurchasesViewController: monthlyButtonTapped - Purchase bypassed.")
    }

    @objc private func yearlyButtonTapped() {
        // purchaseSubscription(identifier: "yearlyUnlock") // Temporarily commented out
        print("PurchasesViewController: yearlyButtonTapped - Purchase bypassed.")
    }

    @objc private func noThanksButtonTapped() {
        // Dismiss the current PurchasesViewController and go back to PlayListViewController
        self.dismiss(animated: true, completion: nil)
    }

    @objc private func weeklyButtonTapped() {
        // purchaseSubscription(identifier: "weeklyunlocked") // Temporarily commented out
        print("PurchasesViewController: weeklyButtonTapped - Purchase bypassed.")
    }

    private func fetchOfferings() {
        print("DEBUG: Starting to fetch offerings - Currently Bypassed")
        // Purchases.shared.getOfferings { [weak self] (offerings, error) in
        //     if let error = error {
        //         print("DEBUG: Error fetching offerings:", error)
        //         self?.showAlert(title: "Error", message: error.localizedDescription)
        //     } else if let offerings = offerings {
        //         print("DEBUG: All offerings:", offerings.all)
        //         print("DEBUG: Current offering identifier:", offerings.current?.identifier ?? "none")
        //         print("DEBUG: Available packages:", offerings.current?.availablePackages.map { $0.identifier } ?? [])
        //         if let currentOffering = offerings.current {
        //             DispatchQueue.main.async {
        //                 self?.displayOffering(offering: currentOffering)
        //             }
        //         } else {
        //             print("DEBUG: No current offering available")
        //         }
        //     } else {
        //         print("DEBUG: No offerings available at all")
        //         self?.showAlert(title: "No Offerings", message: "No offerings are currently available.")
        //     }
        // }
    }

    // private func displayOffering(offering: Offering) { // Temporarily commented out, depends on RevenueCat.Offering
    private func displayOffering() { // Stubbed displayOffering
        print("PurchasesViewController: displayOffering called - Prices will be static for now.")
        // Static button titles as RevenueCat is disabled
        weeklyButton.setTitle("Weekly - Price N/A", for: .normal)
        monthlyButton.setTitle("Monthly - Price N/A", for: .normal)
        yearlyButton.setTitle("Yearly - Price N/A", for: .normal)

        // // Find weekly, monthly, and yearly packages by product identifier
        // let weeklyPackage = offering.availablePackages.first { $0.storeProduct.productIdentifier == "weeklyunlocked" }
        // let monthlyPackage = offering.availablePackages.first { $0.storeProduct.productIdentifier == "monthlyUnlock" }
        // let yearlyPackage = offering.availablePackages.first { $0.storeProduct.productIdentifier == "yearlyUnlock" }
        // 
        // // Update weekly button
        // if let weeklyPackage = weeklyPackage {
        //     let currencyCode = weeklyPackage.storeProduct.currencyCode ?? "$"
        //     let formattedPrice = (currencyCode == "USD") ? "$\(weeklyPackage.storeProduct.price)" : "\(currencyCode) \(weeklyPackage.storeProduct.price)"
        //     weeklyButton.setTitle("Weekly - \(formattedPrice)/week", for: .normal)
        // }
        // 
        // // Update monthly button
        // if let monthlyPackage = monthlyPackage {
        //     let currencyCode = monthlyPackage.storeProduct.currencyCode ?? "$"
        //     let formattedPrice = (currencyCode == "USD") ? "$\(monthlyPackage.storeProduct.price)" : "\(currencyCode) \(monthlyPackage.storeProduct.price)"
        //     monthlyButton.setTitle("Monthly - \(formattedPrice)/month", for: .normal)
        // }
        // 
        // // Update yearly button
        // if let yearlyPackage = yearlyPackage {
        //     let currencyCode = yearlyPackage.storeProduct.currencyCode ?? "$"
        //     let formattedPrice = (currencyCode == "USD") ? "$\(yearlyPackage.storeProduct.price)" : "\(currencyCode) \(yearlyPackage.storeProduct.price)"
        //     let isSubscribedYearly = // Logic to check if subscribed to yearly
        //     if isSubscribedYearly {
        //         yearlyButton.setTitle("Subscribed (Yearly)", for: .normal)
        //         yearlyButton.isEnabled = false // Disable if already subscribed
        //     } else {
        //         yearlyButton.setTitle("Yearly - \(formattedPrice)/year (Save 30%)", for: .normal)
        //     }
        // }
    }

    private func purchaseSubscription(identifier: String) {
        print("DEBUG: purchaseSubscription called with identifier: \(identifier) - Currently Bypassed")
        // Purchases.shared.getOfferings { (offerings, error) in
        //     guard let offerings = offerings, error == nil else {
        //         self.showAlert(title: "Error", message: "Could not fetch offerings: \(error?.localizedDescription ?? "Unknown error")")
        //         return
        //     }
        //     // Find the package with the matching identifier
        //     let packageToPurchase = offerings.all.values.flatMap { $0.availablePackages }.first { $0.storeProduct.productIdentifier == identifier }
        //     guard let package = packageToPurchase else {
        //         self.showAlert(title: "Error", message: "Package not found for identifier: \(identifier)")
        //         return
        //     }
        //     // Purchase the package
        //     Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
        //         if let error = error {
        //             print("DEBUG: Purchase error: \(error.localizedDescription)")
        //             self.showAlert(title: "Error", message: error.localizedDescription)
        //         } else if let customerInfo = customerInfo, customerInfo.entitlements.all.values.contains(where: { $0.isActive }) {
        //             print("DEBUG: Purchase successful. Entitlements: \(customerInfo.entitlements.all.values.filter { $0.isActive }.map { $0.identifier })")
        //             NotificationCenter.default.post(name: Notification.Name("SubscriptionStatusChanged"), object: nil)
        //             self.dismiss(animated: true, completion: nil)
        //         } else if userCancelled {
        //             print("DEBUG: User cancelled the purchase process.")
        //         } else {
        //             print("DEBUG: Purchase failed for unknown reason or no active entitlements.")
        //             self.showAlert(title: "Purchase Failed", message: "The purchase could not be completed or no entitlements were activated.")
        //         }
        //     }
        // }
    }

    private func fetchCustomerInfo() {
        print("DEBUG: Starting to fetch customer info - Currently Bypassed")
        // Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
        //     if let error = error {
        //         print("DEBUG: Error fetching customer info:", error)
        //     } else if let customerInfo = customerInfo {
        //         print("DEBUG: Customer info:", customerInfo)
        //         // Update UI based on subscription status
        //         self?.updateUIBasedOnSubscription(customerInfo: customerInfo)
        //     }
        // }
    }
    
    // private func updateUIBasedOnSubscription(customerInfo: CustomerInfo) { // Temporarily commented out
    private func updateUIBasedOnSubscription() { // Stubbed version
        print("PurchasesViewController: updateUIBasedOnSubscription called - UI will not reflect actual subscription status.")
        // // Check if subscribed to yearly
        // let isSubscribedYearly = customerInfo.entitlements["YearlyAccess"]?.isActive == true
        // if isSubscribedYearly {
        //     yearlyButton.setTitle("Subscribed (Yearly)", for: .normal)
        //     yearlyButton.isEnabled = false
        // } else {
        //     // Reset yearly button title if not subscribed to yearly, relying on displayOffering to set price
        //     // This might need to be re-fetched if prices are dynamic
        // }
        // // Similarly for monthly and weekly if needed
    }

    // PurchasesDelegate methods (Temporarily commented out)
    // func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    //     print("DEBUG: Delegate received updated customer info:", customerInfo)
    //     DispatchQueue.main.async {
    //         self.updateUIBasedOnSubscription(customerInfo: customerInfo)
    //     }
    // }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

// Placeholder for PurchasesDelegate if needed for compilation, but methods are bypassed.
extension PurchasesViewController { // Removed ": PurchasesDelegate"
    // Keep the delegate conformance commented or removed if not strictly needed for build
    // If other parts of the class structure expect this conformance, provide stub implementations or comment them.
    // For now, assuming the class will build without explicit conformance if methods are commented.

    // Example of how you might add stubs if the protocol conformance was mandatory for some reason
    // and you couldn't just remove it:
    // func purchases(_ purchases: Any, receivedUpdated customerInfo: Any) {
    //     print("Stub: receivedUpdated customerInfo bypassed.")
    // }
    // func purchases(_ purchases: Any, readyForPromotedProduct product: Any, purchase startPurchase: @escaping (Any) -> Void) {
    //     print("Stub: readyForPromotedProduct bypassed.")
    // }
}


