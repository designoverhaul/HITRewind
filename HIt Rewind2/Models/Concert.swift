//
//  Concert.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import Foundation

// MARK: - Concert Models
struct Concert: Codable, Identifiable, Hashable {
    let id: String
    let fields: ConcertFields
}

struct ConcertFields: Codable, Hashable {
    let venueName: String?
    let artistName: String
    let eventYear: Int
    let bannerImage: [BannerImageAttachment]?
    let largeImage: [BannerImageAttachment]?
    let eventDescription: String?
    let concertVideos: [String]? // Array of ConcertVideo record IDs
    
    enum CodingKeys: String, CodingKey {
        case venueName = "venueName"
        case artistName = "artistName"
        case eventYear = "eventYear"
        case bannerImage = "bannerImage"
        case largeImage = "largeImage"
        case eventDescription = "eventDescription"
        case concertVideos = "Concert Videos"
    }
    
    // Regular memberwise initializer
    init(venueName: String?, artistName: String, eventYear: Int, bannerImage: [BannerImageAttachment]? = nil, largeImage: [BannerImageAttachment]? = nil, eventDescription: String? = nil, concertVideos: [String]? = nil) {
        self.venueName = venueName
        self.artistName = artistName
        self.eventYear = eventYear
        self.bannerImage = bannerImage
        self.largeImage = largeImage
        self.eventDescription = eventDescription
        self.concertVideos = concertVideos
    }
    
    // Custom decoder for handling string/int conversion
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        venueName = try container.decodeIfPresent(String.self, forKey: .venueName)
        artistName = try container.decode(String.self, forKey: .artistName)
        
        // Handle eventYear as either Int or String
        if let yearInt = try? container.decode(Int.self, forKey: .eventYear) {
            eventYear = yearInt
        } else if let yearString = try? container.decode(String.self, forKey: .eventYear) {
            eventYear = Int(yearString) ?? 2024
        } else {
            eventYear = 2024
        }
        
        bannerImage = try container.decodeIfPresent([BannerImageAttachment].self, forKey: .bannerImage)
        largeImage = try container.decodeIfPresent([BannerImageAttachment].self, forKey: .largeImage)
        eventDescription = try container.decodeIfPresent(String.self, forKey: .eventDescription)
        concertVideos = try container.decodeIfPresent([String].self, forKey: .concertVideos)
    }
}

// MARK: - Airtable Image Attachment
struct BannerImageAttachment: Codable, Hashable {
    let id: String
    let width: Int
    let height: Int
    let url: String
    let filename: String
    let size: Int
    let type: String

    enum CodingKeys: String, CodingKey {
        case id, width, height, url, filename, size, type
    }
}

// MARK: - Airtable API Response
struct ConcertResponse: Codable {
    let records: [Concert]
}