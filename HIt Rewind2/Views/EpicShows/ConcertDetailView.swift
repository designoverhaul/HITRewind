//
//  ConcertDetailView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI

struct ConcertDetailView: View {
    let concert: Concert

    @StateObject private var airtableService = AirtableService()
    @StateObject private var favoritesService = FavoritesService.shared
    @ObservedObject private var directVideoService = DirectVideoService.shared

    // YouTube player coordinator for VJModeView (landscape video player)
    @StateObject private var playerCoordinator = YouTubePlayerCoordinator()
    @State private var concertVideos: [ConcertVideo] = []
    @State private var isLoadingVideos = true
    @State private var errorMessage: String?
    @State private var selectedVideoId: String?
    @State private var selectedVideoInfo: ConcertVideo?

    // Header hide/show offset and scroll tracking
    @State private var headerOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0

    // Device and orientation detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.dismiss) private var dismiss

    // Check if this is a "Top Today" concert that should fetch from TopToday table
    private var isTopTodayConcert: Bool {
        let artistLower = concert.fields.artistName.lowercased()
        let venueLower = (concert.fields.venueName ?? "").lowercased()
        return artistLower.contains("spotify") ||
               artistLower.contains("top today") ||
               venueLower.contains("top today") ||
               venueLower.contains("top 50")
    }
    
