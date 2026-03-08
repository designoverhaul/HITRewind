//
//  ArtistSongsView.swift
//  HIt Rewind2
//
//  Created by Assistant on 8/25/25.
//

import SwiftUI

// MARK: - Reusable Headline Component
struct HitRewindHeadline: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.custom(AppFont.ticketingName(), size: 20))
            .fontWeight(.bold)
            .foregroundColor(.hitRewindPrimaryText)
    }
}

struct ArtistVideo: Identifiable {
    let id: String // use videoId as stable id
    let title: String
    let videoId: String
    let year: String
}

struct ArtistSongsView: View {
    let artistName: String
    @State private var videos: [ArtistVideo] = []
    
    // Device and orientation detection for grid layout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // iPad only: Custom header row (Row 2)
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadHeaderView
            }
            
            mainContentView
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(UIDevice.current.userInterfaceIdiom != .pad)
        .toolbar {
            toolbarContent
        }
        .task {
            await loadArtistVideos()
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // iPad: Row 1 (System Navigation Bar) - back button left, search/settings right
        if UIDevice.current.userInterfaceIdiom == .pad {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.hitRewindPurple)
                }
            }
            
        } else {
            // iPhone: Keep existing toolbar structure
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.hitRewindPurple)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var iPadHeaderView: some View {
        HStack {
            // No sidebar icon for Artist Songs page
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
    }

    private var mainContentView: some View {
        Group {
            if videos.isEmpty {
                loadingView
            } else {
                videosScrollView
            }
        }
    }
    
    private var loadingView: some View {
        SpinningRecordView(size: 30)
    }
    
    private var videosScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HitRewindHeadline(text: artistName)
                    .padding(.horizontal, gridPadding)
            }
            .padding(.top, gridPadding)
            
            videosGridView
        }
    }
    
    private var videosGridView: some View {
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            ForEach(videos) { item in
                Button(action: {
                    handleVideoTap(video: item)
                }) {
                    VideoThumbnailView(
                        videoId: item.videoId,
                        title: item.title,
                        artist: artistName,
                        year: item.year,
                        onTap: {},
                        hideArtistName: true,
                        hideDuration: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(gridPadding)
    }

    private func handleVideoTap(video: ArtistVideo) {
        if PaywallService.shared.testSubscriberMode {
            openVideoInMiniPlayer(video: video)
            return
        }

        Task { @MainActor in
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()
            if isSubscribed {
                openVideoInMiniPlayer(video: video)
            } else {
                PaywallService.shared.presentPaywallWithOrientation {
                    openVideoInMiniPlayer(video: video)
                }
            }
        }
    }

    private func openVideoInMiniPlayer(video: ArtistVideo) {
        let playlistVideos = videos.map { v in
            PlaylistVideo(
                id: v.videoId,
                youtubeURL: "https://www.youtube.com/watch?v=\(v.videoId)",
                title: v.title,
                artist: artistName,
                year: v.year
            )
        }

        let currentIndex = videos.firstIndex(where: { $0.id == video.id }) ?? 0

        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex,
            sourceType: .musicVideos
        )

        let initialVideo = playlistVideos[currentIndex]

        MiniPlayerManager.shared.openVJMode(
            video: initialVideo,
            videos: playlistVideos,
            playlistContext: playlistContext
        )
    }
    
    private func loadArtistVideos() async {
        let service = DirectVideoService.shared
        await service.fetchVideos()

        let results = service.videos
            .filter { $0.fields.artistName?.caseInsensitiveCompare(artistName) == .orderedSame }
            .compactMap { record -> ArtistVideo? in
                guard let title = record.fields.title,
                      let videoId = record.fields.youtubeVideoId else { return nil }
                return ArtistVideo(id: videoId, title: title, videoId: videoId, year: record.fields.year ?? "")
            }

        // Sort by year (newest first), then by title
        videos = results.sorted { first, second in
            if let firstYear = Int(first.year), let secondYear = Int(second.year) {
                if firstYear != secondYear {
                    return firstYear > secondYear
                }
            }
            return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
        }
    }
    
    // MARK: - Grid helpers
    private var gridColumns: [GridItem] {
        let count = columnCount
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: count)
    }
    
    private var columnCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: 2 columns in portrait, 3 columns in landscape
            return horizontalSizeClass == .regular ? 3 : 2
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
}

#Preview {
    NavigationView {
        ArtistSongsView(artistName: "Taylor Swift")
    }
    .preferredColorScheme(.dark)
}


