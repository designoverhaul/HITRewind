//
//  FanCamCategory.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI

struct FanCamCategory: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let imageUrl: URL?
    let color: Color
    let artists: [String]
    let artistIds: [String]
    
    init(id: String = UUID().uuidString, name: String, description: String = "", imageUrl: URL? = nil, color: Color = .purple, artists: [String] = [], artistIds: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.imageUrl = imageUrl
        self.color = color
        self.artists = artists
        self.artistIds = artistIds
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