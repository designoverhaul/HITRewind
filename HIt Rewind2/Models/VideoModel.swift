//
//  VideoModel.swift
//  HIt Rewind2
//
//  Model for direct video records from MTvVideosNEW table
//  Created by Aaron Heine on 1/11/26.
//

import Foundation

// MARK: - Video Models for MTvVideosNEW Direct Records
struct VideoRecord: Codable, Identifiable {
    let id: String
    var fields: VideoFields
}

struct VideoFields: Codable {
    let title: String
    let artistName: String
    let url: String
    let rank: Int
    let year: String  // Note: Year is stored as text in Airtable

    enum CodingKeys: String, CodingKey {
        case title
        case artistName
        case url
        case rank = "Rank"
        case year = "Year"
    }

    // Helper to get year as Int
    var yearInt: Int? {
        Int(year)
    }

    // Helper to get YouTube video ID from URL
    var youtubeVideoId: String? {
        // Extract video ID from YouTube URL
        guard let videoURL = URL(string: url) else { return nil }
        let host = (videoURL.host ?? "").replacingOccurrences(of: "www.", with: "").lowercased()
        let path = videoURL.path

        // Short links: youtu.be/<id>
        if host == "youtu.be" {
            let components = path.split(separator: "/")
            if let first = components.first { return String(first) }
        }

        // Standard watch URL: youtube.com/watch?v=<id>
        if host.contains("youtube.com") {
            if let components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false) {
                if let v = components.queryItems?.first(where: { $0.name.lowercased() == "v" })?.value, !v.isEmpty {
                    return v
                }
            }
        }

        return nil
    }
}

// MARK: - Airtable Response
struct VideoRecordsResponse: Codable {
    let records: [VideoRecord]
    let offset: String?
}

// MARK: - Error Types
enum VideoError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
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
