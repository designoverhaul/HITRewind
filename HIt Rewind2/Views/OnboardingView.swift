//
//  OnboardingView.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/5/25.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @Binding var isOnboardingComplete: Bool

    let pages = OnboardingPage.pages

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Paged content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 20)

                // Next button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        // Complete onboarding
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "NEXT" : "GET STARTED")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.gray)
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation {
            isOnboardingComplete = true
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
