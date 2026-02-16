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
    @StateObject private var imagePreloader = ImagePreloader.shared
    @State private var isLoading = true

    let pages = OnboardingPage.pages

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if isLoading {
                // Simple loading indicator
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            } else {
                contentView
            }
        }
        .task {
            // Preload all images before showing content
            await preloadAssets()
        }
        .onAppear {
            // Switch to portrait for onboarding
            OrientationManager.shared.switchToPortraitForOnboarding()
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
                // Paged content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .environment(\.isPageActive, currentPage == index)
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
                .padding(.bottom, 16)

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
                .padding(.bottom, 60)
        }
    }

    private func preloadAssets() async {
        // Preload all carousel images and onboarding images
        let allImages = [
            "tv1", "tv2", "tv3", "tv4", "tv5", "tv6", // TV carousel
            "onboarding2", "Onboarding4", "Onboarding4.5", "onboarding5" // Static onboarding images
        ]

        await imagePreloader.preloadImages(allImages)

        // Start fetching Top 100 videos in background
        // By the time user finishes onboarding, data will be cached and ready
        // This preloads the DirectVideoService which powers the Top 100 tab
        Task {
            await DirectVideoService.shared.fetchVideos()
        }

        // Small delay to ensure everything is settled
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        await MainActor.run {
            isLoading = false
        }
    }

    private func completeOnboarding() {
        // Switch to landscape before showing main app
        OrientationManager.shared.lockToLandscape()

        // Complete onboarding right away (music continues fading in background)
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation {
            isOnboardingComplete = true
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
