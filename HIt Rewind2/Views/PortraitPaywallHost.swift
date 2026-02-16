//
//  PortraitPaywallHost.swift
//  HIt Rewind2
//
//  Forces portrait mode for paywall - NO ESCAPE
//

import UIKit
import SuperwallKit

class PortraitPaywallHost: UIViewController {

    private var completion: ((Bool) -> Void)?
    private var allowDismiss = false

    // FORCE PORTRAIT - NO EXCEPTIONS
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return allowDismiss ? .all : .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return allowDismiss
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        modalPresentationStyle = .fullScreen
    }

    private var hasDismissed = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🎯 PortraitPaywallHost viewDidAppear - presenting Superwall")

        // Store reference so Superwall delegate can dismiss us
        PortraitPaywallHost.current = self

        // Show Superwall
        Task { @MainActor in
            print("🎯 Calling Superwall.register...")
            await Superwall.shared.register(placement: "MainPlacement")
            print("🎯 Superwall.register returned")

            // FALLBACK: If delegate doesn't dismiss us within 1 second, dismiss anyway
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if !hasDismissed {
                print("🎯 FALLBACK: Delegate didn't fire, dismissing anyway")
                dismissHost()
            }
        }
    }

    static weak var current: PortraitPaywallHost?

    func dismissHost() {
        guard !hasDismissed else { return }
        hasDismissed = true
        print("🎯 PortraitPaywallHost.dismissHost() called")
        Task { @MainActor in
            let subscribed = await HIt_Rewind2App.hasActiveSubscription()
            print("🎯 PortraitPaywallHost dismissing, subscribed=\(subscribed)")
            self.finishAndDismiss(subscribed: subscribed)
        }
    }

    private func finishAndDismiss(subscribed: Bool) {
        print("🎯 finishAndDismiss called, subscribed=\(subscribed)")
        // Allow rotation now so dismiss doesn't conflict
        allowDismiss = true
        OrientationManager.shared.isPaywallShowing = false
        setNeedsUpdateOfSupportedInterfaceOrientations()

        // Small delay then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🎯 Calling dismiss(animated: true)")
            self.dismiss(animated: true) {
                print("🎯 Host dismissed, calling completion")
                self.completion?(subscribed)
            }
        }
    }

    // MARK: - Presentation

    @MainActor
    static func present(completion: @escaping (Bool) -> Void) {
        // SET THE FLAG FIRST - blocks lockToLandscape calls
        OrientationManager.shared.isPaywallShowing = true

        let host = PortraitPaywallHost()
        host.completion = completion
        host.modalPresentationStyle = .fullScreen

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            OrientationManager.shared.isPaywallShowing = false
            completion(false)
            return
        }

        // Find topmost VC
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        print("🎯 Presenting PortraitPaywallHost (portrait locked)")
        topVC.present(host, animated: true)
    }
}
