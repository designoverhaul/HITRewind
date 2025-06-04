import UIKit
import AVKit
import YouTubeKit

class DebugPlayerViewController: UIViewController, AVPlayerViewControllerDelegate {

    lazy var playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Play Test Video", for: .normal)
        button.addTarget(self, action: #selector(playTestVideoButtonTapped), for: .primaryActionTriggered)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .darkGray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()

    // Use a video ID that has previously worked
    let testVideoId = "sWqDIZxO-nU" // "In Rainbows - From the Basement"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupButton()
    }

    func setupButton() {
        view.addSubview(playButton)
        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 300),
            playButton.heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    @objc func playTestVideoButtonTapped() {
        print("DebugPlayerViewController: Play button tapped. Attempting to play video ID: \(self.testVideoId)")
        
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()

        let playerViewController = AVPlayerViewController()
        playerViewController.modalPresentationStyle = .fullScreen // Set immediately
        playerViewController.delegate = self

        Task { @MainActor in
            defer {
                loadingIndicator.stopAnimating()
                loadingIndicator.removeFromSuperview()
            }

            do {
                let video = YouTube(videoID: self.testVideoId)
                let streams = try await video.streams
                
                var streamURL: URL? = streams
                    .filterVideoAndAudio()
                    .filter { $0.isNativelyPlayable }
                    .highestResolutionStream()?
                    .url
                
                if streamURL == nil { // Fallback
                    streamURL = streams.filterVideoAndAudio().first?.url ?? streams.first?.url
                }

                if let finalStreamURL = streamURL {
                    print("🌟 DebugPlayerViewController: YouTubeKit Stream URL: \(finalStreamURL) for video ID: \(self.testVideoId)")
                    let avPlayer = AVPlayer(url: finalStreamURL)
                    playerViewController.player = avPlayer
                    
                    print("DebugPlayerViewController: Attempting to present AVPlayerViewController...")
                    self.present(playerViewController, animated: true) {
                        print("✅ DebugPlayerViewController: AVPlayerViewController presented for video ID: \(self.testVideoId)")
                        avPlayer.play()
                        print("▶️ DebugPlayerViewController: avPlayer.play() called for video ID: \(self.testVideoId)")
                    }
                } else {
                    print("🚫 DebugPlayerViewController: YouTubeKit - finalStreamURL is nil for video ID: \(self.testVideoId)")
                    let alert = UIAlertController(title: "Playback Error", message: "Debug: Could not load video stream (URL is nil).", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            } catch {
                print("🚫 DebugPlayerViewController: YouTubeKit playback error for video ID \(self.testVideoId): \(error.localizedDescription)")
                let alert = UIAlertController(title: "Playback Error", message: "Debug: YouTubeKit error - \(error.localizedDescription)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
} 