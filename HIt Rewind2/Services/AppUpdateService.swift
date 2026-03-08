//
//  AppUpdateService.swift
//  HIt Rewind2
//
//  Checks the App Store for newer versions via iTunes Lookup API.
//

import Foundation
import UIKit

@MainActor
final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()

    @Published var updateAvailable = false
    @Published var appStoreVersion: String?

    private let lastCheckKey = "AppUpdateService_lastCheckDate"
    private let throttleInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    private init() {}

    // MARK: - Public

    /// Checks for update if 24+ hours since last check.
    func checkIfNeeded() {
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastCheck) >= throttleInterval else {
            print("📦 Update check skipped — last check was \(lastCheck)")
            return
        }
        performCheck()
    }

    /// Bypasses the 24-hour throttle.
    func forceCheck() {
        performCheck()
    }

    /// Forces the update alert to show for testing.
    func simulateUpdateAvailable() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.appStoreVersion = "99.0.0"
            self.updateAvailable = true
            print("📦 Simulated update available (v99.0.0)")
        }
    }

    /// Opens the App Store page for Hit Rewind.
    func openAppStore() {
        guard let url = URL(string: "https://apps.apple.com/app/id\(AppConfig.appStoreId)") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Private

    private func performCheck() {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            print("📦 Update check failed — no bundle identifier")
            return
        }

        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleId)"
        guard let url = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)

                guard let result = response.results.first else {
                    print("📦 Update check — app not found in App Store")
                    return
                }

                let storeVersion = result.version
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

                print("📦 App Store version: \(storeVersion) | Current version: \(currentVersion)")

                UserDefaults.standard.set(Date(), forKey: lastCheckKey)

                if isVersion(storeVersion, newerThan: currentVersion) {
                    appStoreVersion = storeVersion
                    updateAvailable = true
                    print("📦 Update available! \(currentVersion) → \(storeVersion)")
                } else {
                    updateAvailable = false
                    print("📦 App is up to date")
                }
            } catch {
                print("📦 Update check failed: \(error.localizedDescription)")
            }
        }
    }

    /// Semantic version comparison. Returns true if `a` is newer than `b`.
    private func isVersion(_ a: String, newerThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(aParts.count, bParts.count) {
            let aVal = i < aParts.count ? aParts[i] : 0
            let bVal = i < bParts.count ? bParts[i] : 0
            if aVal > bVal { return true }
            if aVal < bVal { return false }
        }
        return false
    }
}

// MARK: - iTunes API Response

private struct ITunesLookupResponse: Decodable {
    let resultCount: Int
    let results: [ITunesAppResult]
}

private struct ITunesAppResult: Decodable {
    let version: String
}
