//
//  OnboardingPage.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/5/25.
//

import Foundation

enum OnboardingPageType {
    case textOnly(emoji: String)
    case checklist(items: [String])
    case image(name: String)
    case loopingVideo(name: String)
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let pageType: OnboardingPageType
}

extension OnboardingPage {
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "I miss MTV",
            pageType: .textOnly(emoji: "🥺")
        ),
        OnboardingPage(
            title: "So I made my\nown version!",
            pageType: .textOnly(emoji: "👊")
        ),
        OnboardingPage(
            title: "This one has...",
            pageType: .checklist(items: [
                "Top 100 videos 1975-2026",
                "Live shows from top artists",
                "Official artist releases",
                "Ridiculous collections",
                "No ads"
            ])
        ),
        OnboardingPage(
            title: "Try sending to\nyour TV...",
            pageType: .image(name: "Onboarding4")
        ),
        OnboardingPage(
            title: "Rock your room 🤘",
            pageType: .loopingVideo(name: "songs")
        )
    ]
}
