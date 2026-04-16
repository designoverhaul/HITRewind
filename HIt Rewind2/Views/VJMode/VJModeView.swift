//
//  VJModeView.swift
//  HIt Rewind2
//
//  VJ Mode - Landscape DJ interface for mobile video mixing
//

import SwiftUI
import UIKit
import YouTubeiOSPlayerHelper
import AVKit

/// VJ Mode view with forced landscape orientation
/// Layout: Video fills left, Controls strip (fixed width), Video stack (fixed width, full height)
/// Progress bar under video, year picker at bottom
struct VJModeView: View {
    // Passed from SingleVideoView
    @ObservedObject var playerCoordinator: YouTubePlayerCoordinator
    let initialVideo: PlaylistVideo
    let videos: [PlaylistVideo]
    let playlistContext: PlaylistContext?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared

    // Current video state
    @State private var currentVideo: PlaylistVideo
    @State private var isFavorited: Bool = false

    // UI state
    @State private var controlsVisible: Bool = true
    @State private var selectedYear: Int?
    @State private var selectedArtist: String?
    @State private var displayedVideos: [PlaylistVideo] = []

    // AirPlay state
    @State private var isAirPlayActive: Bool = false

    // Screen Share tutorial state
    @State private var showScreenShareTutorial: Bool = false

    // Timer for updating current time
    @State private var timeUpdateTimer: Timer?

    // Fixed widths
    private let controlStripWidth: CGFloat = 70
    private let videoStackWidth: CGFloat = 140
    private var rightPanelWidth: CGFloat { controlStripWidth + 12 + videoStackWidth } // controls + padding + stack

    init(playerCoordinator: YouTubePlayerCoordinator,
         initialVideo: PlaylistVideo,
         videos: [PlaylistVideo],
         playlistContext: PlaylistContext?) {
        self.playerCoordinator = playerCoordinator
        self.initialVideo = initialVideo
        self.videos = videos
        self.playlistContext = playlistContext
        self._currentVideo = State(initialValue: initialVideo)
    }

    // Determine source type for picker behavior
    private var sourceType: VideoSourceType {
        playlistContext?.sourceType ?? .musicVideos
    }

    private var isMusicVideosMode: Bool {
        if case .musicVideos = sourceType { return true }
        return false
    }

    private var isLiveMode: Bool {
        if case .live = sourceType { return true }
        return false
    }

    private var isConcertMode: Bool {
        if case .concert = sourceType { return true }
        return false
    }

    private var isEpicShowsMode: Bool {
        if case .epicShows = sourceType { return true }
        return false
    }

    private var showPicker: Bool {
        !isConcertMode && !isEpicShowsMode
    }

    // Available years for Music Videos mode (from DirectVideoService - same as Top 100 page)
    private var availableYears: [Int] {
        DirectVideoService.shared.availableYears
    }

    // Available artists for Live mode
    private var availableArtists: [String] {
        playlistContext?.liveArtists ?? []
    }

    // Bottom bar height constants
    private var progressBarHeight: CGFloat { 36 }
    private var pickerHeight: CGFloat { 34 }
    private var bottomBarHeight: CGFloat { showPicker ? progressBarHeight + pickerHeight : progressBarHeight }

