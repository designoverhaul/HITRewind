//
//  AuthenticationService.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI
import UIKit
import AuthenticationServices
import CloudKit

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userIdentifier: String?
    @Published var userEmail: String?
    @Published var userFullName: String?
    @Published var isLoading = false
    
    static let shared = AuthenticationService()
    
    private override init() {
        super.init()
        checkAuthenticationState()
    }
    
    // MARK: - Authentication State Management
    
    func checkAuthenticationState() {
        guard let userIdentifier = UserDefaults.standard.string(forKey: "userIdentifier") else {
            let wasAuthenticated = isAuthenticated
            isAuthenticated = false
            if wasAuthenticated {
                NotificationCenter.default.post(name: .authenticationStateChanged, object: nil)
            }
            return
        }

        self.userIdentifier = userIdentifier
        self.userEmail = UserDefaults.standard.string(forKey: "userEmail")
        self.userFullName = UserDefaults.standard.string(forKey: "userFullName")

        // Verify the user identifier is still valid
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userIdentifier) { [weak self] credentialState, error in
            DispatchQueue.main.async {
                let wasAuthenticated = self?.isAuthenticated ?? false
                switch credentialState {
                case .authorized:
                    self?.isAuthenticated = true
                    if !wasAuthenticated {
                        NotificationCenter.default.post(name: .authenticationStateChanged, object: nil)
                    }
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Sign In
    
    func signInWithApple() {
        isLoading = true
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }
    
    // MARK: - Sign Out

        func signOut() {
        isAuthenticated = false
        userIdentifier = nil
        userEmail = nil
        userFullName = nil

        // Clear stored credentials
        UserDefaults.standard.removeObject(forKey: "userIdentifier")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userFullName")

        // Don't clear favorites on sign out - preserve local data
        // Users may want to sign back in or sign in with different account
        // FavoritesService.shared.clearAllFavorites()

        // Notify that authentication state changed
        NotificationCenter.default.post(name: .authenticationStateChanged, object: nil)
    }

    // MARK: - Delete Account

    func deleteAccount() {
        // Clear all local data
        signOut()

        // Note: For Sign in with Apple, the actual account deletion should be handled
        // through Apple's account management. This method clears local data only.
        // Users should be directed to Apple's account settings to fully delete their Apple ID.

        print("Account data cleared locally. User should delete their Apple ID through Apple's account management.")

        // Authentication state change notification is already posted in signOut()
    }
    
    // MARK: - Private Methods
    
    private func saveUserCredentials(userIdentifier: String, email: String?, fullName: String?) {
        UserDefaults.standard.set(userIdentifier, forKey: "userIdentifier")
        UserDefaults.standard.set(email, forKey: "userEmail")
        UserDefaults.standard.set(fullName, forKey: "userFullName")

        self.userIdentifier = userIdentifier
        self.userEmail = email
        self.userFullName = fullName
        self.isAuthenticated = true

        // Notify that authentication state changed
        NotificationCenter.default.post(name: .authenticationStateChanged, object: nil)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        isLoading = false
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            
            let fullNameString = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            saveUserCredentials(
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullNameString.isEmpty ? nil : fullNameString
            )
            
            print("✅ Sign in with Apple successful")
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        print("❌ Sign in with Apple failed: \(error.localizedDescription)")
        
        // Don't show error for user cancellation
        if let authError = error as? ASAuthorizationError,
           authError.code == .canceled {
            return
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}