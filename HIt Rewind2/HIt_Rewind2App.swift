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
    @StateObject private var reviewService = ReviewRequestService()
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @Environment(\.scenePhase) private var scenePhase

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

                // Check if we should request a review (only after onboarding)
                if hasCompletedOnboarding {
                    reviewService.checkIfShouldRequestReview()
                }
            }
            .environmentObject(reviewService)
            .overlay(
                // Modal review popup (only show after onboarding)
                Group {
                    if hasCompletedOnboarding && reviewService.shouldShowReviewRequest {
                        ReviewRequestView(
                            message: reviewService.currentQuote,
                            onDismiss: {
                                reviewService.dismissReviewRequest()
                            },
                            onNextMessage: {
                                reviewService.nextMessage()
                            }
                        )
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: reviewService.shouldShowReviewRequest)
                    }
                }
            )
        }
    }
}
