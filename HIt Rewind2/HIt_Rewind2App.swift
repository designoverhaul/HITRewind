//
//  HIt_Rewind2App.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import SuperwallKit
import StoreKit

@main
struct HIt_Rewind2App: App {
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    init() {
        // Configure Superwall - simple, basic setup
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚀 App launching - Configuring Superwall...")

        Superwall.configure(apiKey: SuperwallConfig.apiKey)
        print("✅ Superwall configured")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    // Simple helper: Check if user has active subscription in StoreKit
    @MainActor
    static func hasActiveSubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            print("✅ Active subscription found: \(transaction.productID)")
            return true
        }
        print("❌ No active subscription")
        return false
    }

    // Standard iOS review request - shows after 3 launches initially, then periodically
    private func checkIfShouldRequestReview() {
        let userDefaults = UserDefaults.standard
        let launchCountKey = "app_launch_count"
        let lastReviewRequestKey = "last_review_request_date"
        let hasRequestedReviewKey = "has_requested_review"

        // Increment launch count
        let currentCount = userDefaults.integer(forKey: launchCountKey)
        userDefaults.set(currentCount + 1, forKey: launchCountKey)
        let launchCount = currentCount + 1

        let hasRequestedBefore = userDefaults.bool(forKey: hasRequestedReviewKey)

        // Show after 3 launches initially, then every 30 launches
        let shouldShow: Bool
        if !hasRequestedBefore {
            shouldShow = launchCount >= 3
        } else {
            if let lastRequestDate = userDefaults.object(forKey: lastReviewRequestKey) as? Date {
                let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
                shouldShow = launchCount % 30 == 0 && daysSinceLastRequest >= 30
            } else {
                shouldShow = launchCount % 30 == 0
            }
        }

        if shouldShow {
            // Delay to let UI settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                userDefaults.set(true, forKey: hasRequestedReviewKey)
                userDefaults.set(Date(), forKey: lastReviewRequestKey)
                requestReview()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    // Show onboarding
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                        .transition(.opacity)
                } else {
                    // Show main app after onboarding
                    ContentView(shouldRestartOnboarding: $hasCompletedOnboarding)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
            .preferredColorScheme(.dark)
            .onAppear {
                // Attempt to register the Ticketing font if bundled
                FontLoader.registerFonts(containing: ["ticketing"]) // matches filenames like Ticketing-Regular.ttf

                // Request review using standard iOS prompt (only after onboarding)
                if hasCompletedOnboarding {
                    checkIfShouldRequestReview()
                }
            }
        }
    }
}
