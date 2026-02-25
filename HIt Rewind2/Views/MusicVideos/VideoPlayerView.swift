//
//  VideoPlayerView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import YouTubeiOSPlayerHelper
import AVKit
import AVFoundation

// MARK: - Non-Bouncing Horizontal ScrollView
/// A horizontal scroll view that doesn't bounce vertically
struct NonBouncingHScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    let contentHeight: CGFloat

    init(contentHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self.contentHeight = contentHeight
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true // Allow horizontal bounce
        scrollView.alwaysBounceVertical = false // Disable vertical bounce
        scrollView.alwaysBounceHorizontal = true
        scrollView.backgroundColor = .clear

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.hostingController = hostingController

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var hostingController: UIHostingController<Content>?
    }
}

// MARK: - Layout Measurement Preferences
struct TabBarPositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - YouTube Player Coordinator with Controls
class YouTubePlayerCoordinator: NSObject, ObservableObject, YTPlayerViewDelegate {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Float = 0
    @Published var duration: Float = 0
    @Published var videoDidEnd: Bool = false
    weak var playerView: YTPlayerView?
    var onVideoEnd: (() -> Void)?

    // Track video ID to detect when video changes vs player recreation
    private var lastVideoId: String?
    private var pendingSeekTime: Float?

    func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
        print("🎮 playerViewDidBecomeReady called - setting playerView reference")
        self.playerView = playerView

        // Auto-play when ready (iOS often ignores the autoplay parameter)
        playerView.playVideo()

        // If we have a pending seek time (from mode transition), seek to it
        if let seekTime = pendingSeekTime, seekTime > 0 {
            print("🎬 Coordinator: Seeking to preserved position \(seekTime)")
            playerView.seek(toSeconds: seekTime, allowSeekAhead: true)
            pendingSeekTime = nil
        }

        // Get initial duration - defer state update to avoid view update conflicts
        playerView.duration { [weak self] duration, error in
            Task { @MainActor in
                self?.duration = Float(duration)
            }
        }
    }

    /// Call before destroying a player to preserve position for the next player
    func preservePlaybackPosition() {
        if currentTime > 0 {
            pendingSeekTime = currentTime
            print("🎬 Coordinator: Preserved playback position \(currentTime)")
        }
    }

    /// Reset preserved position (call when video changes)
    func resetPreservedPosition() {
        pendingSeekTime = nil
        currentTime = 0
        duration = 0
    }

    func playerView(_ playerView: YTPlayerView, receivedError error: YTPlayerError) {
    }

    func playerView(_ playerView: YTPlayerView, didChangeTo state: YTPlayerState) {
        // Use Task to defer state updates until after the current view update cycle
        // This prevents "Modifying state during view update" warnings
        Task { @MainActor in
            self.isPlaying = state == .playing

            // Notify ContentView of player state change
            NotificationCenter.default.post(
                name: .playerStateChanged,
                object: nil,
                userInfo: ["isPlaying": state == .playing]
            )

            // Detect video end for autoplay
            if state == .ended {
                print("🎬 YouTubePlayerCoordinator: Video state is .ended")
                print("🎬 YouTubePlayerCoordinator: onVideoEnd callback exists: \(self.onVideoEnd != nil)")
                self.videoDidEnd = true
                self.onVideoEnd?()
            }
        }
    }
    
    func stopVideo() {
        playerView?.stopVideo()
    }

    // MARK: - Player Control Methods
    func play() {
        print("🎮 play() called - playerView: \(playerView != nil ? "exists" : "NIL")")
        playerView?.playVideo()
    }

    func pause() {
        print("🎮 pause() called - playerView: \(playerView != nil ? "exists" : "NIL")")
        playerView?.pauseVideo()
    }

    func togglePlayPause() {
        print("🎮 togglePlayPause() called - isPlaying: \(isPlaying), playerView: \(playerView != nil ? "exists" : "NIL")")
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func skipForward(seconds: Float = 10) {
        print("🎮 skipForward(\(seconds)) called - currentTime: \(currentTime), playerView: \(playerView != nil ? "exists" : "NIL")")
        playerView?.seek(toSeconds: currentTime + seconds, allowSeekAhead: true)
    }

    func skipBackward(seconds: Float = 10) {
        print("🎮 skipBackward(\(seconds)) called - currentTime: \(currentTime), playerView: \(playerView != nil ? "exists" : "NIL")")
        playerView?.seek(toSeconds: max(0, currentTime - seconds), allowSeekAhead: true)
    }

    func seekTo(seconds: Float) {
        print("🎮 seekTo(\(seconds)) called - playerView: \(playerView != nil ? "exists" : "NIL")")
        playerView?.seek(toSeconds: seconds, allowSeekAhead: true)
    }

    func getCurrentTime() {
        guard let pv = playerView else {
            print("⏱️ getCurrentTime: playerView is NIL")
            return
        }
        pv.currentTime { [weak self] time, error in
            if let error = error {
                print("⏱️ getCurrentTime callback ERROR: \(error)")
            }
            Task { @MainActor in
                if time != self?.currentTime {
                    print("⏱️ getCurrentTime: \(time) (was \(self?.currentTime ?? -1))")
                }
                self?.currentTime = time
            }
        }
    }

    func getDuration() {
        guard let pv = playerView else {
            print("⏱️ getDuration: playerView is NIL")
            return
        }
        pv.duration { [weak self] duration, error in
            if let error = error {
                print("⏱️ getDuration callback ERROR: \(error)")
            }
            Task { @MainActor in
                let floatDuration = Float(duration)
                if floatDuration != self?.duration {
                    print("⏱️ getDuration: \(floatDuration) (was \(self?.duration ?? -1))")
                }
                self?.duration = floatDuration
            }
        }
    }
}

// MARK: - YouTube Player View with Coordinator
struct VideoPlayerView: UIViewRepresentable {
    let youtubeURL: String
    let coordinator: YouTubePlayerCoordinator

    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        playerView.backgroundColor = .black
        playerView.delegate = coordinator

        // Set playerView reference on coordinator immediately
        coordinator.playerView = playerView
        print("🎬 VideoPlayerView: makeUIView - set playerView reference on coordinator")

        // Store the current video ID for change detection
        context.coordinator.currentVideoId = extractYouTubeVideoID(from: youtubeURL)

