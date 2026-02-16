//
//  SignInSheetView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 9/3/25.
//

import SwiftUI
import AuthenticationServices

struct SignInSheetView: View {
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPhonePortrait: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && horizontalSizeClass == .compact
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Description text
                Text("Sign in to save and sync your favorites across devices.")
                    .font(.body)
                    .foregroundColor(.hitRewindSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Standard Apple Sign In button
                SignInWithAppleButton(.signIn) { request in
                    authService.prepareSignInRequest(request)
                } onCompletion: { result in
                    authService.handleSignInCompletion(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(width: 280, height: 50)
                .disabled(authService.isLoading)

                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.hitRewindPurple)
                }
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
}

#Preview {
    SignInSheetView()
        .preferredColorScheme(.dark)
}