    private var headerHeight: CGFloat { 56 }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .navigationBarHidden(true)
        .task {
            print("🎪 ConcertDetailView loaded for: \(concert.fields.artistName) - \(concert.fields.venueName ?? "Unknown Venue")")
            await loadConcertVideos()
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedVideoId != nil },
            set: { if !$0 { selectedVideoId = nil; selectedVideoInfo = nil } }
        )) {
            if let video = selectedVideoInfo {
                createVideoView(from: video)
            }
        }
    }

    // MARK: - iPad Layout (static header with back button)
    private var iPadLayout: some View {
        ZStack(alignment: .top) {
            // Background image that extends edge-to-edge
            backgroundImageView
                .ignoresSafeArea()

            // Main content layered on top
            VStack(alignment: .leading, spacing: 0) {
                // Static iPad header with back button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.hitRewindPurple)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)

                    Spacer()

                    // Balance the layout
                    Spacer()
                        .frame(width: 44)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.clear)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroContentOverlay
                        contentSection
                    }
                }
            }
        }
        .background(Color.hitRewindBackground)
    }

    // MARK: - iPhone Layout (headroom header that hides on scroll)
    private var iPhoneLayout: some View {
        ZStack(alignment: .top) {
            // Background image that extends edge-to-edge
            backgroundImageView
                .ignoresSafeArea()

            // Main content layered on top
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroContentOverlay
                    contentSection
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HeadroomHeader(height: headerHeight, showBackButton: true, onBackTap: { dismiss() })
                    .offset(y: headerOffset)
                    .animation(.spring(response: 0.35, dampingFraction: 0.9), value: headerOffset)
            }
            .headroomScrollTracking(
                headerOffset: $headerOffset,
                lastScrollOffset: $lastScrollOffset,
                headerHeight: headerHeight
            )
        }
        .background(Color.hitRewindBackground)
    }
    
    // MARK: - Hero Content Overlay (Text only, background is in ZStack)
    private var heroContentOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artist name and year in system font
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(concert.fields.artistName)
                    .font(.system(size: heroArtistFontSize, weight: .semibold))
                    .foregroundColor(.hitRewindPurple)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)

                Text(String(concert.fields.eventYear))
                    .font(.system(size: heroArtistFontSize, weight: .semibold))
                    .foregroundColor(.hitRewindPurple)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
            }

            // Concert title (venue only) in large white text with ticketing font
            Text(concert.fields.venueName ?? "Unknown Venue")
                .font(.custom(AppFont.ticketingName(), size: heroTitleFontSize))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 2, x: 0, y: 1)

            // Description - full text, responsive height
            if let description = concert.fields.eventDescription, !description.isEmpty {
                Text(description)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            // Star rating with video counter (Apple TV style)
            HStack {
                HStack(spacing: 4) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.hitRewindPurple)
                            .shadow(color: .black, radius: 1, x: 0, y: 1)
                    }
                }

                Spacer()

                // Video counter - right aligned with stars
                if !concertVideos.isEmpty {
                    Text("\(concertVideos.count) videos")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 1)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 20) // Add bottom padding for spacing from videos
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, contentPadding)
        .padding(.top, heroContentTopPadding)
    }
    
    // MARK: - Background Image View (Independent)
    private var backgroundImageView: some View {
        Group {
            if let largeImageUrl = concert.fields.largeImage?.first?.url {
                AsyncImage(url: URL(string: largeImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.hitRewindDarkGray)
                        .frame(height: 200)
                        .overlay {
                            ProgressView()
                                .tint(.hitRewindPurple)
                        }
                }
            } else {
                // Fallback gradient background
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.hitRewindPurple.opacity(0.6), .hitRewindBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay {
                        VStack {
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundColor(.hitRewindSecondaryText)
                            Text("Concert")
                                .font(.title3)
                                .foregroundColor(.hitRewindSecondaryText)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            // Gradient overlay for better text contrast at bottom
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.5),
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
        }
    }
    
    // MARK: - Content Section (Apple TV Style)
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Concert videos section (main focus like Apple TV)
            videosSection
        }
    }
    
    private var videosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingVideos {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if concertVideos.isEmpty {
                emptyVideosView
            } else {
                videosGrid
            }
        }
    }
    
    private var videosGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            ForEach(Array(concertVideos.enumerated()), id: \.offset) { index, video in
                let videoId = extractYouTubeVideoID(from: video.fields.youtubeUrl)
                if videoId != nil {
                    Button(action: {
                        handleVideoTap(video: video, videoId: videoId!)
                    }) {
                        VideoThumbnailView(
                            videoId: videoId!,
                            title: video.fields.videoTitle,
                            artist: video.fields.artistName ?? "",  // Use video's artist if available
                            year: "\(concert.fields.eventYear)",
                            onTap: {},
                            hideArtistAndYear: video.fields.artistName == nil,  // Only hide if no artist
                            hideArtistName: false,
                            showDurationInline: false  // Duration is already on thumbnail badge
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, contentPadding)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.hitRewindPurple)
            Text("Loading concert videos...")
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error Loading Videos")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)
            
            Text(message)
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadConcertVideos()
                }
            }
            .foregroundColor(.hitRewindPurple)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, contentPadding)
    }
    
    private var emptyVideosView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(.hitRewindSecondaryText)
            
            Text("No Videos Available")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)
            
            Text("This concert doesn't have any videos available yet.")
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, contentPadding)
    }
    
    // MARK: - Computed Properties
    
    private var gridColumns: [GridItem] {
        let count = columnCount
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: count)
    }
    
    private var columnCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return horizontalSizeClass == .regular ? 4 : 3
        } else {
            // iPhone: always 3 columns (app is landscape only)
            return 3
        }
    }
    
    private var gridSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
    }
    
    private var contentPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16
    }

    private var heroContentTopPadding: CGFloat {
        // Position content below navigation bar area
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 20  // iPad has header row, less padding needed
        } else {
            return 60  // iPhone needs more padding for nav bar
        }
    }

    private var heroArtistFontSize: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 24
        } else {
            return verticalSizeClass == .regular ? 20 : 18
        }
    }
    
    private var heroTitleFontSize: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 42  // Larger for main title
        } else {
            return verticalSizeClass == .regular ? 32 : 28
        }
    }
    
    // MARK: - Helper Methods

    private func createVideoView(from video: ConcertVideo) -> VJModeView {
        // Build playlist context for autoplay (all videos in this concert)
        let playlistVideos = concertVideos.compactMap { concertVideo -> PlaylistVideo? in
            guard let id = extractYouTubeVideoID(from: concertVideo.fields.youtubeUrl) else {
                return nil
            }
            // Use video's artist if available, otherwise fall back to concert artist
            let videoArtist = concertVideo.fields.artistName ?? concert.fields.artistName
            return PlaylistVideo(
                id: id,
                youtubeURL: concertVideo.fields.youtubeUrl,
                title: concertVideo.fields.videoTitle,
                artist: videoArtist,
                year: "\(concert.fields.eventYear)"
            )
        }

        // Find current video index
        guard let videoId = extractYouTubeVideoID(from: video.fields.youtubeUrl),
              let currentIndex = playlistVideos.firstIndex(where: { $0.id == videoId }) else {
            print("⚠️ Could not find video index for autoplay")
            let videoArtist = video.fields.artistName ?? concert.fields.artistName
            let fallbackVideo = PlaylistVideo(
                id: extractYouTubeVideoID(from: video.fields.youtubeUrl) ?? "",
                youtubeURL: video.fields.youtubeUrl,
                title: video.fields.videoTitle,
                artist: videoArtist,
                year: "\(concert.fields.eventYear)"
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
            currentIndex: currentIndex,
            sourceType: .concert  // Concert mode: shows concert videos in sidebar, hides year picker
        )

        return VJModeView(
            playerCoordinator: playerCoordinator,
            initialVideo: currentVideo,
            videos: playlistVideos,
            playlistContext: playlistContext
        )
    }

    private func handleVideoTap(video: ConcertVideo, videoId: String) {
        print("🎥 Concert video \(videoId) tapped")

        Task { @MainActor in
            // Check StoreKit directly for active subscription
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()

            if isSubscribed {
                // User is subscribed - play video immediately
                print("✅ User subscribed - playing video")
                self.selectedVideoId = videoId
                self.selectedVideoInfo = video
            } else {
                // User not subscribed - show paywall with orientation handling
                print("🔒 User not subscribed - showing paywall")
                PaywallService.shared.presentPaywallWithOrientation {
                    // After successful purchase, play video
                    print("✅ Purchase complete - playing video")
                    self.selectedVideoId = videoId
                    self.selectedVideoInfo = video
                }
            }
        }
    }

    private func loadConcertVideos() async {
        isLoadingVideos = true
        errorMessage = nil

        print("🎪 Loading videos for concert: \(concert.fields.artistName) - \(concert.fields.venueName ?? "Unknown Venue")")
        print("🎪 Concert ID: \(concert.id)")
        print("🎪 Is Top Today concert: \(isTopTodayConcert)")

        if isTopTodayConcert {
            // Fetch from TopToday table instead
            print("🎪 Fetching from TopToday table...")
            await directVideoService.fetchTopTodayVideos()

            // Convert DirectVideoRecords to ConcertVideos
            let topTodayVideos = directVideoService.topTodayVideos
            let convertedVideos = topTodayVideos.compactMap { record -> ConcertVideo? in
                guard let url = record.fields.url else { return nil }
                return ConcertVideo(
                    id: record.id,
                    fields: ConcertVideoFields(
                        videoTitle: record.fields.title ?? "Unknown",
                        youtubeUrl: url,
                        concert: nil,
                        cleaner: nil,
                        artistName: record.fields.artistName
                    )
                )
            }

            await MainActor.run {
                print("🎪 Successfully loaded \(convertedVideos.count) TopToday videos")
                self.concertVideos = convertedVideos
                self.isLoadingVideos = false
            }
        } else {
            // Regular concert - fetch from Concert Videos table
            do {
                let videos = try await airtableService.fetchConcertVideos(for: concert)
                await MainActor.run {
                    print("🎪 Successfully loaded \(videos.count) videos for concert")
                    self.concertVideos = videos
                    self.isLoadingVideos = false
                }
            } catch {
                print("🎪 Error loading concert videos: \(error)")
                await MainActor.run {
                    self.errorMessage = "Unable to load concert videos. Please try again."
                    self.isLoadingVideos = false
                }
            }
        }
    }
}

#Preview {
    let sampleConcert = Concert(
        id: "preview",
        fields: ConcertFields(
            venueName: "Madison Square Garden",
            artistName: "Taylor Swift",
            eventYear: 2024,
            bannerImage: nil,
            largeImage: nil,
            eventDescription: "The Eras Tour brings Taylor's entire discography to life in an unforgettable concert experience spanning over three hours.",
            concertVideos: nil
        )
    )
    
    NavigationView {
        ConcertDetailView(concert: sampleConcert)
    }
    .preferredColorScheme(.dark)
}