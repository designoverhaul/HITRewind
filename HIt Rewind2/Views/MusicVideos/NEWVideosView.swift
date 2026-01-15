//
//  NEWVideosView.swift
//  HIt Rewind2
//
//  Test view for MTvVideosNEW table (direct video records)
//  Created by Aaron Heine on 1/11/26.
//

import SwiftUI
import SuperwallKit

struct NEWVideosView: View {
    @StateObject private var videoService = DirectVideoService()

    @State private var selectedYear: Int?
    @State private var selectedVideoId: String?

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
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Years sidebar (1/4 width)
                YearSidebarView(
                    years: availableYears,
                    selectedYear: $selectedYear,
                    onYearSelected: handleYearSelection
                )
                .frame(width: geometry.size.width * 0.25)
                .background(Color.hitRewindBackground)

                // Video grid (3/4 width)
                videoGridView
                    .frame(width: geometry.size.width * 0.75)
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
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    NavigationLink(destination: SearchView()) {
                        Text("🔍")
                    }
                    NavigationLink(destination: SettingsView()) {
                        Text("⚙️")
                    }
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
            VStack(alignment: .center, spacing: 16) {
                Text("Top Hits \(String(selectedYear ?? 2025))")
                    .font(.custom(AppFont.ticketingName(), size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.hitRewindPrimaryText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, gridPadding)
            }
            .padding(.top, gridPadding)

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
                            // Fallback if video ID can't be extracted
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
            .navigationDestination(isPresented: Binding(
                get: { selectedVideoId != nil },
                set: { if !$0 { selectedVideoId = nil } }
            )) {
                if let videoId = selectedVideoId,
                   let video = currentYearVideos.first(where: { $0.fields.youtubeVideoId == videoId }) {
                    createVideoView(from: video)
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var availableYears: [Int] {
        videoService.availableYears
    }

    private var currentYearVideos: [DirectVideoRecord] {
        guard let year = selectedYear else { return [] }
        return videoService.videos(forYear: year)
    }

    private var gridColumns: [GridItem] {
        let count = columnCount
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: count)
    }

    private var columnCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 3
        } else {
            return verticalSizeClass == .regular ? 1 : 2
        }
    }

    private var gridSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
    }

    private var gridPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
    }

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
                // User not subscribed - show paywall
                print("🔒 User not subscribed - showing paywall")
                Superwall.shared.register(placement: "MainPlacement") {
                    // After successful purchase, play video
                    print("✅ Purchase complete - playing video")
                    self.selectedVideoId = videoId
                }
            }
        }
    }

    private func createVideoView(from video: DirectVideoRecord) -> SingleVideoView {
        // Build playlist context for autoplay
        let playlistVideos = currentYearVideos.compactMap { record -> PlaylistVideo? in
            guard let videoId = record.fields.youtubeVideoId,
                  let url = record.fields.url else { return nil }
            return PlaylistVideo(
                id: videoId,
                youtubeURL: url,
                title: record.fields.title ?? "Unknown",
                artist: record.fields.artistName ?? "Unknown Artist",
                year: record.fields.year ?? ""
            )
        }

        // Find current video index
        guard let videoId = video.fields.youtubeVideoId,
              let url = video.fields.url,
              let currentIndex = playlistVideos.firstIndex(where: { $0.id == videoId }) else {
            print("⚠️ Could not find video index for autoplay")
            return SingleVideoView(
                youtubeURL: video.fields.url ?? "https://www.youtube.com",
                videoTitle: video.fields.title ?? "Unknown",
                artistName: video.fields.artistName ?? "Unknown Artist",
                year: video.fields.year ?? "",
                playlistContext: nil
            )
        }

        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex
        )

        return SingleVideoView(
            youtubeURL: video.fields.url ?? "",
            videoTitle: video.fields.title ?? "Unknown",
            artistName: video.fields.artistName ?? "Unknown Artist",
            year: video.fields.year ?? "",
            playlistContext: playlistContext
        )
    }

    private func handleYearSelection(_ year: Int) {
        print("📅 NEW - Year selected: \(String(year))")
        selectedYear = year
        let videos = videoService.videos(forYear: year)
        print("🎵 Found \(videos.count) videos for year \(year) in MTvVideosNEW")
    }
}

// MARK: - Preview
#Preview {
    NEWVideosView()
        .preferredColorScheme(.dark)
}
