//
//  PaywallService.swift
//  HIt Rewind2
//
//  Created by Aaron Heine
//

import Foundation
import SuperwallKit

class PaywallService: ObservableObject {
    static let shared = PaywallService()

    @Published var hasProAccess = false
    @Published var testSubscriberMode = false // For testing without Superwall

    private init() {
        // Check for existing subscription status
        checkSubscriptionStatus()

        // Load test mode from UserDefaults
        testSubscriberMode = UserDefaults.standard.bool(forKey: "testSubscriberMode")
    }

    /// Determines if a video is locked
    /// All videos are locked for free users
    func isVideoLocked(_ videoId: String) -> Bool {
        // Test mode overrides everything
        if testSubscriberMode {
            return false
        }

        // If user has pro access, nothing is locked
        if hasProAccess {
            return false
        }

        // All videos are locked for free users
        return true
    }

    func setTestSubscriberMode(_ enabled: Bool) {
        testSubscriberMode = enabled
        UserDefaults.standard.set(enabled, forKey: "testSubscriberMode")
        objectWillChange.send()
    }

    /// Present the paywall for the MainPlacement
    @MainActor
    func presentPaywall() async -> Bool {
        print("🎯 Attempting to present Superwall paywall...")

        do {
            print("🎯 Calling Superwall.shared.register(placement: MainPlacement)")
            try await Superwall.shared.register(placement: "MainPlacement")
            print("🎯 Paywall register completed successfully")

            // If we get here, paywall was dismissed/completed
            // Force refresh subscription status after paywall dismissal
            await refreshSubscriptionStatus()
            return hasProAccess
        } catch {
            print("❌ Error presenting paywall: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            if let superwallError = error as? NSError {
                print("❌ Error domain: \(superwallError.domain)")
                print("❌ Error code: \(superwallError.code)")
                print("❌ Error userInfo: \(superwallError.userInfo)")
            }
            return false
        }
    }

    /// Force refresh subscription status silently
    @MainActor
    func refreshSubscriptionStatus() async {
        print("🔄 Refreshing subscription status silently...")

        // Give Superwall a moment to update its internal state after purchase
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Check the updated status (delegate should have been called if purchase completed)
        checkSubscriptionStatus()
        print("✅ Subscription status checked: hasProAccess = \(hasProAccess)")
    }

    /// Manually restore purchases (call this from settings only)
    @MainActor
    func restorePurchases() async throws {
        print("🔄 Manually restoring purchases...")
        _ = try await Superwall.shared.restorePurchases()
        print("✅ Purchases restored successfully")
        checkSubscriptionStatus()
    }

    func checkSubscriptionStatus() {
        // Check if user has active subscription
        // This will be updated by Superwall's subscription status
        Task { @MainActor in
            switch Superwall.shared.subscriptionStatus {
            case .active(_):
                hasProAccess = true
            default:
                hasProAccess = false
            }
        }
    }

    /// Configure Superwall delegate to handle subscription changes
    func setupDelegate() {
        Superwall.shared.delegate = self
    }
}

// MARK: - SuperwallDelegate
extension PaywallService: SuperwallDelegate {
    func subscriptionStatusDidChange(to newValue: SuperwallKit.SubscriptionStatus) {
        print("🔔 Superwall subscription status changed to: \(newValue)")
        Task { @MainActor in
            switch newValue {
            case .active(let productId):
                print("✅ Subscription ACTIVE for product: \(productId)")
                hasProAccess = true
            case .inactive:
                print("⚠️ Subscription INACTIVE")
                hasProAccess = false
            case .unknown:
                print("❓ Subscription status UNKNOWN")
                hasProAccess = false
            }
            print("📊 hasProAccess is now: \(hasProAccess)")
        }
    }

    func paywallWillPresent(withInfo paywallInfo: SuperwallKit.PaywallInfo) {
        print("🎯 Paywall WILL PRESENT")
        print("🎯 Paywall name: \(paywallInfo.name)")
        print("🎯 Current subscription status: \(Superwall.shared.subscriptionStatus)")
    }

    func paywallDidDismiss(withInfo paywallInfo: SuperwallKit.PaywallInfo) {
        print("🎯 Paywall DID DISMISS")
        print("🎯 Paywall name: \(paywallInfo.name)")

        // Check subscription status after dismissal
        Task { @MainActor in
            // Small delay to let StoreKit finish processing
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            print("🔍 Checking subscription status after paywall dismissal...")
            checkSubscriptionStatus()
            print("📊 Final status - hasProAccess: \(hasProAccess), Superwall status: \(Superwall.shared.subscriptionStatus)")
        }
    }
}