    // Get actual window safe area (works even with .ignoresSafeArea())
    private var windowSafeArea: UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return .zero
        }
        return window.safeAreaInsets
    }

    var body: some View {
        GeometryReader { geometry in
            // Guard against invalid geometry dimensions
            let safeWidth = max(1, geometry.size.width)
            let safeHeight = max(1, geometry.size.height)
            let videoWidth = controlsVisible ? max(1, safeWidth - rightPanelWidth) : safeWidth
            let videoHeight = controlsVisible ? max(1, safeHeight - bottomBarHeight) : safeHeight

            ZStack(alignment: .topLeading) {
                // Background
                Color.black.ignoresSafeArea()

                // Single video player - frame changes based on controlsVisible
                // This keeps the same player instance when toggling fullscreen
                // Aligned to leading edge so it doesn't overlap right panel
                VStack(alignment: .leading, spacing: 0) {
                    VideoPlayerView(youtubeURL: currentVideo.youtubeURL, coordinator: playerCoordinator)
                        .background(Color.black)
                        .frame(
                            width: videoWidth,
                            height: videoHeight
                        )
                        .animation(.easeInOut(duration: 0.35), value: controlsVisible)

                    // Bottom bar: Progress + Picker (only when controls visible)
                    // Inset from left to make room for button column
                    if controlsVisible {
                        VStack(spacing: 0) {
                            // Progress bar with breathing room
                            VJModeProgressBar(
                                currentTime: playerCoordinator.currentTime,
                                duration: playerCoordinator.duration,
                                onSeek: { time in
                                    playerCoordinator.seekTo(seconds: time)
                                }
                            )
                            .frame(height: progressBarHeight)
                            .padding(.trailing, 8)
                            .zIndex(10) // Ensure progress bar is above other layers for touch

                            // Year/Artist picker - pushed to bottom edge
                            if showPicker {
                                VJModePicker(
                                    sourceType: sourceType,
                                    selectedYear: $selectedYear,
                                    selectedArtist: $selectedArtist,
                                    availableYears: availableYears,
                                    availableArtists: availableArtists,
                                    onYearSelected: fetchVideosForYear,
                                    onArtistSelected: fetchVideosForArtist
                                )
                                .frame(height: pickerHeight)
                            }
                        }
                        .padding(.leading, 50) // Inset for button column
                        .frame(width: max(1, safeWidth - rightPanelWidth), alignment: .leading)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .ignoresSafeArea()

                // Right side panels - slide in/out from right
                // Constrained to video area height so it doesn't block bottom bar touches
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                            .allowsHitTesting(false)

                        // Controls strip
                        VJModeControlStrip(
                            playerCoordinator: playerCoordinator,
                            isFavorited: $isFavorited,
                            artistName: currentVideo.artist,
                            showArtistButton: !isLiveMode,
                            onFavoriteToggle: toggleFavorite,
                            onArtistTap: loadArtistVideos,
                            onNextVideo: playNextVideo
                        )
                        .frame(width: controlStripWidth)
                        .padding(.horizontal, 6)

                        // Video stack
                        VJModeVideoStack(
                            videos: displayedVideos,
                            currentVideoId: currentVideo.id,
                            onVideoSelect: playVideo,
                            showYearSubtitle: isLiveMode
                        )
                        .frame(width: videoStackWidth)
                    }
                    .frame(height: max(1, safeHeight - (controlsVisible ? bottomBarHeight : 0)))

                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                }
                .offset(x: controlsVisible ? 0 : rightPanelWidth + 20)
                .animation(.easeInOut(duration: 0.35), value: controlsVisible)

                // Left-side buttons - vertically centered around Dynamic Island
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            Spacer()

                            // Top buttons - just above Dynamic Island
                            VStack(spacing: 6) {
                                // Exit VJ Mode button - back chevron
                                Button(action: exitVJMode) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 38, height: 38)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }

                                // Fullscreen / Hide controls button
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        controlsVisible.toggle()
                                    }
                                }) {
                                    Image(systemName: controlsVisible ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 38, height: 38)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }

                            // Fixed spacer for Dynamic Island area
                            Spacer()
                                .frame(height: 135)

                            // Bottom buttons - just below Dynamic Island
                            VStack(spacing: 6) {
                                // AirPlay button
                                Button(action: {
                                    AirPlayHelper.shared.showAirPlayPicker()
                                }) {
                                    Image(systemName: isAirPlayActive ? "airplayvideo.circle.fill" : "airplayvideo")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(isAirPlayActive ? .hitRewindPurple : .white)
                                        .frame(width: 38, height: 38)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }

                                // Screen Share info button
                                Button(action: {
                                    showScreenShareTutorial = true
                                }) {
                                    Image(systemName: "music.note.tv")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 38, height: 38)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }

                            Spacer()
                        }
                        .padding(.leading, 8)

                        Spacer()
                    }
                    // Only cover the video area, not the bottom bar
                    .frame(height: max(1, geometry.size.height - bottomBarHeight))

                    Spacer(minLength: 0)
                }
                .offset(x: controlsVisible ? 0 : -80)
                .animation(.easeInOut(duration: 0.35), value: controlsVisible)

                // Tap to show controls when hidden (invisible overlay on video area)
                if !controlsVisible {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                controlsVisible = true
                            }
                        }
                }
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            setupVJMode()
            detectAirPlayState()
        }
        .onDisappear {
            cleanupVJMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
            detectAirPlayState()
        }
        .sheet(isPresented: $showScreenShareTutorial) {
            ScreenShareTutorialView(isPresented: $showScreenShareTutorial, onDismiss: {
                showScreenShareTutorial = false
            })
        }
    }

    // MARK: - AirPlay Detection

    private func detectAirPlayState() {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        // Check if any output port is AirPlay or external screen
        let hasAirPlayOutput = currentRoute.outputs.contains { output in
            output.portType == .airPlay ||
            output.portType == .HDMI ||
            output.portType == .carAudio
        }

        DispatchQueue.main.async {
            isAirPlayActive = hasAirPlayOutput
        }
    }

    // MARK: - Helper Methods

    private func setupVJMode() {
        // Lock to landscape for VJ Mode
        OrientationManager.shared.enterVJMode()

        // Reset any preserved playback position from a previous video session
        // This ensures each new video starts from the beginning
        playerCoordinator.resetPreservedPosition()

        // Initialize current video
        currentVideo = initialVideo
        isFavorited = favoritesService.isFavorited(currentVideo.id)

        // Setup displayed videos based on source type
        setupDisplayedVideos()

        // Setup autoplay callback for when video ends
        playerCoordinator.onVideoEnd = {
            print("🎬 VJModeView: onVideoEnd callback triggered!")
            print("🎬 VJModeView: About to call playNextVideo()")
            self.playNextVideo()
        }
        print("🎬 VJModeView: onVideoEnd callback configured")

        // Start time update timer
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            playerCoordinator.getCurrentTime()
        }

        print("VJModeView: Setup complete")
    }

    private func cleanupVJMode() {
        // Stop timer
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil

        print("VJModeView: Cleanup complete")
    }

    private func exitVJMode() {
        // Preserve playback position so portrait player can resume
        playerCoordinator.preservePlaybackPosition()
        cleanupVJMode()
        OrientationManager.shared.exitVJMode()
        dismiss()
    }

    private func setupDisplayedVideos() {
        print("🎬 setupDisplayedVideos called, sourceType: \(sourceType)")
        switch sourceType {
        case .musicVideos:
            // Initialize with current video's year
            let yearInt = Int(currentVideo.year) ?? availableYears.first ?? 2000
            selectedYear = yearInt
            print("🎬 Music Videos mode: fetching videos for year \(yearInt)")
            fetchVideosForYear(yearInt)

        case .live(let artistName, _, _):
            // Initialize with current artist
            selectedArtist = artistName
            // Use passed-in videos directly (from Official/Charts tabs) instead of re-fetching
            if !videos.isEmpty {
                displayedVideos = videos
                print("🎬 Live mode: using \(videos.count) passed-in videos for artist \(artistName)")
            } else {
                print("🎬 Live mode: fetching videos for artist \(artistName)")
                fetchVideosForArtist(artistName)
            }

        case .concert:
            // Use all videos from context
            displayedVideos = videos
            print("🎬 Concert mode: using \(videos.count) videos from context")

        case .epicShows(let categoryName, _):
            // Use all videos from context
            displayedVideos = videos
            print("🎬 Epic Shows mode (\(categoryName)): using \(videos.count) videos from context")
        }
    }

    private func fetchVideosForYear(_ year: Int) {
        NotificationCenter.default.post(name: .vjPickerYearChanged, object: nil, userInfo: ["year": year])
        // Use DirectVideoService (MTvVideosNEW) - same data source as Top 100 page
        let directVideos = DirectVideoService.shared.videos(forYear: year)

        if directVideos.isEmpty {
            // DirectVideoService may not be loaded yet - try to fetch
            Task {
                await DirectVideoService.shared.fetchVideos()
                await MainActor.run {
                    let reloadedVideos = DirectVideoService.shared.videos(forYear: year)
                    displayedVideos = reloadedVideos.compactMap { record -> PlaylistVideo? in
                        guard let url = record.fields.url,
                              let videoId = record.fields.youtubeVideoId,
                              let title = record.fields.title else { return nil }

                        return PlaylistVideo(
                            id: videoId,
                            youtubeURL: url,
                            title: title,
                            artist: record.fields.artistName ?? "Unknown Artist",
                            year: String(year),
                            rank: record.fields.rank
                        )
                    }
                    print("VJModeView: Loaded \(displayedVideos.count) videos for year \(year) from DirectVideoService")
                }
            }
            return
        }

        displayedVideos = directVideos.compactMap { record -> PlaylistVideo? in
            guard let url = record.fields.url,
                  let videoId = record.fields.youtubeVideoId,
                  let title = record.fields.title else { return nil }

            return PlaylistVideo(
                id: videoId,
                youtubeURL: url,
                title: title,
                artist: record.fields.artistName ?? "Unknown Artist",
                year: String(year),
                rank: record.fields.rank
            )
        }
        print("VJModeView: Loaded \(displayedVideos.count) videos for year \(year) from DirectVideoService")
    }

    private func fetchVideosForArtist(_ artist: String) {
        NotificationCenter.default.post(name: .vjPickerArtistChanged, object: nil, userInfo: ["artistName": artist])
        // For Live mode, fetch videos from Airtable for the selected artist
        if isLiveMode {
            Task {
                let airtableService = AirtableService.shared
                if let loadedArtist = try? await airtableService.fetchArtist(byName: artist) {
                    await MainActor.run {
                        // Build video list from fetched artist data
                        var artistVideos: [PlaylistVideo] = []

                        let videoUrls = loadedArtist.fields.videoUrls ?? []
                        let videoTitles = loadedArtist.fields.videoTitles ?? []
                        let artistNames = loadedArtist.fields.artistNames ?? []
                        let videoYears = loadedArtist.fields.videoYears ?? []
                        let isVisible = loadedArtist.fields.isVisible

                        for index in 0..<videoUrls.count {
                            // Check visibility flag if available
                            let visible = isVisible.isEmpty || (isVisible[safe: index].flatMap { $0 } ?? true)
                            guard visible else { continue }

                            let url = videoUrls[index]
                            guard let videoId = extractYouTubeVideoID(from: url) else { continue }

                            let title = videoTitles[safe: index] ?? "Unknown Title"
                            let artistName = artistNames[safe: index] ?? artist
                            let year = videoYears[safe: index] ?? String(loadedArtist.fields.year)

                            let video = PlaylistVideo(
                                id: videoId,
                                youtubeURL: url,
                                title: title,
                                artist: artistName,
                                year: year
                            )
                            artistVideos.append(video)
                        }

                        // Sort by year descending
                        artistVideos.sort {
                            if let y1 = Int($0.year), let y2 = Int($1.year) {
                                return y1 > y2
                            }
                            return $0.year > $1.year
                        }

                        displayedVideos = artistVideos
                        print("VJModeView: Loaded \(artistVideos.count) videos for artist: \(artist)")
                    }
                } else {
                    print("VJModeView: Failed to fetch artist: \(artist)")
                }
            }
        } else if let context = playlistContext {
            displayedVideos = context.liveVideosForArtist(artist)
        } else {
            displayedVideos = videos.filter { $0.artist == artist }
        }
    }

    /// Load all videos by the current artist from DirectVideoService (MTvVideosNEW)
    private func loadArtistVideos() {
        let artistName = currentVideo.artist
        print("🎤 loadArtistVideos called for artist: \(artistName)")

        // If DirectVideoService hasn't loaded yet, fetch asynchronously
        if DirectVideoService.shared.videos.isEmpty {
            print("🎤 DirectVideoService is empty, fetching videos first...")
            Task {
                await DirectVideoService.shared.fetchVideos()
                await MainActor.run {
                    performArtistSearch(for: artistName)
                }
            }
        } else {
            performArtistSearch(for: artistName)
        }
    }

    private func performArtistSearch(for artistName: String) {
        var artistVideos: [PlaylistVideo] = []
        var addedVideoIds = Set<String>()

        // Parse individual artist names (handle "Queen & David Bowie" etc.)
        let artistNames = parseArtistNames(from: artistName)
        print("🎤 Parsed artist names: \(artistNames)")

        // Search DirectVideoService (MTvVideosNEW) - same source as Top 100 page
        let allVideos = DirectVideoService.shared.videos
        print("🎤 Searching through \(allVideos.count) videos")

        for record in allVideos {
            guard let recordArtist = record.fields.artistName,
                  let url = record.fields.url,
                  let videoId = record.fields.youtubeVideoId,
                  let title = record.fields.title else { continue }

            // Check if this video's artist contains ANY of our target artists
            let matchesAnyArtist = artistNames.contains { targetArtist in
                recordArtist.localizedCaseInsensitiveContains(targetArtist)
            }

            if matchesAnyArtist && !addedVideoIds.contains(videoId) {
                addedVideoIds.insert(videoId)
                artistVideos.append(PlaylistVideo(
                    id: videoId,
                    youtubeURL: url,
                    title: title,
                    artist: recordArtist,
                    year: String(record.fields.yearInt ?? 0),
                    rank: record.fields.rank
                ))
            }
        }

        // Sort by year descending (newest first)
        artistVideos.sort { $0.year > $1.year }

        print("🎤 Found \(artistVideos.count) videos for artist: \(artistName)")

        if !artistVideos.isEmpty {
            displayedVideos = artistVideos
        }
    }

    /// Parse individual artist names from a combined field like "Queen & David Bowie"
    private func parseArtistNames(from artistField: String) -> [String] {
        let separators = [" & ", " feat. ", " feat ", " featuring ", " and ", ", ", "/"]
        var names = [artistField]

        for separator in separators {
            names = names.flatMap { $0.components(separatedBy: separator) }
        }

        return names.map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
    }

    private func playVideo(_ video: PlaylistVideo) {
        print("🎬 playVideo called: \(video.title) (id: \(video.id))")

        withAnimation(.easeInOut(duration: 0.2)) {
            currentVideo = video
        }
        isFavorited = favoritesService.isFavorited(video.id)

        // Reset preserved position since this is a new video (not a mode transition)
        playerCoordinator.resetPreservedPosition()

        // Coordinator will auto-play in playerViewDidBecomeReady
        print("🎬 Video updated, coordinator will auto-play when ready")
    }

    private func playNextVideo() {
        print("🎬 playNextVideo called")
        print("🎬 displayedVideos.count: \(displayedVideos.count)")
        print("🎬 currentVideo.id: \(currentVideo.id), title: \(currentVideo.title)")

        guard let currentIndex = displayedVideos.firstIndex(where: { $0.id == currentVideo.id }) else {
            print("🎬 currentVideo NOT found in displayedVideos - playing first video")
            if let first = displayedVideos.first {
                print("🎬 Playing first video: \(first.title)")
                playVideo(first)
            }
            return
        }

        print("🎬 currentIndex: \(currentIndex) of \(displayedVideos.count - 1)")

        guard currentIndex + 1 < displayedVideos.count else {
            print("🎬 At last video (\(currentIndex)), looping to first")
            if let first = displayedVideos.first {
                playVideo(first)
            }
            return
        }

        let nextVideo = displayedVideos[currentIndex + 1]
        print("🎬 Autoplaying next video [\(currentIndex + 1)]: \(nextVideo.title)")
        playVideo(nextVideo)
    }

    private func toggleFavorite() {
        if authService.isAuthenticated {
            favoritesService.toggleFavorite(
                videoId: currentVideo.id,
                title: currentVideo.title,
                artist: currentVideo.artist,
                year: currentVideo.year
            )
            isFavorited.toggle()
        } else {
            NotificationCenter.default.post(name: .showSignInSheet, object: nil)
        }
    }
}

