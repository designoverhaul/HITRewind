import UIKit
import RevenueCat

func requireSubscription(on viewController: UIViewController, completion: @escaping (Bool) -> Void) {
    print("[DEBUG][PaywallGate] requireSubscription called from: \(type(of: viewController))")
    Purchases.shared.getCustomerInfo { customerInfo, error in
        let isSubscribed = customerInfo?.entitlements.all.contains { $0.value.isActive } ?? false
        DispatchQueue.main.async {
            print("[DEBUG][PaywallGate] isSubscribed: \(isSubscribed)")
            if isSubscribed {
                completion(true)
            } else {
                print("[DEBUG][PaywallGate] Presenting real paywall (PurchasesViewController)")
                let purchasesViewController = PurchasesViewController()
                purchasesViewController.modalPresentationStyle = .fullScreen
                viewController.present(purchasesViewController, animated: true)
                completion(false)
            }
        }
    }
    // print("[DEBUG][PaywallGate] Bypassing subscription check for debugging - returning true")
    // DispatchQueue.main.async {
    //     completion(true) // Always return true to bypass paywall for debugging
    // }
} 