//
//  LegendaryShow.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import Foundation

// MARK: - Legendary Show Models
struct LegendaryShow: Codable, Identifiable {
    let id: String
    let fields: LegendaryShowFields
}

struct LegendaryShowFields: Codable {
    let title: String
    let artist: String
    let year: Int
    let youtubeUrl: String
    let videoImage: String?
    
    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case artist = "Artist" 
        case year = "Year"
        case youtubeUrl = "URL"
        case videoImage = "videoImage"
    }
    
    // Regular memberwise initializer
    init(title: String, artist: String, year: Int, youtubeUrl: String, videoImage: String? = nil) {
        self.title = title
        self.artist = artist
        self.year = year
        self.youtubeUrl = youtubeUrl
        self.videoImage = videoImage
    }
    
    // Custom decoder for handling string/int conversion
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        youtubeUrl = try container.decode(String.self, forKey: .youtubeUrl)
        videoImage = try container.decodeIfPresent(String.self, forKey: .videoImage)
        
        // Handle year as either Int or String
        if let yearInt = try? container.decode(Int.self, forKey: .year) {
            year = yearInt
        } else if let yearString = try? container.decode(String.self, forKey: .year) {
            year = Int(yearString) ?? 2024
        } else {
            year = 2024
        }
    }
}

// MARK: - Airtable API Response
struct LegendaryShowResponse: Codable {
    let records: [LegendaryShow]
}