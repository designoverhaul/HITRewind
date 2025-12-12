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
        print("🎬 AnimatedGIFView init with gifName: \(gifName)")
    }

    var body: some View {
        // Try multiple search paths
        let searchPaths = [
            ("Resources/Onboarding", Bundle.main.url(forResource: gifName, withExtension: "gif", subdirectory: "Resources/Onboarding")),
            ("Onboarding", Bundle.main.url(forResource: gifName, withExtension: "gif", subdirectory: "Onboarding")),
            ("Root", Bundle.main.url(forResource: gifName, withExtension: "gif"))
        ]

        print("🔍 Searching for \(gifName).gif in bundle...")
        for (path, url) in searchPaths {
            print("  - Checking \(path): \(url != nil ? "✅ FOUND" : "❌ NOT FOUND")")
            if url != nil {
                print("    URL: \(url!.path)")
            }
        }

        // Try to find the GIF
        if let foundURL = searchPaths.first(where: { $0.1 != nil })?.1 {
            print("✅ Using GIF from: \(foundURL.path)")
            return AnyView(GIFImageView(gifURL: foundURL, contentMode: contentMode))
        } else {
            // Fallback - show red background to indicate error
            print("❌ ERROR: Could not find \(gifName).gif in any location")
            print("📦 Bundle contents:")
            if let resourcePath = Bundle.main.resourcePath {
                print("   Resource path: \(resourcePath)")
            }
            return AnyView(
                ZStack {
                    Color.red.opacity(0.3)
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("GIF not found: \(gifName)")
                            .foregroundColor(.white)
                            .padding()
                    }
                }
            )
        }
    }
}

/// UIViewRepresentable wrapper for UIImageView that plays GIFs
struct GIFImageView: UIViewRepresentable {
    let gifURL: URL
    let contentMode: ContentMode

    func makeUIView(context: Context) -> UIImageView {
        print("🖼️ GIFImageView makeUIView - Loading: \(gifURL.path)")

        let imageView = UIImageView()
        imageView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
        imageView.clipsToBounds = true

        loadAndAnimateGIF(imageView: imageView)

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Restart animation if not animating
        if !uiView.isAnimating {
            print("🔄 GIF not animating, restarting...")
            uiView.startAnimating()
        }
    }

    private func loadAndAnimateGIF(imageView: UIImageView) {
        // Load and animate GIF
        guard let gifData = try? Data(contentsOf: gifURL) else {
            print("❌ Failed to load data from URL: \(gifURL.path)")
            return
        }

        print("✅ Loaded GIF data: \(gifData.count) bytes")

        guard let source = CGImageSourceCreateWithData(gifData as CFData, nil) else {
            print("❌ Failed to create image source from data")
            return
        }

        let frameCount = CGImageSourceGetCount(source)
        print("📊 GIF has \(frameCount) frames")

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

        print("✅ Loaded \(images.count) frames, duration: \(duration)s")

        imageView.animationImages = images
        imageView.animationDuration = duration
        imageView.animationRepeatCount = 0 // Loop forever
        imageView.startAnimating()

        print("🎬 GIF animation started!")
    }
}

#Preview {
    AnimatedGIFView(gifName: "post")
        .frame(height: 300)
        .background(Color.black)
}
