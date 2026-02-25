//
//  AirtableService.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import Foundation
import Combine

@MainActor
class AirtableService: ObservableObject {
    /// Shared singleton instance - use this to preserve data across navigation
    static let shared = AirtableService()

    @Published var playlists: [Playlist] = []
    @Published var artists: [Playlist] = []
    @Published var categories: [FanCamCategory] = []
    @Published var artistVideoCounts: [String: Int] = [:]
    @Published var legendaryShows: [LegendaryShow] = []
    @Published var legendaryCategories: [LegendaryCategory] = []
    @Published var concerts: [Concert] = []
    @Published var concertVideos: [ConcertVideo] = []
    @Published var spotifyChartVideos: [SpotifyChartVideo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let session = URLSession.shared

    // MARK: - Caching Configuration
    private static let cacheDirectory: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("AirtableCache")
    }()

    private static let playlistsCacheFile = cacheDirectory.appendingPathComponent("playlists.json")
    private static let categoriesCacheFile = cacheDirectory.appendingPathComponent("categories.json")
    private static let concertsCacheFile = cacheDirectory.appendingPathComponent("concerts.json")
    private static let legendaryCategoriesCacheFile = cacheDirectory.appendingPathComponent("legendary_categories.json")
    private static let artistsCacheDirectory = cacheDirectory.appendingPathComponent("artists")
    private static let cacheMetadataFile = cacheDirectory.appendingPathComponent("cache_metadata.json")
    private static let cacheMaxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    // Airtable attachment URLs expire in ~2-4 hours, so use shorter cache for data with images
    private static let attachmentCacheMaxAge: TimeInterval = 1 * 60 * 60 // 1 hour

    private struct CacheMetadata: Codable {
        let lastUpdated: Date
        let version: Int

        static let currentVersion = 1
    }

    // MARK: - Request Deduplication
    private var inflightPlaylistsRequest: Task<Void, Never>?
    private var inflightCategoriesRequest: Task<Void, Never>?
    private var inflightConcertsRequest: Task<Void, Never>?
    private var inflightLegendaryCategoriesRequest: Task<Void, Never>?
    private var inflightArtistRequests: [String: Task<Playlist?, Error>] = [:]
    
    // MARK: - Artist Data Models (Apple TV compatible)
    private struct ArtistResponse: Codable { 
        let records: [ArtistRecord] 
    }
    
    private struct ArtistRecord: Codable { 
        let id: String
        let fields: ArtistRecordFields 
    }
    
    private struct ArtistRecordFields: Codable {
        let artistName: String?
        let videoURLs: [String]?
        let videoTitle: [String]?
        let videoYear: [String]?
        let videoThumbnail: [String]?
        let videoDuration: [String]?
        let youtubeChannelId: String?
        let youtubeChannelIcon: String?

        // Handle both possible field name variations from Airtable
        enum CodingKeys: String, CodingKey {
            case artistName = "artistName"
            case videoURLs = "VideoURLs"  // Match exact Airtable field name
            case videoTitle = "VideoTitle"  // Match exact Airtable field name
            case videoYear = "VideoYear"   // Match exact Airtable field name
            case videoThumbnail = "VideoThumbnail"  // Match exact Airtable field name
            case videoDuration = "VideoDuration"    // Match exact Airtable field name
            case youtubeChannelId = "youtubeChannelId"
            case youtubeChannelIcon = "youtubeChannelIcon"
        }
    }
    
    // MARK: - Fetch Playlists (Music Videos by Year)
    func fetchPlaylists() async {
        print("🔄 Starting fetchPlaylists...")
        isLoading = true
        errorMessage = nil

        // Try to load from cache first
        if let cachedPlaylists = loadPlaylistsFromCache() {
            print("✅ Loaded \(cachedPlaylists.count) playlists from cache")
            playlists = cachedPlaylists

            // Check if cache is stale and refresh in background
            if isCacheStale() {
                print("📦 Cache is stale, refreshing in background...")
                isLoading = false
                Task.detached { [weak self] in
                    await self?.refreshPlaylistsFromNetwork()
                }
            } else {
                print("📦 Cache is fresh, using cached data")
                isLoading = false
            }
            return
        }

        // No cache available, fetch from network
        print("📦 No cache found, fetching from network...")
        await refreshPlaylistsFromNetwork()
        isLoading = false
    }

    /// Force refresh playlists from network (bypasses cache)
    func forceRefreshPlaylists() async {
        print("🔄 Force refreshing playlists from network...")
        isLoading = true
        errorMessage = nil
        await refreshPlaylistsFromNetwork()
        isLoading = false
    }

