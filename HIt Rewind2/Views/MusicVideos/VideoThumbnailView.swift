//
//  VideoThumbnailView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI

struct VideoThumbnailView: View {
    let videoId: String
    let title: String
    let artist: String
    let year: String
    let onTap: () -> Void
    let hideArtistAndYear: Bool // New parameter to hide artist/year for concert videos
    let hideArtistName: Bool // New parameter to hide only artist name (for artist-specific views)
    let rank: Int? // Optional Billboard rank to display
    let hideDuration: Bool // Flag to hide duration badge (for music videos)
    let showDurationInline: Bool // Show duration inline with title in purple (for concert videos)

    // Convenience initializer with default parameters
    init(videoId: String, title: String, artist: String, year: String, onTap: @escaping () -> Void, hideArtistAndYear: Bool = false, hideArtistName: Bool = false, rank: Int? = nil, hideDuration: Bool = false, showDurationInline: Bool = false) {
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.year = year
        self.onTap = onTap
        self.hideArtistAndYear = hideArtistAndYear
        self.hideArtistName = hideArtistName
        self.rank = rank
        self.hideDuration = hideDuration
        self.showDurationInline = showDurationInline
    }
    
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var thumbnailImage: Image?
    @State private var duration: String = ""
    @State private var viewCount: String = ""
    @State private var showingRemoveFavoriteConfirmation = false
    @State private var heartBounceEffect = false

    // Shared caches for better performance
    private let imageCache = ImageCache.shared
    private let videoInfoCache = VideoInfoCache.shared

    private var displayTitle: String {
        title
    }
    
    var body: some View {
        // NavigationLink version - no button wrapper to avoid gesture conflicts
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with play overlay
            thumbnailView
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)

            // Video information
            videoInfo
        }
        .onAppear {
            // Synchronously check memory cache for instant display (no loading flash)
            let cached = imageCache.cachedImage(for: videoId)
            if thumbnailImage == nil, let cached = cached {
                thumbnailImage = Image(uiImage: cached)
            }
        }
        .task {
            // Only load if not already loaded from cache
            if thumbnailImage == nil {
                await loadVideoData()
            } else {
                // Still load video info even if thumbnail is cached
                await loadVideoInfoFromCache()
            }
        }
        .confirmationDialog("Remove from favorites?", isPresented: $showingRemoveFavoriteConfirmation) {
            Button("Remove", role: .destructive) {
                favoritesService.toggleFavorite(videoId: videoId, title: title, artist: artist, year: year)
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Thumbnail View
    private var thumbnailView: some View {
        ZStack {
            // Thumbnail image
            Group {
                if let thumbnailImage = thumbnailImage {
                    thumbnailImage
                        .resizable()
                        .scaledToFill()
                } else {
                    // Simple placeholder - no spinner to avoid flash on navigation
                    Rectangle()
                        .fill(Color.hitRewindDarkGray)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Play button overlay
            playOverlay
            
            // Rank badge, Heart button, and duration badge
            VStack {
                HStack {
                    // Rank badge (top-left)
                    if let rank = rank {
                        Text("#\(rank)")
                            .font(.system(size: 14))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.hitRewindPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.leading, 8)
                            .padding(.top, 5)
                    }

                    Spacer()

                    // Heart button (top-right)
                    ThumbnailFavoriteButton(
                        videoId: videoId,
                        title: title,
                        artist: artist,
                        year: year,
                        bounceEffect: $heartBounceEffect,
                        showingRemoveConfirmation: $showingRemoveFavoriteConfirmation
                    )
                    .environmentObject(authService)
                    .environmentObject(favoritesService)
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                }

                Spacer()

                // Duration badge (bottom-right) - only show if not hidden
                if !hideDuration && !duration.isEmpty {
                    HStack {
                        Spacer()
                        Text(duration)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.trailing, 8)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }
    
    private var playOverlay: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.3)
            
            // Play button
            Image(systemName: "play.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .background(
                    Circle()
                        .fill(Color.hitRewindPurple)
                        .frame(width: 44, height: 44)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(0) // Initially hidden, will be shown on hover/focus
    }
    
    // MARK: - Video Information
    private var videoInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title and duration/view count on same line
            HStack(alignment: .top, spacing: 8) {
                Text(displayTitle)
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.hitRewindPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                // Duration inline (purple) for concert videos, or view count for others
                if showDurationInline && !duration.isEmpty {
                    Text(duration)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.hitRewindPurple)
                        .lineLimit(1)
                } else if !viewCount.isEmpty {
                    Text(viewCount)
                        .font(.caption2)
                        .foregroundColor(.hitRewindSecondaryText)
                        .lineLimit(1)
                }
            }

            // Artist name or year below
            if !hideArtistAndYear {
                if hideArtistName {
                    // Artist-specific view: show year below title if available
                    if !year.isEmpty {
                        Text(year)
                            .font(.custom(AppFont.ticketingName(), size: 15))
                            .fontWeight(.medium)
                            .foregroundColor(.hitRewindPurple)
                            .lineLimit(1)
                    }
                } else if shouldShowArtistName {
                    // Normal view: show artist name below title
                    Text(artist)
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                        .foregroundColor(.hitRewindPurple)
                        .lineLimit(1)
                }
            }
        }
    }
    
    // Helper to determine if artist name should be shown
    private var shouldShowArtistName: Bool {
        // Don't show artist name for Fan Cams - detect this by checking if title starts with artist name
        // Most fan cam titles start with artist name like "Taylor Swift - Live at..."
        // Music video titles usually don't start with artist name
        let titleLower = title.lowercased()
        let artistLower = artist.lowercased()
        
        // If title starts with artist name, likely a fan cam - don't show artist name
        if titleLower.hasPrefix(artistLower) {
            return false
        }
        
        // If title contains " - " and starts with artist, it's likely a fan cam format
        if titleLower.contains(" - ") && titleLower.hasPrefix(artistLower) {
            return false
        }
        
        // Otherwise, show artist name (Music Videos page)
        return true
    }
    
    // MARK: - Data Loading
    private func loadVideoData() async {
        // Load video info from cache first (populated by batch load)
        await loadVideoInfoFromCache()

        // Load thumbnail image with caching
        await loadThumbnailImage()
    }

    private func loadThumbnailImage() async {
        // Use shared image cache for efficient loading
        if let uiImage = await imageCache.loadYouTubeThumbnail(videoId: videoId) {
            await MainActor.run {
                thumbnailImage = Image(uiImage: uiImage)
            }
        }
    }

    private func loadVideoInfoFromCache() async {
        // Check if video info is already in cache (from batch load)
        if let cachedInfo = await videoInfoCache.info(for: videoId) {
            await MainActor.run {
                duration = cachedInfo.duration
                viewCount = cachedInfo.viewCount
            }
            return
        }

        // If showDurationInline is true (e.g., concert videos), fetch from YouTube API
        if showDurationInline {
            await fetchVideoInfoFromAPI()
            return
        }

        // Otherwise, info will be loaded by batch loader in MusicVideosView
        // We don't make individual API calls to reduce API usage
    }

    private func fetchVideoInfoFromAPI() async {
        let youtubeService = YouTubeService()
        do {
            let video = try await youtubeService.getVideoInfo(videoId: videoId)
            var fetchedDuration = ""
            var fetchedViewCount = ""

            if let contentDetails = video.contentDetails {
                fetchedDuration = youtubeService.formatDuration(contentDetails.duration)
            }

            if let statistics = video.statistics,
               let viewCountString = statistics.viewCount,
               let viewCountNumber = Int(viewCountString) {
                fetchedViewCount = formatViewCount(viewCountNumber)
            }

            // Cache the result
            await videoInfoCache.store(videoId: videoId, duration: fetchedDuration, viewCount: fetchedViewCount)

            await MainActor.run {
                duration = fetchedDuration
                viewCount = fetchedViewCount
            }
        } catch {
            print("⚠️ Failed to fetch video info for \(videoId): \(error)")
        }
    }
    
    private func formatViewCount(_ count: Int) -> String {
        let formatter = NumberFormatter()

        switch count {
        case 1_000_000...:
            let millions = Double(count) / 1_000_000.0
            if millions >= 10 {
                formatter.maximumFractionDigits = 0
            } else {
                formatter.maximumFractionDigits = 1
            }
            return "\(formatter.string(from: NSNumber(value: millions)) ?? "0")M"

        case 1_000...:
            let thousands = Double(count) / 1_000.0
            if thousands >= 10 {
                formatter.maximumFractionDigits = 0
            } else {
                formatter.maximumFractionDigits = 1
            }
            return "\(formatter.string(from: NSNumber(value: thousands)) ?? "0")K"

        default:
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: count)) ?? "0"
        }
    }
}

