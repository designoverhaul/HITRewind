//
//  HIt_Rewind2App.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import SuperwallKit

@main
struct HIt_Rewind2App: App {
    @StateObject private var reviewService = ReviewRequestService()
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    init() {
        // Configure Superwall
        print("🎯 Configuring Superwall with API key: \(SuperwallConfig.apiKey.prefix(10))...")
        Superwall.configure(apiKey: SuperwallConfig.apiKey)
        print("🎯 Superwall configured successfully")
        print("🎯 Setting up Superwall delegate...")
        PaywallService.shared.setupDelegate()
        print("🎯 Superwall delegate configured")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView(shouldRestartOnboarding: $hasCompletedOnboarding)
                        .transition(.opacity)
                } else {
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
            .onChange(of: hasCompletedOnboarding) { oldValue, newValue in
                // When onboarding is restarted from settings, restart immediately
                if !newValue {
                    print("🎬 Restarting onboarding...")
                }
            }
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
