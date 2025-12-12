import SwiftUI
import AVKit

/// Looping video player for onboarding
struct LoopingVideoPlayerView: UIViewControllerRepresentable {
    let videoName: String
    @Environment(\.isPageActive) private var isPageActive

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()

        // Find video in bundle
        guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: "m4v", subdirectory: "Resources/Onboarding") ??
                Bundle.main.url(forResource: videoName, withExtension: "m4v") else {
            print("❌ Could not find video: \(videoName).m4v")
            return controller
        }

        print("✅ Found video at: \(videoURL.path)")

        // Use AVPlayerItem for better control over loading
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)

        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = true  // No audio in this video

        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect

        // Setup looping - use background queue to avoid blocking main thread
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: OperationQueue()
        ) { _ in
            player.seek(to: .zero)
            // Only play if we're supposed to be playing
            // Let updateUIViewController handle play/pause based on page activity
            if player.rate > 0 || player.timeControlStatus == .playing {
                player.play()
            }
        }

        // Don't auto-play - let updateUIViewController start playback when page is active
        context.coordinator.observePlayerItem(playerItem)

        return controller
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        private var statusObserver: NSKeyValueObservation?

        func observePlayerItem(_ playerItem: AVPlayerItem) {
            statusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
                if item.status == .readyToPlay {
                    print("✅ Video ready to play (waiting for page to be active)")
                    // Don't auto-play - updateUIViewController will handle it
                } else if item.status == .failed {
                    print("❌ Video failed to load: \(String(describing: item.error))")
                }
            }
        }

        deinit {
            statusObserver?.invalidate()
        }
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        guard let player = uiViewController.player else { return }

        // Simple: only play when page is active, pause otherwise
        if isPageActive {
            // Only start playing if video is ready and not already playing
            if player.currentItem?.status == .readyToPlay && player.timeControlStatus != .playing {
                player.play()
                print("▶️ Video started (page active)")
            }
        } else {
            // Pause when page is not active to prevent background decoding
            if player.timeControlStatus == .playing {
                player.pause()
                print("⏸️ Video paused (page inactive)")
            }
        }
    }
}

#Preview {
    LoopingVideoPlayerView(videoName: "songs")
        .frame(height: 400)
        .background(Color.black)
}