// MARK: - Thumbnail Favorite Button
struct ThumbnailFavoriteButton: View {
    let videoId: String
    let title: String
    let artist: String
    let year: String
    @Binding var bounceEffect: Bool
    @Binding var showingRemoveConfirmation: Bool

    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var favoritesService: FavoritesService

    @State private var isFavorited: Bool = false

    var body: some View {
        Button(action: {
            print("🎥 Thumbnail favorite button tapped for: \(title)")
            if authService.isAuthenticated {
                print("🎥 User authenticated, current isFavorited: \(isFavorited)")
                if isFavorited {
                    // Show confirmation for removing from favorites
                    print("🎥 Showing remove confirmation")
                    showingRemoveConfirmation = true
                } else {
                    // Add to favorites immediately
                    print("🎥 Adding to favorites...")
                    favoritesService.toggleFavorite(videoId: videoId, title: title, artist: artist, year: year)
                    // Update local state immediately
                    isFavorited = true
                    print("🎥 Local state set to favorited")
                    // Trigger bounce animation
                    bounceEffect = true
                }
            } else {
                print("🎥 User not authenticated, showing sign-in sheet")
                NotificationCenter.default.post(name: .showSignInSheet, object: nil)
            }
        }) {
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isFavorited ? .red : .hitRewindPurple)
                .symbolEffect(.bounce, value: bounceEffect)
                .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Initialize the state when the view appears
            isFavorited = favoritesService.isFavorited(videoId)
        }
        .onReceive(favoritesService.objectWillChange) { _ in
            // Update state when favorites change
            isFavorited = favoritesService.isFavorited(videoId)
        }
    }
}

// MARK: - Button Style
struct VideoThumbnailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.clear)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .overlay {
                // Show play overlay on press/hover
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.hitRewindPurple.opacity(0.2))
                        .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
                }
            }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        VideoThumbnailView(
            videoId: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            artist: "Rick Astley",
            year: "1987"
        ) {
            print("Video tapped")
        }
        .frame(width: 200)
        
        VideoThumbnailView(
            videoId: "invalid_id",
            title: "Test Video with Long Title That Spans Multiple Lines",
            artist: "Test Artist",
            year: "2023"
        ) {
            print("Video tapped")
        }
        .frame(width: 200)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}