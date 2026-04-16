//
//  HIt_Rewind2App.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import SuperwallKit
import StoreKit
import AVFoundation
import UIKit
import FirebaseCore
import FirebaseAnalytics

// MARK: - App Delegate for Orientation Support
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        print("🔥 Firebase configured with Analytics enabled")
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // VJ Mode locks orientation on both iPhone and iPad
        // Only way out of VJ Mode is pressing the X button
        return OrientationManager.shared.supportedOrientations()
    }
}

@main
struct HIt_Rewind2App: App {
    // App delegate adapter for orientation support
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @StateObject private var updateService = AppUpdateService.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // IMPORTANT: Set orientation for onboarding FIRST, before anything else
        // This ensures the app launches in portrait if onboarding hasn't been completed
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            print("📱 Onboarding not complete - setting portrait mode flag")
            OrientationManager.shared.isOnboardingShowing = true
        }

        // Configure audio session for media playback (helps AirPlay stability)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }

        // Configure Superwall - simple, basic setup
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚀 App launching - Configuring Superwall...")

        Superwall.configure(apiKey: SuperwallConfig.apiKey)
        print("✅ Superwall configured")

        // Set up PaywallService delegate for orientation handling
        PaywallService.shared.setupDelegate()
        print("✅ PaywallService delegate configured")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // One-time cache clear for banner fix (v1.0.1)
        let cacheFixVersion = "cache_fix_v1.0.1"
        if !UserDefaults.standard.bool(forKey: cacheFixVersion) {
            print("🔧 Clearing outdated cache for banner fix...")
            AirtableService.shared.clearCache(for: .categories)
            AirtableService.shared.clearCache(for: .concerts)
            UserDefaults.standard.set(true, forKey: cacheFixVersion)
            print("✅ Cache cleared - banners will reload with correct data")
        }
    }

    // Simple helper: Check if user has active subscription in StoreKit
    @MainActor
    static func hasActiveSubscription() async -> Bool {
        // Test unsubscriber mode - always return false to force paywall
        if PaywallService.shared.testUnsubscriberMode {
            print("🧪 Test Unsubscriber Mode enabled - forcing paywall")
            return false
        }

        // Test subscriber mode - always return true to bypass paywall
        if PaywallService.shared.testSubscriberMode {
            print("🧪 Test Subscriber Mode enabled - bypassing paywall")
            return true
        }

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

    // Track app launches for review request logic (actual review triggered in FavoritesService)
    private func incrementLaunchCount() {
        let userDefaults = UserDefaults.standard
        let launchCountKey = "app_launch_count"
        let currentCount = userDefaults.integer(forKey: launchCountKey)
        userDefaults.set(currentCount + 1, forKey: launchCountKey)
        print("📱 App launch count: \(currentCount + 1)")
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
            .alert("Update Available",
                   isPresented: $updateService.updateAvailable) {
                Button("Update") {
                    updateService.openAppStore()
                }
                Button("Later", role: .cancel) { }
            } message: {
                Text("A new version of Hit Rewind is available. Update now for the latest features.")
            }
            .onAppear {
                // Only lock to landscape if onboarding is already complete
                // Onboarding runs in portrait mode (flag already set in init)
                if hasCompletedOnboarding {
                    OrientationManager.shared.isOnboardingShowing = false
                    incrementLaunchCount()
                    AppUpdateService.shared.checkIfNeeded()
                } else {
                    // Force portrait orientation for onboarding
                    OrientationManager.shared.switchToPortraitForOnboarding()
                }

                // Attempt to register the Ticketing font if bundled
                FontLoader.registerFonts(containing: ["ticketing"]) // matches filenames like Ticketing-Regular.ttf
            }
        }
    }
}