        // Extract video ID from YouTube URL and load video
        if let videoId = context.coordinator.currentVideoId {
            playerView.load(withVideoId: videoId, playerVars: [
                "playsinline": 1,
                "controls": 0,
                "showinfo": 0,
                "rel": 0,
                "autoplay": 1,
                "iv_load_policy": 3,
                "modestbranding": 1,
                "fs": 0
            ])
        }

        return playerView
    }

    func updateUIView(_ uiView: YTPlayerView, context: Context) {
        // Ensure delegate is always set (in case SwiftUI recreates the view)
        if uiView.delegate !== coordinator {
            print("🎬 VideoPlayerView: Re-setting delegate")
            uiView.delegate = coordinator
        }

        // Also ensure the coordinator has a reference to the player view
        if coordinator.playerView !== uiView {
            print("🎬 VideoPlayerView: Re-setting playerView reference on coordinator")
            coordinator.playerView = uiView
        }

        // Detect video URL change and load new video without recreating player
        let newVideoId = extractYouTubeVideoID(from: youtubeURL)

        if let newId = newVideoId, newId != context.coordinator.currentVideoId {
            print("🎬 VideoPlayerView: Loading new video \(newId) (was: \(context.coordinator.currentVideoId ?? "nil"))")
            context.coordinator.currentVideoId = newId

            // Load new video in existing player - this preserves the view and just swaps content
            uiView.load(withVideoId: newId, playerVars: [
                "playsinline": 1,
                "controls": 0,
                "showinfo": 0,
                "rel": 0,
                "autoplay": 1,
                "iv_load_policy": 3,
                "modestbranding": 1,
                "fs": 0
            ])
        }
    }

    func makeCoordinator() -> ViewCoordinator {
        ViewCoordinator()
    }

    // Coordinator to track current video ID for change detection
    class ViewCoordinator {
        var currentVideoId: String?
    }
}

// MARK: - Single Video View with AirPlay-Safe Layout
// DEPRECATED: This view is no longer used. All video navigation now goes directly to VJModeView.
// Keeping this code for reference in case it's needed for future features.
struct SingleVideoView: View {
    // Initial values passed in
    let initialYoutubeURL: String
    let initialVideoTitle: String
    let initialArtistName: String
    let initialYear: String
    let playlistContext: PlaylistContext? // Optional playlist context for autoplay

    // Current video state (can be swapped without rebuilding view)
    @State private var currentYoutubeURL: String = ""
    @State private var currentVideoTitle: String = ""
    @State private var currentArtistName: String = ""
    @State private var currentYear: String = ""

    // Backward compatibility - extract video ID for other features
    private var videoId: String {
        return extractYouTubeVideoID(from: currentYoutubeURL) ?? ""
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared

    // Layout state
    @State private var tabBarPosition: CGFloat = 0
    @State private var isAirPlayActive: Bool = false

    // Timer for updating current time
    @State private var timeUpdateTimer: Timer?

    // YouTube player coordinator
    @StateObject private var playerCoordinator = YouTubePlayerCoordinator()

    // Navigation to next video
    @State private var nextVideoToPlay: PlaylistVideo?

    // State for horizontal video scroll (Music Videos mode)
    @State private var yearVideos: [PlaylistVideo] = []
    @State private var selectedBrowseYear: Int?

    // State for artist mode (tappable artist name shows all videos by that artist)
    @State private var isShowingArtistModeVideos = false
    @State private var artistModeVideos: [PlaylistVideo] = []
    @State private var isLoadingArtistMode = false

    // State for artist browsing (Epic Shows mode)
    @State private var artistVideos: [PlaylistVideo] = []
    @State private var selectedBrowseArtist: String?

    // State for concert videos (Concert mode)
    @State private var concertVideos: [PlaylistVideo] = []

    // State for live artist browsing (Live mode)
    @State private var liveArtistVideos: [PlaylistVideo] = []
    @State private var selectedLiveArtist: String?
    @State private var isLoadingLiveArtist: Bool = false
    @State private var liveArtistVideosCache: [String: [PlaylistVideo]] = [:] // Cache fetched artist videos

    // State for favorite button
    @State private var isFavorited: Bool = false

    // State for animated gradient button
    @State private var gradientOffset: CGFloat = 0
    @State private var gradientOffsetY: CGFloat = 0
    @State private var isButtonPressed: Bool = false

    // State for orientation detection (default true since app is landscape-only)
    @State private var isLandscape: Bool = true

    // State for VJ Mode
    @State private var showVJMode: Bool = false
    @State private var showScreenShareTutorial: Bool = false

    private var videoHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let standardHeight = screenWidth * 9/16
        if UIDevice.current.userInterfaceIdiom == .pad {
            return standardHeight * 1.15 // 15% taller for iPad
        } else {
            return standardHeight * 1.2 // 20% taller for iPhone (compact)
        }
    }
    
    private var videoWidth: CGFloat {
        UIScreen.main.bounds.width // No side padding - full width
    }

    // Available years from DirectVideoService (MTvVideosNEW - same as Top 100 page)
    private var availableYears: [Int] {
        DirectVideoService.shared.availableYears
    }

    // Check if we're in Epic Shows mode
    private var isEpicShowsMode: Bool {
        guard let context = playlistContext else { return false }
        if case .epicShows = context.sourceType {
            return true
        }
        return false
    }

    // Check if we're in Concert mode
    private var isConcertMode: Bool {
        guard let context = playlistContext else { return false }
        if case .concert = context.sourceType {
            return true
        }
        return false
    }

    // Check if we're in Live mode (FanCams)
    private var isLiveMode: Bool {
        guard let context = playlistContext else { return false }
        if case .live = context.sourceType {
            return true
        }
        return false
    }

    // Check if we're in a mode that hides the picker (Concert and Epic Shows)
    private var isNoPickerMode: Bool {
        isConcertMode || isEpicShowsMode
    }

    // Available artists from Epic Shows category
    private var availableArtists: [String] {
        playlistContext?.categoryArtists ?? []
    }

    // Available artists from Live/FanCams category
    private var availableLiveArtists: [String] {
        playlistContext?.liveArtists ?? []
    }

    // Category name for Epic Shows mode
    private var categoryName: String? {
        guard let context = playlistContext,
              case .epicShows(let name, _) = context.sourceType else { return nil }
        return name
    }

