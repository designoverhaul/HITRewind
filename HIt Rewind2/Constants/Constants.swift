//
//  Constants.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import Foundation

// MARK: - Airtable Configuration
struct AirtableConfig {
    static let apiKey = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
    static let playListUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/MTvPlaylists"
    static let liveShowsUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/LiveShows"
    static let legendaryShowsUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/LegendaryShows"
    static let concertsUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/Concerts"
    static let categoriesUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/Category"
    static let artistsUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/Artists"
    static let videosUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/Videos"
    static let mtvVideosNewUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/tblNwqwVyflL8hNDy"
    static let spotifyChartVideosUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/TopToday"
    static let officialVideosUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/tblSq6zqj4c6aXDhB"
}

// MARK: - YouTube Configuration
struct YouTubeConfig {
    static let apiKey = "AIzaSyBiNw2RoGEbxTMGNiApi3TBZ-EH8oQXy24"
    static let baseURL = "https://www.googleapis.com/youtube/v3"
}

// MARK: - Superwall Configuration
struct SuperwallConfig {
    static let apiKey = "pk_AM59bLbkjLlzMlLOJWEWn"
}

// MARK: - App Configuration
struct AppConfig {
    static let appName = "Hit Rewind"
    static let version = "2.0"
    static let useCloudKit = false  // Deprecated - now using Firebase
    static let useFirebase = true
    static let appStoreId = "6479374259"  // App Store ID for reviews
}