// MARK: - Horizontal Progress Bar (under video)

struct VJModeProgressBar: View {
    let currentTime: Float
    let duration: Float
    let onSeek: (Float) -> Void

    // Bar is 85% of container width (15% shorter), centered
    private let widthMultiplier: CGFloat = 0.85

    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width * widthMultiplier
            let horizontalInset = (geometry.size.width - barWidth) / 2

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: barWidth, height: 6)

                // Progress fill (from left)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.hitRewindPurple)
                    .frame(width: progressWidth(for: barWidth), height: 6)

                // Diamond playhead marker
                Diamond()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: playheadPosition(for: barWidth) - 7) // Center the diamond
            }
            .frame(width: barWidth, height: geometry.size.height) // Fill full height for bigger touch target
            .frame(maxWidth: .infinity) // Center within container
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Adjust for centered bar position
                        let adjustedX = value.location.x - horizontalInset
                        let percentage = adjustedX / barWidth
                        let clampedPercentage = max(0, min(1, percentage))
                        let seekTime = Float(clampedPercentage) * duration
                        onSeek(seekTime)
                    }
            )
        }
    }

    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        guard duration > 0, totalWidth > 0, totalWidth.isFinite else { return 0 }
        let progress = CGFloat(currentTime / duration)
        guard progress.isFinite else { return 0 }
        return max(0, totalWidth * progress)
    }

    private func playheadPosition(for totalWidth: CGFloat) -> CGFloat {
        guard duration > 0, totalWidth > 0, totalWidth.isFinite else { return 0 }
        let progress = CGFloat(currentTime / duration)
        guard progress.isFinite else { return 0 }
        return max(0, totalWidth * progress)
    }
}

// Diamond shape for playhead
struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2

        path.move(to: CGPoint(x: center.x, y: center.y - halfHeight)) // Top
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y)) // Right
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfHeight)) // Bottom
        path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y)) // Left
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    VJModeView(
        playerCoordinator: YouTubePlayerCoordinator(),
        initialVideo: PlaylistVideo(
            id: "M7lc1UVf-VE",
            youtubeURL: "https://www.youtube.com/watch?v=M7lc1UVf-VE",
            title: "Sample Video",
            artist: "Sample Artist",
            year: "2023"
        ),
        videos: [],
        playlistContext: nil
    )
}
