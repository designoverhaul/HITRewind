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

    @State private var concertVideos: [ConcertVideo] = []
    @State private var isLoadingVideos = true
    @State private var errorMessage: String?

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
    }

    // MARK: - iPad Layout (static header with back button)
    private var iPadLayout: some View {
        ZStack(alignment: .top) {
            Color.hitRewindBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Static iPad header with back button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)

                    Spacer()

                    Spacer()
                        .frame(width: 44)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        bannerImageSection
                        bodyContent
                    }
                }
            }
        }
    }

    // MARK: - iPhone Layout (headroom header that hides on scroll)
    private var iPhoneLayout: some View {
        ZStack(alignment: .top) {
            Color.hitRewindBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    bannerImageSection
                    bodyContent
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
    }

    // MARK: - Banner Image Section (fixed height, full width, scrolls with content)
    private var bannerImageSection: some View {
        Group {
            if let bannerUrl = concert.fields.bannerImage?.first?.url,
               let url = URL(string: bannerUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        fallbackBannerImage
                    default:
                        Rectangle()
                            .fill(Color.hitRewindDarkGray)
                    }
                }
            } else {
                fallbackBannerImage
            }
        }
        .frame(height: bannerHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var fallbackBannerImage: some View {
        Image("HeaderBackground")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }

    // MARK: - Body Content (below banner, solid background)
    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroInfoSection
            contentSection
        }
        .background(Color.hitRewindBackground)
    }

    // MARK: - Hero Info Section (artist, venue, description, stars)
    private var heroInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artist name
            Text(concert.fields.artistName)
                .font(.custom(AppFont.ticketingName(), size: heroSubtitleFontSize))
                .fontWeight(.bold)
                .foregroundColor(.hitRewindPurple)

            // Concert title (venue)
            Text(concert.fields.venueName ?? "Unknown Venue")
                .font(.system(size: heroTitleFontSize, weight: .bold))
                .foregroundColor(.white)

            // Description
            if let description = concert.fields.eventDescription, !description.isEmpty {
                Text(description)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            // Star rating with video counter
            HStack {
                HStack(spacing: 4) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.hitRewindPurple)
                    }
                }

                Spacer()

                if !concertVideos.isEmpty {
                    Text("\(concertVideos.count) videos")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, contentPadding)
        .padding(.vertical, 16)
    }

    private var bannerHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 280 : 200
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
                            year: concert.fields.eventYear.map { "\($0)" } ?? "",
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

    private var heroSubtitleFontSize: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 16
        } else {
            return verticalSizeClass == .regular ? 14 : 13
        }
    }

    private var heroTitleFontSize: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 48
        } else {
            return verticalSizeClass == .regular ? 38 : 34
        }
    }
    
    // MARK: - Helper Methods

    private func openVideoInMiniPlayer(video: ConcertVideo) {
        let playlistVideos = concertVideos.compactMap { concertVideo -> PlaylistVideo? in
            guard let id = extractYouTubeVideoID(from: concertVideo.fields.youtubeUrl) else { return nil }
            let videoArtist = concertVideo.fields.artistName ?? concert.fields.artistName
            return PlaylistVideo(
                id: id, youtubeURL: concertVideo.fields.youtubeUrl,
                title: concertVideo.fields.videoTitle, artist: videoArtist,
                year: concert.fields.eventYear.map { "\($0)" } ?? ""
            )
        }

        guard let videoId = extractYouTubeVideoID(from: video.fields.youtubeUrl),
              let currentIndex = playlistVideos.firstIndex(where: { $0.id == videoId }) else { return }

        let currentVideo = playlistVideos[currentIndex]
        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex,
            sourceType: .concert
        )

        MiniPlayerManager.shared.openVJMode(
            video: currentVideo,
            videos: playlistVideos,
            playlistContext: playlistContext
        )
    }

    private func handleVideoTap(video: ConcertVideo, videoId: String) {
        print("🎥 Concert video \(videoId) tapped")

        Task { @MainActor in
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()

            if isSubscribed {
                print("✅ User subscribed - playing video")
                openVideoInMiniPlayer(video: video)
            } else {
                print("🔒 User not subscribed - showing paywall")
                PaywallService.shared.presentPaywallWithOrientation {
                    print("✅ Purchase complete - playing video")
                    openVideoInMiniPlayer(video: video)
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
            eventDescription: "The Eras Tour brings Taylor's entire discography to life in an unforgettable concert experience spanning over three hours.",
            concertVideos: nil
        )
    )
    
    NavigationView {
        ConcertDetailView(concert: sampleConcert)
    }
    .preferredColorScheme(.dark)
}