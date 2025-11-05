import SwiftUI
import Foundation

@MainActor
class ReviewRequestService: ObservableObject {
    @Published var shouldShowReviewRequest = false
    @Published var currentQuote = "Tell me something good"
    @Published var currentQuoteIndex = 0
    
    private let songQuotes = [
        "Tell me something good",
        "I get by with a little help from my friends.",
        "One good thing about music, when it hits you, you feel no pain.",
        "All you need is love.",
        "Say something, I'm giving up on you.",
        "We all need somebody to lean on."
    ]
    
    private let userDefaults = UserDefaults.standard
    private let launchCountKey = "app_launch_count"
    private let lastReviewRequestKey = "last_review_request_date"
    private let hasRequestedReviewKey = "has_requested_review"
    private let currentQuoteIndexKey = "current_quote_index"
    
    init() {
        loadCurrentQuoteIndex()
        incrementLaunchCount()
        updateCurrentQuote()
    }
    
    private func loadCurrentQuoteIndex() {
        currentQuoteIndex = userDefaults.integer(forKey: currentQuoteIndexKey)
        if currentQuoteIndex >= songQuotes.count {
            currentQuoteIndex = 0
        }
    }
    
    private func incrementLaunchCount() {
        let currentCount = userDefaults.integer(forKey: launchCountKey)
        userDefaults.set(currentCount + 1, forKey: launchCountKey)
    }
    
    private func updateCurrentQuote() {
        currentQuote = songQuotes[currentQuoteIndex]
    }
    
    func checkIfShouldRequestReview() {
        let launchCount = userDefaults.integer(forKey: launchCountKey)
        let hasRequestedBefore = userDefaults.bool(forKey: hasRequestedReviewKey)
        
        // Show after 3 launches initially, then every 7 launches (more frequent)
        let shouldShow: Bool
        if !hasRequestedBefore {
            shouldShow = launchCount >= 3
        } else {
            if let lastRequestDate = userDefaults.object(forKey: lastReviewRequestKey) as? Date {
                let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
                shouldShow = launchCount % 7 == 0 && daysSinceLastRequest >= 7
            } else {
                shouldShow = launchCount % 7 == 0
            }
        }
        
        if shouldShow {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.shouldShowReviewRequest = true
            }
        }
    }
    
    func markReviewRequested() {
        userDefaults.set(true, forKey: hasRequestedReviewKey)
        userDefaults.set(Date(), forKey: lastReviewRequestKey)
        shouldShowReviewRequest = false
    }
    
    func dismissReviewRequest() {
        userDefaults.set(Date(), forKey: lastReviewRequestKey)
        shouldShowReviewRequest = false
    }
    
    func nextMessage() {
        currentQuoteIndex = (currentQuoteIndex + 1) % songQuotes.count
        userDefaults.set(currentQuoteIndex, forKey: currentQuoteIndexKey)
        updateCurrentQuote()
    }
}