    private func refreshPlaylistsFromNetwork() async {
        print("🔄 Fetching playlists from: \(AirtableConfig.playListUrl)")

        do {
            let result = try await performRequest(url: AirtableConfig.playListUrl)
            print("✅ Fetched \(result.count) playlists from Airtable")

            let sortedPlaylists = try await sortAndArrangePlaylists(result)
            print("✅ Processed and sorted \(sortedPlaylists.count) playlists")

            // Update on main actor
            await MainActor.run {
                self.playlists = sortedPlaylists
            }

            // Save to cache
            savePlaylistsToCache(sortedPlaylists)

            // Debug: Print first few playlists
            for (index, playlist) in sortedPlaylists.prefix(3).enumerated() {
                print("🎵 Playlist \(index): \(String(playlist.fields.year)) - \(playlist.fields.title) (\(playlist.fields.videoTitles?.count ?? 0) videos)")
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            print("❌ Error fetching playlists: \(error)")
        }
    }

    // MARK: - Cache Methods

    private func ensureCacheDirectoryExists() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: Self.cacheDirectory.path) {
            try? fileManager.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        }
    }

    private func loadPlaylistsFromCache() -> [Playlist]? {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: Self.playlistsCacheFile.path) else {
            print("📦 Cache file doesn't exist")
            return nil
        }

        do {
            let data = try Data(contentsOf: Self.playlistsCacheFile)
            let decoder = JSONDecoder()
            let playlists = try decoder.decode([Playlist].self, from: data)
            print("📦 Successfully loaded \(playlists.count) playlists from cache")
            return playlists
        } catch {
            print("📦 Failed to load cache: \(error)")
            return nil
        }
    }

    private func savePlaylistsToCache(_ playlists: [Playlist]) {
        ensureCacheDirectoryExists()

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(playlists)
            try data.write(to: Self.playlistsCacheFile)

            // Save metadata
            let metadata = CacheMetadata(lastUpdated: Date(), version: CacheMetadata.currentVersion)
            let metadataData = try encoder.encode(metadata)
            try metadataData.write(to: Self.cacheMetadataFile)

            print("📦 Successfully saved \(playlists.count) playlists to cache")
        } catch {
            print("📦 Failed to save cache: \(error)")
        }
    }

    private func isCacheStale() -> Bool {
        guard let metadata = loadCacheMetadata() else {
            return true
        }

        let age = Date().timeIntervalSince(metadata.lastUpdated)
        let isStale = age > Self.cacheMaxAge
        print("📦 Cache age: \(Int(age / 60)) minutes, stale: \(isStale)")
        return isStale
    }

    private func loadCacheMetadata() -> CacheMetadata? {
        guard FileManager.default.fileExists(atPath: Self.cacheMetadataFile.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: Self.cacheMetadataFile)
            return try JSONDecoder().decode(CacheMetadata.self, from: data)
        } catch {
            return nil
        }
    }

    /// Clear all cached data
    func clearCache() {
        try? FileManager.default.removeItem(at: Self.cacheDirectory)
        print("📦 Cache cleared")
    }

    /// Clear specific cache type
    func clearCache(for type: CacheType) {
        let cacheFile: URL
        switch type {
        case .playlists:
            cacheFile = Self.playlistsCacheFile
        case .categories:
            cacheFile = Self.categoriesCacheFile
        case .concerts:
            cacheFile = Self.concertsCacheFile
        case .legendaryCategories:
            cacheFile = Self.legendaryCategoriesCacheFile
        case .artists:
            try? FileManager.default.removeItem(at: Self.artistsCacheDirectory)
            print("📦 Artists cache cleared")
            return
        }

        try? FileManager.default.removeItem(at: cacheFile)
        let metadataFile = cacheFile.deletingPathExtension().appendingPathExtension("meta.json")
        try? FileManager.default.removeItem(at: metadataFile)
        print("📦 \(type) cache cleared")
    }

    enum CacheType {
        case playlists
        case categories
        case concerts
        case legendaryCategories
        case artists
    }

    // MARK: - Generic Cache Methods

    /// Generic method to load cached data of any Codable type
    /// - Parameters:
    ///   - cacheFile: The cache file URL
    ///   - typeName: Name for logging
    ///   - maxAge: Optional custom max age. Use attachmentCacheMaxAge for data with Airtable image URLs.
    private func loadFromCache<T: Codable>(_ cacheFile: URL, typeName: String, maxAge: TimeInterval? = nil) -> T? {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: cacheFile.path) else {
            print("📦 \(typeName) cache file doesn't exist")
            return nil
        }

        // Check if cache is stale
        if isCacheStale(for: cacheFile, maxAge: maxAge) {
            print("📦 \(typeName) cache is stale")
            return nil
        }

        do {
            let data = try Data(contentsOf: cacheFile)
            let decoder = JSONDecoder()
            let result = try decoder.decode(T.self, from: data)
            print("📦 Successfully loaded \(typeName) from cache")
            return result
        } catch {
            print("📦 Failed to load \(typeName) cache: \(error)")
            return nil
        }
    }

    /// Generic method to save data to cache
    private func saveToCache<T: Codable>(_ data: T, cacheFile: URL, typeName: String) {
        ensureCacheDirectoryExists()

        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: cacheFile)

            // Save metadata with current timestamp
            let metadataFile = cacheFile.deletingPathExtension().appendingPathExtension("meta.json")
            let metadata = CacheMetadata(lastUpdated: Date(), version: CacheMetadata.currentVersion)
            let metadataData = try encoder.encode(metadata)
            try metadataData.write(to: metadataFile)

            print("📦 Successfully saved \(typeName) to cache")
        } catch {
            print("📦 Failed to save \(typeName) cache: \(error)")
        }
    }

    /// Check if specific cache file is stale
    /// - Parameters:
    ///   - cacheFile: The cache file URL to check
    ///   - maxAge: Optional custom max age (defaults to cacheMaxAge). Use attachmentCacheMaxAge for data with Airtable image URLs.
    private func isCacheStale(for cacheFile: URL, maxAge: TimeInterval? = nil) -> Bool {
        let metadataFile = cacheFile.deletingPathExtension().appendingPathExtension("meta.json")
        let effectiveMaxAge = maxAge ?? Self.cacheMaxAge

        guard FileManager.default.fileExists(atPath: metadataFile.path) else {
            return true
        }

        do {
            let data = try Data(contentsOf: metadataFile)
            let metadata = try JSONDecoder().decode(CacheMetadata.self, from: data)
            let age = Date().timeIntervalSince(metadata.lastUpdated)
            let isStale = age > effectiveMaxAge
            print("📦 Cache age: \(Int(age / 3600)) hours, stale: \(isStale)")
            return isStale
        } catch {
            return true
        }
    }
    
    // MARK: - Fetch Artists (Live Shows/Fan Cams)
    func fetchArtists() async {
        // Deprecated in favor of lazy per-artist fetch. Kept for manual refresh scenarios.
        print("ℹ️ fetchArtists() is deprecated; using lazy per-artist loading instead.")
    }

    // MARK: - Artists table → map to Playlist model
    private func fetchArtistsFromArtistsTable() async throws -> [Playlist] {
        struct AirtableArtistResponse: Decodable { let records: [AirtableArtistRecord]; let offset: String? }
        struct AirtableArtistRecord: Decodable { let id: String; let fields: AirtableArtistFields }
        struct AirtableArtistFields: Codable {
            let artistName: String?
            let VideoURLs: [String]?
            let VideoTitle: [String]?
            let VideoYear: [Int]?
            let videoThumbnail: [AirtableAttachment]? // assume first as thumbnail
            let PremiumArtist: Bool?
            
            enum CodingKeys: String, CodingKey {
                case artistName
                case VideoURLs
                case VideoTitle
                case VideoYear
                case videoThumbnail
                case PremiumArtist
            }
        }
        
        func makeArtistsPageURL(offset: String?) throws -> URL {
            guard var components = URLComponents(string: AirtableConfig.artistsUrl) else { throw PlaylistError.invalidURL }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "pageSize", value: "100"))
            if let offset = offset { items.append(URLQueryItem(name: "offset", value: offset)) }
            components.queryItems = items
            guard let final = components.url else { throw PlaylistError.invalidURL }
            return final
        }
        
        var accumulated: [AirtableArtistRecord] = []
        var nextOffset: String? = nil
        let decoder = JSONDecoder()
        repeat {
            let requestURL = try makeArtistsPageURL(offset: nextOffset)
            var request = URLRequest(url: requestURL)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await session.data(for: request)
            if let json = String(data: data, encoding: .utf8) { print("📡 Raw Artists Response (page): \(String(json.prefix(300)))…") }
            let resp = try decoder.decode(AirtableArtistResponse.self, from: data)
            accumulated.append(contentsOf: resp.records)
            nextOffset = resp.offset
        } while nextOffset != nil
        
        // Map to Playlist
        var playlists: [Playlist] = []
        for record in accumulated {
            let f = record.fields
            let name = f.artistName ?? "Unknown Artist"
            let urls = f.VideoURLs ?? []
            let titles = f.VideoTitle ?? []
            let years = f.VideoYear ?? []
            let mostRecentYear = years.max() ?? 0
            let isVisible: [Bool?] = Array(repeating: true, count: max(urls.count, titles.count))
            let artistNames: [String] = Array(repeating: name, count: max(urls.count, titles.count))
            let thumbUrl = f.videoThumbnail?.first?.url ?? URL(string: "https://via.placeholder.com/300x200")!
            let fields = PlaylistFields(
                thumbnail: thumbUrl,
                year: mostRecentYear,
                title: name,
                mtvVideos: nil,
                videoUrls: urls,
                artistNames: artistNames,
                videoTitles: titles,
                videoYears: years.map { String($0) },
                isVisible: isVisible,
                isLocked: false,
                isPlaylist: false
            )
            playlists.append(Playlist(id: record.id, fields: fields))
        }
        return playlists.sorted { $0.fields.title.localizedCaseInsensitiveCompare($1.fields.title) == .orderedAscending }
    }

    // MARK: - Fetch single artist by name (lazy load videos)
    // Fixed to match Apple TV implementation: extract video data directly from Artists table
    func fetchArtist(byName name: String) async throws -> Playlist? {
        print("🎯 fetchArtist(byName:) start for: \(name)")

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for inflight request (deduplication)
        if let existingTask = inflightArtistRequests[normalizedName] {
            print("⏳ Artist request for '\(normalizedName)' already in progress, waiting...")
            return try await existingTask.value
        }

        // Try to load from cache first
        let artistCacheFile = Self.artistsCacheDirectory.appendingPathComponent("\(normalizedName.replacingOccurrences(of: "/", with: "_")).json")
        if let cachedPlaylist: Playlist = loadFromCache(artistCacheFile, typeName: "Artist[\(normalizedName)]") {
            print("✅ Loaded artist '\(normalizedName)' from cache")
            return cachedPlaylist
        }

        // Create new request task
        let task = Task<Playlist?, Error> {
            return try await fetchArtistFromNetwork(name: normalizedName, cacheFile: artistCacheFile)
        }
        inflightArtistRequests[normalizedName] = task

        defer {
            inflightArtistRequests.removeValue(forKey: normalizedName)
        }

        return try await task.value
    }

    private func fetchArtistFromNetwork(name: String, cacheFile: URL) async throws -> Playlist? {
        print("🎯 Finding artist in Artists table and extracting embedded video data...")

        // Build request to Artists table with filter
        guard var components = URLComponents(string: AirtableConfig.artistsUrl) else { throw PlaylistError.invalidURL }
        var items = components.queryItems ?? []
        let escaped = name.replacingOccurrences(of: "\"", with: "\\\"")
        items.append(URLQueryItem(name: "filterByFormula", value: "{artistName} = '\(escaped)'"))
        items.append(URLQueryItem(name: "pageSize", value: "1"))

        // Limit fields to reduce payload size
        items.append(URLQueryItem(name: "fields[]", value: "artistName"))
        items.append(URLQueryItem(name: "fields[]", value: "VideoURLs"))
        items.append(URLQueryItem(name: "fields[]", value: "VideoTitle"))
        items.append(URLQueryItem(name: "fields[]", value: "VideoYear"))
        items.append(URLQueryItem(name: "fields[]", value: "youtubeChannelId"))
        items.append(URLQueryItem(name: "fields[]", value: "youtubeChannelIcon"))

        components.queryItems = items
        guard let url = components.url else { throw PlaylistError.invalidURL }

        print("🔍 API URL: \(url.absoluteString)")
        print("🔍 Filter formula: {artistName} = '\(escaped)'")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)

        // Debug raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📡 Raw Artists API Response: \(String(jsonString.prefix(500)))...")
        }

        let decoder = JSONDecoder()
        let artistResponse = try decoder.decode(ArtistResponse.self, from: data)

        guard let artistRecord = artistResponse.records.first else {
            print("🚫 Artist not found in Artists table: \(name)")
            return nil
        }

        print("✅ Found artist: \(artistRecord.fields.artistName ?? "Unknown")")
        print("🎬 Artist has \(artistRecord.fields.videoURLs?.count ?? 0) videos")

        // Convert the artist's embedded video data to Playlist format (matching Apple TV logic)
        if let playlist = convertArtistToPlaylist(artistRecord: artistRecord, requestedName: name) {
            // Save to cache
            ensureCacheDirectoryExists()
            try? FileManager.default.createDirectory(at: Self.artistsCacheDirectory, withIntermediateDirectories: true)
            saveToCache(playlist, cacheFile: cacheFile, typeName: "Artist[\(name)]")
            return playlist
        }

        return nil
    }
    
    // MARK: - Helper function to convert artist data to playlist (Apple TV implementation)
    private func convertArtistToPlaylist(artistRecord: ArtistRecord, requestedName: String) -> Playlist? {
        let fields = artistRecord.fields
        
        // DEBUG: Print all available fields in the API response
        print("🔍 DEBUG: Raw artistRecord.fields for \(requestedName):")
        print("  - artistName: \(fields.artistName ?? "nil")")
        print("  - videoURLs count: \(fields.videoURLs?.count ?? 0)")
        print("  - videoTitle count: \(fields.videoTitle?.count ?? 0)")
        print("  - videoYear count: \(fields.videoYear?.count ?? 0)")
        
        if let urls = fields.videoURLs {
            print("  - videoURLs sample: \(urls.prefix(2))")
        }
        if let titles = fields.videoTitle {
            print("  - videoTitle sample: \(titles.prefix(2))")
        }
        if let years = fields.videoYear {
            print("  - videoYear sample: \(years.prefix(2))")
        }
        
        guard let videoURLs = fields.videoURLs,
              let videoTitles = fields.videoTitle,
              let videoYears = fields.videoYear,
              !videoURLs.isEmpty else {
            print("🚫 Artist \(requestedName) has 0 videos - missing required fields")
            return nil
        }
        
        let artistName = fields.artistName ?? requestedName
        print("🎵 Processing \(videoURLs.count) videos for \(artistName)")
        
        // Create parallel arrays for the Playlist format
        let videoIds = videoURLs.compactMap { extractYouTubeVideoID(from: $0) }
        let artistNames = Array(repeating: artistName, count: videoURLs.count)
        let isVisible = Array(repeating: true, count: videoURLs.count) // Default all to visible
        
        // Find most recent year
        let years = videoYears.compactMap { Int($0) }
        let mostRecentYear = years.max() ?? 2020
        
        // Build the PlaylistFields exactly like Apple TV version
        let playlistFields = PlaylistFields(
            thumbnail: URL(string: "https://via.placeholder.com/300x200")!, // Placeholder thumbnail
            year: mostRecentYear,
            title: artistName,
            mtvVideos: videoIds,
            videoUrls: videoURLs,
            artistNames: artistNames,
            videoTitles: videoTitles,
            videoYears: videoYears,
            isVisible: isVisible,
            isLocked: false,
            isPlaylist: false,
            youtubeChannelId: fields.youtubeChannelId,
            youtubeChannelIcon: fields.youtubeChannelIcon
        )
        
        print("✅ Created playlist for \(artistName): \(videoURLs.count) videos, recent year \(String(mostRecentYear))")
        return Playlist(id: artistRecord.id, fields: playlistFields)
    }

    // Try LiveShows table: records include videoUrls/videoTitles/isVisible
    private func fetchArtistFromLiveShows(byName name: String) async throws -> Playlist? {
        struct AirtableListResponse<Record: Codable>: Codable { let records: [Record]; let offset: String? }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
        guard var components = URLComponents(string: AirtableConfig.liveShowsUrl) else { throw PlaylistError.invalidURL }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "filterByFormula", value: "LOWER({artist})=LOWER(\"\(escaped)\")"))
        items.append(URLQueryItem(name: "pageSize", value: "1"))
        components.queryItems = items
        guard let url = components.url else { throw PlaylistError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        if let json = String(data: data, encoding: .utf8) { print("📡 Raw LiveShows Single Artist Response: \(String(json.prefix(500)))…") }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let resp = try decoder.decode(AirtableListResponse<Playlist>.self, from: data)
        let rec = resp.records.first
        if let rec = rec {
            print("✅ LiveShows returned record for \(name) with \(rec.fields.videoUrls?.count ?? 0) urls")
        } else {
            print("⚠️ LiveShows returned no record for \(name)")
        }
        return rec
    }

    // Query Videos table by Artist record ID
    private func fetchVideosByArtistRecordId(artistRecordId: String, artistName: String) async throws -> (urls: [String], titles: [String], mostRecentYear: Int) {
        struct Resp: Codable { let records: [Rec]; let offset: String? }
        struct Rec: Codable { let fields: F }
        struct F: Codable { 
            let artistNumber: [String]? // linked record IDs 
            let URL: String?; 
            let Title: String?; 
            let Year: String? 
            
            enum CodingKeys: String, CodingKey {
                case artistNumber = "Artist Number"
                case URL = "URL"
                case Title = "Title" 
                case Year = "Year"
            }
        }
        
        var urls: [String] = []
        var titles: [String] = []
        var years: [Int] = []
        var nextOffset: String? = nil
        let decoder = JSONDecoder()
        
        repeat {
            guard var components = URLComponents(string: AirtableConfig.videosUrl) else { break }
            var items = components.queryItems ?? []
            // Query for videos where Artist Number contains the artist record ID we need to find
            let formula = "FIND('\(artistRecordId)', ARRAYJOIN({Artist Number}))"
            items.append(URLQueryItem(name: "filterByFormula", value: formula))
            items.append(URLQueryItem(name: "pageSize", value: "100"))
            if let nextOffset { items.append(URLQueryItem(name: "offset", value: nextOffset)) }
            components.queryItems = items
            guard let url = components.url else { break }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await session.data(for: request)
            if let json = String(data: data, encoding: .utf8) { 
                print("📡 Raw Videos by Artist ID Response: \(String(json.prefix(300)))…") 
            }
            let r = try decoder.decode(Resp.self, from: data)
            for rec in r.records {
                if let u = rec.fields.URL { urls.append(u) }
                if let t = rec.fields.Title { titles.append(t) }
                if let y = rec.fields.Year, let yi = Int(y) { years.append(yi) }
            }
            nextOffset = r.offset
        } while nextOffset != nil
        
        print("✅ Videos by artist ID aggregated: urls=\(urls.count), titles=\(titles.count) for \(artistName)")
        return (urls, titles, years.max() ?? 0)
    }

    // Fallback: query the Videos table for an artist's URLs/titles/years
    private func fetchArtistVideosFromVideosTable(artistName: String) async throws -> (urls: [String], titles: [String], mostRecentYear: Int) {
        struct Resp: Codable { let records: [Rec]; let offset: String? }
        struct Rec: Codable { let fields: F }
        struct F: Codable { 
            let artistName: String?
            let artistNumber: [String]? // linked record IDs 
            let URL: String?; 
            let Title: String?; 
            let Year: String? 
            
            enum CodingKeys: String, CodingKey {
                case artistName
                case artistNumber = "Artist Number"
                case URL = "URL"
                case Title = "Title" 
                case Year = "Year"
            }
        }
        let trimmed = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
        var urls: [String] = []
        var titles: [String] = []
        var years: [Int] = []
        var nextOffset: String? = nil
        let decoder = JSONDecoder()
        repeat {
            guard var components = URLComponents(string: AirtableConfig.videosUrl) else { break }
            var items = components.queryItems ?? []
            let equality = "LOWER({artistName})=LOWER(\"\(escaped)\")"
            let contains = "FIND(LOWER(\"\(escaped)\"), LOWER({artistName}))"
            items.append(URLQueryItem(name: "filterByFormula", value: "OR(\(equality), \(contains))"))
            items.append(URLQueryItem(name: "pageSize", value: "100"))
            if let nextOffset { items.append(URLQueryItem(name: "offset", value: nextOffset)) }
            components.queryItems = items
            guard let url = components.url else { break }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await session.data(for: request)
            if let json = String(data: data, encoding: .utf8) { print("📡 Raw Videos Response (chunk): \(String(json.prefix(300)))…") }
            let r = try decoder.decode(Resp.self, from: data)
            for rec in r.records {
                if let u = rec.fields.URL { urls.append(u) }
                if let t = rec.fields.Title { titles.append(t) }
                if let y = rec.fields.Year, let yi = Int(y) { years.append(yi) }
            }
            nextOffset = r.offset
        } while nextOffset != nil
        print("✅ Videos fallback aggregated: urls=\(urls.count), titles=\(titles.count), mostRecentYear=\(String(years.max() ?? 0)) for artist=\(artistName)")
        return (urls, titles, years.max() ?? 0)
    }

    // Fetch Videos by linked record IDs
    private func fetchVideosByRecordIds(recordIds: [String]) async throws -> (urls: [String], titles: [String], mostRecentYear: Int) {
        struct Resp: Codable { let records: [Rec]; let offset: String? }
        struct Rec: Codable { let fields: F }
        struct F: Codable { let URL: String?; let Title: String?; let Year: String? }
        var urls: [String] = []
        var titles: [String] = []
        var years: [Int] = []
        let chunkSize = 10
        let chunks: [[String]] = stride(from: 0, to: recordIds.count, by: chunkSize).map { Array(recordIds[$0..<min($0 + chunkSize, recordIds.count)]) }
        let decoder = JSONDecoder()
        for chunk in chunks {
            var nextOffset: String? = nil
            repeat {
                guard var components = URLComponents(string: AirtableConfig.videosUrl) else { break }
                var items = components.queryItems ?? []
                let ors = chunk.map { "RECORD_ID()='\($0)'" }.joined(separator: ",")
                items.append(URLQueryItem(name: "filterByFormula", value: "OR(\(ors))"))
                items.append(URLQueryItem(name: "pageSize", value: "100"))
                if let nextOffset { items.append(URLQueryItem(name: "offset", value: nextOffset)) }
                items.append(URLQueryItem(name: "fields[]", value: "URL"))
                items.append(URLQueryItem(name: "fields[]", value: "Title"))
                items.append(URLQueryItem(name: "fields[]", value: "Year"))
                components.queryItems = items
                guard let url = components.url else { break }
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
                let (data, _) = try await session.data(for: request)
                let r = try decoder.decode(Resp.self, from: data)
                for rec in r.records {
                    if let u = rec.fields.URL { urls.append(u) }
                    if let t = rec.fields.Title { titles.append(t) }
                    if let y = rec.fields.Year, let yi = Int(y) { years.append(yi) }
                }
                nextOffset = r.offset
            } while nextOffset != nil
        }
        return (urls, titles, years.max() ?? 0)
    }
    
    // MARK: - Fetch only counts for a list of artist names (for list UI)
    func fetchVideoCounts(for artistNames: [String]) async {
        let names = artistNames.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !names.isEmpty else { return }
        
        // Split into chunks to avoid overly long URLs
        let chunkSize = 10
        let chunks: [[String]] = stride(from: 0, to: names.count, by: chunkSize).map {
            Array(names[$0..<min($0 + chunkSize, names.count)])
        }
        var counts: [String: Int] = [:]
        
        struct Resp: Codable { let records: [Rec]; let offset: String? }
        struct Rec: Codable { let fields: F }
        struct F: Codable {
            let artistName: String?
            let VideoURLs: [String]?
            let Videos: [String]? // linked records fallback
        }
        
        let decoder = JSONDecoder()
        
        for chunk in chunks {
            var nextOffset: String? = nil
            repeat {
                guard var components = URLComponents(string: AirtableConfig.artistsUrl) else { break }
                var items = components.queryItems ?? []
                // fields selection to minimize payload
                items.append(URLQueryItem(name: "fields[]", value: "artistName"))
                items.append(URLQueryItem(name: "fields[]", value: "VideoURLs"))
                items.append(URLQueryItem(name: "fields[]", value: "Videos"))
                
                // Build OR filter for this chunk
                let orParts = chunk.map { name in
                    let escaped = name.replacingOccurrences(of: "\"", with: "\\\"")
                    return "LOWER({artistName})=LOWER(\"\(escaped)\")"
                }
                let formula = orParts.count == 1 ? orParts[0] : "OR(\(orParts.joined(separator: ",")))"
                items.append(URLQueryItem(name: "filterByFormula", value: formula))
                items.append(URLQueryItem(name: "pageSize", value: "100"))
                if let nextOffset { items.append(URLQueryItem(name: "offset", value: nextOffset)) }
                components.queryItems = items
                guard let url = components.url else { break }
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
                do {
                    let (data, _) = try await session.data(for: request)
                    let r = try decoder.decode(Resp.self, from: data)
                    for rec in r.records {
                        let n = rec.fields.artistName ?? ""
                        let count = (rec.fields.VideoURLs?.count ?? 0)
                        let fallback = rec.fields.Videos?.count ?? 0
                        if !n.isEmpty {
                            counts[n] = max(count, fallback)
                        }
                    }
                    nextOffset = r.offset
                } catch {
                    nextOffset = nil
                }
            } while nextOffset != nil
        }
        artistVideoCounts = counts
    }
    
    // MARK: - Fetch Categories (Fan Cam Categories with Images)
    func fetchCategories() async {
        print("🔄 Starting fetchCategories...")

        // Check for inflight request (deduplication)
        if let existingTask = inflightCategoriesRequest {
            print("⏳ Categories request already in progress, waiting...")
            await existingTask.value
            return
        }

        // Try to load from cache first
        if let cachedCategories: [FanCamCategory] = loadFromCache(Self.categoriesCacheFile, typeName: "Categories") {
            print("✅ Loaded \(cachedCategories.count) categories from cache")
            categories = cachedCategories
            return
        }

        // Create new request task
        let task = Task<Void, Never> {
            await refreshCategoriesFromNetwork()
        }
        inflightCategoriesRequest = task

        isLoading = true
        errorMessage = nil
        await task.value
        inflightCategoriesRequest = nil
        isLoading = false
    }

    /// Force refresh categories from network (bypasses cache)
    func forceRefreshCategories() async {
        print("🔄 Force refreshing categories from network...")
        isLoading = true
        errorMessage = nil
        await refreshCategoriesFromNetwork()
        isLoading = false
    }

    private func refreshCategoriesFromNetwork() async {
        print("🔄 Fetching categories from: \(AirtableConfig.categoriesUrl)")

        do {
            let result = try await performCategoriesRequest(url: AirtableConfig.categoriesUrl)
            print("✅ Fetched \(result.count) categories from Airtable")

            let sortedCategories = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            // Update on main actor
            await MainActor.run {
                self.categories = sortedCategories
            }

            // Save to cache
            saveToCache(sortedCategories, cacheFile: Self.categoriesCacheFile, typeName: "Categories")

            // Debug: Print first few categories
            for (index, category) in sortedCategories.prefix(3).enumerated() {
                print("🎵 Category \(index): \(category.name) - Image: \(category.imageUrl?.absoluteString ?? "No image")")
            }

        } catch {
            print("❌ Error fetching categories: \(error)")
            print("🔄 Falling back to mock data for demonstration")

            await MainActor.run {
                // Fallback to mock data for demonstration
                self.categories = createMockCategoryData()
                self.errorMessage = nil // Clear error since we have fallback data
            }
        }
    }
    
    // MARK: - Mock Data for Development/Demo
    private func createMockCategoryData() -> [FanCamCategory] {
        return [
            FanCamCategory(name: "Pop", description: "Pop music and artists", imageUrl: nil, artists: [
                "Adele", "Ariana Grande", "Backstreet Boys", "Billie Eilish", "Taylor Swift", "Lady Gaga", "Ed Sheeran", "Post Malone", "The Weeknd"
            ]),
            FanCamCategory(name: "Modern Rock", description: "Modern rock and alternative", imageUrl: nil, artists: [
                "Coldplay", "Foo Fighters", "Green Day", "Imagine Dragons", "Twenty One Pilots", "Red Hot Chili Peppers", "Vampire Weekend"
            ]),
            FanCamCategory(name: "Classic Rock", description: "Classic rock legends", imageUrl: nil, artists: [
                "U2", "Red Hot Chili Peppers", "Foo Fighters", "Green Day"
            ]),
            FanCamCategory(name: "Jam Bands", description: "Jam bands and psychedelic rock", imageUrl: nil, artists: [
                "Red Hot Chili Peppers", "Vampire Weekend"
            ]),
            FanCamCategory(name: "Hip Hop", description: "Hip hop and rap music", imageUrl: nil, artists: [
                "Drake", "Kendrick Lamar", "Post Malone"
            ]),
            FanCamCategory(name: "Country", description: "Country and americana", imageUrl: nil, artists: [
                "Luke Combs"  // This matches what you mentioned seeing
            ]),
            FanCamCategory(name: "Electronic", description: "Electronic and EDM", imageUrl: nil, artists: [
                "The Weeknd", "Imagine Dragons"
            ])
        ]
    }
    
    private func createMockArtistData() -> [Playlist] {
        let mockArtists = [
            "Adele", "Ariana Grande", "Backstreet Boys", "Billie Eilish", "Coldplay",
            "Drake", "Ed Sheeran", "Foo Fighters", "Green Day", "Imagine Dragons",
            "Kendrick Lamar", "Lady Gaga", "Luke Combs", "Maroon 5", "Post Malone", "Red Hot Chili Peppers",
            "Taylor Swift", "The Weeknd", "Twenty One Pilots", "U2", "Vampire Weekend"
        ]
        
        return mockArtists.map { artistName in
            Playlist(
                id: UUID().uuidString,
                fields: PlaylistFields(
                    thumbnail: URL(string: "https://via.placeholder.com/300x200")!,
                    year: 2023,
                    title: artistName,
                    videoUrls: [
                        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                        "https://www.youtube.com/watch?v=kJQP7kiw5Fk",
                        "https://www.youtube.com/watch?v=fJ9rUzIMcZQ"
                    ],
                    artistNames: [artistName, artistName, artistName],
                    videoTitles: [
                        "\(artistName) - Live at Madison Square Garden",
                        "\(artistName) - Acoustic Session",
                        "\(artistName) - Festival Performance"
                    ],
                    videoYears: ["2023", "2022", "2024"],
                    isVisible: [true, true, true]
                )
            )
        }
    }
    
    // MARK: - Private Helper Methods
    private func performRequest(url: String) async throws -> [Playlist] {
        struct AirtableListResponse<Record: Codable>: Codable {
            let records: [Record]
            let offset: String?
        }
        
        func makePageURL(offset: String?) throws -> URL {
            guard var components = URLComponents(string: url) else { throw PlaylistError.invalidURL }
            var items = components.queryItems ?? []
            // Ensure consistent page size to reduce number of requests
            if !items.contains(where: { $0.name == "pageSize" }) {
                items.append(URLQueryItem(name: "pageSize", value: "100"))
            }
            if let offset = offset {
                // Replace existing offset if present
                items.removeAll { $0.name == "offset" }
                items.append(URLQueryItem(name: "offset", value: offset))
            }
            components.queryItems = items
            guard let finalURL = components.url else { throw PlaylistError.invalidURL }
            return finalURL
        }
        
        var accumulated: [Playlist] = []
        var nextOffset: String? = nil
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        repeat {
            let requestUrl = try makePageURL(offset: nextOffset)
            var request = URLRequest(url: requestUrl)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await session.data(for: request)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 Raw API Response (page): \(String(jsonString.prefix(300)))...")
            }
            let response = try decoder.decode(AirtableListResponse<Playlist>.self, from: data)
            accumulated.append(contentsOf: response.records)
            nextOffset = response.offset
        } while nextOffset != nil
        
        // Handle nullable isLocked values
        for i in 0..<accumulated.count {
            accumulated[i].fields.isLocked = accumulated[i].fields.isLocked ?? false
        }
        
        return accumulated
    }
    
    private func sortAndArrangePlaylists(_ playlists: [Playlist]) async throws -> [Playlist] {
        var sortedPlaylists = playlists.sorted { $0.fields.year > $1.fields.year }
        
        // Process each playlist to sort video titles and rearrange data
        for playlistIndex in 0..<sortedPlaylists.count {
            if let videoTitles = sortedPlaylists[playlistIndex].fields.videoTitles {
                // Custom sorting closure
                let sortedVideoTitles = videoTitles.sorted { (title1, title2) -> Bool in
                    let isTitle1Alphabet = title1.first?.isLetter ?? false
                    let isTitle2Alphabet = title2.first?.isLetter ?? false
                    
                    if isTitle1Alphabet && !isTitle2Alphabet {
                        return true
                    } else if !isTitle1Alphabet && isTitle2Alphabet {
                        return false
                    } else {
                        return title1 < title2
                    }
                }
                
                // Get sorted indices
                let sortedIndices = sortedVideoTitles.compactMap { videoTitle in
                    return videoTitles.firstIndex(of: videoTitle)
                }
                
                guard sortedIndices.count == videoTitles.count else {
                    throw PlaylistError.sortingError("Mismatch in sorted indices count")
                }
                
                // Update playlist fields with sorted data
                sortedPlaylists[playlistIndex].fields.videoTitles = sortedVideoTitles
                
                // mtvVideos not needed here; we rebuild from URLs below
                let videoUrls = sortedPlaylists[playlistIndex].fields.videoUrls ?? []
                let artistNames = sortedPlaylists[playlistIndex].fields.artistNames ?? []
                let isVisible = sortedPlaylists[playlistIndex].fields.isVisible
                
                // Extract YouTube video IDs
                let extractedVideoIds = videoUrls.map { url in
                    return extractYouTubeVideoID(from: url) ?? ""
                }
                
                // Update with sorted data
                sortedPlaylists[playlistIndex].fields.mtvVideos = sortedIndices.map { extractedVideoIds.indices.contains($0) ? extractedVideoIds[$0] : "" }
                sortedPlaylists[playlistIndex].fields.videoUrls = sortedIndices.map { videoUrls.indices.contains($0) ? videoUrls[$0] : "" }
                sortedPlaylists[playlistIndex].fields.artistNames = sortedIndices.map { artistNames.indices.contains($0) ? artistNames[$0] : "" }
                sortedPlaylists[playlistIndex].fields.isVisible = sortedIndices.map { isVisible.indices.contains($0) ? isVisible[$0] ?? false : false }
            }
        }
        
        return sortedPlaylists
    }
    
    private func performCategoriesRequest(url: String) async throws -> [FanCamCategory] {
        struct AirtableListResponse<Record: Codable>: Codable {
            let records: [Record]
            let offset: String?
        }

        func makeCategoriesPageURL(offset: String?) throws -> URL {
            guard var components = URLComponents(string: url) else { throw PlaylistError.invalidURL }
            var items = components.queryItems ?? []
            if !items.contains(where: { $0.name == "pageSize" }) {
                items.append(URLQueryItem(name: "pageSize", value: "100"))
            }
            // Limit fields to reduce payload size - only request fields that exist
            items.append(URLQueryItem(name: "fields[]", value: "CategoryName"))
            items.append(URLQueryItem(name: "fields[]", value: "CategoryImage"))
            items.append(URLQueryItem(name: "fields[]", value: "ArtistNames"))
            // Note: "description" field doesn't exist in Airtable, omitting
            if let offset = offset {
                items.removeAll { $0.name == "offset" }
                items.append(URLQueryItem(name: "offset", value: offset))
            }
            components.queryItems = items
            guard let finalURL = components.url else { throw PlaylistError.invalidURL }
            return finalURL
        }
        
        var accumulated: [AirtableCategoryRecord] = []
        var nextOffset: String? = nil
        let decoder = JSONDecoder()
        
        repeat {
            let requestUrl = try makeCategoriesPageURL(offset: nextOffset)
            var request = URLRequest(url: requestUrl)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await session.data(for: request)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 Raw Categories Response (page): \(String(jsonString.prefix(300)))...")
            }
            let response = try decoder.decode(AirtableListResponse<AirtableCategoryRecord>.self, from: data)
            accumulated.append(contentsOf: response.records)
            nextOffset = response.offset
        } while nextOffset != nil
        
        return accumulated.map { record in
            FanCamCategory(
                id: record.id,
                name: record.fields.categoryName,
                description: record.fields.description ?? "",
                imageUrl: record.fields.categoryImage?.first?.url,
                color: .purple,
                artists: record.fields.artistNames ?? []
            )
        }
    }

    // MARK: - LegendaryShows fallback → Build artists by grouping per-URL rows
    private func fetchArtistsFromLegendaryShows() async throws -> [Playlist] {
        guard let url = URL(string: AirtableConfig.legendaryShowsUrl) else {
            throw PlaylistError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        if let json = String(data: data, encoding: .utf8) {
            print("📡 Raw LegendaryShows Response: \(String(json.prefix(500)))…")
        }
        let decoder = JSONDecoder()
        let response = try decoder.decode(AirtableLegendaryResponse.self, from: data)
        let records = response.records
        // Group by artist
        let grouped = Dictionary(grouping: records) { rec in
            rec.fields.artist?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        }
        var built: [Playlist] = []
        for (_, group) in grouped {
            guard let any = group.first else { continue }
            let artistName = any.fields.artist ?? "Unknown Artist"
            let urls: [String] = group.compactMap { $0.fields.url }
            let titles: [String] = group.compactMap { $0.fields.title }
            let years: [Int] = group.compactMap { Int($0.fields.year ?? "") }
            let mostRecentYear = years.max() ?? 0
            let isVisible: [Bool?] = Array(repeating: true, count: urls.count)
            let artistNames: [String] = Array(repeating: artistName, count: urls.count)
            // Build minimal Playlist compatible object
            if let placeholder = URL(string: "https://via.placeholder.com/300x200") {
                let fields = PlaylistFields(
                    thumbnail: placeholder,
                    year: mostRecentYear,
                    title: artistName,
                    mtvVideos: nil,
                    videoUrls: urls,
                    artistNames: artistNames,
                    videoTitles: titles,
                    videoYears: years.map { String($0) },
                    isVisible: isVisible,
                    isLocked: false,
                    isPlaylist: false
                )
                built.append(Playlist(id: UUID().uuidString, fields: fields))
            }
        }
        return built.sorted { $0.fields.title.localizedCaseInsensitiveCompare($1.fields.title) == .orderedAscending }
    }
    
    // MARK: - Epic Shows Fetch Methods
    
    /// Fetch Legendary Shows for Epic Shows page (legacy table)
    func fetchLegendaryShows() async {
        print("🔄 Starting fetchLegendaryShows from: \(AirtableConfig.legendaryShowsUrl)")
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await performLegendaryShowsRequest()
            print("✅ Fetched \(result.count) legendary shows from Airtable")
            legendaryShows = result
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error fetching legendary shows: \(error)")
        }
        
        isLoading = false
    }
    
    /// Fetch Legendary categories from Videos table using multi-select field "LegendaryShows"
    func fetchLegendaryCategoriesFromVideos() async {
        let timer = PerformanceTimer("Airtable - Fetch Legendary Categories")
        print("🔄 Starting fetchLegendaryCategoriesFromVideos...")

        // Check for inflight request (deduplication)
        if let existingTask = inflightLegendaryCategoriesRequest {
            print("⏳ Legendary categories request already in progress, waiting...")
            await existingTask.value
            timer.end()
            return
        }

        // Try to load from cache first
        if let cachedCategories: [LegendaryCategory] = loadFromCache(Self.legendaryCategoriesCacheFile, typeName: "LegendaryCategories") {
            print("✅ Loaded \(cachedCategories.count) legendary categories from cache")
            legendaryCategories = cachedCategories
            timer.end()
            return
        }

        // Create new request task
        let task = Task<Void, Never> {
            await refreshLegendaryCategoriesFromNetwork()
        }
        inflightLegendaryCategoriesRequest = task

        isLoading = true
        errorMessage = nil
        await task.value
        inflightLegendaryCategoriesRequest = nil
        isLoading = false
        timer.end()
    }

    private func refreshLegendaryCategoriesFromNetwork() async {
        print("🔄 Fetching legendary categories from: \(AirtableConfig.videosUrl)")

        do {
            let categories = try await performLegendaryCategoriesFromVideosRequest()
            print("✅ Built \(categories.count) legendary categories from Videos table")

            // Update on main actor
            await MainActor.run {
                self.legendaryCategories = categories
            }

            // Save to cache
            saveToCache(categories, cacheFile: Self.legendaryCategoriesCacheFile, typeName: "LegendaryCategories")

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            print("❌ Error building legendary categories: \(error)")
        }
    }
    
    /// Fetch Concerts for Epic Shows banners
    func fetchConcerts() async {
        let timer = PerformanceTimer("Airtable - Fetch Concerts")
        print("🔄 Starting fetchConcerts...")

        // Check for inflight request (deduplication)
        if let existingTask = inflightConcertsRequest {
            print("⏳ Concerts request already in progress, waiting...")
            await existingTask.value
            timer.end()
            return
        }

        // Try to load from cache first (using shorter cache duration for attachment URLs)
        if let cachedConcerts: [Concert] = loadFromCache(Self.concertsCacheFile, typeName: "Concerts", maxAge: Self.attachmentCacheMaxAge) {
            print("✅ Loaded \(cachedConcerts.count) concerts from cache")
            concerts = cachedConcerts
            timer.end()
            return
        }

        // Create new request task
        let task = Task<Void, Never> {
            await refreshConcertsFromNetwork()
        }
        inflightConcertsRequest = task

        isLoading = true
        errorMessage = nil
        await task.value
        inflightConcertsRequest = nil
        isLoading = false
        timer.end()
    }

    private func refreshConcertsFromNetwork() async {
        print("🔄 Fetching concerts from: \(AirtableConfig.concertsUrl)")

        do {
            let result = try await performConcertsRequest()
            print("✅ Fetched \(result.count) concerts from Airtable")

            // Update on main actor
            await MainActor.run {
                self.concerts = result
            }

            // Save to cache
            saveToCache(result, cacheFile: Self.concertsCacheFile, typeName: "Concerts")

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            print("❌ Error fetching concerts: \(error)")
        }
    }
    
    /// Fetch Concert Videos for a specific concert using the concert's video IDs
    func fetchConcertVideos(for concert: Concert) async throws -> [ConcertVideo] {
        let timer = PerformanceTimer("Airtable - Fetch Concert Videos")
        print("🔄 Starting fetchConcertVideos for concert: \(concert.fields.artistName) - \(concert.fields.venueName ?? "Unknown Venue")")

        // First check if concert has linked video IDs
        guard let videoIds = concert.fields.concertVideos, !videoIds.isEmpty else {
            print("⚠️ No concert video IDs found for this concert")
            timer.end()
            return []
        }

        print("📋 Found \(videoIds.count) video IDs: \(videoIds)")

        // Create filter to get videos by their record IDs
        let videoIdFilters = videoIds.map { "RECORD_ID()='\($0)'" }.joined(separator: ",")
        let filterFormula = "OR(\(videoIdFilters))"

        // Use the Concert Videos table instead of Videos table
        let concertVideosUrl = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/Concert%20Videos"
        guard var components = URLComponents(string: concertVideosUrl) else {
            throw PlaylistError.invalidURL
        }

        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "filterByFormula", value: filterFormula))
        items.append(URLQueryItem(name: "pageSize", value: "100"))
        components.queryItems = items

        guard let url = components.url else {
            throw PlaylistError.invalidURL
        }

        print("🔍 Concert Videos API URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await session.data(for: request)

        if let jsonString = String(data: data, encoding: .utf8) {
            print("📡 Raw Concert Videos Response: \(String(jsonString.prefix(500)))...")
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(ConcertVideoResponse.self, from: data)

        print("✅ Fetched \(response.records.count) concert videos")
        timer.end()
        return response.records
    }

    // MARK: - Fetch Spotify Chart Videos (Top 50)

    /// Fetch Spotify Top 50 chart videos
    func fetchSpotifyChartVideos() async {
        let timer = PerformanceTimer("Airtable - Fetch Spotify Chart Videos")
        print("🔄 Starting fetchSpotifyChartVideos...")

        // Note: isLoading should already be set by the caller to avoid race conditions
        // but we set it here too for safety when called directly
        isLoading = true
        errorMessage = nil

        do {
            let result = try await performSpotifyChartVideosRequest()
            print("✅ Fetched \(result.count) Spotify chart videos from Airtable")

            // Debug: print first few records
            for (index, video) in result.prefix(3).enumerated() {
                print("  📹 Video \(index): \(video.fields.title ?? "nil") by \(video.fields.artistName ?? "nil") - rank \(video.fields.rank ?? 0)")
            }

            self.spotifyChartVideos = result
            print("📊 spotifyChartVideos array now has \(self.spotifyChartVideos.count) items")
        } catch {
            print("❌ Error fetching Spotify chart videos: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
        timer.end()
    }

    private func performSpotifyChartVideosRequest() async throws -> [SpotifyChartVideo] {
        guard var components = URLComponents(string: AirtableConfig.spotifyChartVideosUrl) else {
            throw PlaylistError.invalidURL
        }

        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "pageSize", value: "100"))
        // Sort by Rank ascending
        items.append(URLQueryItem(name: "sort[0][field]", value: "Rank"))
        items.append(URLQueryItem(name: "sort[0][direction]", value: "asc"))
        components.queryItems = items

        guard let url = components.url else {
            throw PlaylistError.invalidURL
        }

        print("🔍 Spotify Chart Videos API URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await session.data(for: request)

        if let jsonString = String(data: data, encoding: .utf8) {
            print("📡 Raw Spotify Chart Videos Response: \(String(jsonString.prefix(500)))...")
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(SpotifyChartVideoResponse.self, from: data)

        print("✅ Fetched \(response.records.count) Spotify chart videos")
        return response.records
    }

    // MARK: - Private Helper Methods for Epic Shows
    
    private func performLegendaryShowsRequest() async throws -> [LegendaryShow] {
        struct AirtableListResponse<Record: Codable>: Codable {
            let records: [Record]
            let offset: String?
        }
        
        func makePageURL(offset: String?) throws -> URL {
            guard var components = URLComponents(string: AirtableConfig.legendaryShowsUrl) else {
                throw PlaylistError.invalidURL
            }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "pageSize", value: "100"))
            if let offset = offset {
                items.removeAll { $0.name == "offset" }
                items.append(URLQueryItem(name: "offset", value: offset))
            }
            components.queryItems = items
            guard let finalURL = components.url else { throw PlaylistError.invalidURL }
            return finalURL
        }
        
        var accumulated: [LegendaryShow] = []
        var nextOffset: String? = nil
        let decoder = JSONDecoder()
        
        repeat {
            let requestUrl = try makePageURL(offset: nextOffset)
            var request = URLRequest(url: requestUrl)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await session.data(for: request)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 Raw Legendary Shows Response (page): \(String(jsonString.prefix(300)))...")
            }
            
            let response = try decoder.decode(AirtableListResponse<LegendaryShow>.self, from: data)
            accumulated.append(contentsOf: response.records)
            nextOffset = response.offset
            
        } while nextOffset != nil
        
        return accumulated
    }
    
    /// Build Legendary categories by grouping Videos table rows by multi-select LegendaryShows
    /// Also fetches from MTvVideosNEW table and merges results
    private func performLegendaryCategoriesFromVideosRequest() async throws -> [LegendaryCategory] {
        struct AirtableListResponse<Record: Codable>: Codable { let records: [Record]; let offset: String? }

        // Videos table structure
        struct VideoRecord: Codable { let id: String; let fields: VideoFields }
        struct VideoFields: Codable {
            let Title: String?
            let Artist: String?
            let artistName: [String]? // some bases store as array
            let Year: String?
            let URL: String?
            let videoImage: String?
            let LegendaryShow: [String]? // multi-select values (names)
        }

        // MTvVideosNEW table structure (different field names)
        struct MtvVideoRecord: Codable { let id: String; let fields: MtvVideoFields }
        struct MtvVideoFields: Codable {
            let title: String?
            let artistName: String?
            let url: String?
            let Year: String?
            let LegendaryShows: [String]? // note: plural "Shows"
        }

        // Helper to generate YouTube thumbnail from URL
        func extractVideoImage(from url: String) -> String? {
            // Extract video ID from YouTube URL
            if let range = url.range(of: "v=") {
                let videoId = String(url[range.upperBound...].prefix(11))
                return "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg"
            } else if url.contains("youtu.be/") {
                if let range = url.range(of: "youtu.be/") {
                    let videoId = String(url[range.upperBound...].prefix(11))
                    return "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg"
                }
            }
            return nil
        }

        var groups: [String: [LegendaryShow]] = [:]
        let decoder = JSONDecoder()

        // MARK: - Fetch from Videos table
        func makeVideosPageURL(offset: String?) throws -> URL {
            guard var components = URLComponents(string: AirtableConfig.videosUrl) else { throw PlaylistError.invalidURL }
            var items = components.queryItems ?? []
            if !items.contains(where: { $0.name == "pageSize" }) {
                items.append(URLQueryItem(name: "pageSize", value: "100"))
            }
            let fields = ["Title","artistName","Year","URL","videoImage","LegendaryShow"]
            for f in fields { items.append(URLQueryItem(name: "fields[]", value: f)) }
            if let offset = offset { items.append(URLQueryItem(name: "offset", value: offset)) }
            components.queryItems = items
            guard let finalURL = components.url else { throw PlaylistError.invalidURL }
            return finalURL
        }

        var videosAccumulated: [VideoRecord] = []
        var nextOffset: String? = nil

        repeat {
            let requestUrl = try makeVideosPageURL(offset: nextOffset)
            var request = URLRequest(url: requestUrl)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            let (data, responseMeta) = try await session.data(for: request)
            if let json = String(data: data, encoding: .utf8) {
                print("📡 Raw Videos Legendary fetch (page): \(String(json.prefix(500)))…")
            }
            if let http = responseMeta as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw PlaylistError.networkError(NSError(domain: "Airtable", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]))
            }
            let response = try decoder.decode(AirtableListResponse<VideoRecord>.self, from: data)
            videosAccumulated.append(contentsOf: response.records)
            nextOffset = response.offset
        } while nextOffset != nil

        // Process Videos table records
        for rec in videosAccumulated {
            let f = rec.fields
            guard let url = f.URL, !url.isEmpty,
                  let title = f.Title, !title.isEmpty
            else { continue }
            let artist = (f.artistName?.first?.isEmpty == false ? f.artistName?.first : f.Artist) ?? "Unknown Artist"
            let yearInt: Int = Int(f.Year ?? "") ?? 0
            let showFields = LegendaryShowFields(title: title, artist: artist, year: yearInt, youtubeUrl: url, videoImage: f.videoImage)
            let show = LegendaryShow(id: rec.id, fields: showFields)
            let tags = f.LegendaryShow ?? []
            for tag in tags where !tag.trimmingCharacters(in: .whitespaces).isEmpty {
                groups[tag, default: []].append(show)
            }
        }

        print("✅ Processed \(videosAccumulated.count) records from Videos table")

        // MARK: - Fetch from MTvVideosNEW table
        func makeMtvVideosPageURL(offset: String?) throws -> URL {
            guard var components = URLComponents(string: AirtableConfig.mtvVideosNewUrl) else { throw PlaylistError.invalidURL }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "pageSize", value: "100"))
            // Filter to only records that have LegendaryShows assigned
            items.append(URLQueryItem(name: "filterByFormula", value: "LegendaryShows!=''"))
            let fields = ["title","artistName","Year","url","LegendaryShows"]
            for f in fields { items.append(URLQueryItem(name: "fields[]", value: f)) }
            if let offset = offset { items.append(URLQueryItem(name: "offset", value: offset)) }
            components.queryItems = items
            guard let finalURL = components.url else { throw PlaylistError.invalidURL }
            return finalURL
        }

        var mtvAccumulated: [MtvVideoRecord] = []
        nextOffset = nil

        repeat {
            let requestUrl = try makeMtvVideosPageURL(offset: nextOffset)
            var request = URLRequest(url: requestUrl)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            let (data, responseMeta) = try await session.data(for: request)
            if let json = String(data: data, encoding: .utf8) {
                print("📡 Raw MTvVideosNEW Legendary fetch (page): \(String(json.prefix(500)))…")
            }
            if let http = responseMeta as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                print("⚠️ MTvVideosNEW fetch returned HTTP \(http.statusCode), skipping...")
                break
            }
            let response = try decoder.decode(AirtableListResponse<MtvVideoRecord>.self, from: data)
            mtvAccumulated.append(contentsOf: response.records)
            nextOffset = response.offset
        } while nextOffset != nil

        // Process MTvVideosNEW records
        for rec in mtvAccumulated {
            let f = rec.fields
            guard let url = f.url, !url.isEmpty,
                  let title = f.title, !title.isEmpty
            else { continue }
            let artist = f.artistName ?? "Unknown Artist"
            let yearInt: Int = Int(f.Year ?? "") ?? 0
            let videoImage = extractVideoImage(from: url)
            let showFields = LegendaryShowFields(title: title, artist: artist, year: yearInt, youtubeUrl: url, videoImage: videoImage)
            let show = LegendaryShow(id: rec.id, fields: showFields)
            let tags = f.LegendaryShows ?? []
            for tag in tags where !tag.trimmingCharacters(in: .whitespaces).isEmpty {
                groups[tag, default: []].append(show)
            }
        }

        print("✅ Processed \(mtvAccumulated.count) records from MTvVideosNEW table")

        // Convert to categories, shuffle videos within each, and return sorted by name
        let categories: [LegendaryCategory] = groups.map { (key, shows) in
            LegendaryCategory(name: key, shows: shows)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        print("✅ Built \(categories.count) legendary categories total")
        return categories
    }
    
    private func performConcertsRequest() async throws -> [Concert] {
        func makePageURL(offset: String?) throws -> URL {
            guard var components = URLComponents(string: AirtableConfig.concertsUrl) else {
                throw PlaylistError.invalidURL
            }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "pageSize", value: "100"))
            // Limit fields to reduce payload size - only fetch what we need
            items.append(URLQueryItem(name: "fields[]", value: "artistName"))
            items.append(URLQueryItem(name: "fields[]", value: "venueName"))
            items.append(URLQueryItem(name: "fields[]", value: "eventYear"))
            items.append(URLQueryItem(name: "fields[]", value: "bannerImage"))
            items.append(URLQueryItem(name: "fields[]", value: "eventDescription"))
            items.append(URLQueryItem(name: "fields[]", value: "Concert Videos"))
            if let offset = offset {
                items.removeAll { $0.name == "offset" }
                items.append(URLQueryItem(name: "offset", value: offset))
            }
            components.queryItems = items
            guard let finalURL = components.url else { throw PlaylistError.invalidURL }
            return finalURL
        }

        var accumulated: [Concert] = []
        var nextOffset: String? = nil
        let decoder = JSONDecoder()

        repeat {
            let requestUrl = try makePageURL(offset: nextOffset)
            var request = URLRequest(url: requestUrl)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await session.data(for: request)

            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 Raw Concerts Response (page): \(String(jsonString.prefix(300)))...")
            }

            // Parse JSON manually so one bad record doesn't break the entire feed
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let records = json["records"] as? [[String: Any]] else {
                throw PlaylistError.networkError(NSError(domain: "Airtable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid concerts response format"]))
            }

            var skippedCount = 0
            for record in records {
                do {
                    let recordData = try JSONSerialization.data(withJSONObject: record)
                    let concert = try decoder.decode(Concert.self, from: recordData)
                    accumulated.append(concert)
                } catch {
                    let recordId = record["id"] as? String ?? "unknown"
                    skippedCount += 1
                    print("⚠️ Skipped concert record \(recordId): \(error.localizedDescription)")
                }
            }
            if skippedCount > 0 {
                print("⚠️ Skipped \(skippedCount) concert records with missing/invalid data")
            }

            nextOffset = (json["offset"] as? String)

        } while nextOffset != nil

        return accumulated
    }
}

