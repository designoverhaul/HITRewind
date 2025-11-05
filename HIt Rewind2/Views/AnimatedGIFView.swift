import SwiftUI
import UIKit
import ImageIO

/// Native SwiftUI view for displaying animated GIFs without external dependencies
struct AnimatedGIFView: View {
    let gifName: String
    let contentMode: ContentMode

    init(gifName: String, contentMode: ContentMode = .fit) {
        self.gifName = gifName
        self.contentMode = contentMode
    }

    var body: some View {
        if let gifURL = Bundle.main.url(forResource: gifName, withExtension: "gif", subdirectory: "Resources/Onboarding") {
            GIFImageView(gifURL: gifURL, contentMode: contentMode)
        } else {
            // Fallback if GIF not found
            Color.clear
        }
    }
}

/// UIViewRepresentable wrapper for UIImageView that plays GIFs
struct GIFImageView: UIViewRepresentable {
    let gifURL: URL
    let contentMode: ContentMode

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
        imageView.clipsToBounds = true

        // Load and animate GIF
        if let gifData = try? Data(contentsOf: gifURL),
           let source = CGImageSourceCreateWithData(gifData as CFData, nil) {

            let frameCount = CGImageSourceGetCount(source)
            var images: [UIImage] = []
            var duration: TimeInterval = 0

            for i in 0..<frameCount {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    images.append(UIImage(cgImage: cgImage))

                    // Get frame duration
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                       let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                        duration += frameDuration
                    } else {
                        duration += 0.1 // Default frame duration
                    }
                }
            }

            imageView.animationImages = images
            imageView.animationDuration = duration
            imageView.animationRepeatCount = 0 // Loop forever
            imageView.startAnimating()
        }

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // No updates needed
    }
}

#Preview {
    AnimatedGIFView(gifName: "post")
        .frame(height: 300)
        .background(Color.black)
}
