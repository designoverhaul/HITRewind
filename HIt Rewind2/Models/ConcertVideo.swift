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
}

struct ConcertVideoFields: Codable {
    let videoTitle: String
    let youtubeUrl: String
    let concert: [String]? // Array of Concert record IDs this video belongs to
    let cleaner: String?
    
    enum CodingKeys: String, CodingKey {
        case videoTitle = "videoTItle"  // Note: Airtable field has typo with capital "I"
        case youtubeUrl = "youtubeUrl"
        case concert = "concert"
        case cleaner = "cleaner"
    }
}

// MARK: - Airtable API Response
struct ConcertVideoResponse: Codable {
    let records: [ConcertVideo]
}