//
//  VideoPlayerView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import UIKit
import YouTubeiOSPlayerHelper
import Combine
import AVKit

// MARK: - YouTube Player Coordinator
class YouTubePlayerCoordinator: NSObject, ObservableObject, YTPlayerViewDelegate {
    @Published var isPlaying: Bool = false
    @Published var isReady: Bool = false
    weak var playerView: YTPlayerView?
    private var loadedVideoId: String?
    
    func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
        self.playerView = playerView
        isReady = true
        print("🎥 YouTube player is ready")
        
        // Check initial state
        playerView.playerState { [weak self] state, error in
            DispatchQueue.main.async {
                self?.isPlaying = state == .playing
            }
        }
    }
    
    func playerView(_ playerView: YTPlayerView, didChangeTo state: YTPlayerState) {
        DispatchQueue.main.async {
            self.isPlaying = state == .playing
            print("🎥 Player state changed to: \(state.rawValue)")
        }
    }
    
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
    
    func skipForward(seconds: Float = 10.0) {
        playerView?.currentTime { [weak self] currentTime, error in
            if error == nil {
                let newTime = currentTime + seconds
                self?.playerView?.seek(toSeconds: newTime, allowSeekAhead: true)
            }
        }
    }

    func skipBackward(seconds: Float = 10.0) {
        playerView?.currentTime { [weak self] currentTime, error in
            if error == nil {
                let newTime = max(0, currentTime - seconds)
                self?.playerView?.seek(toSeconds: newTime, allowSeekAhead: true)
            }
        }
    }
    
    func loadVideo(videoId: String, playerVars: [String: Any]) {
        // Only load if it's a different video or if no video is loaded
        guard loadedVideoId != videoId else {
            print("🎥 Video \(videoId) already loaded, skipping reload")
            return
        }
        
        playerView?.load(withVideoId: videoId, playerVars: playerVars)
        loadedVideoId = videoId
        print("🎥 Loading new video: \(videoId)")
    }
}

// MARK: - SwiftUI YouTube Player View
struct VideoPlayerView: UIViewRepresentable {
    let videoId: String
    @StateObject private var coordinator = YouTubePlayerCoordinator()
    
    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        playerView.backgroundColor = .black
        playerView.delegate = coordinator
        
        // Load the video with autoplay enabled and minimal YouTube interface
        let playerVars: [String: Any] = [
            "playsinline": 1,
            "autoplay": 1,
            "controls": 1,
            "showinfo": 0,          // Hide video title and uploader info
            "rel": 0,               // Don't show related videos at end
            "iv_load_policy": 3,    // Hide video annotations
            "fs": 1,                // Allow fullscreen
            "color": "white",       // White progress bar
            "modestbranding": 1,    // Hide YouTube logo
            "disablekb": 0,         // Enable keyboard controls
            "end": 0,               // Don't specify end time
            "loop": 0,              // Don't loop video
            "playlist": "",         // No playlist
            "start": 0              // Start from beginning
        ]
        playerView.load(withVideoId: videoId, playerVars: playerVars)
        print("🎥 Loading video with autoplay: \(videoId)")
        
        return playerView
    }
    
    func updateUIView(_ uiView: YTPlayerView, context: Context) {
        // Update if needed
    }
    
    // Expose the coordinator for external controls
    var playerCoordinator: YouTubePlayerCoordinator {
        coordinator
    }
}

// MARK: - Single Video View with External Controls
struct SingleVideoView: View {
    let videoId: String
    let videoTitle: String
    let artistName: String
    let year: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerCoordinator = YouTubePlayerCoordinator()
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared
    
    // Orientation detection
    @State private var orientation = UIDeviceOrientation.unknown
    
    private var isLandscape: Bool {
        orientation.isLandscape
    }
    