    // MARK: - AirPlay Detection and Layout Helpers
    private func detectAirPlayState() {
        DispatchQueue.main.async {
            // Check audio route first (most reliable for AirPlay)
            let audioSession = AVAudioSession.sharedInstance()
            let hasAirPlayAudio = audioSession.currentRoute.outputs.contains { output in
                output.portType == .airPlay
            }

            // Check for external screens (secondary method)
            let externalScreens: [UIScreen]
            if #available(iOS 16.0, *) {
                externalScreens = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .compactMap { $0.screen }
                    .filter { $0 != UIScreen.main }
            } else {
                // swiftlint:disable:next deprecated_api_usage
                externalScreens = (UIScreen.screens as [UIScreen]).filter { $0 != UIScreen.main }
            }
            let hasExternalScreen = !externalScreens.isEmpty

            // AirPlay is active if EITHER audio route OR external screen is detected
            let wasActive = self.isAirPlayActive
            self.isAirPlayActive = hasAirPlayAudio || hasExternalScreen

            if wasActive != self.isAirPlayActive {
                print("🎥 AirPlay state changed: \(self.isAirPlayActive ? "ACTIVE ✅" : "INACTIVE ❌")")
                print("🎥 Audio route AirPlay: \(hasAirPlayAudio), External screen: \(hasExternalScreen)")
            }
        }
    }

    private func updateLayoutForAirPlay() {
        // No-op - layout is now tab bar relative
    }
    
}

extension SingleVideoView {
    var body: some View {
        ZStack {
            // Custom header for all devices - hide in landscape
            if !isLandscape {
                VStack {
                    HStack {
                        // Left side - Back button with trailing spacer to match right side width
                        HStack(spacing: 16) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.hitRewindPurple)
                            }
                            // Invisible spacer to match right side
                            Color.clear
                                .frame(width: 22, height: 22)
                        }

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

                    Spacer()
                }
                .zIndex(1)
            }

            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                // Calculate video height to fit within available space
                // Reserve space for: header(75) + progress(28) + info(40) + controls(68) + picker(46) + videos(140) + button(56) + spacer(8)
                // iPad portrait needs more space (~480pt), iPad landscape needs less (no header), iPhone needs 360pt
                let reservedHeight: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? (isLandscape ? 320 : 480) : 360
                let calculatedVideoHeight = min(videoHeight, availableHeight - reservedHeight)
                let finalVideoHeight = max(calculatedVideoHeight, 160) // Minimum video height

                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Top spacer for header - reduced in landscape when header is hidden
                        Spacer()
                            .frame(height: isLandscape ? 16 : (UIDevice.current.userInterfaceIdiom == .phone ? 60 : 75))

