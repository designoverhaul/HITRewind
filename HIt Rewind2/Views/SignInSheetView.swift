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
            VStack(spacing: 32) {
                Spacer()
                
                // Post2 image - responsive sizing
                Image("post2")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: isIPhonePortrait ? .infinity : 500)
                    .clipped()
                    .padding(.horizontal, isIPhonePortrait ? 0 : 16)
                
                VStack(spacing: 4) {
                    Text("Save your faves")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.hitRewindPrimaryText)
                    
                    Text("Sign in to save your favorite music videos and sync them across all your devices with iCloud.")
                        .font(.body)
                        .foregroundColor(.hitRewindSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Sign in button
                Button(action: {
                    authService.signInWithApple()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18))
                            .foregroundColor(.hitRewindPurple)
                        Text("Sign in with Apple")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                }
                .disabled(authService.isLoading)
                .padding(.horizontal, 40)
                
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