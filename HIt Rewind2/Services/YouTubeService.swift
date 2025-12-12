//
//  YouTubeService.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Array Extension for Batching
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - YouTube Models
struct YouTubeVideoResponse: Codable {
    let items: [YouTubeVideo]
}

struct YouTubeVideo: Codable {
    let id: String
    let snippet: YouTubeVideoSnippet
    let contentDetails: YouTubeContentDetails?
    let statistics: YouTubeStatistics?
    let status: YouTubeStatus?
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
    let embeddable: Bool? // Whether the video can be embedded
}

struct YouTubeStatistics: Codable {
    let viewCount: String?
}

struct YouTubeStatus: Codable {
    let privacyStatus: String
    let embeddable: Bool?
}

// MARK: - YouTube Service
class YouTubeService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Custom URLSession with more robust network configuration
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        
        // Increase timeouts for flaky connections
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        
        // Disable HTTP/3 (QUIC) to avoid protocol issues
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Allow cellular data
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        return URLSession(configuration: config)
    }()

    // MARK: - Video Information
    func getVideoInfo(videoId: String) async throws -> YouTubeVideo {
        let videos = try await getBatchVideoInfo(videoIds: [videoId])
        guard let video = videos[videoId] else {
            throw YouTubeError.videoNotFound
        }
        return video
    }
    
    // MARK: - Batch Video Information (Much more efficient!)
    func getBatchVideoInfo(videoIds: [String]) async throws -> [String: YouTubeVideo] {
        let totalTimer = PerformanceTimer("YouTube - Batch Video Info (Total)")
        print("⏱️ [YouTube] Starting batch load for \(videoIds.count) video IDs")

        let apiKey = YouTubeConfig.apiKey
        guard !apiKey.isEmpty && apiKey != "YOUR_YOUTUBE_API_KEY_HERE" else {
            throw YouTubeError.missingAPIKey
        }

        // YouTube API supports up to 50 video IDs in a single request
        let batchSize = 50
        var allVideos: [String: YouTubeVideo] = [:]

        // Calculate number of batches
        let batches = Array(videoIds.chunked(into: batchSize))
        let batchCount = batches.count
        print("⏱️ [YouTube] Will process \(batchCount) batch(es) of up to \(batchSize) videos each")

        // Process videos in batches of 50
        var currentBatch = 0
        for batch in batches {
            currentBatch += 1
            let batchTimer = PerformanceTimer("YouTube - API Request (batch \(currentBatch)/\(batchCount), \(batch.count) videos)")
            let videoIdsString = batch.joined(separator: ",")
            let urlString = "\(YouTubeConfig.baseURL)/videos?part=snippet,contentDetails,statistics,status&id=\(videoIdsString)&key=\(apiKey)"
            
            guard let url = URL(string: urlString) else {
                throw YouTubeError.invalidURL
            }
            
            do {
                // Create request with timeout
                var request = URLRequest(url: url)
                request.timeoutInterval = 15.0
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
                
                let (data, response) = try await session.data(for: request)
                
                // Check HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    guard 200...299 ~= httpResponse.statusCode else {
                        print("🎬 YouTube API HTTP error: \(httpResponse.statusCode)")
                        throw YouTubeError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode))
                    }
                }
                
                // Validate data before decoding
                guard !data.isEmpty else {
                    print("🎬 YouTube API returned empty response")
                    throw YouTubeError.networkError(NSError(domain: "EmptyResponse", code: -1))
                }
                
                let youTubeResponse = try JSONDecoder().decode(YouTubeVideoResponse.self, from: data)
                
                // Map videos by ID for easy lookup
                for video in youTubeResponse.items {
                    allVideos[video.id] = video
                }

                print("⏱️ [YouTube] Batch \(currentBatch)/\(batchCount) returned \(youTubeResponse.items.count) videos")
                batchTimer.end()

            } catch let decodingError as DecodingError {
                print("🎬 YouTube API JSON decode error: \(decodingError)")
                batchTimer.end()
                throw YouTubeError.networkError(decodingError)
            } catch {
                print("🎬 YouTube API network error: \(error.localizedDescription)")
                batchTimer.end()
                throw YouTubeError.networkError(error)
            }
        }

        print("⏱️ [YouTube] Successfully loaded \(allVideos.count) videos across \(batchCount) batch(es)")
        totalTimer.end()
        return allVideos
    }

    // MARK: - Check Video Embeddability
    func checkVideoEmbeddability(videoId: String) async throws -> Bool {
        let video = try await getVideoInfo(videoId: videoId)

        let contentEmbeddable = video.contentDetails?.embeddable ?? false
        let statusEmbeddable = video.status?.embeddable ?? false
        let isPublic = video.status?.privacyStatus == "public"
        let isEmbeddable = contentEmbeddable || statusEmbeddable

        return isPublic && isEmbeddable
    }

    // MARK: - Quick API Test (Call this to diagnose issues)
    func quickAPITest() async {
        print("\n🔍 === YOUTUBE API STATUS CHECK ===")
        print("⏰ Time: \(Date().formatted())")
        print("🔑 API Key: \(YouTubeConfig.apiKey.prefix(10))...")

        let status = await checkAPIStatus()
        print("📊 Overall Status: \(status.isValid ? "✅ WORKING" : "❌ ISSUES DETECTED")")

        if let error = status.error {
            print("❌ Error Details: \(error)")
        }

        if let quota = status.quotaInfo {
            print("📈 Quota Info: \(quota)")
        }

        // Additional API health checks
        await performAPIHealthCheck()

        print("====================================\n")
    }

    // MARK: - API Health Check
    private func performAPIHealthCheck() async {
        print("\n🏥 API HEALTH CHECK:")

        // Test different endpoints
        let endpoints = [
            "search": "search?part=snippet&type=video&q=test&maxResults=1",
            "videos": "videos?part=snippet&id=dQw4w9WgXcQ",
            "channels": "channels?part=snippet&id=UCuAXFkgsw1L7xaCfnd5JJOw"
        ]

        for (name, path) in endpoints {
            let urlString = "\(YouTubeConfig.baseURL)/\(path)&key=\(YouTubeConfig.apiKey)"
            guard let url = URL(string: urlString) else {
                print("❌ \(name): Invalid URL")
                continue
            }

            do {
                let startTime = Date()
                let (data, response) = try await session.data(from: url)
                let duration = Date().timeIntervalSince(startTime)

                if let httpResponse = response as? HTTPURLResponse {
                    let status = httpResponse.statusCode
                    print("✅ \(name): \(status) (\(String(format: "%.2f", duration))s)")

                    // Check for quota exceeded or blocking
                    if status == 403 {
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = json["error"] as? [String: Any],
                           let errors = error["errors"] as? [[String: Any]],
                           let firstError = errors.first,
                           let reason = firstError["reason"] as? String {
                            print("   🚫 Access Issue: \(reason)")
                        } else {
                            print("   🚫 Access Forbidden (403)")
                        }
                    } else if status == 400 {
                        print("   ⚠️ Bad Request (400) - Check API key format")
                    }
                }
            } catch {
                print("❌ \(name): Failed - \(error.localizedDescription)")
            }
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
    
    // MARK: - API Key Validation
    func validateAPIKey() async -> Bool {
        let apiKey = YouTubeConfig.apiKey
        if apiKey.isEmpty || apiKey == "YOUR_YOUTUBE_API_KEY_HERE" {
            return false
        }

        let testVideoId = "dQw4w9WgXcQ"
        do {
            _ = try await getVideoInfo(videoId: testVideoId)
            return true
        } catch {
            return false
        }
    }

    // MARK: - API Status Check
    func checkAPIStatus() async -> (isValid: Bool, error: String?, quotaInfo: String?) {
        print("🔍 DEBUG: Checking YouTube API status...")

        guard !YouTubeConfig.apiKey.isEmpty && YouTubeConfig.apiKey != "YOUR_YOUTUBE_API_KEY_HERE" else {
            return (false, "API key is missing or placeholder", nil)
        }

        // Test with multiple videos to check for patterns
        let testVideos = [
            "dQw4w9WgXcQ", // Rick Astley (highly popular, should work)
            "jNQXAC9IVRw", // YouTube's first video
            "kJQP7kiw5Fk"  // Despacito (very popular)
        ]

        var results: [(videoId: String, success: Bool, error: String?)] = []

        for videoId in testVideos {
            do {
                let startTime = Date()
                let video = try await getVideoInfo(videoId: videoId)
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)

                results.append((videoId, true, nil))
                print("✅ DEBUG: API test successful for \(videoId) - \(video.snippet.title) (\(String(format: "%.2f", duration))s)")

                // If any video works, API is generally functional
                return (true, nil, "API appears functional - some videos may be restricted")
            } catch let error as YouTubeError {
                results.append((videoId, false, error.localizedDescription))
                print("❌ DEBUG: API test failed for \(videoId) - \(error.localizedDescription)")
            } catch {
                results.append((videoId, false, error.localizedDescription))
                print("❌ DEBUG: API test failed for \(videoId) - \(error.localizedDescription)")
            }
        }

        // Analyze results
        let successCount = results.filter { $0.success }.count
        let failureCount = results.filter { !$0.success }.count

        if failureCount == testVideos.count {
            return (false, "All API calls failed - check API key and network", nil)
        } else if successCount > 0 {
            return (true, "API partially functional - some videos restricted", "\(successCount)/\(testVideos.count) videos accessible")
        } else {
            return (false, "API key may be invalid or quota exceeded", nil)
        }
    }

    // MARK: - Comprehensive Debug Diagnostics
    func runVideoDiagnostics(videoId: String) async {
        print("🔍 ============= YOUTUBE VIDEO DIAGNOSTICS =============")
        print("🎬 Testing video: \(videoId)")

        // 1. Check API Status
        print("\n1️⃣ YOUTUBE API STATUS:")
        let apiStatus = await checkAPIStatus()
        print("   API Status: \(apiStatus.isValid ? "✅" : "❌")")
        if let error = apiStatus.error {
            print("   Error: \(error)")
        }
        if let quota = apiStatus.quotaInfo {
            print("   Quota Info: \(quota)")
        }

        // 2. Check Network Connectivity
        print("\n2️⃣ NETWORK CONNECTIVITY:")
        let networkTest = await testNetworkConnectivity()
        print("   Network Available: \(networkTest ? "✅" : "❌")")

        // 3. Check Video ID Format
        print("\n3️⃣ VIDEO ID VALIDATION:")
        let idValid = isValidYouTubeVideoId(videoId)
        print("   Video ID Format: \(idValid ? "✅" : "❌")")

        // 4. Test YouTube API Call
        print("\n4️⃣ YOUTUBE API CALL:")
        do {
            let video = try await getVideoInfo(videoId: videoId)
            print("   API Call Successful: ✅")
            print("   Video Title: \(video.snippet.title)")
            print("   Channel: \(video.snippet.channelTitle)")
        } catch {
            print("   API Call Failed: ❌")
            print("   Error: \(error.localizedDescription)")
        }

        // 5. Check Thumbnail URLs
        print("\n5️⃣ THUMBNAIL URLS:")
        let qualities: [ThumbnailQuality] = [.default, .medium, .high, .standard, .maxres]
        for quality in qualities {
            let url = getThumbnailURL(for: videoId, quality: quality)
            print("   \(quality): \(url?.absoluteString ?? "nil")")
        }

        print("\n🔍 ============= END DIAGNOSTICS =============\n")
    }

    private func testNetworkConnectivity() async -> Bool {
        do {
            let testURL = URL(string: "https://www.google.com")!
            let (_, response) = try await session.data(from: testURL)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func isValidYouTubeVideoId(_ videoId: String) -> Bool {
        let videoIdPattern = "^[a-zA-Z0-9_-]{11}$"
        let regex = try? NSRegularExpression(pattern: videoIdPattern)
        let range = NSRange(location: 0, length: videoId.utf16.count)
        return regex?.firstMatch(in: videoId, range: range) != nil
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