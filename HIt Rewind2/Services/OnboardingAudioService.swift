import Foundation
import AVFoundation

/// Manages background music playback during onboarding with fade-out capability
class OnboardingAudioService: ObservableObject {
    static let shared = OnboardingAudioService()

    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var fadeTimer: Timer?
    private var timeObserver: Any?

    private init() {
        setupAudioSession()
        setupAudioPlayer()
    }

    private func setupAudioSession() {
        do {
            // Force output to device speaker only (not AirPlay) during onboarding
            // Use .playback category with .mixWithOthers to allow other audio
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )

            // Request 100ms buffer for resilience during UI operations
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.1)

            // Override to force speaker output (prevents AirPlay routing)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)

            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured - forcing device speaker output (no AirPlay)")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }

    private func setupAudioPlayer() {
        // Use AVPlayer instead of AVAudioPlayer for better control and to prevent AirPlay routing
        guard let audioURL = Bundle.main.url(forResource: "Queen", withExtension: "mp3", subdirectory: "Resources/Onboarding") ??
                Bundle.main.url(forResource: "Queen", withExtension: "mp3") else {
            print("❌ Could not find Queen.mp3")
            return
        }

        print("✅ Found audio at: \(audioURL.path)")

        // Create AVPlayerItem and AVPlayer
        let item = AVPlayerItem(url: audioURL)
        let player = AVPlayer(playerItem: item)

        // Start at 0 volume, will fade in when startMusic() is called
        player.volume = 0.0

        // Setup looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        self.audioPlayer = player
        self.playerItem = item

        print("✅ AVPlayer initialized and ready (will play from device speaker only)")
    }

    /// Start playing onboarding background music with smooth fade-in
    func startMusic() {
        guard let player = audioPlayer else {
            print("❌ Audio player not initialized")
            return
        }

        // Start playback at 0 volume
        player.volume = 0.0
        player.play()

        print("🎵 Started playing onboarding music (fading in...)")

        // Fade in from 0.0 to 0.40 (40% volume) over 4 seconds for smooth start
        let fadeDuration: TimeInterval = 4.0
        let targetVolume: Float = 0.40  // Lowered from 0.70 to 0.40
        let fadeSteps = 40
        let stepInterval = fadeDuration / TimeInterval(fadeSteps)
        let volumeIncrement: Float = targetVolume / Float(fadeSteps)

        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self, let player = self.audioPlayer else {
                timer.invalidate()
                return
            }

            currentStep += 1

            if currentStep >= fadeSteps {
                // Fade complete
                player.volume = targetVolume
                timer.invalidate()
                self.fadeTimer = nil
                print("🎵 Fade in complete, music at 40% volume")
            } else {
                // Increase volume gradually
                let newVolume = min(targetVolume, Float(currentStep) * volumeIncrement)
                player.volume = newVolume
            }
        }
    }

    /// Fade out music over specified duration (in seconds)
    func fadeOut(duration: TimeInterval = 8.0) {
        guard let player = audioPlayer else {
            print("⚠️ No audio player to fade out")
            return
        }

        print("🎵 Starting fade out over \(duration) seconds...")

        // Cancel any active fade-in timer
        fadeTimer?.invalidate()

        let fadeSteps = 40 // Number of volume steps
        let stepInterval = duration / TimeInterval(fadeSteps)
        let volumeDecrement = player.volume / Float(fadeSteps)

        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self, let player = self.audioPlayer else {
                timer.invalidate()
                return
            }

            currentStep += 1

            if currentStep >= fadeSteps {
                // Fade complete
                player.pause()
                player.seek(to: .zero)
                timer.invalidate()
                self.fadeTimer = nil
                print("🎵 Fade out complete, music stopped")
            } else {
                // Decrease volume
                let newVolume = max(0, player.volume - volumeDecrement)
                player.volume = newVolume
            }
        }
    }

    /// Stop music immediately
    func stopMusic() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        audioPlayer?.pause()
        audioPlayer = nil

        // Remove notification observer
        if let item = playerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        }
        playerItem = nil

        print("🎵 Music stopped")
    }

    deinit {
        stopMusic()
    }
}
