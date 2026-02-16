//
//  MusicVideosView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import SuperwallKit

struct MusicVideosView: View {
    @ObservedObject private var airtableService = AirtableService.shared
    @StateObject private var youtubeService = YouTubeService()
    @StateObject private var playerCoordinator = YouTubePlayerCoordinator()

    @State private var selectedYear: Int?
    @State private var selectedPlaylist: Playlist?
    @State private var visibleVideoIndices: [Int] = []
    @State private var selectedVideoId: String?
    @State private var isLoadingVideoInfo = false

    // Device and orientation detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var body: some View {
        NavigationStack {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad layout with permanent sidebar
                iPadLayout
            } else {
                // iPhone layout with sliding sidebar
                iPhoneLayout
            }
        }
        .task {
            // Only fetch if not already loaded (prevents reload on navigation back)
            if airtableService.playlists.isEmpty {
                await airtableService.fetchPlaylists()
            }
            selectFirstAvailableYear()
        }
        .refreshable {
            // Pull-to-refresh support
            await airtableService.forceRefreshPlaylists()
            if let year = selectedYear {
                await batchLoadVideoInfo(for: year)
            }
        }
    }
    
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Permanent sidebar
            YearSidebarView(
                years: availableYears,
                selectedYear: $selectedYear,
                onYearSelected: handleYearSelection
            )
            .frame(width: 200)
            .background(Color.hitRewindBackground)
            
            // Main content area
            VStack(alignment: .leading, spacing: 0) {
                // Custom header row
                HStack {
                    // Left side - invisible spacer to balance right side
                    HStack(spacing: 16) {
                        Color.clear
                            .frame(width: 22, height: 22)
                        Color.clear
                            .frame(width: 22, height: 22)
                    }

                    Spacer()

                    // Logo centered
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(Color.hitRewindBackground)

                videoGridView
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        GeometryReader { geometry in
            let sidebarWidth: CGFloat = 70
            let videosWidth = geometry.size.width - sidebarWidth

            HStack(spacing: 0) {
                // Column 1: Videos area (with 3-column subgrid inside)
                videoGridView
                    .frame(width: videosWidth)

                // Column 2: Years sidebar (fixed width)
                YearSidebarView(
                    years: availableYears,
                    selectedYear: $selectedYear,
                    onYearSelected: handleYearSelection
                )
                .frame(width: sidebarWidth)
                .background(Color.hitRewindBackground)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
            }
        }
        .background(
            NavigationConfigurator { nc in
                nc.hidesBarsOnSwipe = true
            }
        )
    }
    
    // MARK: - Video Grid View
    private var videoGridView: some View {
        Group {
            let _ = print("🔍 videoGridView: isLoading=\(airtableService.isLoading), isShowingSpotifyChart=\(isShowingSpotifyChart), spotifyChartVideos.count=\(airtableService.spotifyChartVideos.count), selectedPlaylist=\(selectedPlaylist != nil), visibleVideoIndices.count=\(visibleVideoIndices.count)")
            if airtableService.isLoading {
                LoadingView()
            } else if let errorMessage = airtableService.errorMessage {
                ErrorView(message: errorMessage) {
                    Task {
                        await airtableService.fetchPlaylists()
                    }
                }
            } else if isShowingSpotifyChart && !airtableService.spotifyChartVideos.isEmpty {
                // Spotify Top 50 chart
                let _ = print("✅ Showing Spotify chart grid with \(airtableService.spotifyChartVideos.count) videos")
                videoGrid
            } else if selectedPlaylist != nil && !visibleVideoIndices.isEmpty {
                // Regular year playlist
                videoGrid
            } else {
                let _ = print("⚠️ Showing ContentUnavailableView - no videos condition")
                ContentUnavailableView(
                    "No Videos Available",
                    systemImage: "music.note.list",
                    description: Text("Select a year to view music videos")
                )
            }
        }
    }
    
    private var videoGrid: some View {
        ScrollView {
            scrollContent
        }
        .id(selectedYear) // Reset scroll position when year changes
    }

    // Title text for the current view
    private var gridTitle: String {
        if isShowingSpotifyChart {
            return "Top Today"
        } else {
            return "Music Videos \(String(selectedYear ?? 2025))"
        }
    }

    private var scrollContent: some View {
        Group {
            VStack(alignment: .center, spacing: 16) {
                Text(gridTitle)
                    .font(.custom(AppFont.ticketingName(), size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.hitRewindPrimaryText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, gridPadding)
            }
            .padding(.top, gridPadding)
            
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(visibleVideos) { item in
                    Button(action: {
                        handleVideoTap(item: item)
                    }) {
                        VideoThumbnailView(
                            videoId: item.id,
                            title: item.title,
                            artist: item.artist,
                            year: item.year,
                            onTap: {},
                            rank: item.rank,
                            hideDuration: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(gridPadding)
            .navigationDestination(isPresented: Binding(
                get: { selectedVideoId != nil },
                set: { if !$0 { selectedVideoId = nil } }
            )) {
                if let videoId = selectedVideoId,
                   let video = visibleVideos.first(where: { $0.id == videoId }) {
                    createVideoView(from: video)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var availableYears: [Int] {
        let years = airtableService.playlists.map { $0.fields.year }
        let sortedYears = Array(Set(years)).sorted(by: >)
        // Add "Top Today" (Spotify chart) at the top
        return [kSpotifyTop50Year] + sortedYears
    }

    // Check if currently showing Spotify Top 50
    private var isShowingSpotifyChart: Bool {
        selectedYear == kSpotifyTop50Year
    }
    
    private var gridColumns: [GridItem] {
        // Force 3 columns with flexible sizing (minimum 50pt to ensure they fit)
        return [
            GridItem(.flexible(minimum: 50), spacing: gridSpacing),
            GridItem(.flexible(minimum: 50), spacing: gridSpacing),
            GridItem(.flexible(minimum: 50), spacing: gridSpacing)
        ]
    }

    private var gridSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 12 : 4
    }

    private var gridPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 12 : 4
    }
    
    // MARK: - Helper Methods
    private var navigationTitleString: String {
        return "Top Music Videos"
    }
    private func selectFirstAvailableYear() {
        guard selectedYear == nil, let firstYear = availableYears.first else {
            // If year already selected, still trigger batch load on app launch
            if let year = selectedYear {
                Task {
                    await batchLoadVideoInfo(for: year)
                }
            }
            return
        }
        selectedYear = firstYear
        handleYearSelection(firstYear)
    }
    
    private func handleVideoTap(item: VisibleVideo) {
        print("🎥 Video \(item.id) tapped")

        // Check test subscriber mode first (for development testing)
        if PaywallService.shared.testSubscriberMode {
            print("🧪 Test subscriber mode enabled - playing video")
            self.selectedVideoId = item.id
            return
        }

        Task { @MainActor in
            // Check StoreKit directly for active subscription
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()

            if isSubscribed {
                // User is subscribed - play video immediately
                print("✅ User subscribed - playing video")
                self.selectedVideoId = item.id
            } else {
                // User not subscribed - show paywall
                print("🔒 User not subscribed - showing paywall")
                PaywallService.shared.presentPaywallWithOrientation {
                    // After successful purchase, play video
                    print("✅ Purchase complete - playing video")
                    self.selectedVideoId = item.id
                }
            }
        }
    }

    private func createVideoView(from video: VisibleVideo) -> VJModeView {
        // Build playlist context for autoplay
        let playlistVideos = visibleVideos.map { video in
            PlaylistVideo(
                id: video.id,
                youtubeURL: video.originalURL,
                title: video.title,
                artist: video.artist,
                year: video.year
            )
        }

        // Find current video index
        guard let currentIndex = playlistVideos.firstIndex(where: { $0.id == video.id }) else {
            print("⚠️ Could not find video index for autoplay")
            let fallbackVideo = PlaylistVideo(
                id: video.id,
                youtubeURL: video.originalURL,
                title: video.title,
                artist: video.artist,
                year: video.year
            )
            return VJModeView(
                playerCoordinator: playerCoordinator,
                initialVideo: fallbackVideo,
                videos: [],
                playlistContext: nil
            )
        }

        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex
        )

        let initialVideo = playlistVideos[currentIndex]

        return VJModeView(
            playerCoordinator: playerCoordinator,
            initialVideo: initialVideo,
            videos: playlistVideos,
            playlistContext: playlistContext
        )
    }

    private func handleYearSelection(_ year: Int) {
        print("📅 Year selected: \(String(year))")
        selectedYear = year

        if year == kSpotifyTop50Year {
            // Handle Spotify Top Today selection
            print("🎵 Loading Spotify Top Today chart")
            selectedPlaylist = nil
            visibleVideoIndices = []
            // Set loading state IMMEDIATELY before Task starts (avoids race condition)
            airtableService.isLoading = true
            Task {
                await airtableService.fetchSpotifyChartVideos()
                // Batch load video info for Spotify chart videos
                await batchLoadVideoInfoForSpotifyChart()
            }
        } else {
            // Handle regular year selection
            selectedPlaylist = airtableService.playlists.first { $0.fields.year == year }
            updateVisibleVideoIndices()
            print("🎵 Found playlist: \(selectedPlaylist?.fields.title ?? "None") with \(visibleVideoIndices.count) visible videos")

            // Batch load video info for this year
            Task {
                await batchLoadVideoInfo(for: year)
            }
        }
    }

    /// Batch load video info for Spotify chart videos
    private func batchLoadVideoInfoForSpotifyChart() async {
        let videoInfoCache = VideoInfoCache.shared

        let videoIds = airtableService.spotifyChartVideos.compactMap { video -> String? in
            guard let url = video.fields.url else { return nil }
            return extractYouTubeVideoID(from: url)
        }

        guard !videoIds.isEmpty else { return }

        var uncachedIds: [String] = []
        for id in videoIds {
            if await videoInfoCache.info(for: id) == nil {
                uncachedIds.append(id)
            }
        }

        guard !uncachedIds.isEmpty else {
            print("✅ All \(videoIds.count) Spotify chart videos already cached")
            return
        }

        print("🎬 Batch loading video info for \(uncachedIds.count) Spotify chart videos...")
        isLoadingVideoInfo = true

        do {
            let videos = try await youtubeService.getBatchVideoInfo(videoIds: uncachedIds)
            await videoInfoCache.storeBatch(videos, youtubeService: youtubeService)
            print("✅ Batch loaded info for \(videos.count) videos")
        } catch {
            print("❌ Batch load failed: \(error)")
        }

        isLoadingVideoInfo = false
    }

    /// Batch load video info (duration, view count) for all videos in a year
    private func batchLoadVideoInfo(for year: Int) async {
        let videoInfoCache = VideoInfoCache.shared

        // Check if already loading this year
        if await videoInfoCache.isLoadingYear(year) {
            print("⏳ Already loading video info for \(year)")
            return
        }

        // Get video IDs for this year
        let videoIds = visibleVideos.map { $0.id }
        guard !videoIds.isEmpty else { return }

        // Check how many are already cached
        var uncachedIds: [String] = []
        for id in videoIds {
            if await videoInfoCache.info(for: id) == nil {
                uncachedIds.append(id)
            }
        }

        guard !uncachedIds.isEmpty else {
            print("✅ All \(videoIds.count) videos for \(year) already cached")
            return
        }

        print("🎬 Batch loading video info for \(uncachedIds.count) videos in \(year)...")
        await videoInfoCache.startLoadingYear(year)
        isLoadingVideoInfo = true

        do {
            // Use batch API - fetches up to 50 videos per request
            let videos = try await youtubeService.getBatchVideoInfo(videoIds: uncachedIds)
            await videoInfoCache.storeBatch(videos, youtubeService: youtubeService)
            print("✅ Batch loaded info for \(videos.count) videos")
        } catch {
            print("❌ Batch load failed: \(error)")
        }

        await videoInfoCache.finishLoadingYear(year)
        isLoadingVideoInfo = false
    }
    
    private func updateVisibleVideoIndices() {
        guard let playlist = selectedPlaylist else {
            visibleVideoIndices = []
            return
        }
        
        visibleVideoIndices = playlist.fields.isVisible.enumerated().compactMap { index, isVisible in
            (isVisible ?? false) ? index : nil
        }
    }
}

// MARK: - Visible Video Model
private struct VisibleVideo: Identifiable, Hashable {
    let id: String        // YouTube videoId (for VideoThumbnailView compatibility)
    let originalURL: String  // Full YouTube URL with timestamps
    let title: String
    let artist: String
    let year: String
    let rank: Int?        // Spotify chart rank (nil for regular year videos)
}

private extension MusicVideosView {
    var visibleVideos: [VisibleVideo] {
        // Handle Spotify Top 50 chart
        if selectedYear == kSpotifyTop50Year {
            print("🎯 visibleVideos: Processing Spotify chart, spotifyChartVideos.count = \(airtableService.spotifyChartVideos.count)")
            let results = airtableService.spotifyChartVideos.compactMap { video -> VisibleVideo? in
                guard let url = video.fields.url,
                      let videoId = extractYouTubeVideoID(from: url) else {
                    print("  ⚠️ Skipping video: url=\(video.fields.url ?? "nil"), extraction failed")
                    return nil
                }
                let title = video.fields.title ?? "Unknown Title"
                let artist = video.fields.artistName ?? "Unknown Artist"
                let rank = video.fields.rank ?? 0
                return VisibleVideo(
                    id: videoId,
                    originalURL: url,
                    title: title,
                    artist: artist,
                    year: "Top Today",
                    rank: rank
                )
            }
            print("🎯 visibleVideos: Returning \(results.count) Spotify chart videos")
            return results
        }

        // Handle regular year playlists
        guard let playlist = selectedPlaylist else { return [] }
        var result: [VisibleVideo] = []
        for index in visibleVideoIndices {
            if let url = playlist.fields.videoUrls?[safe: index],
               let videoId = extractYouTubeVideoID(from: url) {
                let title = playlist.fields.videoTitles?[safe: index] ?? "Unknown Title"
                let artist = playlist.fields.artistNames?[safe: index] ?? "Unknown Artist"
                result.append(VisibleVideo(id: videoId, originalURL: url, title: title, artist: artist, year: String(playlist.fields.year), rank: nil))
            }
        }
        return result
    }
}

// MARK: - Supporting Views
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.hitRewindPurple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.hitRewindSecondaryText)
                .padding(.horizontal)
            
            Button("Try Again") {
                retry()
            }
            .buttonStyle(HitRewindButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Structures

struct HitRewindButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .hitRewindPurple.opacity(0.7) : .hitRewindPurple)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.hitRewindPurple, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Array Extension

// MARK: - Preview
#Preview {
    MusicVideosView()
        .preferredColorScheme(.dark)
}