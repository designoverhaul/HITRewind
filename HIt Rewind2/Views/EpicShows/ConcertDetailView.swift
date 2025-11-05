//
//  ConcertDetailView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI
import SuperwallKit

struct ConcertDetailView: View {
    let concert: Concert

    @StateObject private var airtableService = AirtableService()
    @StateObject private var favoritesService = FavoritesService.shared
    @ObservedObject private var paywallService = PaywallService.shared
    @State private var concertVideos: [ConcertVideo] = []
    @State private var isLoadingVideos = true
    @State private var errorMessage: String?
    @State private var isDescriptionExpanded = false
    @State private var navigationDestination: SingleVideoView?

    // Device and orientation detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // iPad only: Custom header row (Row 2)
            if UIDevice.current.userInterfaceIdiom == .pad {
                HStack {
                    // No sidebar icon for Concert Detail page
                    Spacer()
                    
                    // Logo centered
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.hitRewindBackground)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero section with large concert image
                    heroSection
                    
                    // Concert details and videos
                    contentSection
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            print("🎪 ConcertDetailView loaded for: \(concert.fields.artistName) - \(concert.fields.venueName ?? "Unknown Venue")")
            await loadConcertVideos()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // iPad: Row 1 (System Navigation Bar) - back button left, search/settings right
            if UIDevice.current.userInterfaceIdiom == .pad {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.custom(AppFont.ticketingName(), size: 16))
                        }
                        .foregroundColor(.hitRewindPurple)
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
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.custom(AppFont.ticketingName(), size: 16))
                        }
                        .foregroundColor(.hitRewindPurple)
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
        }
    }
    
    // MARK: - Hero Section (Apple TV Style)
    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            // Background image with minimum height
            backgroundImageView
                .frame(minHeight: heroImageHeight)
            
            // Content container - properly constrained to screen width
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
                
                // Description preview - expandable on tap with natural height
                if let description = concert.fields.eventDescription, !description.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isDescriptionExpanded.toggle()
                        }
                    }) {
                        Text(description)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(isDescriptionExpanded ? nil : 3)
                            .shadow(color: .black, radius: 2, x: 0, y: 1)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
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
            .frame(maxWidth: UIScreen.main.bounds.width, alignment: .leading)
            .padding(.horizontal, contentPadding)
            .padding(.top, 60)  // Position 60px from top as requested
        }
    }
    
    // MARK: - Background Image View (Independent)
    private var backgroundImageView: some View {
        GeometryReader { geometry in
            Group {
                if let largeImageUrl = concert.fields.largeImage?.first?.url {
                    AsyncImage(url: URL(string: largeImageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.hitRewindDarkGray)
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
            .frame(width: backgroundImageWidth, height: geometry.size.height)
            .clipped()
            .position(x: backgroundImageXPosition(in: geometry), y: geometry.size.height / 2)
            .overlay {
                // Gradient overlay for better contrast at top
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
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
                            artist: concert.fields.artistName,
                            year: "\(concert.fields.eventYear)",
                            onTap: {},
                            hideArtistAndYear: true  // Hide redundant info for concert videos
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, contentPadding)
        .background(
            NavigationLink(
                destination: navigationDestination,
                isActive: Binding(
                    get: { navigationDestination != nil },
                    set: { if !$0 { navigationDestination = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        )
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
            return verticalSizeClass == .regular ? 1 : 2
        }
    }
    
    private var gridSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
    }
    
    private var contentPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16
    }
    
    private var heroImageHeight: CGFloat {
        // Set to 1/3 of screen height as requested
        return UIScreen.main.bounds.height / 3
    }
    
    private var backgroundImageWidth: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Tablets: edge-to-edge (100% width)
            return UIScreen.main.bounds.width
        } else {
            // Phones: wider than screen to allow right-alignment cropping
            return UIScreen.main.bounds.width * 1.5
        }
    }
    
    // Calculate X position for background image based on device type
    private func backgroundImageXPosition(in geometry: GeometryProxy) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Tablets: center the image
            return geometry.size.width / 2
        } else {
            // Phones: position to show right side of image
            return geometry.size.width - (backgroundImageWidth / 2) + (UIScreen.main.bounds.width * 0.25)
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

    private func handleVideoTap(video: ConcertVideo, videoId: String) {
        let videoDestination = SingleVideoView(
            youtubeURL: video.fields.youtubeUrl,
            videoTitle: video.fields.videoTitle,
            artistName: concert.fields.artistName,
            year: "\(concert.fields.eventYear)"
        )

        // Check if video is locked
        if paywallService.isVideoLocked(videoId) {
            print("🔒 Video \(videoId) is locked, presenting paywall")

            // Use Superwall's register method with closure
            // The closure ONLY executes if user has subscription
            Task { @MainActor in
                await Superwall.shared.register(placement: "MainPlacement") {
                    print("✅ User has access, navigating to video")
                    self.navigationDestination = videoDestination
                }
            }
        } else {
            // Video is unlocked, navigate directly
            print("🔓 Video \(videoId) is unlocked, navigating")
            navigationDestination = videoDestination
        }
    }

    private func loadConcertVideos() async {
        isLoadingVideos = true
        errorMessage = nil
        
        print("🎪 Loading videos for concert: \(concert.fields.artistName) - \(concert.fields.venueName ?? "Unknown Venue")")
        print("🎪 Concert ID: \(concert.id)")
        
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