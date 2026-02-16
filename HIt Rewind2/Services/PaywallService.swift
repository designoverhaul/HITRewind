//
//  PaywallService.swift
//  HIt Rewind2
//

import Foundation
import SuperwallKit
import UIKit

class PaywallService: ObservableObject {
    static let shared = PaywallService()

    @Published var hasProAccess = false
    @Published var testSubscriberMode = false
    @Published var testUnsubscriberMode = false

    private init() {
        checkSubscriptionStatus()
        testSubscriberMode = UserDefaults.standard.bool(forKey: "testSubscriberMode")
        testUnsubscriberMode = UserDefaults.standard.bool(forKey: "testUnsubscriberMode")
    }

    func isVideoLocked(_ videoId: String) -> Bool {
        if testUnsubscriberMode { return true }
        if testSubscriberMode { return false }
        if hasProAccess { return false }
        return true
    }

    func setTestSubscriberMode(_ enabled: Bool) {
        testSubscriberMode = enabled
        UserDefaults.standard.set(enabled, forKey: "testSubscriberMode")
        if enabled {
            testUnsubscriberMode = false
            UserDefaults.standard.set(false, forKey: "testUnsubscriberMode")
        }
    }

    func setTestUnsubscriberMode(_ enabled: Bool) {
        testUnsubscriberMode = enabled
        UserDefaults.standard.set(enabled, forKey: "testUnsubscriberMode")
        if enabled {
            testSubscriberMode = false
            UserDefaults.standard.set(false, forKey: "testSubscriberMode")
        }
    }

    private var paywallSuccessHandler: (() -> Void)?

    /// Present paywall in portrait mode - uses portrait-locked host controller
    @MainActor
    func presentPaywallWithOrientation(onSuccess: @escaping () -> Void) {
        self.paywallSuccessHandler = onSuccess

        // Present portrait-locked host that will show Superwall
        PortraitPaywallHost.present { subscribed in
            if subscribed {
                self.paywallSuccessHandler?()
            }
            self.paywallSuccessHandler = nil
        }
    }

    /// Legacy async method
    @MainActor
    func presentPaywall() async -> Bool {
        OrientationManager.shared.switchToPortraitForPaywall()
        try? await Task.sleep(nanoseconds: 300_000_000)

        await Superwall.shared.register(placement: "MainPlacement")

        try? await Task.sleep(nanoseconds: 300_000_000)
        OrientationManager.shared.endPaywallAndRotateToLandscape()

        await refreshSubscriptionStatus()
        return hasProAccess
    }

    @MainActor
    func refreshSubscriptionStatus() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        checkSubscriptionStatus()
    }

    @MainActor
    func restorePurchases() async {
        _ = await Superwall.shared.restorePurchases()
        checkSubscriptionStatus()
    }

    func checkSubscriptionStatus() {
        Task { @MainActor in
            switch Superwall.shared.subscriptionStatus {
            case .active(_):
                hasProAccess = true
            default:
                hasProAccess = false
            }
        }
    }

    func setupDelegate() {
        Superwall.shared.delegate = self
    }
}

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

    func paywallWillPresent(withInfo paywallInfo: SuperwallKit.PaywallInfo) {
        print("🎯 SUPERWALL DELEGATE: paywallWillPresent - paywall IS showing")
    }

    func paywallDidDismiss(withInfo paywallInfo: SuperwallKit.PaywallInfo) {
        print("🎯 SUPERWALL DELEGATE: paywallDidDismiss fired!")
        print("🎯 PortraitPaywallHost.current = \(PortraitPaywallHost.current != nil ? "exists" : "nil")")

        // Tell the portrait host to dismiss itself
        PortraitPaywallHost.current?.dismissHost()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            checkSubscriptionStatus()
        }
    }
}
