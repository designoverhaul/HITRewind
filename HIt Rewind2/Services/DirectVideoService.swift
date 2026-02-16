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
    @Published var errorMessage: String?

    private let baseURL = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/tblNwqwVyflL8hNDy"
    private let topTodayURL = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/tblY46dNwduOlOuLG"

    // Cache configuration
    private let cacheFileName = "direct_videos_cache.json"
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours

    private var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(cacheFileName)
    }

    private init() {
        // Load from cache on init
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
        isLoading = true
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
    }

    // Get available years from loaded videos
    var availableYears: [Int] {
        let years = videos.compactMap { $0.fields.yearInt }
        return Array(Set(years)).sorted(by: >)
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

    /// Fetch videos from TopToday table
    func fetchTopTodayVideos() async {
        // If we already have videos loaded, don't reload
        if !topTodayVideos.isEmpty {
            print("📦 DirectVideo: Using \(topTodayVideos.count) cached TopToday videos")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            var urlComponents = URLComponents(string: topTodayURL)
            var queryItems: [URLQueryItem] = []

            // Sort by rank ascending
            queryItems.append(URLQueryItem(name: "sort[0][field]", value: "Rank"))
            queryItems.append(URLQueryItem(name: "sort[0][direction]", value: "asc"))

            // Set page size
            queryItems.append(URLQueryItem(name: "pageSize", value: "100"))

            urlComponents?.queryItems = queryItems

            guard let url = urlComponents?.url else {
                throw DirectVideoError.invalidURL
            }

            print("🔍 TopToday API URL: \(url.absoluteString)")

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 Raw TopToday Response: \(String(jsonString.prefix(500)))...")
            }

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

            self.topTodayVideos = allVideos
            print("✅ Fetched \(allVideos.count) videos from TopToday")

        } catch let error as DirectVideoError {
            self.errorMessage = error.localizedDescription
            print("❌ TopToday fetch error: \(error.localizedDescription)")
        } catch {
            self.errorMessage = "Failed to fetch TopToday videos: \(error.localizedDescription)"
            print("❌ TopToday fetch error: \(error)")
        }

        isLoading = false
    }
}
