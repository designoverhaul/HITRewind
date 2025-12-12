//
//  PostOnboardingPaywallView.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/6/25.
//

import SwiftUI
import SuperwallKit

/// Simple view that presents Superwall's native paywall after onboarding
/// User can dismiss the paywall and continue to the main app
struct PostOnboardingPaywallView: View {
    @Binding var hasSeenPaywall: Bool

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .onAppear {
                print("🎯 Post-onboarding paywall trigger view appeared")
                // Present Superwall's paywall immediately
                presentPaywall()
            }
    }

    private func presentPaywall() {
        print("🎯 Presenting Superwall paywall after onboarding...")

        Task { @MainActor in
            do {
                // Present Superwall's native paywall and WAIT for dismissal
                try await Superwall.shared.register(placement: "MainPlacement")
                print("✅ Paywall completed (user may have subscribed)")
            } catch {
                print("⚠️ Paywall was dismissed: \(error.localizedDescription)")
            }

            // IMMEDIATELY dismiss the paywall view for instant UI response
            print("🎯 Paywall dismissed, continuing to main app")
            UserDefaults.standard.set(true, forKey: "hasSeenPaywall")
            withAnimation {
                hasSeenPaywall = true
            }

            // Note: Subscription status updates are handled by:
            // 1. StoreKit 2 transaction observer (for purchase detection)
            // 2. SuperwallDelegate.paywallDidDismiss (for status check)
            // 3. SuperwallDelegate.subscriptionStatusDidChange (for state updates)
        }
    }
}

#Preview {
    PostOnboardingPaywallView(hasSeenPaywall: .constant(false))
}
