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
            // Check subscription status after paywall dismissal
            checkSubscriptionStatus()
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
        Task { @MainActor in
            switch newValue {
            case .active(_):
                hasProAccess = true
            default:
                hasProAccess = false
            }
        }
    }
}
