import Foundation
import UIKit
import RevenueCat

class PurchasesViewController: UIViewController, PurchasesDelegate {

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
        Purchases.shared.delegate = self
        setupUI()
        fetchOfferings()
        fetchCustomerInfo()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Invalidate customer info cache to help ensure fresh data
        Purchases.shared.invalidateCustomerInfoCache()
        // Fetch offerings every time the view appears to ensure freshness
        fetchOfferings()
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

        // Weekly Button (selected state)
        weeklyButton = createPricingButton(price: "$4.99", period: "a week", showSavings: false, isSelected: true)
        weeklyButton.addTarget(self, action: #selector(weeklyButtonTapped), for: .primaryActionTriggered)
        view.addSubview(weeklyButton)

        // Monthly Button (unselected state)
        monthlyButton = createPricingButton(price: "$8.99", period: "a month", showSavings: true, savingsPercent: "58%", isSelected: false)
        monthlyButton.addTarget(self, action: #selector(monthlyButtonTapped), for: .primaryActionTriggered)
        view.addSubview(monthlyButton)

        // Yearly Button (unselected state)
        yearlyButton = createPricingButton(price: "$49.99", period: "a year", showSavings: true, savingsPercent: "81%", isSelected: false)
        yearlyButton.addTarget(self, action: #selector(yearlyButtonTapped), for: .primaryActionTriggered)
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
    
    private func createPricingButton(price: String, period: String, showSavings: Bool, savingsPercent: String = "", isSelected: Bool = true) -> UIButton {
        let button = UIButton(type: .custom)
        
        if isSelected {
            // Selected state: Yellow background
            button.backgroundColor = UIColor(hex: "#FFE135")
            button.layer.borderWidth = 0
        } else {
            // Unselected state: Transparent background with yellow border
            button.backgroundColor = UIColor.clear
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor(hex: "#FFE135").cgColor
        }
        
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Create container view for complex layout
        let containerView = UIView()
        containerView.isUserInteractionEnabled = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(containerView)
        
        // Determine text color based on selection state
        let textColor = isSelected ? UIColor.black : UIColor(hex: "#FFE135")
        
        // Create horizontal stack for price and period
        let priceStackView = UIStackView()
        priceStackView.axis = .horizontal
        priceStackView.spacing = 4
        priceStackView.alignment = .lastBaseline
        priceStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(priceStackView)
        
        // Price label (bold, larger)
        let priceLabel = UILabel()
        priceLabel.text = price
        priceLabel.textColor = textColor
        priceLabel.font = UIFont.boldSystemFont(ofSize: 24)
        priceStackView.addArrangedSubview(priceLabel)
        
        // Period label (lighter, smaller)
        let periodLabel = UILabel()
        periodLabel.text = period
        periodLabel.textColor = textColor
        periodLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        priceStackView.addArrangedSubview(periodLabel)
        
        // Free Trial label (right side)
        let freeTrialLabel = UILabel()
        freeTrialLabel.text = "Free Trial"
        freeTrialLabel.textColor = textColor
        freeTrialLabel.font = UIFont.boldSystemFont(ofSize: 24)
        freeTrialLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(freeTrialLabel)
        
        // Savings pill (if applicable)
        if showSavings && !savingsPercent.isEmpty {
            let savingsPill = UIView()
            savingsPill.backgroundColor = UIColor(hex: "#8B5CF6") // Purple background
            savingsPill.layer.cornerRadius = 12
            savingsPill.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(savingsPill)
            
            let savingsLabel = UILabel()
            savingsLabel.text = "Save \(savingsPercent)"
            savingsLabel.textColor = .white
            savingsLabel.font = UIFont.boldSystemFont(ofSize: 14)
            savingsLabel.translatesAutoresizingMaskIntoConstraints = false
            savingsPill.addSubview(savingsLabel)
            
            NSLayoutConstraint.activate([
                savingsPill.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
                savingsPill.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -10),
                savingsPill.heightAnchor.constraint(equalToConstant: 24),
                savingsPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
                
                savingsLabel.centerXAnchor.constraint(equalTo: savingsPill.centerXAnchor),
                savingsLabel.centerYAnchor.constraint(equalTo: savingsPill.centerYAnchor),
                savingsLabel.leadingAnchor.constraint(equalTo: savingsPill.leadingAnchor, constant: 12),
                savingsLabel.trailingAnchor.constraint(equalTo: savingsPill.trailingAnchor, constant: -12)
            ])
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: button.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            
            priceStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            priceStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            freeTrialLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            freeTrialLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        return button
    }
    
    private func updatePricingButton(_ button: UIButton, price: String, period: String, showSavings: Bool, savingsPercent: String = "", isSelected: Bool = true) {
        // Remove existing subviews
        button.subviews.forEach { $0.removeFromSuperview() }
        
        // Update button styling based on selection state
        if isSelected {
            button.backgroundColor = UIColor(hex: "#FFE135")
            button.layer.borderWidth = 0
        } else {
            button.backgroundColor = UIColor.clear
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor(hex: "#FFE135").cgColor
        }
        
        // Recreate the button content
        let containerView = UIView()
        containerView.isUserInteractionEnabled = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(containerView)
        
        // Determine text color based on selection state
        let textColor = isSelected ? UIColor.black : UIColor(hex: "#FFE135")
        
        // Create horizontal stack for price and period
        let priceStackView = UIStackView()
        priceStackView.axis = .horizontal
        priceStackView.spacing = 4
        priceStackView.alignment = .lastBaseline
        priceStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(priceStackView)
        
        // Price label (bold, larger)
        let priceLabel = UILabel()
        priceLabel.text = price
        priceLabel.textColor = textColor
        priceLabel.font = UIFont.boldSystemFont(ofSize: 24)
        priceStackView.addArrangedSubview(priceLabel)
        
        // Period label (lighter, smaller)
        let periodLabel = UILabel()
        periodLabel.text = period
        periodLabel.textColor = textColor
        periodLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        priceStackView.addArrangedSubview(periodLabel)
        
        // Free Trial label (right side)
        let freeTrialLabel = UILabel()
        freeTrialLabel.text = "Free Trial"
        freeTrialLabel.textColor = textColor
        freeTrialLabel.font = UIFont.boldSystemFont(ofSize: 24)
        freeTrialLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(freeTrialLabel)
        
        // Savings pill (if applicable)
        if showSavings && !savingsPercent.isEmpty {
            let savingsPill = UIView()
            savingsPill.backgroundColor = UIColor(hex: "#8B5CF6") // Purple background
            savingsPill.layer.cornerRadius = 12
            savingsPill.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(savingsPill)
            
            let savingsLabel = UILabel()
            savingsLabel.text = "Save \(savingsPercent)"
            savingsLabel.textColor = .white
            savingsLabel.font = UIFont.boldSystemFont(ofSize: 14)
            savingsLabel.translatesAutoresizingMaskIntoConstraints = false
            savingsPill.addSubview(savingsLabel)
            
            NSLayoutConstraint.activate([
                savingsPill.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
                savingsPill.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -10),
                savingsPill.heightAnchor.constraint(equalToConstant: 24),
                savingsPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
                
                savingsLabel.centerXAnchor.constraint(equalTo: savingsPill.centerXAnchor),
                savingsLabel.centerYAnchor.constraint(equalTo: savingsPill.centerYAnchor),
                savingsLabel.leadingAnchor.constraint(equalTo: savingsPill.leadingAnchor, constant: 12),
                savingsLabel.trailingAnchor.constraint(equalTo: savingsPill.trailingAnchor, constant: -12)
            ])
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: button.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            
            priceStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            priceStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            freeTrialLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            freeTrialLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    private func updateSubscribedButton(_ button: UIButton) {
        // Remove existing subviews
        button.subviews.forEach { $0.removeFromSuperview() }
        
        // Create simple subscribed label
        let subscribedLabel = UILabel()
        subscribedLabel.text = "✅ Subscribed"
        subscribedLabel.textColor = .black
        subscribedLabel.font = UIFont.boldSystemFont(ofSize: 28)
        subscribedLabel.textAlignment = .center
        subscribedLabel.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(subscribedLabel)
        
        NSLayoutConstraint.activate([
            subscribedLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            subscribedLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        button.isEnabled = false
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        // Focus gained
        if let nextFocusedButton = context.nextFocusedView as? UIButton {
            coordinator.addCoordinatedAnimations({
                if nextFocusedButton == self.noThanksButton {
                    nextFocusedButton.backgroundColor = .yellow
                    nextFocusedButton.setTitleColor(.black, for: .normal)
                } else {
                    // For pricing buttons, just add a subtle scale effect
                    nextFocusedButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                }
            }, completion: nil)
        }

        // Focus lost
        if let previouslyFocusedButton = context.previouslyFocusedView as? UIButton {
            coordinator.addCoordinatedAnimations({
                if previouslyFocusedButton == self.noThanksButton {
                    previouslyFocusedButton.backgroundColor = .black
                    previouslyFocusedButton.setTitleColor(.white, for: .normal)
                } else {
                    // Reset scale for pricing buttons
                    previouslyFocusedButton.transform = CGAffineTransform.identity
                }
            }, completion: nil)
        }
    }

    @objc private func monthlyButtonTapped() {
        purchaseSubscription(packageType: "monthly")
    }

    @objc private func yearlyButtonTapped() {
        purchaseSubscription(packageType: "yearly")
    }

    @objc private func noThanksButtonTapped() {
        // Dismiss the current PurchasesViewController and go back to PlayListViewController
        self.dismiss(animated: true, completion: nil)
    }

    @objc private func weeklyButtonTapped() {
        purchaseSubscription(packageType: "weekly")
    }

    private func fetchOfferings() {
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            if let error = error {
                print("DEBUG: Error fetching offerings:", error)
                self?.showAlert(title: "Error", message: error.localizedDescription)
            } else if let offerings = offerings {
                print("DEBUG: All offerings:", offerings.all)
                print("DEBUG: Current offering identifier:", offerings.current?.identifier ?? "none")
                print("DEBUG: Available packages:", offerings.current?.availablePackages.map { $0.identifier } ?? [])
                
                // Debug: Print detailed package information
                if let currentOffering = offerings.current {
                    print("DEBUG: Package details:")
                    for package in currentOffering.availablePackages {
                        print("  - Package ID: \(package.identifier)")
                        print("    Product ID: \(package.storeProduct.productIdentifier)")
                        print("    Package Type: \(package.packageType)")
                        print("    Price: \(package.storeProduct.price)")
                        print("    Currency: \(package.storeProduct.currencyCode ?? "Unknown")")
                    }
                    
                    print("DEBUG: Weekly package: \(currentOffering.weekly?.storeProduct.productIdentifier ?? "nil")")
                    print("DEBUG: Monthly package: \(currentOffering.monthly?.storeProduct.productIdentifier ?? "nil")")
                    print("DEBUG: Annual package: \(currentOffering.annual?.storeProduct.productIdentifier ?? "nil")")
                }
                
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

    private func displayOffering(offering: RevenueCat.Offering) {
        // Use RevenueCat's package types instead of product identifiers
        let weeklyPackage = offering.weekly
        let monthlyPackage = offering.monthly
        let yearlyPackage = offering.annual
        
        // Update weekly button
        if let weeklyPackage = weeklyPackage {
            let currencyCode = weeklyPackage.storeProduct.currencyCode ?? "$"
            let formattedPrice = (currencyCode == "USD") ? "$\(weeklyPackage.storeProduct.price)" : "\(currencyCode) \(weeklyPackage.storeProduct.price)"
            updatePricingButton(weeklyButton, price: formattedPrice, period: "a week", showSavings: false, isSelected: true)
        }
        
        // Update monthly button
        if let monthlyPackage = monthlyPackage {
            let currencyCode = monthlyPackage.storeProduct.currencyCode ?? "$"
            let formattedPrice = (currencyCode == "USD") ? "$\(monthlyPackage.storeProduct.price)" : "\(currencyCode) \(monthlyPackage.storeProduct.price)"
            updatePricingButton(monthlyButton, price: formattedPrice, period: "a month", showSavings: true, savingsPercent: "58%", isSelected: false)
        }
        
        // Update yearly button
        if let yearlyPackage = yearlyPackage {
            let currencyCode = yearlyPackage.storeProduct.currencyCode ?? "$"
            let formattedPrice = (currencyCode == "USD") ? "$\(yearlyPackage.storeProduct.price)" : "\(currencyCode) \(yearlyPackage.storeProduct.price)"
            // Check subscription status for yearly
            Purchases.shared.getCustomerInfo { (customerInfo, error) in
                if let customerInfo = customerInfo {
                    let isSubscribedYearly = customerInfo.entitlements.all.values.contains { $0.isActive && $0.productIdentifier == yearlyPackage.storeProduct.productIdentifier }
                    DispatchQueue.main.async {
                        if isSubscribedYearly {
                            // For subscribed state, update the button differently
                            self.updateSubscribedButton(self.yearlyButton)
                        } else {
                            self.updatePricingButton(self.yearlyButton, price: formattedPrice, period: "a year", showSavings: true, savingsPercent: "81%", isSelected: false)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.updatePricingButton(self.yearlyButton, price: formattedPrice, period: "a year", showSavings: true, savingsPercent: "81%", isSelected: false)
                    }
                }
            }
        }
    }

    private func purchaseSubscription(packageType: String) {
        Purchases.shared.getOfferings { (offerings, error) in
            guard let offerings = offerings, error == nil else {
                self.showAlert(title: "Error", message: "Could not fetch offerings: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            guard let currentOffering = offerings.current else {
                self.showAlert(title: "Error", message: "No current offering available")
                return
            }
            
            // Get the appropriate package based on type
            var packageToPurchase: RevenueCat.Package?
            switch packageType {
            case "weekly":
                packageToPurchase = currentOffering.weekly
            case "monthly":
                packageToPurchase = currentOffering.monthly
            case "yearly":
                packageToPurchase = currentOffering.annual
            default:
                self.showAlert(title: "Error", message: "Unknown package type: \(packageType)")
                return
            }
            
            guard let package = packageToPurchase else {
                self.showAlert(title: "Error", message: "Package not found for type: \(packageType)")
                return
            }
            
            // Purchase the package
            Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
                if let error = error {
                    print("DEBUG: Purchase error: \(error.localizedDescription)")
                    self.showAlert(title: "Error", message: error.localizedDescription)
                } else if let customerInfo = customerInfo, customerInfo.entitlements["lifetime"]?.isActive == true {
                    print("DEBUG: Purchase successful. Active entitlement: lifetime")
                    NotificationCenter.default.post(name: Notification.Name("SubscriptionStatusChanged"), object: nil)
                    self.dismiss(animated: true, completion: nil)
                } else if userCancelled {
                    print("DEBUG: User cancelled the purchase process.")
                } else {
                    print("DEBUG: Purchase failed for unknown reason or no active entitlements.")
                    self.showAlert(title: "Purchase Failed", message: "The purchase could not be completed or no entitlements were activated.")
                }
            }
        }
    }

    private func fetchCustomerInfo() {
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            if let error = error {
                print("DEBUG: Error fetching customer info:", error)
            } else if let customerInfo = customerInfo {
                print("DEBUG: Customer info:", customerInfo)
                // Update UI based on subscription status
                self?.updateUIBasedOnSubscription(customerInfo: customerInfo)
            }
        }
    }
    
    private func updateUIBasedOnSubscription(customerInfo: RevenueCat.CustomerInfo) {
        // Check if user has active "lifetime" entitlement
        let hasActiveEntitlement = customerInfo.entitlements["lifetime"]?.isActive == true
        if hasActiveEntitlement {
            // User is subscribed, update all buttons to show subscribed state
            updateSubscribedButton(weeklyButton)
            updateSubscribedButton(monthlyButton)
            updateSubscribedButton(yearlyButton)
        } else {
            // User not subscribed, ensure buttons are enabled and show pricing
            weeklyButton.isEnabled = true
            monthlyButton.isEnabled = true
            yearlyButton.isEnabled = true
            // Refresh offerings to show current pricing
            fetchOfferings()
        }
    }

    // PurchasesDelegate methods
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: RevenueCat.CustomerInfo) {
        print("DEBUG: Delegate received updated customerInfo: \(customerInfo)")
        DispatchQueue.main.async {
            self.updateUIBasedOnSubscription(customerInfo: customerInfo)
        }
    }

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

