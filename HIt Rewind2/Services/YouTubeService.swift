//
//  YouTubeService.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - YouTube Models
struct YouTubeVideoResponse: Codable {
    let items: [YouTubeVideo]
}

struct YouTubeVideo: Codable {
    let id: String
    let snippet: YouTubeVideoSnippet
    let contentDetails: YouTubeContentDetails?
}

struct YouTubeVideoSnippet: Codable {
    let title: String
    let description: String
    let thumbnails: YouTubeThumbnails
    let channelTitle: String
    let publishedAt: String
}

struct YouTubeThumbnails: Codable {
    let `default`: YouTubeThumbnail?
    let medium: YouTubeThumbnail?
    let high: YouTubeThumbnail?
    let standard: YouTubeThumbnail?
    let maxres: YouTubeThumbnail?
}

struct YouTubeThumbnail: Codable {
    let url: String
    let width: Int
    let height: Int
}

struct YouTubeContentDetails: Codable {
    let duration: String
}

// MARK: - YouTube Service
@MainActor
class YouTubeService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let session = URLSession.shared
    
    // MARK: - Video Information
    func getVideoInfo(videoId: String) async throws -> YouTubeVideo {
        guard !YouTubeConfig.apiKey.isEmpty && YouTubeConfig.apiKey != "YOUR_YOUTUBE_API_KEY_HERE" else {
            throw YouTubeError.missingAPIKey
        }
        
        let urlString = "\(YouTubeConfig.baseURL)/videos?part=snippet,contentDetails&id=\(videoId)&key=\(YouTubeConfig.apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw YouTubeError.invalidURL
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(YouTubeVideoResponse.self, from: data)
            
            guard let video = response.items.first else {
                throw YouTubeError.videoNotFound
            }
            
            return video
        } catch {
            throw YouTubeError.networkError(error)
        }
    }
    
    // MARK: - Thumbnail URL Generation
    func getThumbnailURL(for videoId: String, quality: ThumbnailQuality = .medium) -> URL? {
        let urlString: String
        
        switch quality {
        case .default:
            urlString = "https://i.ytimg.com/vi/\(videoId)/default.jpg"
        case .medium:
            urlString = "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
        case .high:
            urlString = "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
        case .standard:
            urlString = "https://i.ytimg.com/vi/\(videoId)/sddefault.jpg"
        case .maxres:
            urlString = "https://i.ytimg.com/vi/\(videoId)/maxresdefault.jpg"
        }
        
        return URL(string: urlString)
    }
    
    // MARK: - Video Player URL (for AVPlayer)
    func getVideoPlayerURL(for videoId: String) -> URL? {
        // For now, we'll return the standard YouTube watch URL
        // In a production app, you'd want to use a proper video extraction service
        // or integrate with YouTube Player iOS SDK for embedded playback
        return URL(string: "https://www.youtube.com/watch?v=\(videoId)")
    }
    
    // MARK: - Duration Formatting
    func formatDuration(_ isoDuration: String) -> String {
        // Parse ISO 8601 duration format (PT4M13S -> 4:13, PT1H5M30S -> 65:30)
        let duration = isoDuration.replacingOccurrences(of: "PT", with: "")
        
        var hours = 0
        var minutes = 0
        var seconds = 0
        
        // Parse hours
        if duration.contains("H") {
            let hourPattern = #"(\d+)H"#
            if let match = duration.range(of: hourPattern, options: .regularExpression) {
                let hourString = String(duration[match]).replacingOccurrences(of: "H", with: "")
                hours = Int(hourString) ?? 0
            }
        }
        
        // Parse minutes
        if duration.contains("M") {
            let minutePattern = #"(\d+)M"#
            if let match = duration.range(of: minutePattern, options: .regularExpression) {
                let minuteString = String(duration[match]).replacingOccurrences(of: "M", with: "")
                minutes = Int(minuteString) ?? 0
            }
        }
        
        // Parse seconds
        if duration.contains("S") {
            let secondPattern = #"(\d+)S"#
            if let match = duration.range(of: secondPattern, options: .regularExpression) {
                let secondString = String(duration[match]).replacingOccurrences(of: "S", with: "")
                seconds = Int(secondString) ?? 0
            }
        }
        
        // Format according to the new style: 1h 34m, 22min, 7min
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 && minutes == 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)min"
        } else if seconds > 0 {
            // For videos less than a minute, round up to 1min
            return "1min"
        } else {
            return ""
        }
    }
}

// MARK: - Enums and Errors
enum ThumbnailQuality {
    case `default`  // 120x90
    case medium     // 320x180
    case high       // 480x360
    case standard   // 640x480
    case maxres     // 1280x720
}

enum YouTubeError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case videoNotFound
    case networkError(Error)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "YouTube API key is missing. Please configure your API key in Constants.swift"
        case .invalidURL:
            return "Invalid YouTube URL"
        case .videoNotFound:
            return "Video not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}