    // IMPORTANT: Video player height - DO NOT REVERT!
    // This height is intentionally TALLER than standard 16:9 aspect ratio on phones
    // to allow onscreen controls to be positioned above and below the video player,
    // not overlapping on top of the video content.
    // UPDATED: Made 10% taller as requested
    private var videoPlayerHeight: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 440  // Fixed height for iPad (10% taller: 400 * 1.1 = 440)
        } else {
            // CRITICAL: iPhone uses DOUBLE height to push controls above/below video
            // Standard 16:9 would be: UIScreen.main.bounds.width * (9.0/16.0)
            // We use DOUBLE that height so controls don't overlap video content
            // UPDATED: Made 10% taller (2.0 * 1.1 = 2.2)
            return UIScreen.main.bounds.width * (9.0/16.0) * 2.2  // DOUBLE HEIGHT + 10% for control positioning
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Single player instance that persists across orientation changes
                VideoPlayerViewWithCoordinator(videoId: videoId, coordinator: playerCoordinator)
                    .frame(maxWidth: .infinity)
                    .frame(height: isLandscape ? UIScreen.main.bounds.height : videoPlayerHeight)
                    .background(Color.black)
                    .clipped()
                    .ignoresSafeArea(isLandscape ? .all : [])

                // Portrait-only content (hidden in landscape)
                if !isLandscape {
                    // Push content to bottom with Spacer
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Header: Title left, Artist right (tappable)
                        HStack(alignment: .firstTextBaseline) {
                            Text(videoTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            NavigationLink(destination: ArtistSongsView(artistName: artistName)) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .imageScale(.medium)
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.hitRewindPurple)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        
                        // Controls directly below the title/artist
                        HStack(spacing: 16) {
                            // Heart button
                            Button(action: {
                                if authService.isAuthenticated {
                                    favoritesService.toggleFavorite(videoId: videoId, title: videoTitle, artist: artistName, year: year)
                                } else {
                                    authService.signInWithApple()
                                }
                            }) {
                                Image(systemName: favoritesService.isFavorited(videoId) ? "heart.fill" : "heart")
                                    .font(.system(size: 20))
                                    .foregroundColor(favoritesService.isFavorited(videoId) ? .red : Color(red: 0.65, green: 0.53, blue: 0.99))
                                    .frame(width: 60, height: 60)
                                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }

                            // Skip backward
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                playerCoordinator.skipBackward()
                            }) {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                                    .frame(width: 60, height: 60)
                                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .disabled(!playerCoordinator.isReady)
                            .opacity(playerCoordinator.isReady ? 1.0 : 0.5)

                            // Play/Pause (centered)
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                playerCoordinator.togglePlayPause()
                            }) {
                                Image(systemName: playerCoordinator.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                                    .frame(width: 60, height: 60)
                                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .disabled(!playerCoordinator.isReady)
                            .opacity(playerCoordinator.isReady ? 1.0 : 0.5)

                            // Skip forward
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                playerCoordinator.skipForward()
                            }) {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                                    .frame(width: 60, height: 60)
                                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .disabled(!playerCoordinator.isReady)
                            .opacity(playerCoordinator.isReady ? 1.0 : 0.5)

                            AirPlayButton()
                                .frame(width: 60, height: 60)
                                .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                                .clipShape(Circle())
                                .opacity(playerCoordinator.isReady ? 1.0 : 0.5)
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20) // Add bottom padding to position above tab bar
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
        .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe right (positive translation) to go back
                    if value.translation.width > 100 && abs(value.translation.height) < 50 {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            dismiss()
                        }
                    }
                }
        )
        .toolbar {
            if !isLandscape {
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
        }
        .background(Color(UIColor.systemBackground))
        .background(
            NavigationConfigurator { nc in
                nc.hidesBarsOnSwipe = false
            }
        )
        .onAppear {
            // Set initial orientation
            orientation = UIDevice.current.orientation
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientation = UIDevice.current.orientation
        }
    }
    
}

// Fullscreen feature removed

// MARK: - Video Player View with Coordinator Support
struct VideoPlayerViewWithCoordinator: UIViewRepresentable {
    let videoId: String
    let coordinator: YouTubePlayerCoordinator
    
    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        playerView.backgroundColor = .black
        playerView.delegate = coordinator
        
        // Store reference in coordinator to prevent recreation
        coordinator.playerView = playerView
        
        // Load the video with autoplay enabled and minimal YouTube interface
        let playerVars: [String: Any] = [
            "playsinline": 1,
            "autoplay": 1,
            "controls": 1,
            "showinfo": 0,          // Hide video title and uploader info
            "rel": 0,               // Don't show related videos at end
            "iv_load_policy": 3,    // Hide video annotations
            "fs": 1,                // Allow fullscreen
            "color": "white",       // White progress bar
            "modestbranding": 1,    // Hide YouTube logo
            "disablekb": 0,         // Enable keyboard controls
            "end": 0,               // Don't specify end time
            "loop": 0,              // Don't loop video
            "playlist": "",         // No playlist
            "start": 0              // Start from beginning
        ]
        coordinator.loadVideo(videoId: videoId, playerVars: playerVars)
        
        return playerView
    }
    
    func updateUIView(_ uiView: YTPlayerView, context: Context) {
        // Don't reload the video on orientation changes - this prevents restarting
        // The player view already exists and maintains its state
        if coordinator.playerView != uiView {
            coordinator.playerView = uiView
        }
    }
}

// MARK: - AirPlay Button
struct AirPlayButton: UIViewRepresentable {
    @StateObject private var airPlayService = AirPlayService.shared
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let routePickerView = AVRoutePickerView()
        // Set colors based on connection status
        let yellowColor = UIColor(red: 1.0, green: 0.96, blue: 0.11, alpha: 1.0) // #FFF61D
        let purpleColor = UIColor(red: 0.65, green: 0.53, blue: 0.99, alpha: 1.0)
        
        routePickerView.tintColor = airPlayService.isConnected ? yellowColor : purpleColor
        routePickerView.activeTintColor = airPlayService.isConnected ? yellowColor : purpleColor
        routePickerView.backgroundColor = .clear
        routePickerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Make the icon smaller by scaling it down
        routePickerView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        
        containerView.addSubview(routePickerView)
        context.coordinator.routePickerView = routePickerView
        
        // Center the scaled AirPlay button in the container
        NSLayoutConstraint.activate([
            routePickerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            routePickerView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            routePickerView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            routePickerView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        
        // Add haptic feedback when AirPlay button is tapped
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.airPlayTapped))
        containerView.addGestureRecognizer(gesture)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update colors when connection status changes
        if let routePickerView = context.coordinator.routePickerView {
            let yellowColor = UIColor(red: 1.0, green: 0.96, blue: 0.11, alpha: 1.0) // #FFF61D
            let purpleColor = UIColor(red: 0.65, green: 0.53, blue: 0.99, alpha: 1.0)
            
            routePickerView.tintColor = airPlayService.isConnected ? yellowColor : purpleColor
            routePickerView.activeTintColor = airPlayService.isConnected ? yellowColor : purpleColor
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var routePickerView: AVRoutePickerView?
        
        @objc func airPlayTapped() {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
}

// Volume slider removed

// MARK: - Preview
#Preview {
    NavigationView {
        SingleVideoView(videoId: "kJQP7kiw5Fk", videoTitle: "Sample Video Title", artistName: "Sample Artist", year: "2023")
    }
    .preferredColorScheme(.dark)
}