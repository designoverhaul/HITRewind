//
//  ConcertVideo.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import Foundation

// MARK: - Concert Video Models
struct ConcertVideo: Codable, Identifiable {
    let id: String
    let fields: ConcertVideoFields

    init(id: String, fields: ConcertVideoFields) {
        self.id = id
        self.fields = fields
    }
}

struct ConcertVideoFields: Codable {
    let videoTitle: String
    let youtubeUrl: String
    let concert: [String]? // Array of Concert record IDs this video belongs to
    let cleaner: String?
    let artistName: String? // Optional artist name for videos with different performers

    init(videoTitle: String, youtubeUrl: String, concert: [String]? = nil, cleaner: String? = nil, artistName: String? = nil) {
        self.videoTitle = videoTitle
        self.youtubeUrl = youtubeUrl
        self.concert = concert
        self.cleaner = cleaner
        self.artistName = artistName
    }

    enum CodingKeys: String, CodingKey {
        case videoTitle = "videoTItle"  // Note: Airtable field has typo with capital "I"
        case youtubeUrl = "youtubeUrl"
        case concert = "concert"
        case cleaner = "cleaner"
        case artistName = "artistName"
    }
}

// MARK: - Airtable API Response
struct ConcertVideoResponse: Codable {
    let records: [ConcertVideo]
}