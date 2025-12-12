//
//  VideoPlayerView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import YouTubeiOSPlayerHelper
import AVKit

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

    func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
        self.playerView = playerView

        // Get initial duration
        playerView.duration { [weak self] duration, error in
            DispatchQueue.main.async {
                self?.duration = Float(duration)
            }
        }
    }

    func playerView(_ playerView: YTPlayerView, receivedError error: YTPlayerError) {
    }

    func playerView(_ playerView: YTPlayerView, didChangeTo state: YTPlayerState) {
        DispatchQueue.main.async {
            self.isPlaying = state == .playing

            // Notify ContentView of player state change
            NotificationCenter.default.post(
                name: .playerStateChanged,
                object: nil,
                userInfo: ["isPlaying": state == .playing]
            )

            // Detect video end for autoplay
            if state == .ended {
                print("🎬 Video ended, triggering autoplay callback")
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
        playerView?.playVideo()
    }

    func pause() {
        playerView?.pauseVideo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func skipForward(seconds: Float = 10) {
        playerView?.seek(toSeconds: currentTime + seconds, allowSeekAhead: true)
    }

    func skipBackward(seconds: Float = 10) {
        playerView?.seek(toSeconds: max(0, currentTime - seconds), allowSeekAhead: true)
    }

    func seekTo(seconds: Float) {
        playerView?.seek(toSeconds: seconds, allowSeekAhead: true)
    }

    func getCurrentTime() {
        playerView?.currentTime { [weak self] time, error in
            DispatchQueue.main.async {
                self?.currentTime = time
            }
        }
    }

    func getDuration() {
        playerView?.duration { [weak self] duration, error in
            DispatchQueue.main.async {
                self?.duration = Float(duration)
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

        // Extract video ID from YouTube URL and load video
        if let videoId = extractYouTubeVideoID(from: youtubeURL) {
            playerView.load(withVideoId: videoId, playerVars: [
                "playsinline": 1,
                "controls": 1,
                "showinfo": 1,
                "rel": 0,
                "autoplay": 1
            ])
        }
        
        return playerView
    }

    func updateUIView(_ uiView: YTPlayerView, context: Context) {
        // No updates needed
    }
}

// MARK: - Single Video View with AirPlay-Safe Layout
struct SingleVideoView: View {
    let youtubeURL: String
    let videoTitle: String
    let artistName: String
    let year: String
    let playlistContext: PlaylistContext? // Optional playlist context for autoplay

    // Backward compatibility - extract video ID for other features
    private var videoId: String {
        return extractYouTubeVideoID(from: youtubeURL) ?? ""
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

    private var videoHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let standardHeight = screenWidth * 9/16
        if UIDevice.current.userInterfaceIdiom == .pad {
            return standardHeight * 1.4 // 40% taller for iPad
        } else {
            return standardHeight * 1.7 // 70% taller for iPhone
        }
    }
    
    private var videoWidth: CGFloat {
        UIScreen.main.bounds.width // No side padding - full width
    }

    // MARK: - AirPlay Detection and Layout Helpers
    private func detectAirPlayState() {
        // Check if there are any external screens connected (indicates AirPlay)
        // Suppress deprecation warning - this is properly handled with availability check
        let externalScreens: [UIScreen]
        if #available(iOS 16.0, *) {
            // Use modern iOS API to detect external displays
            externalScreens = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .compactMap { $0.screen }
                .filter { $0 != UIScreen.main }
        } else {
            // Fallback for older iOS versions
            // swiftlint:disable:next deprecated_api_usage
            externalScreens = (UIScreen.screens as [UIScreen]).filter { $0 != UIScreen.main }
        }
        isAirPlayActive = !externalScreens.isEmpty
    }

    private func updateLayoutForAirPlay() {
        // No-op - layout is now tab bar relative
    }
    
}

extension SingleVideoView {
    var body: some View {
        ZStack {
            // Custom header for all devices
            VStack {
                HStack {
                    // Back button on left
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.hitRewindPurple)
                    }

                    Spacer()

                    // Logo centered
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)

                    Spacer()

                    // Search and settings buttons
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

                Spacer()
            }
            .zIndex(1)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    // Reduced top spacer to move video up on both devices
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        Spacer()
                            .frame(maxHeight: 65)
                    } else {
                        // iPad: smaller top spacer to position video higher
                        Spacer()
                            .frame(maxHeight: 80)
                    }

                    // Video player
                    VideoPlayerView(youtubeURL: youtubeURL, coordinator: playerCoordinator)
                        .frame(width: videoWidth, height: videoHeight)
                        .background(Color.black)

                    Spacer()
                }
            }

            // Hidden navigationDestination for autoplay to next video
            Color.clear
                .navigationDestination(item: $nextVideoToPlay) { video in
                    createNextVideoView(from: video)
                }
        }
        .onAppear {
            setupVideoPlayer()
        }
        .onDisappear {
            // Clean up timers and observers
            // NOTE: We don't stop the video here to allow AirPlay to continue when switching tabs
            timeUpdateTimer?.invalidate()
            timeUpdateTimer = nil
            NotificationCenter.default.removeObserver(self, name: UIScene.didActivateNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerSkipBackward, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerTogglePlayPause, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerSkipForward, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerSkip60Forward, object: nil)

            // Notify ContentView that video player is dismissed
            NotificationCenter.default.post(name: .videoPlayerDismissed, object: nil)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(.all, edges: .bottom)
        .background(
            NavigationConfigurator { nc in
                nc.hidesBarsOnSwipe = false
            }
        )
    }

    // MARK: - Helper Methods

    private func setupVideoPlayer() {
        // Register this player with the manager, which will stop any previous video
        VideoPlayerManager.shared.registerPlayer(playerCoordinator)

        detectAirPlayState()
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            playerCoordinator.getCurrentTime()
        }

        NotificationCenter.default.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { _ in
            detectAirPlayState()
        }

        // Listen for player control notifications from ContentView
        NotificationCenter.default.addObserver(forName: .playerSkipBackward, object: nil, queue: .main) { _ in
            playerCoordinator.skipBackward(seconds: 10)
        }
        NotificationCenter.default.addObserver(forName: .playerTogglePlayPause, object: nil, queue: .main) { _ in
            playerCoordinator.togglePlayPause()
        }
        NotificationCenter.default.addObserver(forName: .playerSkipForward, object: nil, queue: .main) { _ in
            playerCoordinator.skipForward(seconds: 10)
        }
        NotificationCenter.default.addObserver(forName: .playerSkip60Forward, object: nil, queue: .main) { _ in
            playerCoordinator.skipForward(seconds: 60)
        }

        // Notify ContentView that video player is presented
        NotificationCenter.default.post(
            name: .videoPlayerPresented,
            object: nil,
            userInfo: [
                "videoId": videoId,
                "title": videoTitle,
                "artist": artistName,
                "year": year
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

    private func createNextVideoView(from video: PlaylistVideo) -> SingleVideoView {
        // Create playlist context for the next video
        guard let context = playlistContext else {
            return SingleVideoView(
                youtubeURL: video.youtubeURL,
                videoTitle: video.title,
                artistName: video.artist,
                year: video.year,
                playlistContext: nil
            )
        }

        let newContext = PlaylistContext(
            videos: context.videos,
            currentIndex: context.currentIndex + 1
        )

        return SingleVideoView(
            youtubeURL: video.youtubeURL,
            videoTitle: video.title,
            artistName: video.artist,
            year: video.year,
            playlistContext: newContext
        )
    }
}


// MARK: - Preview
#Preview {
    NavigationView {
        SingleVideoView(
            youtubeURL: "https://www.youtube.com/watch?v=M7lc1UVf-VE",
            videoTitle: "Sample Video Title",
            artistName: "Sample Artist",
            year: "2023",
            playlistContext: nil
        )
    }
}