//
//  SearchService.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/27/25.
//

import Foundation
import Combine

@MainActor
class SearchService: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let session = URLSession.shared
    private var searchTask: Task<Void, Never>?
    
    static let shared = SearchService()
    
    private init() {}
    
    // MARK: - Search Methods
    
    func searchContent(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            await performSearch(query: query)
        }
    }
    
    private func performSearch(query: String) async {
        isLoading = true
        errorMessage = nil
        searchResults = []
        
        // Search both Videos and MTvVideos tables in parallel like Apple TV
        async let videosResults = searchVideosTable(query: query)
        async let mtvVideosResults = searchMTVVideosTable(query: query)
        
        do {
            let (videos, mtvVideos) = try await (videosResults, mtvVideosResults)
            let allResults = videos + mtvVideos
            
            // Sort by relevance score and artist name
            let sortedResults = allResults.sorted { first, second in
                if first.relevanceScore != second.relevanceScore {
                    return first.relevanceScore > second.relevanceScore
                }
                return first.artistName.localizedCaseInsensitiveCompare(second.artistName) == .orderedAscending
            }
            
            searchResults = sortedResults
            
        } catch {
            // Don't show cancellation errors to user
            if (error as NSError).code != NSURLErrorCancelled {
                errorMessage = error.localizedDescription
                print("❌ Search error: \(error)")
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Search Individual Tables
    
    private func searchVideosTable(query: String) async throws -> [SearchResult] {
        let safeQuery = query.replacingOccurrences(of: "'", with: "\\'")
        
        // Don't search if query is effectively empty
        let trimmedQuery = safeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }
        
        let formula = "OR(" +
            "FIND(UPPER('\(safeQuery)'), UPPER({artistName}&\"\"))," +
            "FIND(UPPER('\(safeQuery)'), UPPER({Title}&\"\"))," +
            "FIND(UPPER('\(safeQuery)'), UPPER({Year}&\"\"))" +
        ")"
        
        guard var components = URLComponents(string: AirtableConfig.videosUrl) else {
            throw SearchError.invalidURL
        }
        
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "filterByFormula", value: formula))
        items.append(URLQueryItem(name: "pageSize", value: "100"))
        components.queryItems = items
        
        guard let url = components.url else {
            throw SearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, urlResponse) = try await session.data(for: request)
        
        // Check for HTTP errors
        if let httpResponse = urlResponse as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                // Try to decode error response
                if let errorData = try? JSONDecoder().decode(AirtableErrorResponse.self, from: data) {
                    throw SearchError.airtableError(errorData.error.message)
                } else {
                    throw SearchError.httpError(httpResponse.statusCode)
                }
            }
        }
        
        let decoder = JSONDecoder()
        
        // First check if the response has the expected structure
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              jsonObject["records"] != nil else {
            // Log the actual response for debugging
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("🔍 Unexpected API response: \(responseString)")
            throw SearchError.unexpectedResponse("Missing 'records' field in API response")
        }
        
        let apiResponse = try decoder.decode(VideosSearchResponse.self, from: data)
        
        return apiResponse.records.compactMap { record in
            convertVideoRecordToSearchResult(record: record, type: .video, query: safeQuery)
        }
    }
    
    private func searchMTVVideosTable(query: String) async throws -> [SearchResult] {
        let safeQuery = query.replacingOccurrences(of: "'", with: "\\'")
        
        // Don't search if query is effectively empty
        let trimmedQuery = safeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }
        
        let formula = "OR(" +
            "FIND(UPPER('\(safeQuery)'), UPPER({artistNames}&\"\"))," +
            "FIND(UPPER('\(safeQuery)'), UPPER({title}&\"\"))," +
            "FIND(UPPER('\(safeQuery)'), UPPER({year}&\"\"))" +
        ")"
        
        guard var components = URLComponents(string: AirtableConfig.playListUrl) else {
            throw SearchError.invalidURL
        }
        
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "filterByFormula", value: formula))
        items.append(URLQueryItem(name: "pageSize", value: "100"))
        components.queryItems = items
        
        guard let url = components.url else {
            throw SearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, urlResponse) = try await session.data(for: request)
        
        // Check for HTTP errors
        if let httpResponse = urlResponse as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                // Try to decode error response
                if let errorData = try? JSONDecoder().decode(AirtableErrorResponse.self, from: data) {
                    throw SearchError.airtableError(errorData.error.message)
                } else {
                    throw SearchError.httpError(httpResponse.statusCode)
                }
            }
        }
        
        let decoder = JSONDecoder()
        
        // First check if the response has the expected structure
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              jsonObject["records"] != nil else {
            // Log the actual response for debugging
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("🔍 Unexpected API response: \(responseString)")
            throw SearchError.unexpectedResponse("Missing 'records' field in API response")
        }
        
        let apiResponse = try decoder.decode(MTVVideosSearchResponse.self, from: data)
        
        return apiResponse.records.flatMap { record in
            convertMTVRecordToSearchResults(record: record, query: safeQuery)
        }
    }
    
    // MARK: - Conversion Methods
    
    private func convertVideoRecordToSearchResult(record: VideoRecord, type: SearchResultType, query: String) -> SearchResult? {
        guard let artistName = record.fields.artistName,
              let title = record.fields.title,
              let url = record.fields.url,
              let year = record.fields.year else {
            return nil
        }
        
        let matchType = determineMatchType(query: query, artistName: artistName, title: title)
        let relevanceScore = calculateRelevanceScore(matchType: matchType, query: query, artistName: artistName, title: title)
        
        // Extract YouTube video ID
        let videoId = extractYouTubeVideoID(from: url) ?? ""
        
        return SearchResult(
            id: record.id,
            videoId: videoId,
            title: title,
            artistName: artistName,
            year: year,
            url: url,
            videoImage: "", // Will be loaded from YouTube API
            type: type,
            matchType: matchType,
            relevanceScore: relevanceScore
        )
    }
    
    private func convertMTVRecordToSearchResults(record: MTVVideoRecord, query: String) -> [SearchResult] {
        var results: [SearchResult] = []
        
        let videoUrls = record.fields.videoUrls ?? []
        let videoTitles = record.fields.videoTitles ?? []
        let artistNames = record.fields.artistNames ?? []
        let mtvVideos = record.fields.mtvVideos ?? []
        
        let maxCount = max(videoUrls.count, videoTitles.count, artistNames.count)
        
        for i in 0..<maxCount {
            let videoUrl = i < videoUrls.count ? videoUrls[i] : ""
            let videoTitle = i < videoTitles.count ? videoTitles[i] : ""
            let artistName = i < artistNames.count ? artistNames[i] : ""
            let videoId = i < mtvVideos.count ? mtvVideos[i] : ""
            
            guard !videoUrl.isEmpty, !videoTitle.isEmpty, !artistName.isEmpty else { continue }
            
            let matchType = determineMatchType(query: query, artistName: artistName, title: videoTitle)
            let relevanceScore = calculateRelevanceScore(matchType: matchType, query: query, artistName: artistName, title: videoTitle)
            
            let searchResult = SearchResult(
                id: "\(record.id)_\(i)",
                videoId: videoId.isEmpty ? extractYouTubeVideoID(from: videoUrl) ?? "" : videoId,
                title: videoTitle,
                artistName: artistName,
                year: String(record.fields.year),
                url: videoUrl,
                videoImage: "",
                type: .mtvVideo,
                matchType: matchType,
                relevanceScore: relevanceScore
            )
            
            results.append(searchResult)
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    private func determineMatchType(query: String, artistName: String, title: String) -> SearchMatchType {
        let queryLower = query.lowercased()
        let artistLower = artistName.lowercased()
        let titleLower = title.lowercased()
        
        let artistMatch = artistLower.contains(queryLower)
        let titleMatch = titleLower.contains(queryLower)
        
        if artistMatch && titleMatch {
            return .both
        } else if artistMatch {
            return .artistName
        } else if titleMatch {
            return .songTitle
        } else {
            return .artistName // Default fallback
        }
    }
    
    private func calculateRelevanceScore(matchType: SearchMatchType, query: String, artistName: String, title: String) -> Int {
        let queryLower = query.lowercased()
        let artistLower = artistName.lowercased()
        let titleLower = title.lowercased()
        
        var score = 0
        
        // Artist name scoring
        if artistLower == queryLower {
            score += 95 // Exact artist match
        } else if artistLower.hasPrefix(queryLower) {
            score += 90 // Artist prefix match
        } else if artistLower.contains(queryLower) {
            score += 80 // General artist match
        }
        
        // Title scoring
        if titleLower == queryLower {
            score += 85 // Exact title match
        } else if titleLower.hasPrefix(queryLower) {
            score += 75 // Title prefix match
        } else if titleLower.contains(queryLower) {
            score += 60 // General title match
        }
        
        return score
    }
}

// MARK: - Search Models

struct SearchResult: Identifiable, Hashable {
    let id: String
    let videoId: String
    let title: String
    let artistName: String
    let year: String
    let url: String
    let videoImage: String
    let type: SearchResultType
    let matchType: SearchMatchType
    let relevanceScore: Int
}

enum SearchResultType: Hashable {
    case video
    case mtvVideo
}

enum SearchMatchType: Hashable {
    case artistName
    case songTitle
    case both
}

enum SearchError: Error, LocalizedError {
    case invalidURL
    case noResults
    case httpError(Int)
    case airtableError(String)
    case unexpectedResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .noResults:
            return "No search results found"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .airtableError(let message):
            return "Airtable error: \(message)"
        case .unexpectedResponse(let message):
            return "Unexpected response: \(message)"
        }
    }
}