// MARK: - Airtable Category Response Models
struct AirtableCategoryRecord: Codable {
    let id: String
    let fields: AirtableCategoryFields
}

struct AirtableCategoryFields: Codable {
    let categoryName: String
    let description: String?
    let categoryImage: [AirtableAttachment]?
    let artistNames: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case categoryName = "CategoryName"
        case description
        case categoryImage = "CategoryImage"
        case artistNames = "ArtistNames"
    }
}

struct AirtableAttachment: Codable {
    let id: String
    let url: URL
    let filename: String
    let size: Int?
    let type: String?
    let width: Int?
    let height: Int?
    let thumbnails: [String: AirtableThumbnail]?
}

struct AirtableThumbnail: Codable {
    let url: URL
    let width: Int
    let height: Int
}

// MARK: - LegendaryShows response (fallback source)
struct AirtableLegendaryResponse: Codable {
    let records: [AirtableLegendaryRecord]
}

struct AirtableLegendaryRecord: Codable {
    let id: String
    let fields: AirtableLegendaryFields
}

struct AirtableLegendaryFields: Codable {
    let artist: String?
    let year: String?
    let title: String?
    let url: String?
    
    private enum CodingKeys: String, CodingKey {
        case artist = "Artist"
        case year = "Year"
        case title = "Title"
        case url = "URL"
    }
}