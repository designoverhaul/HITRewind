//
//  MusicVideosView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import SuperwallKit

struct MusicVideosView: View {
    @StateObject private var airtableService = AirtableService()
    @StateObject private var youtubeService = YouTubeService()

    @State private var selectedYear: Int?
    @State private var selectedPlaylist: Playlist?
    @State private var visibleVideoIndices: [Int] = []
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
            await airtableService.fetchPlaylists()
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
            if airtableService.isLoading {
                LoadingView()
            } else if let errorMessage = airtableService.errorMessage {
                ErrorView(message: errorMessage) {
                    Task {
                        await airtableService.fetchPlaylists()
                    }
                }
            } else if selectedPlaylist != nil && !visibleVideoIndices.isEmpty {
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
                Text("Music Videos \(String(selectedYear ?? 2025))")
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
                            onTap: {}
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .id(selectedPlaylist?.id)
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
        return Array(Set(years)).sorted(by: >)
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
    private var navigationTitleString: String {
        return "Top Music Videos"
    }
    private func selectFirstAvailableYear() {
        guard selectedYear == nil, let firstYear = availableYears.first else { return }
        selectedYear = firstYear
        handleYearSelection(firstYear)
    }
    
    private func handleVideoTap(item: VisibleVideo) {
        print("🎥 Video \(item.id) tapped")

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
                Superwall.shared.register(placement: "MainPlacement") {
                    // After successful purchase, play video
                    print("✅ Purchase complete - playing video")
                    self.selectedVideoId = item.id
                }
            }
        }
    }

    private func createVideoView(from video: VisibleVideo) -> SingleVideoView {
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
            return SingleVideoView(
                youtubeURL: video.originalURL,
                videoTitle: video.title,
                artistName: video.artist,
                year: video.year,
                playlistContext: nil
            )
        }

        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex
        )

        return SingleVideoView(
            youtubeURL: video.originalURL,
            videoTitle: video.title,
            artistName: video.artist,
            year: video.year,
            playlistContext: playlistContext
        )
    }

    private func handleYearSelection(_ year: Int) {
        print("📅 Year selected: \(String(year))")
        selectedYear = year
        selectedPlaylist = airtableService.playlists.first { $0.fields.year == year }
        updateVisibleVideoIndices()
        print("🎵 Found playlist: \(selectedPlaylist?.fields.title ?? "None") with \(visibleVideoIndices.count) visible videos")
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
}

private extension MusicVideosView {
    var visibleVideos: [VisibleVideo] {
        guard let playlist = selectedPlaylist else { return [] }
        var result: [VisibleVideo] = []
        for index in visibleVideoIndices {
            if let url = playlist.fields.videoUrls?[safe: index],
               let videoId = extractYouTubeVideoID(from: url) {
                let title = playlist.fields.videoTitles?[safe: index] ?? "Unknown Title"
                let artist = playlist.fields.artistNames?[safe: index] ?? "Unknown Artist"
                result.append(VisibleVideo(id: videoId, originalURL: url, title: title, artist: artist, year: String(playlist.fields.year)))
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