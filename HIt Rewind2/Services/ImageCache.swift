//
//  ImageCache.swift
//  HIt Rewind2
//
//  Created by Claude on 1/15/26.
//

import SwiftUI
import UIKit
import Foundation

/// Shared image cache for thumbnail images
/// Uses NSCache for automatic memory management
/// Note: Uses a class-based synchronous cache for instant access, with actor for async loading
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    // Synchronous in-memory cache - can be accessed without await
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let loadQueue = DispatchQueue(label: "com.hitrewind.imagecache", attributes: .concurrent)
    private var loadingTasks: [String: Task<UIImage?, Never>] = [:]
    private let tasksLock = NSLock()

    // Initialize disk cache URL upfront (not lazy) to avoid thread-safety issues
    private let diskCacheURL: URL

    private init() {
        // Initialize disk cache directory
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("ImageCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        self.diskCacheURL = cacheDir

        // Configure cache limits
        memoryCache.countLimit = 200 // Max 200 images in memory
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB max
    }

    // MARK: - Synchronous Access (for instant UI updates)

    /// Get image from memory cache synchronously - use this for immediate display
    func cachedImage(for videoId: String) -> UIImage? {
        let key = "yt_thumb_\(videoId)" as NSString
        return memoryCache.object(forKey: key)
    }

    // MARK: - Public API

    /// Get image from cache (memory or disk)
    func image(for key: String) -> UIImage? {
        // Check memory cache first
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            // Promote to memory cache
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }

        return nil
    }

    /// Store image in cache (memory and disk)
    func store(_ image: UIImage, for key: String) {
        // Store in memory
        memoryCache.setObject(image, forKey: key as NSString)

        // Store on disk asynchronously
        saveToDiskAsync(image, key: key)
    }

    /// Load image from URL with caching
    func loadImage(from url: URL, cacheKey: String) async -> UIImage? {
        // Check cache first
        if let cached = image(for: cacheKey) {
            return cached
        }

        // Check if already loading
        tasksLock.lock()
        if let existingTask = loadingTasks[cacheKey] {
            tasksLock.unlock()
            return await existingTask.value
        }

        // Create loading task
        let task = Task<UIImage?, Never> { [weak self] in
            guard let self = self else { return nil }
            do {
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
                request.setValue("image/avif,image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    return nil
                }

                guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                      contentType.hasPrefix("image") else {
                    return nil
                }

                guard let image = UIImage(data: data) else {
                    return nil
                }

                // Cache the image
                self.store(image, for: cacheKey)
                return image

            } catch {
                return nil
            }
        }

        loadingTasks[cacheKey] = task
        tasksLock.unlock()

        let result = await task.value

        tasksLock.lock()
        loadingTasks[cacheKey] = nil
        tasksLock.unlock()

        return result
    }

    /// Load YouTube thumbnail with automatic fallback to different qualities.
    /// Returns nil when YouTube serves its 120×90 "no thumbnail" gray placeholder
    /// (happens for removed/private videos), so callers can show the `missing` asset.
    func loadYouTubeThumbnail(videoId: String) async -> UIImage? {
        let cacheKey = "yt_thumb_\(videoId)"

        if let cached = image(for: cacheKey) {
            return cached
        }

        // mqdefault is 320×180 for real videos, 120×90 when missing.
        // hqdefault is 480×360 for real videos, 120×90 when missing.
        // We intentionally skip `default.jpg` since its real size (120×90) is
        // indistinguishable from the gray placeholder.
        let qualities = ["mqdefault.jpg", "hqdefault.jpg"]
        let hosts = ["i.ytimg.com", "img.youtube.com"]

        for quality in qualities {
            for host in hosts {
                guard let url = URL(string: "https://\(host)/vi/\(videoId)/\(quality)") else { continue }

                if let image = await loadImageWithoutCache(from: url) {
                    if image.size.width > 120 {
                        store(image, for: cacheKey)
                        return image
                    }
                }
            }
        }

        return nil
    }

    /// Fetch image bytes without consulting or writing to the cache.
    /// Used when the caller needs to validate the response before caching.
    private func loadImageWithoutCache(from url: URL) async -> UIImage? {
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
            request.setValue("image/avif,image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let contentType = http.value(forHTTPHeaderField: "Content-Type"), contentType.hasPrefix("image") else {
                return nil
            }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    /// Clear all cached images
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Disk Cache Helpers

    private func diskPath(for key: String) -> URL {
        let sanitizedKey = key.replacingOccurrences(of: "/", with: "_")
        return diskCacheURL.appendingPathComponent(sanitizedKey + ".jpg")
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let path = diskPath(for: key)
        guard fileManager.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private func saveToDiskAsync(_ image: UIImage, key: String) {
        let path = diskPath(for: key)
        loadQueue.async {
            guard let data = image.jpegData(compressionQuality: 0.8) else { return }
            try? data.write(to: path)
        }
    }
}

// MARK: - YouTube Thumbnail View

/// Loads a YouTube thumbnail via `ImageCache` and falls back to the `missing`
/// asset when the video is gone or YouTube served its gray "no thumbnail" image.
struct YouTubeThumbnailImage: View {
    let videoId: String
    var contentMode: ContentMode = .fill

    @State private var uiImage: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if didFail {
                Image("missing")
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(Color.hitRewindDarkGray)
            }
        }
        .onAppear {
            if uiImage == nil, let cached = ImageCache.shared.cachedImage(for: videoId) {
                uiImage = cached
            }
        }
        .task(id: videoId) {
            guard uiImage == nil, !didFail else { return }
            if let img = await ImageCache.shared.loadYouTubeThumbnail(videoId: videoId) {
                uiImage = img
            } else {
                didFail = true
            }
        }
    }
}

