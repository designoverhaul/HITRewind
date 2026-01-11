//
//  VideoModel.swift
//  HIt Rewind2
//
//  Model for direct video records from MTvVideosNEW table
//  Created by Aaron Heine on 1/11/26.
//

import Foundation

// MARK: - Video Models for MTvVideosNEW Direct Records
struct DirectVideoRecord: Codable, Identifiable {
    let id: String
    var fields: DirectVideoFields
}

struct DirectVideoFields: Codable {
    let title: String?
    let artistName: String?
    let url: String?  // Optional because 4 videos don't have URLs
    let rank: Int?
    let year: String?  // Note: Year is stored as text in Airtable

    enum CodingKeys: String, CodingKey {
        case title
        case artistName
        case url
        case rank = "Rank"
        case year = "Year"
    }

    // Helper to get year as Int
    var yearInt: Int? {
        guard let year = year else { return nil }
        return Int(year)
    }

    // Helper to get YouTube video ID from URL
    var youtubeVideoId: String? {
        // Extract video ID from YouTube URL
        guard let urlString = url, let videoURL = URL(string: urlString) else { return nil }
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
struct DirectVideoRecordsResponse: Codable {
    let records: [DirectVideoRecord]
    let offset: String?
}

// MARK: - Error Types
enum DirectVideoError: Error, LocalizedError {
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
