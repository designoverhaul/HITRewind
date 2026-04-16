//
//  DirectVideoService.swift
//  HIt Rewind2
//
//  Service to fetch videos directly from MTvVideosNEW table
//  Created by Aaron Heine on 1/11/26.
//

import Foundation

@MainActor
class DirectVideoService: ObservableObject {
    // Singleton for shared state across views
    static let shared = DirectVideoService()

    @Published var videos: [DirectVideoRecord] = []
    @Published var topTodayVideos: [DirectVideoRecord] = []
    @Published var isLoading = false
    @Published var isLoadingCatalog = false
    @Published var errorMessage: String?

    private let baseURL = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/tblNwqwVyflL8hNDy"
    // YouTube Charts: "Top 100 Music Videos United States" playlist (updated daily by YouTube)
    private let topTodayPlaylistId = "PL4fGSI1pDJn61unMfmrUSz68RT8IFFnks"
    private let topTodayCacheFileName = "top_today_cache.json"
    private let topTodayCacheExpiry: TimeInterval = 4 * 60 * 60 // 4 hours

    // Cache configuration
    private let cacheFileName = "direct_videos_cache.json"
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours

    private var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(cacheFileName)
    }

    // Hardcoded year list so sidebar appears instantly (no network wait)
    static let knownYears: [Int] = Array(stride(from: 2025, through: 1973, by: -1))

    private init() {
        loadFromCache()
    }

    // MARK: - Cache Management

    private func loadFromCache() {
        guard let cacheURL = cacheURL,
              FileManager.default.fileExists(atPath: cacheURL.path) else {
            print("📦 DirectVideo cache: No cache file found")
            return
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let cached = try JSONDecoder().decode(DirectVideoCacheData.self, from: data)

            // Check if cache is still valid
            if Date().timeIntervalSince(cached.timestamp) < cacheExpiry {
                self.videos = cached.videos
                print("📦 DirectVideo cache: Loaded \(cached.videos.count) videos from cache (age: \(Int(Date().timeIntervalSince(cached.timestamp)/60)) min)")
            } else {
                print("📦 DirectVideo cache: Cache expired, will fetch fresh data")
            }
        } catch {
            print("📦 DirectVideo cache: Failed to load cache - \(error)")
        }
    }

    private func saveToCache() {
        guard let cacheURL = cacheURL else { return }

        let cacheData = DirectVideoCacheData(videos: videos, timestamp: Date())

        do {
            let data = try JSONEncoder().encode(cacheData)
            try data.write(to: cacheURL)
            print("📦 DirectVideo cache: Saved \(videos.count) videos to cache")
        } catch {
            print("📦 DirectVideo cache: Failed to save - \(error)")
        }

    }

    /// Force refresh videos from network (bypasses cache)
    /// Uses detached task to prevent cancellation when view dismisses
    func forceRefreshVideos() async {
        print("🔄 DirectVideo: Force refreshing from network...")

        // Run in detached task so view lifecycle doesn't cancel the request
        await Task.detached { [weak self] in
            await self?.fetchVideosFromNetwork()
        }.value
    }

    func fetchVideos(year: String? = nil) async {
        // If we already have videos loaded (from cache or previous fetch), don't reload
        if !videos.isEmpty {
            print("📦 DirectVideo: Using \(videos.count) cached videos")
            return
        }

        await fetchVideosFromNetwork(year: year)
    }

    private func fetchVideosFromNetwork(year: String? = nil) async {
        // Only show full-screen loading spinner if we have nothing to show yet
        let showMainSpinner = topTodayVideos.isEmpty && videos.isEmpty
        if showMainSpinner {
            isLoading = true
        }
        isLoadingCatalog = true
        errorMessage = nil

        do {
            var urlComponents = URLComponents(string: baseURL)
            var queryItems: [URLQueryItem] = []

            // Add filter for year if specified
            if let year = year {
                queryItems.append(URLQueryItem(name: "filterByFormula", value: "{Year}=\"\(year)\""))
            }

            // Sort by rank ascending
            queryItems.append(URLQueryItem(name: "sort[0][field]", value: "Rank"))
            queryItems.append(URLQueryItem(name: "sort[0][direction]", value: "asc"))

            // Set page size
            queryItems.append(URLQueryItem(name: "pageSize", value: "100"))

            urlComponents?.queryItems = queryItems

            guard let url = urlComponents?.url else {
                throw DirectVideoError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DirectVideoError.networkError(NSError(domain: "Invalid response", code: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw DirectVideoError.networkError(NSError(domain: "HTTP \(httpResponse.statusCode)", code: httpResponse.statusCode))
            }

            let decoder = JSONDecoder()
            var allVideos: [DirectVideoRecord] = []
            var currentData = data
            var hasMorePages = true

            // Handle pagination
            while hasMorePages {
                let videoResponse = try decoder.decode(DirectVideoRecordsResponse.self, from: currentData)
                allVideos.append(contentsOf: videoResponse.records)

                // Check if there are more pages
                if let offset = videoResponse.offset {
                    // Fetch next page
                    var nextQueryItems = queryItems
                    nextQueryItems.append(URLQueryItem(name: "offset", value: offset))
                    urlComponents?.queryItems = nextQueryItems

                    guard let nextURL = urlComponents?.url else {
                        hasMorePages = false
                        break
                    }

                    var nextRequest = URLRequest(url: nextURL)
                    nextRequest.httpMethod = "GET"
                    nextRequest.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
                    nextRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let (nextData, _) = try await URLSession.shared.data(for: nextRequest)
                    currentData = nextData
                } else {
                    hasMorePages = false
                }
            }

            self.videos = allVideos
            print("✅ Fetched \(allVideos.count) videos from MTvVideosNEW" + (year != nil ? " for year \(year!)" : ""))

            // Save to cache
            saveToCache()

        } catch let error as DirectVideoError {
            self.errorMessage = error.localizedDescription
            print("❌ Video fetch error: \(error.localizedDescription)")
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Request was cancelled (e.g., view dismissed) - not a real error
            // Keep using cached data if available
            print("⚠️ Video fetch cancelled - using cached data (\(videos.count) videos)")
        } catch {
            self.errorMessage = "Failed to fetch videos: \(error.localizedDescription)"
            print("❌ Video fetch error: \(error)")
        }

        isLoading = false
        isLoadingCatalog = false
    }

    // Always returns the full year list instantly (no network dependency)
    var availableYears: [Int] {
        DirectVideoService.knownYears
    }

    // Filter videos by year (only return videos with URLs for playback)
    func videos(forYear year: Int) -> [DirectVideoRecord] {
        videos.filter {
            $0.fields.yearInt == year &&
            $0.fields.url != nil &&
            $0.fields.youtubeVideoId != nil
        }
    }

    // MARK: - Top Today Videos

    /// Fetch Top 100 Music Videos from YouTube Charts playlist (updated daily by YouTube)
    func fetchTopTodayVideos() async {
        if !topTodayVideos.isEmpty {
            print("📦 DirectVideo: Using \(topTodayVideos.count) cached TopToday videos")
            return
        }

        // Try disk cache first
        if let cached = loadTopTodayCache() {
            self.topTodayVideos = cached
            print("📦 DirectVideo: Loaded \(cached.count) TopToday videos from disk cache")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            var allVideos: [DirectVideoRecord] = []
            var pageToken: String? = nil
            var rank = 1

            // YouTube playlistItems returns max 50 per page, so we need 2 pages for 100
            repeat {
                var components = URLComponents(string: "\(YouTubeConfig.baseURL)/playlistItems")!
                var queryItems = [
                    URLQueryItem(name: "part", value: "snippet"),
                    URLQueryItem(name: "playlistId", value: topTodayPlaylistId),
                    URLQueryItem(name: "maxResults", value: "50"),
                    URLQueryItem(name: "key", value: YouTubeConfig.apiKey)
                ]
                if let token = pageToken {
                    queryItems.append(URLQueryItem(name: "pageToken", value: token))
                }
                components.queryItems = queryItems

                guard let url = components.url else { throw DirectVideoError.invalidURL }

                var request = URLRequest(url: url)
                if let bundleId = Bundle.main.bundleIdentifier {
                    request.setValue(bundleId, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
                }
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw DirectVideoError.networkError(
                        NSError(domain: "HTTP error", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
                    )
                }

                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                let items = json["items"] as? [[String: Any]] ?? []
                pageToken = json["nextPageToken"] as? String

                for item in items {
                    guard let snippet = item["snippet"] as? [String: Any],
                          let resourceId = snippet["resourceId"] as? [String: Any],
                          let videoId = resourceId["videoId"] as? String else { continue }

                    let rawTitle = snippet["title"] as? String ?? "Unknown"
                    let channelTitle = snippet["videoOwnerChannelTitle"] as? String ?? ""
                    let artistName = Self.cleanChannelName(channelTitle)
                    let videoTitle = Self.cleanVideoTitle(rawTitle, artist: artistName)

                    let record = DirectVideoRecord(
                        id: videoId,
                        fields: DirectVideoFields(
                            title: videoTitle,
                            artistName: artistName,
                            url: "https://www.youtube.com/watch?v=\(videoId)",
                            rank: rank,
                            year: nil
                        )
                    )
                    allVideos.append(record)
                    rank += 1
                }
            } while pageToken != nil && allVideos.count < 100

            self.topTodayVideos = allVideos
            saveTopTodayCache(allVideos)
            print("✅ Fetched \(allVideos.count) videos from YouTube Charts playlist")

        } catch {
            // Don't set errorMessage — it's shared state and would block the year-based catalog view
            print("❌ TopToday fetch error: \(error)")
        }

        isLoading = false
    }

    /// Strip "VEVO", "- Topic", "Official", etc. from channel names to get clean artist names
    private static func cleanChannelName(_ name: String) -> String {
        name.replacingOccurrences(of: "VEVO", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " - Topic", with: "")
            .replacingOccurrences(of: " Official", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Strip "Artist - " prefix and "(Official Video)"-style suffixes from YouTube titles
    private static func cleanVideoTitle(_ title: String, artist: String) -> String {
        var cleaned = title

        // Drop "Artist - " prefix if present (case-insensitive)
        if !artist.isEmpty {
            let prefix = "\(artist) - "
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }

        // Strip common parenthetical/bracket suffixes
        let patterns = [
            #"\s*\((?:Official\s+)?(?:Music\s+)?Video\)"#,
            #"\s*\(Official\s+Audio\)"#,
            #"\s*\(Official\s+Lyric\s+Video\)"#,
            #"\s*\(Lyric\s+Video\)"#,
            #"\s*\(Visualizer\)"#,
            #"\s*\(Audio\)"#,
            #"\s*\(Official\)"#,
            #"\s*\(Clean\s+Edit\)"#,
            #"\s*\[(?:Official\s+)?(?:Music\s+)?Video\]"#,
            #"\s*\[Official\s+Audio\]"#,
        ]
        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - TopToday Disk Cache

    private var topTodayCacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(topTodayCacheFileName)
    }

    private func loadTopTodayCache() -> [DirectVideoRecord]? {
        guard let url = topTodayCacheURL,
              let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(DirectVideoCacheData.self, from: data),
              Date().timeIntervalSince(cached.timestamp) < topTodayCacheExpiry else { return nil }
        return cached.videos
    }

    private func saveTopTodayCache(_ videos: [DirectVideoRecord]) {
        guard let url = topTodayCacheURL else { return }
        let cacheData = DirectVideoCacheData(videos: videos, timestamp: Date())
        if let data = try? JSONEncoder().encode(cacheData) {
            try? data.write(to: url)
        }
    }
}