// MARK: - Video Info Cache

/// Shared cache for YouTube video metadata (duration, view count)
actor VideoInfoCache {
    static let shared = VideoInfoCache()

    private var cache: [String: CachedVideoInfo] = [:]
    private var loadingYears: Set<Int> = []

    struct CachedVideoInfo {
        let duration: String
        let viewCount: String
        let cachedAt: Date
    }

    private init() {}

    /// Get cached video info
    func info(for videoId: String) -> CachedVideoInfo? {
        guard let info = cache[videoId] else { return nil }

        // Check if cache is still valid (24 hours)
        let age = Date().timeIntervalSince(info.cachedAt)
        if age > 24 * 60 * 60 {
            cache[videoId] = nil
            return nil
        }

        return info
    }

    /// Store video info
    func store(videoId: String, duration: String, viewCount: String) {
        cache[videoId] = CachedVideoInfo(
            duration: duration,
            viewCount: viewCount,
            cachedAt: Date()
        )
    }

    /// Batch store video info from YouTube API response
    func storeBatch(_ videos: [String: YouTubeVideo], youtubeService: YouTubeService) {
        for (videoId, video) in videos {
            var duration = ""
            var viewCount = ""

            if let contentDetails = video.contentDetails {
                duration = youtubeService.formatDuration(contentDetails.duration)
            }

            if let statistics = video.statistics,
               let viewCountString = statistics.viewCount,
               let viewCountNumber = Int(viewCountString) {
                viewCount = formatViewCount(viewCountNumber)
            }

            cache[videoId] = CachedVideoInfo(
                duration: duration,
                viewCount: viewCount,
                cachedAt: Date()
            )
        }
        print("📦 Cached video info for \(videos.count) videos")
    }

    /// Check if year is currently being loaded
    func isLoadingYear(_ year: Int) -> Bool {
        loadingYears.contains(year)
    }

    /// Mark year as loading
    func startLoadingYear(_ year: Int) {
        loadingYears.insert(year)
    }

    /// Mark year as done loading
    func finishLoadingYear(_ year: Int) {
        loadingYears.remove(year)
    }

    /// Clear cache
    func clearCache() {
        cache.removeAll()
        loadingYears.removeAll()
    }

    private func formatViewCount(_ count: Int) -> String {
        let formatter = NumberFormatter()

        switch count {
        case 1_000_000...:
            let millions = Double(count) / 1_000_000.0
            formatter.maximumFractionDigits = millions >= 10 ? 0 : 1
            return "\(formatter.string(from: NSNumber(value: millions)) ?? "0")M"

        case 1_000...:
            let thousands = Double(count) / 1_000.0
            formatter.maximumFractionDigits = thousands >= 10 ? 0 : 1
            return "\(formatter.string(from: NSNumber(value: thousands)) ?? "0")K"

        default:
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: count)) ?? "0"
        }
    }
}
