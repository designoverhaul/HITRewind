import SwiftUI
import AVFoundation

struct LoopingVideoPlayerView: UIViewRepresentable {
    let videoName: String

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(videoName: videoName)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
}

class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    init(videoName: String) {
        super.init(frame: .zero)
        backgroundColor = .black

        guard let url = Bundle.main.url(forResource: videoName, withExtension: "m4v", subdirectory: "Resources/Onboarding") ??
                Bundle.main.url(forResource: videoName, withExtension: "m4v") else {
            return
        }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = true

        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)

        queuePlayer.play()
        self.player = queuePlayer
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
