//
//  VJModeOverlay.swift
//  HIt Rewind2
//
//  VJ Mode overlay - shares the video player from SingleVideoView
//  Video keeps playing seamlessly when entering/exiting
//

import SwiftUI
import UIKit
import AVKit

/// VJ Mode overlay that reuses the existing video player
/// Displayed on top of SingleVideoView, video continues playing when closed
struct VJModeOverlay: View {
    @ObservedObject var playerCoordinator: YouTubePlayerCoordinator
    @Binding var currentVideo: PlaylistVideo
    let videos: [PlaylistVideo]
    let playlistContext: PlaylistContext?
    @Binding var isPresented: Bool
    let onVideoChange: (PlaylistVideo) -> Void

    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared

    // UI state
    @State private var controlsVisible: Bool = true
    @State private var selectedYear: Int?
    @State private var selectedArtist: String?
    @State private var displayedVideos: [PlaylistVideo] = []
    @State private var isFavorited: Bool = false

    // AirPlay state
    @State private var isAirPlayActive: Bool = false

    // Screen Share tutorial state
    @State private var showScreenShareTutorial: Bool = false

    // Timer for updating current time
    @State private var timeUpdateTimer: Timer?

    // Widths - larger on iPad for better touch targets and visibility
    private var controlStripWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 90 : 70
    }
    private var videoStackWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 180 : 140
    }
    private var rightPanelWidth: CGFloat { controlStripWidth + 12 + videoStackWidth }

    // Source type helpers
    private var sourceType: VideoSourceType {
        playlistContext?.sourceType ?? .musicVideos
    }

    private var showPicker: Bool {
        if case .concert = sourceType { return false }
        if case .epicShows = sourceType { return false }
        return true
    }

    private var isLiveMode: Bool {
        if case .live = sourceType { return true }
        return false
    }

    private var availableYears: [Int] {
        // Use DirectVideoService (MTvVideosNEW) - same data source as Top 100 page
        DirectVideoService.shared.availableYears
    }

    private var availableArtists: [String] {
        playlistContext?.liveArtists ?? []
    }

    // Bottom bar height constants
    private var progressBarHeight: CGFloat { 36 }
    private var pickerHeight: CGFloat { 34 }
    private var bottomBarHeight: CGFloat { showPicker ? progressBarHeight + pickerHeight : progressBarHeight }

    var body: some View {
        GeometryReader { geometry in
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
                            width: controlsVisible ? geometry.size.width - rightPanelWidth : geometry.size.width,
                            height: controlsVisible ? geometry.size.height - bottomBarHeight : geometry.size.height
                        )
                        .animation(.easeInOut(duration: 0.35), value: controlsVisible)

                    // Bottom bar: Progress + Picker (only when controls visible)
                    if controlsVisible {
                        VStack(spacing: 0) {
                            // Progress bar
                            VJModeProgressBar(
                                currentTime: playerCoordinator.currentTime,
                                duration: playerCoordinator.duration,
                                onSeek: { time in
                                    playerCoordinator.seekTo(seconds: time)
                                }
                            )
                            .frame(height: progressBarHeight)
                            .padding(.leading, 0) // Start at left edge
                            .padding(.trailing, 8)

                            // Year/Artist picker - starts at left edge
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
                        .frame(width: geometry.size.width - rightPanelWidth, alignment: .leading)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // Right side panels - slide in/out from right
                // Constrained to video area height so bottom bar stays touchable
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                            .allowsHitTesting(false)

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

                        VJModeVideoStack(
                            videos: displayedVideos,
                            currentVideoId: currentVideo.id,
                            onVideoSelect: playVideo
                        )
                        .frame(width: videoStackWidth)
                    }
                    .frame(height: controlsVisible ? geometry.size.height - bottomBarHeight : geometry.size.height)

                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                }
                .offset(x: controlsVisible ? 0 : rightPanelWidth + 20)
                .animation(.easeInOut(duration: 0.35), value: controlsVisible)

                // Left-side buttons (always visible) - top and bottom aligned closer to dynamic island
                // Only covers video area height so it doesn't block bottom bar touches
                VStack(spacing: 0) {
                    HStack {
                        VStack {
                            // Top buttons (above camera/island) - moved down 10px
                            VStack(spacing: 10) {
                                // Exit VJ Mode button - back chevron
                                Button(action: exitVJMode) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }

                                // Fullscreen toggle button
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        controlsVisible.toggle()
                                    }
                                }) {
                                    Image(systemName: controlsVisible ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(12)
                            .padding(.top, 10)

                            Spacer()

                            // Bottom buttons (below camera/island) - moved up 10px
                            VStack(spacing: 10) {
                                // AirPlay button
                                Button(action: {
                                    AirPlayHelper.shared.showAirPlayPicker()
                                }) {
                                    Image(systemName: isAirPlayActive ? "airplayvideo.circle.fill" : "airplayvideo")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(isAirPlayActive ? .hitRewindPurple : .white)
                                        .frame(width: 40, height: 40)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }

                                // Screen Share info button
                                Button(action: {
                                    showScreenShareTutorial = true
                                }) {
                                    Image(systemName: "music.note.tv")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(12)
                            .padding(.bottom, 10)
                        }

                        Spacer()
                    }
                    .frame(height: controlsVisible ? geometry.size.height - bottomBarHeight : geometry.size.height)

                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                }

                // Tap to show controls when hidden
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

    // MARK: - Setup/Cleanup

    private func setupVJMode() {
        OrientationManager.shared.lockToLandscapeRight()
        isFavorited = favoritesService.isFavorited(currentVideo.id)
        setupDisplayedVideos()

        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            playerCoordinator.getCurrentTime()
        }

    }

    private func cleanupVJMode() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
    }

    private func exitVJMode() {
        // Preserve playback position so portrait player can resume
        playerCoordinator.preservePlaybackPosition()
        cleanupVJMode()
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }

    // MARK: - Video Management

    private func setupDisplayedVideos() {
        switch sourceType {
        case .musicVideos:
            let yearInt = Int(currentVideo.year) ?? availableYears.first ?? 2000
            selectedYear = yearInt
            fetchVideosForYear(yearInt)

        case .live(let artistName, _, _):
            selectedArtist = artistName
            fetchVideosForArtist(artistName)

        case .concert, .epicShows:
            displayedVideos = videos
        }
    }

    private func fetchVideosForYear(_ year: Int) {
        // Use DirectVideoService (MTvVideosNEW) - same data source as Top 100 page
        let directVideos = DirectVideoService.shared.videos(forYear: year)

        displayedVideos = directVideos.compactMap { record -> PlaylistVideo? in
            guard let url = record.fields.url,
                  let videoId = record.fields.youtubeVideoId,
                  let title = record.fields.title else { return nil }

            return PlaylistVideo(
                id: videoId,
                youtubeURL: url,
                title: title,
                artist: record.fields.artistName ?? "Unknown Artist",
                year: String(year)
            )
        }
    }

    private func fetchVideosForArtist(_ artist: String) {
        if let context = playlistContext {
            displayedVideos = context.liveVideosForArtist(artist)
        } else {
            displayedVideos = videos.filter { $0.artist == artist }
        }
    }

    /// Load all videos by the current artist from DirectVideoService (MTvVideosNEW)
    private func loadArtistVideos() {
        let artistName = currentVideo.artist
        var artistVideos: [PlaylistVideo] = []
        var addedVideoIds = Set<String>()

        // Parse individual artist names (handles "Queen & David Bowie" etc.)
        let separators = [" & ", " feat. ", " feat ", " featuring ", " and ", ", ", "/"]
        var artistNames = [artistName]
        for separator in separators {
            artistNames = artistNames.flatMap { $0.components(separatedBy: separator) }
        }
        artistNames = artistNames.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        // Search all videos from DirectVideoService
        let allVideos = DirectVideoService.shared.videos

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
                    year: String(record.fields.yearInt ?? 0)
                ))
            }
        }

        // Sort by year descending (newest first)
        artistVideos.sort { $0.year > $1.year }

        if !artistVideos.isEmpty {
            displayedVideos = artistVideos
            print("🎬 VJ Mode: Loaded \(artistVideos.count) videos for artist(s): \(artistNames.joined(separator: ", "))")
        }
    }

    private func playVideo(_ video: PlaylistVideo) {
        currentVideo = video
        onVideoChange(video)
        isFavorited = favoritesService.isFavorited(video.id)
        // Reset preserved position since this is a new video (not a mode transition)
        playerCoordinator.resetPreservedPosition()
    }

    private func playNextVideo() {
        guard let currentIndex = displayedVideos.firstIndex(where: { $0.id == currentVideo.id }),
              currentIndex + 1 < displayedVideos.count else {
            if let first = displayedVideos.first {
                playVideo(first)
            }
            return
        }
        playVideo(displayedVideos[currentIndex + 1])
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
