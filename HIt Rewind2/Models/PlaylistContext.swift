//
//  PlaylistContext.swift
//  HIt Rewind2
//
//  Created for autoplay functionality
//

import Foundation

/// Represents a video in a playlist for autoplay
struct PlaylistVideo: Identifiable, Equatable, Hashable {
    let id: String // YouTube video ID
    let youtubeURL: String
    let title: String
    let artist: String
    let year: String
    let rank: Int? // Billboard rank from Airtable (nil if not applicable)
    let duration: String? // Formatted duration (e.g. "4:13") - nil if not available

    /// Initialize with optional rank and duration (defaults to nil for backward compatibility)
    init(id: String, youtubeURL: String, title: String, artist: String, year: String, rank: Int? = nil, duration: String? = nil) {
        self.id = id
        self.youtubeURL = youtubeURL
        self.title = title
        self.artist = artist
        self.year = year
        self.rank = rank
        self.duration = duration
    }
}

/// The source where the video was played from, affects UI in player
enum VideoSourceType: Equatable {
    /// Music Videos page - shows years row and videos by year
    case musicVideos

    /// Epic Shows page - shows artists row and videos by artist
    /// categoryName: The category name (e.g., "80s Hits")
    /// allCategoryVideos: All videos in this category (not just the 8 displayed)
    case epicShows(categoryName: String, allCategoryVideos: [PlaylistVideo])

    /// Concert page - shows concert videos only (no picker)
    case concert

    /// Live/FanCams page - shows artists from category and videos by artist
    /// artistName: The current artist name
    /// categoryArtists: All artist names in the same category
    /// allArtistVideos: Dictionary mapping artist name to their videos
    case live(artistName: String, categoryArtists: [String], allArtistVideos: [String: [PlaylistVideo]])

    static func == (lhs: VideoSourceType, rhs: VideoSourceType) -> Bool {
        switch (lhs, rhs) {
        case (.musicVideos, .musicVideos):
            return true
        case (.concert, .concert):
            return true
        case let (.epicShows(name1, _), .epicShows(name2, _)):
            return name1 == name2
        case (.live(let artist1, _, _), .live(let artist2, _, _)):
            return artist1 == artist2
        default:
            return false
        }
    }
}

/// Context passed to video player for autoplay functionality
struct PlaylistContext {
    let videos: [PlaylistVideo]
    let currentIndex: Int
    let sourceType: VideoSourceType

    /// Initialize with default musicVideos source type for backward compatibility
    init(videos: [PlaylistVideo], currentIndex: Int, sourceType: VideoSourceType = .musicVideos) {
        self.videos = videos
        self.currentIndex = currentIndex
        self.sourceType = sourceType
    }

    /// Get the next video in the playlist, if available
    var nextVideo: PlaylistVideo? {
        let nextIndex = currentIndex + 1
        guard nextIndex < videos.count else { return nil }
        return videos[nextIndex]
    }

    /// Check if there's a next video available
    var hasNextVideo: Bool {
        return nextVideo != nil
    }

    /// Get unique artists from Epic Shows category (for artist picker)
    var categoryArtists: [String] {
        guard case .epicShows(_, let allVideos) = sourceType else { return [] }
        let artists = allVideos.map { $0.artist }
        return Array(Set(artists)).sorted()
    }

    /// Get videos by artist from Epic Shows category
    func videosForArtist(_ artist: String) -> [PlaylistVideo] {
        guard case .epicShows(_, let allVideos) = sourceType else { return [] }
        return allVideos.filter { $0.artist == artist }
    }

    /// Get artists from Live/FanCams category (for artist picker)
    var liveArtists: [String] {
        guard case .live(_, let artists, _) = sourceType else { return [] }
        return artists
    }

    /// Get videos by artist from Live/FanCams mode
    func liveVideosForArtist(_ artist: String) -> [PlaylistVideo] {
        guard case .live(_, _, let allArtistVideos) = sourceType else { return [] }
        return allArtistVideos[artist] ?? []
    }
}
