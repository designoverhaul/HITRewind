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
    weak var playerView: YTPlayerView?

    func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
        self.playerView = playerView
        print("YouTube player is ready")

        // Get initial duration
        playerView.duration { [weak self] duration, error in
            DispatchQueue.main.async {
                self?.duration = Float(duration)
            }
        }
    }

    func playerView(_ playerView: YTPlayerView, receivedError error: YTPlayerError) {
        print("YouTube player error: \(error.rawValue)")
    }

    func playerView(_ playerView: YTPlayerView, didChangeTo state: YTPlayerState) {
        DispatchQueue.main.async {
            self.isPlaying = state == .playing
        }
        print("Player state changed to: \(state.rawValue)")
    }

    // MARK: - Player Control Methods
    func play() {
        playerView?.playVideo()
        print("🎥 Play command sent")
    }

    func pause() {
        playerView?.pauseVideo()
        print("🎥 Pause command sent")
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
        print("🎥 Skip forward \(seconds) seconds")
    }

    func skipBackward(seconds: Float = 10) {
        playerView?.seek(toSeconds: max(0, currentTime - seconds), allowSeekAhead: true)
        print("🎥 Skip backward \(seconds) seconds")
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
    let videoId: String
    let coordinator: YouTubePlayerCoordinator

    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        playerView.backgroundColor = .black
        playerView.delegate = coordinator

        // Load the video with basic inline player settings
        let playerVars = [
            "playsinline": 1,
            "autoplay": 1
        ]

        playerView.load(withVideoId: videoId, playerVars: playerVars)
        return playerView
    }

    func updateUIView(_ uiView: YTPlayerView, context: Context) {
        // No updates needed
    }
}

// MARK: - Single Video View with AirPlay-Safe Layout
struct SingleVideoView: View {
    let videoId: String
    let videoTitle: String
    let artistName: String
    let year: String

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

    private var videoHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return screenWidth * 9/16
    }
    
    private var videoWidth: CGFloat {
        UIScreen.main.bounds.width - 32
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
        print("🎥 AirPlay detection: \(isAirPlayActive) (external screens: \(externalScreens.count))")
    }

    private func updateLayoutForAirPlay() {
        // No-op - layout is now tab bar relative
    }
}

extension SingleVideoView {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Just the video player - centered in screen
            VStack {
                Spacer()
                VideoPlayerView(videoId: videoId, coordinator: playerCoordinator)
                    .frame(width: videoWidth, height: videoHeight)
                    .background(Color.black)
                Spacer()
            }
        }
        .onAppear {
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
        }
        .onDisappear {
            timeUpdateTimer?.invalidate()
            timeUpdateTimer = nil
            NotificationCenter.default.removeObserver(self, name: UIScene.didActivateNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerSkipBackward, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerTogglePlayPause, object: nil)
            NotificationCenter.default.removeObserver(self, name: .playerSkipForward, object: nil)
            
            // Notify ContentView that video player is dismissed
            NotificationCenter.default.post(name: .videoPlayerDismissed, object: nil)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .navigationBarBackButtonHidden(false)
        .toolbar {
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
                    Text("Back")
                        .font(.custom(AppFont.ticketingName(), size: 20))
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
        .ignoresSafeArea(.all, edges: .top)
        .background(
            NavigationConfigurator { nc in
                nc.hidesBarsOnSwipe = false
            }
        )
    }
}


// MARK: - Preview
#Preview {
    NavigationView {
        SingleVideoView(videoId: "M7lc1UVf-VE", videoTitle: "Sample Video Title", artistName: "Sample Artist", year: "2023")
    }
}