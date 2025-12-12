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
    
    // Convenience initializer with default hideArtistAndYear = false, hideArtistName = false
    init(videoId: String, title: String, artist: String, year: String, onTap: @escaping () -> Void, hideArtistAndYear: Bool = false, hideArtistName: Bool = false) {
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.year = year
        self.onTap = onTap
        self.hideArtistAndYear = hideArtistAndYear
        self.hideArtistName = hideArtistName
    }
    
    @StateObject private var youtubeService = YouTubeService()
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var thumbnailImage: Image?
    @State private var duration: String = ""
    @State private var viewCount: String = ""
    @State private var isLoading = true
    @State private var showingRemoveFavoriteConfirmation = false
    @State private var heartBounceEffect = false

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
        .task {
            await loadVideoData()
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
                    // Placeholder while loading
                    Rectangle()
                        .fill(Color.hitRewindDarkGray)
                        .overlay {
                            if isLoading {
                                ProgressView()
                                    .tint(.hitRewindPurple)
                            } else {
                                // Custom fallback image
                                Image("missing")
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Play button overlay
            playOverlay
            
            // Heart button and duration badge
            VStack {
                HStack {
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

                // Duration badge (bottom-right)
                if !duration.isEmpty {
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
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Vertical layout
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.hitRewindPrimaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Show year when we're hiding artist name (artist-specific views), otherwise show artist name
                    if !hideArtistAndYear {
                        if hideArtistName {
                            // Artist-specific view: show year below title with ticketing font
                            Text(year)
                                .font(.custom(AppFont.ticketingName(), size: 15))
                                .fontWeight(.medium)
                                .foregroundColor(.hitRewindPurple)
                                .lineLimit(1)
                        } else if shouldShowArtistName {
                            // Normal view: show artist name below title
                            Text(artist)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.hitRewindPurple)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                // iPhone: Horizontal layout (same as iPad for consistency)
                HStack(alignment: .top) {
                    Text(displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.hitRewindPrimaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    // Show year when we're hiding artist name (artist-specific views), otherwise show artist name
                    if !hideArtistAndYear {
                        if hideArtistName {
                            // Artist-specific view: show year on the right with ticketing font
                            Text(year)
                                .font(.custom(AppFont.ticketingName(), size: 15))
                                .fontWeight(.medium)
                                .foregroundColor(.hitRewindPurple)
                                .lineLimit(1)
                        } else if shouldShowArtistName {
                            // Normal view: show artist name on the right
                            Text(artist)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.hitRewindPurple)
                                .lineLimit(1)
                        }
                    }
                }
                
                // View count (below artist/year)
                if !viewCount.isEmpty {
                    Text(viewCount)
                        .font(.caption2)
                        .foregroundColor(.hitRewindSecondaryText)
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
        isLoading = true
        
        // Load thumbnail image
        await loadThumbnailImage()
        
        // Load video info for duration
        await loadVideoInfo()
        
        isLoading = false
    }
    
    private func loadThumbnailImage() async {
        let qualities: [ThumbnailQuality] = [.medium, .high, .default]
        let hosts: [String] = ["i.ytimg.com", "img.youtube.com"]
        for quality in qualities {
            for host in hosts {
                let path: String
                switch quality {
                case .default: path = "default.jpg"
                case .medium: path = "mqdefault.jpg"
                case .high: path = "hqdefault.jpg"
                case .standard: path = "sddefault.jpg"
                case .maxres: path = "maxresdefault.jpg"
                }
                guard let url = URL(string: "https://\(host)/vi/\(videoId)/\(path)") else { continue }
                var request = URLRequest(url: url)
                // Simulator sometimes needs a mobile UA and explicit Accept for images
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
                request.setValue("image/avif,image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let http = response as? HTTPURLResponse,
                       (200..<300).contains(http.statusCode),
                       let contentType = http.value(forHTTPHeaderField: "Content-Type"), contentType.hasPrefix("image"),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run { thumbnailImage = Image(uiImage: uiImage) }
                        return
                    }
                } catch {
                    // Try next host/quality
                    continue
                }
            }
        }
    }
    
    private func loadVideoInfo() async {
        do {
            let video = try await youtubeService.getVideoInfo(videoId: videoId)
            
            await MainActor.run {
                // Duration
                if let contentDetails = video.contentDetails {
                    let formattedDuration = youtubeService.formatDuration(contentDetails.duration)
                    duration = formattedDuration
                }
                
                // View count
                if let statistics = video.statistics,
                   let viewCountString = statistics.viewCount,
                   let viewCountNumber = Int(viewCountString) {
                    viewCount = formatViewCount(viewCountNumber)
                }
            }
        } catch {
            // Video info loading failed, but we can continue without it
            print("Failed to load video info for \(videoId): \(error)")
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
            return "\(formatter.string(from: NSNumber(value: millions)) ?? "0")M views"
            
        case 1_000...:
            let thousands = Double(count) / 1_000.0
            if thousands >= 10 {
                formatter.maximumFractionDigits = 0
            } else {
                formatter.maximumFractionDigits = 1
            }
            return "\(formatter.string(from: NSNumber(value: thousands)) ?? "0")K views"
            
        default:
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: count)) ?? "0") views"
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
                .foregroundColor(isFavorited ? .red : .white)
                .symbolEffect(.bounce, value: bounceEffect)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
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