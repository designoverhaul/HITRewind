//
//  FanCamCategory.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI

struct FanCamCategory: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let description: String
    let imageUrl: URL?
    let color: Color
    let artists: [String]
    let artistIds: [String]

    // CodingKeys to handle Color encoding/decoding
    enum CodingKeys: String, CodingKey {
        case id, name, description, imageUrl, colorHex, artists, artistIds
    }

    init(id: String = UUID().uuidString, name: String, description: String = "", imageUrl: URL? = nil, color: Color = .purple, artists: [String] = [], artistIds: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.imageUrl = imageUrl
        self.color = color
        self.artists = artists
        self.artistIds = artistIds
    }

    // Custom encoding to handle Color
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        // Store color as hex string
        try container.encode("#A789FD", forKey: .colorHex) // Default purple
        try container.encode(artists, forKey: .artists)
        try container.encode(artistIds, forKey: .artistIds)
    }

    // Custom decoding to handle Color
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        imageUrl = try container.decodeIfPresent(URL.self, forKey: .imageUrl)
        // Always use purple color when decoding from cache
        color = .purple
        artists = try container.decode([String].self, forKey: .artists)
        artistIds = try container.decode([String].self, forKey: .artistIds)
    }

    func containsArtist(_ artistName: String) -> Bool {
        return artists.contains { artist in
            artist.localizedCaseInsensitiveCompare(artistName) == .orderedSame ||
            artistName.localizedCaseInsensitiveContains(artist) ||
            artist.localizedCaseInsensitiveContains(artistName)
        }
    }

    static func == (lhs: FanCamCategory, rhs: FanCamCategory) -> Bool {
        return lhs.id == rhs.id
    }
}

extension FanCamCategory {
    static var allCategories: [FanCamCategory] {
        // Mock data for previews
        return [
            FanCamCategory(name: "Pop", description: "Pop music and artists", imageUrl: nil),
            FanCamCategory(name: "Modern Rock", description: "Modern rock and alternative", imageUrl: nil),
            FanCamCategory(name: "Classic Rock", description: "Classic rock legends", imageUrl: nil)
        ]
    }
}