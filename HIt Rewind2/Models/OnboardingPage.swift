//
//  OnboardingPage.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/5/25.
//

import Foundation

struct OnboardingPage: Identifiable {
    let id = UUID()
    let imageName: String
    let gifName: String?
    let title: String
    let subtitle: String
    let useCarousel: Bool
    let useGIFCarousel: Bool
}

extension OnboardingPage {
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "onboarding1",
            gifName: nil,
            title: "Remember music\non your TV?",
            subtitle: "I want that to\nhappen again.",
            useCarousel: true,
            useGIFCarousel: false
        ),
        OnboardingPage(
            imageName: "onboarding2",
            gifName: nil,
            title: "Music is still here",
            subtitle: "But Netflix stole the screen\n😢",
            useCarousel: false,
            useGIFCarousel: false
        ),
        OnboardingPage(
            imageName: "onboarding3",
            gifName: nil,
            title: "Let's take it back 🔥",
            subtitle: "",
            useCarousel: false,
            useGIFCarousel: true
        ),
        OnboardingPage(
            imageName: "onboarding4",
            gifName: nil,
            title: "Press \"Send to TV\"",
            subtitle: "Rock your room",
            useCarousel: false,
            useGIFCarousel: false
        ),
        OnboardingPage(
            imageName: "onboarding5",
            gifName: nil,
            title: "Pick a Year",
            subtitle: "You're the VJ",
            useCarousel: false,
            useGIFCarousel: false
        )
    ]
}
