//
//  VideoPlayerManager.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 11/5/25.
//

import Foundation

/// Manages active video players to ensure only one video plays at a time
class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()

    private var currentPlayerCoordinator: YouTubePlayerCoordinator?

    private init() {}

    /// Register a new video player and stop any previously playing video
    func registerPlayer(_ coordinator: YouTubePlayerCoordinator) {
        // Stop the previous video if one exists
        currentPlayerCoordinator?.stopVideo()

        // Set the new current player
        currentPlayerCoordinator = coordinator
    }

    /// Manually stop the current video (if needed)
    func stopCurrentVideo() {
        currentPlayerCoordinator?.stopVideo()
        currentPlayerCoordinator = nil
    }
}
