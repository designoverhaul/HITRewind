//
//  AuthenticationService.swift
//  HIt Rewind2
//
//  Firebase Authentication with Sign in with Apple
//  (Migrated from standalone Sign in with Apple)
//

import SwiftUI
import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userIdentifier: String?
    @Published var userEmail: String?
    @Published var userFullName: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    static let shared = AuthenticationService()

    // Firebase user reference
    private var currentUser: User? {
        Auth.auth().currentUser
    }

    // For Sign in with Apple nonce verification
    private var currentNonce: String?

    private override init() {
        super.init()
        setupAuthStateListener()
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                let wasAuthenticated = self?.isAuthenticated ?? false
                self?.isAuthenticated = user != nil
                self?.userIdentifier = user?.uid
                self?.userEmail = user?.email
                self?.userFullName = user?.displayName

                if let user = user {
                    print("Firebase Auth: User signed in - \(user.uid)")
                } else {
                    print("Firebase Auth: User signed out")
                }

                // Notify if state changed
                if wasAuthenticated != (user != nil) {
                    NotificationCenter.default.post(name: .authenticationStateChanged, object: nil)
                }
            }
        }
    }

    // MARK: - Check Authentication State (called on app launch)

    func checkAuthenticationState() {
        // Firebase handles this automatically via the state listener
        // This method is kept for API compatibility
        if let user = Auth.auth().currentUser {
            isAuthenticated = true
            userIdentifier = user.uid
            userEmail = user.email
            userFullName = user.displayName
        }
    }

    // MARK: - Sign In with Apple

    func signInWithApple() {
        isLoading = true
        errorMessage = nil

        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }

    // MARK: - SignInWithAppleButton Support

    func prepareSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        isLoading = true
        errorMessage = nil
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            handleAuthorization(authorization)
        case .failure(let error):
            handleAuthorizationError(error)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            userIdentifier = nil
            userEmail = nil
            userFullName = nil
            print("Firebase sign out successful")
        } catch {
            print("Firebase sign out error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Account

    func deleteAccount() {
        guard let user = currentUser else {
            print("No user to delete")
            return
        }

        Task {
            do {
                try await user.delete()
                print("Firebase account deleted successfully")
                signOut()
            } catch {
                print("Error deleting account: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Nonce Generation (required for Sign in with Apple + Firebase)

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handleAuthorization(authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        handleAuthorizationError(error)
    }
}

// MARK: - Authorization Handling

extension AuthenticationService {
    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            isLoading = false
            errorMessage = "Invalid credential type"
            return
        }

        guard let nonce = currentNonce else {
            isLoading = false
            errorMessage = "Invalid state: A login callback was received, but no login request was sent."
            return
        }

        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            isLoading = false
            errorMessage = "Unable to fetch identity token"
            return
        }

        // Create Firebase credential
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        // Sign in to Firebase
        Task {
            do {
                let result = try await Auth.auth().signIn(with: credential)
                print("Firebase Sign in with Apple successful - UID: \(result.user.uid)")

                // Update display name if available from Apple
                if let fullName = appleIDCredential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")

                    if !displayName.isEmpty {
                        let changeRequest = result.user.createProfileChangeRequest()
                        changeRequest.displayName = displayName
                        try? await changeRequest.commitChanges()
                        self.userFullName = displayName
                    }
                }

                isLoading = false
            } catch {
                print("Firebase sign in error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func handleAuthorizationError(_ error: Error) {
        isLoading = false

        // Don't show error for user cancellation
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }

        print("Sign in with Apple failed: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
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
