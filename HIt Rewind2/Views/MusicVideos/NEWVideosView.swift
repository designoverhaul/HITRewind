//
//  NEWVideosView.swift
//  HIt Rewind2
//
//  Test view for MTvVideosNEW table (direct video records)
//  Created by Aaron Heine on 1/11/26.
//

import SwiftUI

struct NEWVideosView: View {
    @ObservedObject private var videoService = DirectVideoService.shared

    @State private var selectedYear: Int?
    @State private var selectedVideoId: String?

    // YouTube player coordinator for VJModeView (landscape video player)
    @StateObject private var playerCoordinator = YouTubePlayerCoordinator()

    // Header hide/show offset and scroll tracking (iPhone only)
    @State private var headerOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    private var headerHeight: CGFloat { 56 }

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
            await videoService.fetchVideos()
            selectFirstAvailableYear()
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
                    Spacer()

                    // Logo centered
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)

                    Spacer()

                    // Search and settings on right
                    HStack(spacing: 16) {
                        NavigationLink(destination: SearchView()) {
                            Text("🔍")
                        }
                        NavigationLink(destination: SettingsView()) {
                            Text("⚙️")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.hitRewindBackground)

                videoGridView
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedVideoId != nil },
            set: { if !$0 { selectedVideoId = nil } }
        )) {
            if let videoId = selectedVideoId,
               let video = currentYearVideos.first(where: { $0.fields.youtubeVideoId == videoId }) {
                createVideoView(from: video)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - iPhone Layout (with headroom effect) - Landscape only
    private var iPhoneLayout: some View {
        GeometryReader { geometry in
            let sidebarWidth: CGFloat = 80 // Fixed width for year sidebar
            let gridWidth = geometry.size.width - sidebarWidth

            HStack(spacing: 0) {
                // Video grid (3 columns) with headroom scroll tracking
                videoGridContent
                    .frame(width: gridWidth)

                // Years sidebar (fixed width, on right side)
                YearSidebarView(
                    years: availableYears,
                    selectedYear: $selectedYear,
                    onYearSelected: handleYearSelection
                )
                .frame(width: sidebarWidth)
                .background(Color.hitRewindBackground)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HeadroomHeader(height: headerHeight)
                .offset(y: headerOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: headerOffset)
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedVideoId != nil },
            set: { if !$0 { selectedVideoId = nil } }
        )) {
            if let videoId = selectedVideoId,
               let video = currentYearVideos.first(where: { $0.fields.youtubeVideoId == videoId }) {
                createVideoView(from: video)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - Video Grid Content
    private var videoGridContent: some View {
        Group {
            if videoService.isLoading {
                LoadingView()
            } else if let errorMessage = videoService.errorMessage {
                ErrorView(message: errorMessage) {
                    Task {
                        await videoService.fetchVideos()
                    }
                }
            } else if selectedYear != nil && !currentYearVideos.isEmpty {
                videoGridScrollView
            } else {
                ContentUnavailableView(
                    "No Videos Available",
                    systemImage: "music.note.list",
                    description: Text("Select a year to view music videos")
                )
            }
        }
    }

    private var videoGridScrollView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Show subtitle for Today (TopToday) section
                if isShowingTopToday {
                    Text("Most streamed songs globally 🌎")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }

                LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                    ForEach(currentYearVideos) { video in
                        Button(action: {
                            handleVideoTap(video: video)
                        }) {
                            if let videoId = video.fields.youtubeVideoId {
                                VideoThumbnailView(
                                    videoId: videoId,
                                    title: video.fields.title ?? "Unknown",
                                    artist: video.fields.artistName ?? "Unknown Artist",
                                    year: video.fields.year ?? "",
                                    onTap: {},
                                    rank: video.fields.rank,
                                    hideDuration: true
                                )
                            } else {
                                Text(video.fields.title ?? "Unknown Video")
                                    .foregroundColor(.hitRewindPrimaryText)
                                    .frame(height: 200)
                                    .background(Color.hitRewindBackground)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(gridPadding)
            }
        }
        .id(selectedYear) // Reset scroll position when year changes
        .headroomScrollTracking(
            headerOffset: $headerOffset,
            lastScrollOffset: $lastScrollOffset,
            headerHeight: headerHeight
        )
    }

    // MARK: - Video Grid View (iPad)
    private var videoGridView: some View {
        Group {
            if videoService.isLoading {
                LoadingView()
            } else if let errorMessage = videoService.errorMessage {
                ErrorView(message: errorMessage) {
                    Task {
                        await videoService.fetchVideos()
                    }
                }
            } else if selectedYear != nil && !currentYearVideos.isEmpty {
                videoGrid
            } else {
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
            VStack(spacing: 8) {
                // Show subtitle for Today (TopToday) section
                if isShowingTopToday {
                    Text("Most streamed songs globally 🌎")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }

                LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                    ForEach(currentYearVideos) { video in
                        Button(action: {
                            handleVideoTap(video: video)
                        }) {
                            if let videoId = video.fields.youtubeVideoId {
                                VideoThumbnailView(
                                    videoId: videoId,
                                    title: video.fields.title ?? "Unknown",
                                    artist: video.fields.artistName ?? "Unknown Artist",
                                    year: video.fields.year ?? "",
                                    onTap: {},
                                    rank: video.fields.rank,
                                    hideDuration: true
                                )
                            } else {
                                Text(video.fields.title ?? "Unknown Video")
                                    .foregroundColor(.hitRewindPrimaryText)
                                    .frame(height: 200)
                                    .background(Color.hitRewindBackground)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(gridPadding)
            }
        }
        .id(selectedYear) // Reset scroll position when year changes
    }

    // MARK: - Computed Properties

    // Check if showing TopToday
    private var isShowingTopToday: Bool {
        selectedYear == kSpotifyTop50Year
    }

    private var availableYears: [Int] {
        // Add "Today" (kSpotifyTop50Year = 9999) at the top of the list
        [kSpotifyTop50Year] + videoService.availableYears
    }

    private var currentYearVideos: [DirectVideoRecord] {
        guard let year = selectedYear else { return [] }
        // Return TopToday videos if that's selected
        if year == kSpotifyTop50Year {
            return videoService.topTodayVideos
        }
        return videoService.videos(forYear: year)
    }

    private var gridColumns: [GridItem] {
        // Always 3 columns - iPhone landscape only
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private var gridSpacing: CGFloat { 8 }

    private var gridPadding: CGFloat { 8 }

    // MARK: - Helper Methods
    private func selectFirstAvailableYear() {
        guard selectedYear == nil, let firstYear = availableYears.first else { return }
        selectedYear = firstYear
        handleYearSelection(firstYear)
    }

    private func handleVideoTap(video: DirectVideoRecord) {
        guard let videoId = video.fields.youtubeVideoId else { return }
        print("🎥 NEW Video \(videoId) tapped - \(video.fields.title)")

        Task { @MainActor in
            // Check StoreKit directly for active subscription
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()

            if isSubscribed {
                // User is subscribed - play video immediately
                print("✅ User subscribed - playing video")
                self.selectedVideoId = videoId
            } else {
                // User not subscribed - show paywall with orientation handling
                print("🔒 User not subscribed - showing paywall")
                PaywallService.shared.presentPaywallWithOrientation {
                    // After successful purchase, play video
                    print("✅ Purchase complete - playing video")
                    self.selectedVideoId = videoId
                }
            }
        }
    }

    private func createVideoView(from video: DirectVideoRecord) -> VJModeView {
        // Build playlist context for autoplay
        let playlistVideos = currentYearVideos.compactMap { record -> PlaylistVideo? in
            guard let videoId = record.fields.youtubeVideoId,
                  let url = record.fields.url else { return nil }
            return PlaylistVideo(
                id: videoId,
                youtubeURL: url,
                title: record.fields.title ?? "Unknown",
                artist: record.fields.artistName ?? "Unknown Artist",
                year: record.fields.year ?? "",
                rank: record.fields.rank
            )
        }

        // Find current video index
        guard let videoId = video.fields.youtubeVideoId,
              let currentIndex = playlistVideos.firstIndex(where: { $0.id == videoId }) else {
            print("⚠️ Could not find video index for autoplay")
            let fallbackVideo = PlaylistVideo(
                id: extractYouTubeVideoID(from: video.fields.url ?? "") ?? "",
                youtubeURL: video.fields.url ?? "",
                title: video.fields.title ?? "Unknown",
                artist: video.fields.artistName ?? "Unknown Artist",
                year: video.fields.year ?? "",
                rank: video.fields.rank
            )
            return VJModeView(
                playerCoordinator: playerCoordinator,
                initialVideo: fallbackVideo,
                videos: playlistVideos,
                playlistContext: nil
            )
        }

        let currentVideo = playlistVideos[currentIndex]

        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex
        )

        return VJModeView(
            playerCoordinator: playerCoordinator,
            initialVideo: currentVideo,
            videos: playlistVideos,
            playlistContext: playlistContext
        )
    }

    private func handleYearSelection(_ year: Int) {
        print("📅 NEW - Year selected: \(String(year))")
        selectedYear = year

        if year == kSpotifyTop50Year {
            // Fetch TopToday videos
            print("🎵 Loading TopToday chart")
            Task {
                await videoService.fetchTopTodayVideos()
                print("🎵 Found \(videoService.topTodayVideos.count) videos in TopToday")
            }
        } else {
            let videos = videoService.videos(forYear: year)
            print("🎵 Found \(videos.count) videos for year \(year) in MTvVideosNEW")
        }
    }
}

// MARK: - Preview
#Preview {
    NEWVideosView()
        .preferredColorScheme(.dark)
}
