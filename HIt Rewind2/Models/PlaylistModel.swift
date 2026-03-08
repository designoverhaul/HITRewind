//
//  PlaylistModel.swift
//  HIt Rewind2
//
//  Adapted from Apple TV version for iOS SwiftUI
//  Created by Aaron Heine on 8/24/25.
//

import Foundation

// MARK: - Playlist Models
struct Playlist: Codable, Identifiable {
    let id: String
    var fields: PlaylistFields
}

struct PlaylistFields: Codable {
    let thumbnail: URL
    let year: Int
    let title: String
    var mtvVideos: [String]?
    var videoUrls: [String]?
    var artistNames: [String]?
    var videoTitles: [String]?
    var videoYears: [String]?
    var isVisible: [Bool?]
    var isLocked: Bool?
    var isPlaylist: Bool?
    var videoDurations: [String]?
    var youtubeChannelId: String?
    var youtubeChannelIcon: String?

    enum CodingKeys: String, CodingKey {
        case thumbnail
        case year
        case title
        case mtvVideos
        case videoUrls
        case videoTitles
        case videoYears
        case isVisible
        case isLocked
        case isPlaylist
        case artistNames
        case artistName // alias used by Airtable
        case videoDurations = "VideoDuration"
        case youtubeChannelId
        case youtubeChannelIcon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        thumbnail = try container.decode(URL.self, forKey: .thumbnail)
        year = try container.decode(Int.self, forKey: .year)
        title = try container.decode(String.self, forKey: .title)
        mtvVideos = try container.decodeIfPresent([String].self, forKey: .mtvVideos)
        videoUrls = try container.decodeIfPresent([String].self, forKey: .videoUrls)
        videoTitles = try container.decodeIfPresent([String].self, forKey: .videoTitles)
        videoYears = try container.decodeIfPresent([String].self, forKey: .videoYears)
        isVisible = try container.decodeIfPresent([Bool?].self, forKey: .isVisible) ?? []
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked)
        isPlaylist = try container.decodeIfPresent(Bool.self, forKey: .isPlaylist)

        // Accept either artistNames or artistName from Airtable
        artistNames = try container.decodeIfPresent([String].self, forKey: .artistNames)
        if artistNames == nil {
            artistNames = try container.decodeIfPresent([String].self, forKey: .artistName)
        }
        videoDurations = try container.decodeIfPresent([String].self, forKey: .videoDurations)
        youtubeChannelId = try container.decodeIfPresent(String.self, forKey: .youtubeChannelId)
        youtubeChannelIcon = try container.decodeIfPresent(String.self, forKey: .youtubeChannelIcon)
    }

    init(
        thumbnail: URL,
        year: Int,
        title: String,
        mtvVideos: [String]? = nil,
        videoUrls: [String]? = nil,
        artistNames: [String]? = nil,
        videoTitles: [String]? = nil,
        videoYears: [String]? = nil,
        isVisible: [Bool?] = [],
        isLocked: Bool? = nil,
        isPlaylist: Bool? = nil,
        videoDurations: [String]? = nil,
        youtubeChannelId: String? = nil,
        youtubeChannelIcon: String? = nil
    ) {
        self.thumbnail = thumbnail
        self.year = year
        self.title = title
        self.mtvVideos = mtvVideos
        self.videoUrls = videoUrls
        self.artistNames = artistNames
        self.videoTitles = videoTitles
        self.videoYears = videoYears
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.isPlaylist = isPlaylist
        self.videoDurations = videoDurations
        self.youtubeChannelId = youtubeChannelId
        self.youtubeChannelIcon = youtubeChannelIcon
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(thumbnail, forKey: .thumbnail)
        try container.encode(year, forKey: .year)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(mtvVideos, forKey: .mtvVideos)
        try container.encodeIfPresent(videoUrls, forKey: .videoUrls)
        try container.encodeIfPresent(videoTitles, forKey: .videoTitles)
        try container.encodeIfPresent(videoYears, forKey: .videoYears)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encodeIfPresent(isLocked, forKey: .isLocked)
        try container.encodeIfPresent(isPlaylist, forKey: .isPlaylist)
        try container.encodeIfPresent(artistNames, forKey: .artistNames)
        try container.encodeIfPresent(videoDurations, forKey: .videoDurations)
        try container.encodeIfPresent(youtubeChannelId, forKey: .youtubeChannelId)
        try container.encodeIfPresent(youtubeChannelIcon, forKey: .youtubeChannelIcon)
    }
}

// MARK: - Error Types
enum PlaylistError: Error, LocalizedError {
    case sortingError(String)
    case invalidURL
    case noData
    case decodingError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .sortingError(let message):
            return "Sorting error: \(message)"
        case .invalidURL:
            return "Invalid URL provided"
        case .noData:
            return "No data received from server"
        case .decodingError(let message):
            return "Failed to decode data: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helper Functions
func extractYouTubeVideoID(from videoURL: String) -> String? {
    guard let url = URL(string: videoURL) else { return nil }
    let host = (url.host ?? "").replacingOccurrences(of: "www.", with: "").lowercased()
    let path = url.path

    // 1) Short links: youtu.be/<id>
    if host == "youtu.be" {
        let components = path.split(separator: "/")
        if let first = components.first { return String(first) }
    }

    // 2) Standard watch URL: youtube.com/watch?v=<id>
    if host.contains("youtube.com") {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let v = components.queryItems?.first(where: { $0.name.lowercased() == "v" })?.value, !v.isEmpty {
                return v
            }
            if let vi = components.queryItems?.first(where: { $0.name.lowercased() == "vi" })?.value, !vi.isEmpty {
                return vi
            }
        }

        // 3) Embed URL: /embed/<id>
        if path.lowercased().hasPrefix("/embed/") {
            let comps = path.split(separator: "/")
            if comps.count >= 2 { return String(comps[1]) }
        }

        // 4) Shorts URL: /shorts/<id>
        if path.lowercased().hasPrefix("/shorts/") {
            let comps = path.split(separator: "/")
            if comps.count >= 2 { return String(comps[1]) }
        }
    }

    return nil
}