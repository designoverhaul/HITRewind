import Foundation
import AVFoundation

/// Manages background music playback during onboarding with fade-out capability
class OnboardingAudioService: ObservableObject {
    static let shared = OnboardingAudioService()

    private var audioPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?

    private init() {
        setupAudioSession()
        setupAudioPlayer()
    }

    private func setupAudioSession() {
        do {
            // Use .moviePlayback mode for better buffering and resilience
            // Add .mixWithOthers to share resources better with video playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])

            // Request 100ms buffer for resilience during UI operations and video playback
            // Larger buffer prevents stuttering when main thread is blocked by video/animations
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.1)

            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured with movie playback mode")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }

    private func setupAudioPlayer() {
        // Initialize and prepare the audio player EARLY (like Channel Lab V2)
        // This allows iOS to buffer the audio before playback starts, preventing stuttering
        guard let audioURL = Bundle.main.url(forResource: "Queen", withExtension: "mp3", subdirectory: "Resources/Onboarding") ??
                Bundle.main.url(forResource: "Queen", withExtension: "mp3") else {
            print("❌ Could not find Queen.mp3")
            return
        }

        print("✅ Found audio at: \(audioURL.path)")

        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.numberOfLoops = -1 // Loop indefinitely
            player.volume = 0.0 // Start at 0 volume, will fade in when startMusic() is called

            // Preload audio buffer - CRITICAL for preventing stuttering
            player.prepareToPlay()

            self.audioPlayer = player
            print("✅ Audio player initialized and prepared (ready to play with 100ms buffer)")
        } catch {
            print("❌ Failed to initialize audio player: \(error)")
        }
    }

    /// Start playing onboarding background music with smooth fade-in
    func startMusic() {
        guard let player = audioPlayer else {
            print("❌ Audio player not initialized")
            return
        }

        // Player is already prepared, just start it at 0 volume
        player.volume = 0.0
        let success = player.play()

        if success {
            print("🎵 Started playing onboarding music (fading in...)")

            // Fade in from 0.0 to 0.10 (10% volume) over 4 seconds for smooth start
            let fadeDuration: TimeInterval = 4.0
            let targetVolume: Float = 0.10
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
                    print("🎵 Fade in complete, music at 10% volume")
                } else {
                    // Increase volume gradually
                    let newVolume = min(targetVolume, Float(currentStep) * volumeIncrement)
                    player.volume = newVolume
                }
            }
        } else {
            print("❌ Audio play() returned false")
        }
    }

    /// Fade out music over specified duration (in seconds)
    func fadeOut(duration: TimeInterval = 8.0) {
        guard let player = audioPlayer, player.isPlaying else {
            print("⚠️ No audio playing to fade out")
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
                player.stop()
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
        audioPlayer?.stop()
        audioPlayer = nil
        print("🎵 Music stopped")
    }

    deinit {
        stopMusic()
    }
}
