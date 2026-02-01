//
//  SpotifyChartVideo.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 1/30/26.
//

import Foundation

// MARK: - Spotify Chart Video Models
struct SpotifyChartVideo: Codable, Identifiable {
    let id: String
    let fields: SpotifyChartVideoFields
}

struct SpotifyChartVideoFields: Codable {
    let title: String?
    let url: String?
    let rank: Int?
    let artistName: String?

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case rank = "Rank"
        case artistName
    }
}

// MARK: - Airtable API Response
struct SpotifyChartVideoResponse: Codable {
    let records: [SpotifyChartVideo]
    let offset: String?
}
