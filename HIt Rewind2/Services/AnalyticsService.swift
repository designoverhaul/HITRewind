//
//  AnalyticsService.swift
//  HIt Rewind2
//
//  Thin wrapper around Firebase Analytics for event logging.
//

import FirebaseAnalytics

enum AnalyticsService {

    // MARK: - Video Playback

    static func logVideoPlayed(title: String, artist: String, year: String, source: String) {
        Analytics.logEvent("video_played", parameters: [
            "title": title,
            "artist": artist,
            "year": year,
            "source": source
        ])
    }

    // MARK: - Navigation

    static func logTabViewed(tab: String) {
        Analytics.logEvent("tab_viewed", parameters: [
            "tab_name": tab
        ])
    }

    static func logYearSelected(year: Int) {
        Analytics.logEvent("year_selected", parameters: [
            "year": year
        ])
    }

    static func logArtistViewed(artist: String) {
        Analytics.logEvent("artist_viewed", parameters: [
            "artist": artist
        ])
    }

    // MARK: - Search

    static func logSearchPerformed(query: String, resultCount: Int) {
        Analytics.logEvent("search_performed", parameters: [
            "query": query,
            "result_count": resultCount
        ])
    }

    // MARK: - Favorites

    static func logFavoriteToggled(title: String, artist: String, isFavorited: Bool) {
        Analytics.logEvent("favorite_toggled", parameters: [
            "title": title,
            "artist": artist,
            "action": isFavorited ? "added" : "removed"
        ])
    }

    // MARK: - VJ Mode

    static func logVJModeOpened(source: String) {
        Analytics.logEvent("vj_mode_opened", parameters: [
            "source": source
        ])
    }

    static func logVJModeClosed() {
        Analytics.logEvent("vj_mode_closed", parameters: [:])
    }
}