                        // Video player - hidden when VJ mode is active to avoid two players
                        if !showVJMode {
                            VideoPlayerView(youtubeURL: currentYoutubeURL, coordinator: playerCoordinator)
                                .frame(width: videoWidth, height: finalVideoHeight)
                                .background(Color.black)
                        } else {
                            // Placeholder when VJ mode is active (player is in VJ overlay)
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: videoWidth, height: finalVideoHeight)
                        }

                        // Custom progress bar
                        videoProgressBar
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                        // Song info section (song name and artist)
                        videoInfoSection
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                        // Custom control buttons
                        customControlButtons
                            .padding(.vertical, 4)

                        // Horizontal picker: Years (Music Videos), Artists (Live), or nothing (Concert/Epic Shows)
                        if isNoPickerMode {
                            // Concert/Epic Shows mode: no picker, just show videos below
                        } else if isLiveMode {
                            // Live mode: show artists from same category
                            if !availableLiveArtists.isEmpty {
                                horizontalLiveArtistPicker
                                    .padding(.top, 6)
                            }
                        } else {
                            // Music Videos mode: show years
                            if !availableYears.isEmpty {
                                horizontalYearPicker
                                    .padding(.bottom, 6)
                            }
                        }

                        // Horizontal scrolling videos
                        if isNoPickerMode {
                            // Concert/Epic Shows mode: show all videos from playlist (same concert/category)
                            if !concertVideos.isEmpty {
                                horizontalConcertVideosScroll
                                    .padding(.vertical, 8)
                            }
                        } else if isLiveMode {
                            // Live mode: show videos for selected artist
                            if isLoadingLiveArtist {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(.hitRewindPurple)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                            } else if !liveArtistVideos.isEmpty {
                                horizontalLiveVideosScroll
                                    .padding(.vertical, 8)
                            }
                        } else {
                            // Music Videos mode: show videos for selected year or artist
                            if isLoadingArtistMode {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(.hitRewindPurple)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                            } else if !displayedMusicVideos.isEmpty {
                                horizontalVideosScroll
                                    .padding(.vertical, 8)
                            }
                        }

                        // Animated AirPlay button
                        animatedAirPlayButton
                            .padding(.top, 8)
                            .padding(.horizontal, 20)

                        Spacer(minLength: 8)
                    }
                }
            }

            // Hidden navigationDestination for autoplay to next video
            Color.clear
                .navigationDestination(item: $nextVideoToPlay) { video in
                    createNextVideoView(from: video)
                }
        }
        // VJ Mode as overlay (shares the same player - no interruption)
        .overlay {
            if showVJMode {
                VJModeOverlay(
                    playerCoordinator: playerCoordinator,
                    currentVideo: Binding(
                        get: {
                            PlaylistVideo(
                                id: videoId,
                                youtubeURL: currentYoutubeURL,
                                title: currentVideoTitle,
                                artist: currentArtistName,
                                year: currentYear
                            )
                        },
                        set: { newVideo in
                            currentYoutubeURL = newVideo.youtubeURL
                            currentVideoTitle = newVideo.title
                            currentArtistName = newVideo.artist
                            currentYear = newVideo.year
                        }
                    ),
                    videos: getCurrentVideoList(),
                    playlistContext: playlistContext,
                    isPresented: $showVJMode,
                    onVideoChange: { video in
                        // Update the current video in SingleVideoView
                        currentYoutubeURL = video.youtubeURL
                        currentVideoTitle = video.title
                        currentArtistName = video.artist
                        currentYear = video.year
                        isFavorited = favoritesService.isFavorited(video.id)
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        // Screen share tutorial overlay (shown first time entering VJ Mode)
        .overlay {
            if showScreenShareTutorial {
                ScreenShareTutorialView(
                    isPresented: $showScreenShareTutorial,
                    onDismiss: {
                        // After tutorial, proceed to VJ Mode
                        playerCoordinator.preservePlaybackPosition()
                        showVJMode = true
                    }
                )
                .transition(.opacity)
                .zIndex(101)
            }
        }
        .onAppear {
            setupVideoPlayer()
            detectOrientation()

            // Listen for orientation changes
            NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                detectOrientation()
            }
        }
        .onDisappear {
            // Clean up timers and observers
            // NOTE: We don't stop the video here to allow AirPlay to continue when switching tabs
            timeUpdateTimer?.invalidate()
            timeUpdateTimer = nil
            NotificationCenter.default.removeObserver(self, name: UIScene.didActivateNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerTogglePlayPause, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerSkipForward, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerSkip60Forward, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerSkipToNext, object: nil)

            // Notify ContentView that video player is dismissed
            NotificationCenter.default.post(name: .videoPlayerDismissed, object: nil)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea(.all, edges: .bottom)
        .background(
            NavigationConfigurator { nc in
                nc.hidesBarsOnSwipe = false
            }
        )
    }

    // MARK: - Video Progress Bar

    private var videoProgressBar: some View {
        VStack(spacing: 8) {
            // Progress bar with gesture
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // 4px spacer above
                    Spacer()
                        .frame(height: 4)

                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.hitRewindPurple)
                            .frame(width: progressWidth(for: geometry.size.width), height: 6)

                        // Diamond playhead marker
                        ProgressDiamond()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .offset(x: progressWidth(for: geometry.size.width) - 7) // Center the diamond
                    }
                    .frame(height: 14) // Height to accommodate diamond
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            seekToPosition(value.location.x, width: geometry.size.width)
                        }
                )
            }
            .frame(height: 18)

            // Time labels
            HStack {
                Text(formatTime(playerCoordinator.currentTime))
                    .font(.caption2)
                    .foregroundColor(.white)

                Spacer()

                Text(formatTime(playerCoordinator.duration))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        guard playerCoordinator.duration > 0 else { return 0 }
        let progress = CGFloat(playerCoordinator.currentTime / playerCoordinator.duration)
        return totalWidth * progress
    }

    private func seekToPosition(_ x: CGFloat, width: CGFloat) {
        let percentage = max(0, min(1, x / width))
        let seekTime = Float(percentage) * playerCoordinator.duration
        playerCoordinator.seekTo(seconds: seekTime)
    }

    private func formatTime(_ seconds: Float) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    // MARK: - Video Info Section

    private var videoInfoSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(currentVideoTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()

            // Artist name - tappable only in Music Videos mode
            if isLiveMode || isNoPickerMode {
                // Live/Concert/Epic Shows: plain grey text, not tappable
                Text(currentArtistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                // Music Videos mode: tappable to show all videos by this artist
                Button(action: {
                    showArtistModeVideos()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 14))
                        Text(currentArtistName)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    .foregroundColor(Color.hitRewindPurple)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Custom Control Buttons

    private var customControlButtons: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)

            // Favorite button
            Button(action: {
                print("🎬 Favorite button tapped for video: \(currentVideoTitle)")
                if authService.isAuthenticated {
                    print("🎬 User authenticated, toggling favorite...")
                    favoritesService.toggleFavorite(videoId: videoId, title: currentVideoTitle, artist: currentArtistName, year: currentYear)
                    isFavorited.toggle()
                } else {
                    print("🎬 User not authenticated, showing sign-in sheet")
                    NotificationCenter.default.post(name: .showSignInSheet, object: nil)
                }
            }) {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor(isFavorited ? .red : Color.hitRewindPurple)
                    .frame(width: 60, height: 60)
                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            // Play/Pause button
            Button(action: {
                playerCoordinator.togglePlayPause()
            }) {
                Image(systemName: playerCoordinator.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.hitRewindPurple)
                    .frame(width: 60, height: 60)
                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            // Skip forward 10s button
            Button(action: {
                playerCoordinator.skipForward(seconds: 10)
            }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 24))
                    .foregroundColor(Color.hitRewindPurple)
                    .frame(width: 60, height: 60)
                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            // Skip forward 60s button
            Button(action: {
                playerCoordinator.skipForward(seconds: 60)
            }) {
                Image(systemName: "goforward.60")
                    .font(.system(size: 20))
                    .foregroundColor(Color.hitRewindPurple)
                    .frame(width: 60, height: 60)
                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            // Skip to next video button
            Button(action: {
                playNextVideo()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.hitRewindPurple)
                    .frame(width: 60, height: 60)
                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Horizontal Year Picker

    private var horizontalYearPicker: some View {
        NonBouncingHScrollView(contentHeight: 36) {
            HStack(spacing: 8) {
                ForEach(availableYears, id: \.self) { year in
                    Button(action: {
                        selectedBrowseYear = year
                        isShowingArtistModeVideos = false // Exit artist mode when year is tapped
                        fetchVideosForYear(year)
                    }) {
                        Text(String(year))
                            .font(.custom(AppFont.ticketingName(), size: 18))
                            .fontWeight(selectedBrowseYear == year ? .bold : .medium)
                            .foregroundColor(selectedBrowseYear == year ? .black : .hitRewindPrimaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedBrowseYear == year ? Color.hitRewindPurple : Color.hitRewindSecondaryBackground)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 36)
        .padding(.vertical, 5) // 5 pixels above and below
    }

    // MARK: - Horizontal Artist Picker (Epic Shows mode)

    private var horizontalArtistPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Category name header
            if let name = categoryName {
                Text(name)
                    .font(.custom(AppFont.ticketingName(), size: 14))
                    .foregroundColor(.hitRewindSecondaryText)
                    .padding(.horizontal, 20)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(availableArtists, id: \.self) { artist in
                        Button(action: {
                            selectedBrowseArtist = artist
                            fetchVideosForArtist(artist)
                        }) {
                            Text(artist)
                                .font(.custom(AppFont.ticketingName(), size: 16))
                                .fontWeight(selectedBrowseArtist == artist ? .bold : .medium)
                                .foregroundColor(selectedBrowseArtist == artist ? .black : .hitRewindPrimaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedBrowseArtist == artist ? Color.hitRewindPurple : Color.hitRewindSecondaryBackground)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 36)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Horizontal Live Artist Picker (Live/FanCams mode)

    private var horizontalLiveArtistPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(availableLiveArtists, id: \.self) { artist in
                    Button(action: {
                        selectedLiveArtist = artist
                        fetchLiveVideosForArtist(artist)
                    }) {
                        Text(artist)
                            .font(.custom(AppFont.ticketingName(), size: 16))
                            .fontWeight(selectedLiveArtist == artist ? .bold : .medium)
                            .foregroundColor(selectedLiveArtist == artist ? .black : .hitRewindPrimaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedLiveArtist == artist ? Color.hitRewindPurple : Color.hitRewindSecondaryBackground)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 36)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Horizontal Videos Scroll

    /// Videos to display in Music Videos mode - either year-based or artist-based
    private var displayedMusicVideos: [PlaylistVideo] {
        isShowingArtistModeVideos ? artistModeVideos : yearVideos
    }

    private var horizontalVideosScroll: some View {
        NonBouncingHScrollView(contentHeight: 120) {
            HStack(spacing: 12) {
                ForEach(Array(displayedMusicVideos.enumerated()), id: \.element.id) { index, video in
                    Button(action: {
                        playVideo(video)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            // Video thumbnail with badge
                            ZStack {
                                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.id)/mqdefault.jpg")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 140, height: 78.75)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                // Badge (top-left): Year when in artist mode, Rank when in year mode
                                VStack {
                                    HStack {
                                        Text(isShowingArtistModeVideos ? video.year : "#\(index + 1)")
                                            .font(.system(size: 11))
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.hitRewindPurple)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .padding(.leading, 5)
                                            .padding(.top, 4)

                                        Spacer()
                                    }
                                    Spacer()
                                }

                                // Highlight current video with border when in artist mode
                                if isShowingArtistModeVideos && video.id == videoId {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.hitRewindPurple, lineWidth: 2)
                                        .frame(width: 140, height: 78.75)
                                }
                            }
                            .frame(width: 140, height: 78.75)

                            // Video title
                            Text(video.title)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(width: 140, alignment: .topLeading)

                            // Artist name
                            Text(video.artist)
                                .font(.system(size: 10))
                                .foregroundColor(.hitRewindPurple)
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 140)
    }

    // MARK: - Horizontal Artist Videos Scroll (Epic Shows mode)

    private var horizontalArtistVideosScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(artistVideos.enumerated()), id: \.element.id) { index, video in
                    Button(action: {
                        playVideo(video)
                    }) {
                        VStack(alignment: .leading, spacing: 3) {
                            // Video thumbnail with year badge
                            ZStack {
                                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.id)/mqdefault.jpg")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 140, height: 78.75)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                // Year badge (top-left) - shows year instead of rank for Epic Shows
                                VStack {
                                    HStack {
                                        Text(video.year)
                                            .font(.system(size: 11))
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.hitRewindPurple)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .padding(.leading, 5)
                                            .padding(.top, 4)

                                        Spacer()
                                    }
                                    Spacer()
                                }
                            }
                            .frame(width: 140, height: 78.75)

                            // Video title
                            Text(video.title)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(width: 140, alignment: .topLeading)

                            // Artist name (in purple)
                            Text(video.artist)
                                .font(.system(size: 9))
                                .foregroundColor(.hitRewindPurple)
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 140)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Horizontal Live Videos Scroll (Live/FanCams mode)

    private var horizontalLiveVideosScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(liveArtistVideos.enumerated()), id: \.element.id) { index, video in
                    Button(action: {
                        playVideo(video)
                    }) {
                        VStack(alignment: .leading, spacing: 3) {
                            // Video thumbnail with year badge
                            ZStack {
                                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.id)/mqdefault.jpg")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 140, height: 78.75)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                // Year badge (top-left)
                                VStack {
                                    HStack {
                                        Text(video.year)
                                            .font(.system(size: 11))
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.hitRewindPurple)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .padding(.leading, 5)
                                            .padding(.top, 4)

                                        Spacer()
                                    }
                                    Spacer()
                                }

                                // Highlight current video with border
                                if video.id == videoId {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.hitRewindPurple, lineWidth: 2)
                                        .frame(width: 140, height: 78.75)
                                }
                            }
                            .frame(width: 140, height: 78.75)

                            // Video title
                            Text(video.title)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(width: 140, alignment: .topLeading)

                            // Artist name (in purple)
                            Text(video.artist)
                                .font(.system(size: 9))
                                .foregroundColor(.hitRewindPurple)
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 140)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Horizontal Concert Videos Scroll (Concert mode)

    private var horizontalConcertVideosScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(concertVideos.enumerated()), id: \.element.id) { index, video in
                    Button(action: {
                        playVideo(video)
                    }) {
                        VStack(alignment: .leading, spacing: 3) {
                            // Video thumbnail with year badge
                            ZStack {
                                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.id)/mqdefault.jpg")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 140, height: 78.75)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                // Year badge (top-left)
                                VStack {
                                    HStack {
                                        Text(video.year)
                                            .font(.system(size: 11))
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.hitRewindPurple)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .padding(.leading, 5)
                                            .padding(.top, 4)

                                        Spacer()
                                    }
                                    Spacer()
                                }

                                // Highlight current video with border
                                if video.id == videoId {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.hitRewindPurple, lineWidth: 2)
                                        .frame(width: 140, height: 78.75)
                                }
                            }
                            .frame(width: 140, height: 78.75)

                            // Video title
                            Text(video.title)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(width: 140, alignment: .topLeading)

                            // Artist name (in purple)
                            Text(video.artist)
                                .font(.system(size: 9))
                                .foregroundColor(.hitRewindPurple)
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 140)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Animated AirPlay Button

    // Shared animated gradient for both buttons
    private var animatedGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.07, green: 0.016, blue: 0.19),  // #120430
                Color(red: 0.15, green: 0.03, blue: 0.35),   // Subtle mid-tone
                Color(red: 0.22, green: 0.05, blue: 0.59),   // #380d96
                Color(red: 0.15, green: 0.03, blue: 0.35),   // Subtle mid-tone
                Color(red: 0.07, green: 0.016, blue: 0.19),  // #120430
                Color(red: 0.15, green: 0.03, blue: 0.35),   // Subtle mid-tone
                Color(red: 0.22, green: 0.05, blue: 0.59),   // #380d96
                Color(red: 0.15, green: 0.03, blue: 0.35),   // Subtle mid-tone
                Color(red: 0.07, green: 0.016, blue: 0.19),  // #120430 - seamless loop
            ]),
            startPoint: UnitPoint(x: gradientOffset - 1.0, y: gradientOffsetY - 0.3),
            endPoint: UnitPoint(x: gradientOffset + 1.0, y: gradientOffsetY + 0.3)
        )
    }

    private var animatedAirPlayButton: some View {
        HStack(spacing: 12) {
            // VJ Mode button - works on both iPhone and iPad
            Button(action: {
                print("🎬 VJ Mode button tapped")

                // Tap animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isButtonPressed = true
                }

                // Check if user has seen the screen share tutorial
                if !ScreenShareTutorialView.hasSeenTutorial {
                    // Show tutorial first
                    showScreenShareTutorial = true
                } else {
                    // Present VJ Mode directly
                    playerCoordinator.preservePlaybackPosition()
                    showVJMode = true
                }

                // Reset animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        isButtonPressed = false
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Text("Enter")
                        .font(.custom(AppFont.ticketingName(), size: 20))
                        .kerning(1.0)
                        .foregroundColor(Color(red: 0.84, green: 0.76, blue: 1.0)) // #d6c2ff

                    Image(systemName: "music.note.tv")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(red: 0.84, green: 0.76, blue: 1.0)) // #d6c2ff

                    Text("VJ Mode")
                        .font(.custom(AppFont.ticketingName(), size: 20))
                        .kerning(1.0)
                        .foregroundColor(Color(red: 0.84, green: 0.76, blue: 1.0)) // #d6c2ff
                }
                // iPhone: full width, iPad: fixed width
                .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 280 : .infinity, minHeight: 46)
                .background(animatedGradient)
                .clipShape(RoundedRectangle(cornerRadius: 23))
                .shadow(color: Color(red: 0.22, green: 0.0, blue: 0.73).opacity(0.33), radius: 15, x: 0, y: 0)
                .scaleEffect(isButtonPressed ? 0.97 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())

            // Circular AirPlay button - shown on both iPhone and iPad
            Button(action: {
                print("🎬 AirPlay button tapped")
                AirPlayHelper.shared.showAirPlayPicker()
            }) {
                Image(systemName: isAirPlayActive ? "airplayvideo.circle.fill" : "airplayvideo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isAirPlayActive ? Color(red: 1.0, green: 0.84, blue: 0.0) : Color(red: 0.84, green: 0.76, blue: 1.0))
                    .frame(width: 46, height: 46)
                    .background(animatedGradient)
                    .clipShape(Circle())
                    .shadow(color: Color(red: 0.22, green: 0.0, blue: 0.73).opacity(0.33), radius: 10, x: 0, y: 0)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            // Start gradient animation - figure-eight wave pattern
            // X-axis moves in one direction
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                gradientOffset = 2.0
            }

            // Y-axis oscillates to create wave/figure-eight motion
            withAnimation(.easeInOut(duration: 9.6).repeatForever(autoreverses: true)) {
                gradientOffsetY = 1.0
            }
        }
    }

    private func checkAudioRoute() {
        // Just call the unified detection method
        detectAirPlayState()
    }

    private func detectOrientation() {
        DispatchQueue.main.async {
            let wasLandscape = self.isLandscape

            // Use screen bounds for reliable landscape detection
            // UIDevice.current.orientation can be .unknown or .faceUp/.faceDown which returns false for isLandscape
            let screenBounds = UIScreen.main.bounds
            let isScreenLandscape = screenBounds.width > screenBounds.height

            // Update landscape state based on screen dimensions (more reliable)
            self.isLandscape = isScreenLandscape

            if wasLandscape != self.isLandscape {
                print("📱 Orientation changed - Landscape: \(self.isLandscape) (screen: \(screenBounds.width)x\(screenBounds.height))")

                // Auto-enter VJ mode when rotating to landscape (both iPhone and iPad)
                if self.isLandscape && !self.showVJMode {
                    print("📱 Auto-entering VJ mode due to landscape rotation")
                    self.playerCoordinator.preservePlaybackPosition()
                    self.showVJMode = true
                }
            }
        }
    }

    private func getAirPlayDeviceName() -> String? {
        // Try to get device name from audio route first
        let audioSession = AVAudioSession.sharedInstance()
        let airPlayOutput = audioSession.currentRoute.outputs.first { $0.portType == .airPlay }
        if let deviceName = airPlayOutput?.portName {
            return deviceName
        }

        // Fallback to external screens
        if #available(iOS 16.0, *) {
            let externalScreens = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .compactMap { $0.screen }
                .filter { $0 != UIScreen.main }

            // Get the first external screen's name if available
            return externalScreens.first?.mirrored?.debugDescription.components(separatedBy: ":").first
        } else {
            return nil
        }
    }

    // MARK: - Helper Methods

    private func playVideo(_ video: PlaylistVideo) {
        // Swap video content in place instead of navigating
        withAnimation(.easeInOut(duration: 0.2)) {
            currentYoutubeURL = video.youtubeURL
            currentVideoTitle = video.title
            currentArtistName = video.artist
            currentYear = video.year
        }

        // Update favorite state for new video
        let newVideoId = extractYouTubeVideoID(from: video.youtubeURL) ?? ""
        isFavorited = favoritesService.isFavorited(newVideoId)

        // Reset preserved position since this is a new video
        playerCoordinator.resetPreservedPosition()

        // Notify ContentView of video change
        NotificationCenter.default.post(
            name: .videoPlayerPresented,
            object: nil,
            userInfo: [
                "videoId": newVideoId,
                "title": video.title,
                "artist": video.artist,
                "year": video.year
            ]
        )
    }

    private func fetchYearVideos() {
        // Initialize with current video's year
        let yearInt = Int(currentYear) ?? 0
        selectedBrowseYear = yearInt
        fetchVideosForYear(yearInt)
    }

    private func fetchArtistVideos() {
        // Initialize with current video's artist
        print("🎬 fetchArtistVideos - currentArtistName: \(currentArtistName)")
        selectedBrowseArtist = currentArtistName
        fetchVideosForArtist(currentArtistName)
    }

    private func fetchVideosForArtist(_ artist: String) {
        // Get videos for this artist from the Epic Shows category
        guard let context = playlistContext else {
            print("🎬 fetchVideosForArtist - playlistContext is nil!")
            return
        }
        artistVideos = context.videosForArtist(artist)
        print("🎬 fetchVideosForArtist - found \(artistVideos.count) videos for artist: \(artist)")
    }

    private func fetchConcertVideos() {
        // Get all videos from the concert (passed in playlist context)
        guard let context = playlistContext else { return }
        concertVideos = context.videos
    }

    private func fetchLiveArtistVideos() {
        // Initialize with current video's artist and cache from context
        selectedLiveArtist = currentArtistName

        // Pre-populate cache with videos passed from context
        if let context = playlistContext {
            let contextVideos = context.liveVideosForArtist(currentArtistName)
            if !contextVideos.isEmpty {
                liveArtistVideosCache[currentArtistName] = contextVideos
            }
        }

        fetchLiveVideosForArtist(currentArtistName)
    }

    private func fetchLiveVideosForArtist(_ artist: String) {
        // Check cache first
        if let cachedVideos = liveArtistVideosCache[artist], !cachedVideos.isEmpty {
            print("🎬 fetchLiveVideosForArtist - using cached \(cachedVideos.count) videos for artist: \(artist)")
            liveArtistVideos = cachedVideos.sorted { first, second in
                if let firstYear = Int(first.year), let secondYear = Int(second.year) {
                    return firstYear > secondYear // Newest first
                }
                return first.title < second.title
            }
            return
        }

        // Check context for pre-loaded videos
        if let context = playlistContext {
            let contextVideos = context.liveVideosForArtist(artist)
            if !contextVideos.isEmpty {
                print("🎬 fetchLiveVideosForArtist - found \(contextVideos.count) videos in context for artist: \(artist)")
                let sortedVideos = contextVideos.sorted { first, second in
                    if let firstYear = Int(first.year), let secondYear = Int(second.year) {
                        return firstYear > secondYear // Newest first
                    }
                    return first.title < second.title
                }
                liveArtistVideos = sortedVideos
                liveArtistVideosCache[artist] = sortedVideos
                return
            }
        }

        // Fetch from Airtable
        print("🎬 fetchLiveVideosForArtist - fetching from Airtable for artist: \(artist)")
        isLoadingLiveArtist = true

        Task {
            let airtableService = AirtableService.shared
            if let loaded = try? await airtableService.fetchArtist(byName: artist) {
                await MainActor.run {
                    // Convert Playlist to PlaylistVideo array
                    var videos: [PlaylistVideo] = []
                    let isVisibleFlags = loaded.fields.isVisible
                    let urlsCount = loaded.fields.videoUrls?.count ?? 0

                    // Determine visible indices
                    let visibleIndices: [Int]
                    if isVisibleFlags.isEmpty && urlsCount > 0 {
                        visibleIndices = Array(0..<urlsCount)
                    } else {
                        visibleIndices = isVisibleFlags.enumerated().compactMap { index, flag in (flag ?? false) ? index : nil }
                    }

                    // Build PlaylistVideo array from visible videos
                    for index in visibleIndices {
                        if let url = loaded.fields.videoUrls?[safe: index],
                           let videoId = extractYouTubeVideoID(from: url) {
                            let title = loaded.fields.videoTitles?[safe: index] ?? "Unknown Title"
                            let artistName = loaded.fields.artistNames?[safe: index] ?? loaded.fields.title
                            let videoYear = loaded.fields.videoYears?[safe: index] ?? String(loaded.fields.year)

                            videos.append(PlaylistVideo(
                                id: videoId,
                                youtubeURL: url,
                                title: title,
                                artist: artistName,
                                year: videoYear
                            ))
                        }
                    }

                    // Sort by year (newest first)
                    videos.sort { first, second in
                        if let firstYear = Int(first.year), let secondYear = Int(second.year) {
                            return firstYear > secondYear
                        }
                        return first.title < second.title
                    }

                    print("🎬 fetchLiveVideosForArtist - loaded \(videos.count) videos from Airtable for artist: \(artist)")
                    liveArtistVideos = videos
                    liveArtistVideosCache[artist] = videos
                    isLoadingLiveArtist = false
                }
            } else {
                await MainActor.run {
                    print("⚠️ fetchLiveVideosForArtist - failed to load artist: \(artist)")
                    liveArtistVideos = []
                    isLoadingLiveArtist = false
                }
            }
        }
    }

    private func fetchVideosForYear(_ yearInt: Int) {
        // Use DirectVideoService (MTvVideosNEW) - same data source as Top 100 page
        let directVideos = DirectVideoService.shared.videos(forYear: yearInt)

        // Convert DirectVideoRecord to PlaylistVideo
        yearVideos = directVideos.compactMap { record -> PlaylistVideo? in
            guard let url = record.fields.url,
                  let videoId = record.fields.youtubeVideoId,
                  let title = record.fields.title else { return nil }

            return PlaylistVideo(
                id: videoId,
                youtubeURL: url,
                title: title,
                artist: record.fields.artistName ?? "Unknown Artist",
                year: String(yearInt)
            )
        }
    }

    // MARK: - Artist Mode (Tappable Artist Name)

    /// Parse individual artist names from a combined field like "Queen & David Bowie"
    private func parseArtistNames(from artistField: String) -> [String] {
        // Split on common separators: &, feat., featuring, and, comma, /
        let separators = [" & ", " feat. ", " feat ", " featuring ", " and ", ", ", "/"]
        var names = [artistField]

        for separator in separators {
            names = names.flatMap { $0.components(separatedBy: separator) }
        }

        // Trim whitespace and filter empty strings
        return names.map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
    }

    /// Show all videos by the current artist (called when artist name is tapped)
    private func showArtistModeVideos() {
        print("🎬 Artist name tapped: \(currentArtistName)")
        isLoadingArtistMode = true
        isShowingArtistModeVideos = true

        Task {
            await fetchArtistModeVideos(for: currentArtistName)
        }
    }

    /// Fetch all videos containing ANY of the parsed artist names
    private func fetchArtistModeVideos(for artistField: String) async {
        var results: [PlaylistVideo] = []
        var addedVideoIds = Set<String>() // Prevent duplicates

        // Parse all individual artist names from the field
        let artistNames = parseArtistNames(from: artistField)
        print("🎬 Parsed artist names: \(artistNames)")

        // Ensure DirectVideoService has loaded its videos
        if DirectVideoService.shared.videos.isEmpty {
            print("🎬 DirectVideoService is empty, fetching videos...")
            await DirectVideoService.shared.fetchVideos()
        }

        // Search all cached videos from DirectVideoService (MTvVideosNEW)
        let allVideos = DirectVideoService.shared.videos
        print("🎬 Searching through \(allVideos.count) videos for artist match")

        for record in allVideos {
            guard let artistName = record.fields.artistName,
                  let url = record.fields.url,
                  let videoId = record.fields.youtubeVideoId,
                  let title = record.fields.title else { continue }

            // Check if this video's artist contains ANY of our target artists
            let matchesAnyArtist = artistNames.contains { targetArtist in
                artistName.localizedCaseInsensitiveContains(targetArtist)
            }

            if matchesAnyArtist && !addedVideoIds.contains(videoId) {
                addedVideoIds.insert(videoId)
                results.append(PlaylistVideo(
                    id: videoId,
                    youtubeURL: url,
                    title: title,
                    artist: artistName,
                    year: String(record.fields.yearInt ?? 0)
                ))
            }
        }

        // Sort by year (newest first), then by title
        artistModeVideos = results.sorted {
            if $0.year != $1.year { return $0.year > $1.year }
            return $0.title < $1.title
        }

        isLoadingArtistMode = false
        print("🎬 Found \(artistModeVideos.count) videos for artist(s): \(artistNames.joined(separator: ", "))")
    }

    private func setupVideoPlayer() {
        // Initialize current state from initial values
        currentYoutubeURL = initialYoutubeURL
        currentVideoTitle = initialVideoTitle
        currentArtistName = initialArtistName
        currentYear = initialYear

        // Register this player with the manager, which will stop any previous video
        VideoPlayerManager.shared.registerPlayer(playerCoordinator)

        // Initialize favorite state
        isFavorited = favoritesService.isFavorited(videoId)

        // Initialize browsing based on source type
        print("🎬 VideoPlayer setup - playlistContext: \(playlistContext != nil ? "exists" : "nil")")
        if let context = playlistContext {
            print("🎬 VideoPlayer setup - sourceType: \(context.sourceType)")
            print("🎬 VideoPlayer setup - isConcertMode: \(isConcertMode), isLiveMode: \(isLiveMode), isEpicShowsMode: \(isEpicShowsMode)")
        }

        if isNoPickerMode {
            // Concert/Epic Shows mode: use all videos from the playlist context (no picker needed)
            print("🎬 Entering Concert/Epic Shows mode (no picker)")
            fetchConcertVideos()
        } else if isLiveMode {
            // Live mode: initialize with current artist, show category artists in picker
            print("🎬 Entering Live mode - artists: \(availableLiveArtists)")
            fetchLiveArtistVideos()
        } else {
            // Music Videos mode: ensure DirectVideoService has data before fetching year videos
            print("🎬 Entering Music Videos mode")
            Task {
                // Use DirectVideoService (MTvVideosNEW) - same data source as Top 100 page
                if DirectVideoService.shared.videos.isEmpty {
                    await DirectVideoService.shared.fetchVideos()
                }

                // Now fetch videos for the current year
                fetchYearVideos()
            }
        }

        detectAirPlayState()
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            playerCoordinator.getCurrentTime()
            // Also update AirPlay state periodically
            detectAirPlayState()
        }

        NotificationCenter.default.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { _ in
            detectAirPlayState()
        }

        // Listen for AirPlay route changes
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { notification in
            print("🎥 Audio route changed notification received")
            detectAirPlayState()
            checkAudioRoute()
        }

        // Initial audio route check
        checkAudioRoute()

        // Listen for player control notifications from ContentView
        NotificationCenter.default.addObserver(forName: .playerTogglePlayPause, object: nil, queue: .main) { _ in
            playerCoordinator.togglePlayPause()
        }
        NotificationCenter.default.addObserver(forName: .playerSkipForward, object: nil, queue: .main) { _ in
            playerCoordinator.skipForward(seconds: 10)
        }
        NotificationCenter.default.addObserver(forName: .playerSkip60Forward, object: nil, queue: .main) { _ in
            playerCoordinator.skipForward(seconds: 60)
        }
        NotificationCenter.default.addObserver(forName: .playerSkipToNext, object: nil, queue: .main) { _ in
            self.playNextVideo()
        }

        // Notify ContentView that video player is presented
        NotificationCenter.default.post(
            name: .videoPlayerPresented,
            object: nil,
            userInfo: [
                "videoId": videoId,
                "title": currentVideoTitle,
                "artist": currentArtistName,
                "year": currentYear
            ]
        )

        // Setup autoplay callback if playlist context exists
        if let context = playlistContext, context.hasNextVideo {
            playerCoordinator.onVideoEnd = {
                print("🎬 Autoplay: Current video ended, loading next video")
                self.playNextVideo()
            }
        }
    }

    private func playNextVideo() {
        guard let context = playlistContext,
              let nextVideo = context.nextVideo else {
            print("🎬 Autoplay: No next video available")
            return
        }

        print("🎬 Autoplay: Playing next video - \(nextVideo.title)")

        // Trigger navigation to next video
        nextVideoToPlay = nextVideo
    }

    /// Get the current video list based on the active mode
    /// Used when entering VJ Mode to pass the appropriate video list
    private func getCurrentVideoList() -> [PlaylistVideo] {
        if isNoPickerMode {
            // Concert/Epic Shows: use concert videos
            return concertVideos
        } else if isLiveMode {
            // Live mode: use artist videos
            return liveArtistVideos
        } else {
            // Music Videos mode: use year videos
            return yearVideos
        }
    }

    private func createNextVideoView(from video: PlaylistVideo) -> SingleVideoView {
        // Create playlist context for the next video
        guard let context = playlistContext else {
            return SingleVideoView(
                initialYoutubeURL: video.youtubeURL,
                initialVideoTitle: video.title,
                initialArtistName: video.artist,
                initialYear: video.year,
                playlistContext: nil
            )
        }

        // Preserve the source type when creating next video context
        let newContext = PlaylistContext(
            videos: context.videos,
            currentIndex: context.currentIndex + 1,
            sourceType: context.sourceType
        )

        return SingleVideoView(
            initialYoutubeURL: video.youtubeURL,
            initialVideoTitle: video.title,
            initialArtistName: video.artist,
            initialYear: video.year,
            playlistContext: newContext
        )
    }
}


// MARK: - Diamond Shape for Progress Bar Playhead

/// Diamond shape used as a playhead marker on progress bars
struct ProgressDiamond: Shape {
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
    NavigationView {
        SingleVideoView(
            initialYoutubeURL: "https://www.youtube.com/watch?v=M7lc1UVf-VE",
            initialVideoTitle: "Sample Video Title",
            initialArtistName: "Sample Artist",
            initialYear: "2023",
            playlistContext: nil
        )
    }
}