// MARK: - API Response Models

struct VideosSearchResponse: Codable {
    let records: [VideoRecord]
}

struct VideoRecord: Codable {
    let id: String
    let fields: VideoFields
}

struct VideoFields: Codable {
    let artistName: String?
    let title: String?
    let year: String?
    let url: String?
    
    private enum CodingKeys: String, CodingKey {
        case artistName
        case title = "Title"
        case year = "Year"
        case url = "URL"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        year = try container.decodeIfPresent(String.self, forKey: .year)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        
        // Handle artistName as either String or [String]
        if let artistNameString = try? container.decodeIfPresent(String.self, forKey: .artistName) {
            artistName = artistNameString
        } else if let artistNameArray = try? container.decodeIfPresent([String].self, forKey: .artistName),
                  let firstArtist = artistNameArray.first {
            artistName = firstArtist
        } else {
            artistName = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(artistName, forKey: .artistName)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(url, forKey: .url)
    }
}

struct MTVVideosSearchResponse: Codable {
    let records: [MTVVideoRecord]
}

struct MTVVideoRecord: Codable {
    let id: String
    let fields: MTVVideoFields
}

struct MTVVideoFields: Codable {
    let year: Int
    let title: String
    let videoUrls: [String]?
    let artistNames: [String]?
    let videoTitles: [String]?
    let mtvVideos: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case year
        case title
        case videoUrls
        case artistNames
        case videoTitles
        case mtvVideos
    }
}

// MARK: - Airtable Error Response Models

struct AirtableErrorResponse: Codable {
    let error: AirtableError
}

struct AirtableError: Codable {
    let type: String
    let message: String
}