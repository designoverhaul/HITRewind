//
//  OrientationManager.swift
//  HIt Rewind2
//
//  Manages orientation locking for the app
//

import SwiftUI
import UIKit

final class OrientationManager {
    static let shared = OrientationManager()

    var isVJModeActive: Bool = false
    var isPaywallShowing: Bool = false
    var isOnboardingShowing: Bool = false

    private var sceneObserver: NSObjectProtocol?

    private init() {
        // Observe scene activation to enforce landscape on iPad
        sceneObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.enforceOrientationIfNeeded()
        }
    }

    deinit {
        if let observer = sceneObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Called when scene activates - enforces landscape on iPad
    private func enforceOrientationIfNeeded() {
        // Don't enforce during onboarding or paywall
        guard !isPaywallShowing && !isOnboardingShowing else { return }

        // Only needed for iPad - iPhone respects AppDelegate
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }

        print("📱 iPad scene activated - enforcing landscape")
        lockToLandscape()
    }

    /// Preferred landscape orientation based on device
    private var preferredLandscape: UIInterfaceOrientationMask {
        // iPad: either landscape direction
        // iPhone: landscape right only (dynamic island on left)
        return UIDevice.current.userInterfaceIdiom == .pad ? .landscape : .landscapeRight
    }

    func lockToLandscape() {
        print("🔄 lockToLandscape called, isPaywallShowing=\(isPaywallShowing)")
        if isPaywallShowing {
            print("🛡️ lockToLandscape BLOCKED")
            return
        }
        print("🔄 lockToLandscape running")

        isOnboardingShowing = false

        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }

            rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()

            let targetOrientation = preferredLandscape
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: targetOrientation)) { error in
                    if let error = error as NSError?, error.code != 0 {
                        print("⚠️ requestGeometryUpdate error: \(error)")
                    }
                }
            }
        }
    }

    func switchToPortraitForPaywall() {
        isPaywallShowing = true
    }

    func endPaywallAndRotateToLandscape() {
        print("⚠️ endPaywallAndRotateToLandscape called")
        Thread.callStackSymbols.prefix(8).forEach { print($0) }
        isPaywallShowing = false

        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }

            rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()

            let targetOrientation = preferredLandscape
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: targetOrientation)) { error in
                    if let error = error as NSError?, error.code != 0 {
                        print("⚠️ requestGeometryUpdate error: \(error)")
                    }
                }
            }
        }
    }

    func switchToPortraitForOnboarding() {
        isOnboardingShowing = true

        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }

            rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
            }
        }
    }

    // Legacy methods
    func lockToLandscapeLeft() { lockToLandscape() }
    func lockToLandscapeRight() { lockToLandscape() }
    func forceLockToLandscape() { endPaywallAndRotateToLandscape() }
    func unlockOrientation() { }
    func setPaywallPresenting(_ presenting: Bool) {
        if presenting {
            switchToPortraitForPaywall()
        } else {
            endPaywallAndRotateToLandscape()
        }
    }
    func switchToPortraitForPaywallAsync() async {
        switchToPortraitForPaywall()
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    func supportedOrientations() -> UIInterfaceOrientationMask {
        if isPaywallShowing || isOnboardingShowing {
            return .portrait
        }
        // iPhone: dynamic island on left (landscape right only)
        // iPad: either landscape direction
        return UIDevice.current.userInterfaceIdiom == .pad ? .landscape : .landscapeRight
    }
}
