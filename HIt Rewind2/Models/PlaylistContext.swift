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
}

/// Context passed to video player for autoplay functionality
struct PlaylistContext {
    let videos: [PlaylistVideo]
    let currentIndex: Int

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
}
