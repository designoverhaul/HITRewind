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

        // Note: Post-onboarding paywall stays in portrait (onboarding was portrait)
        // so we don't need to switch back to landscape - that happens when main app loads
        Task { @MainActor in
            // Ensure we're in portrait mode
            await OrientationManager.shared.switchToPortraitForPaywallAsync()

            // Present Superwall's native paywall (awaits until dismissed)
            await Superwall.shared.register(placement: "MainPlacement")
            print("✅ Paywall completed (user may have subscribed)")

            // IMMEDIATELY dismiss the paywall view for instant UI response
            // Main app will handle locking to landscape
            print("🎯 Paywall dismissed, continuing to main app")
            UserDefaults.standard.set(true, forKey: "hasSeenPaywall")
            withAnimation {
                hasSeenPaywall = true
            }
        }
    }
}

#Preview {
    PostOnboardingPaywallView(hasSeenPaywall: .constant(false))
}
