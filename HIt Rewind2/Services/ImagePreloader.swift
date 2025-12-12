import UIKit
import SwiftUI

/// Preloads and caches images for smooth carousel performance
class ImagePreloader: ObservableObject {
    static let shared = ImagePreloader()

    @Published var isReady = false
    private var imageCache: [String: UIImage] = [:]

    private init() {}

    /// Preload images from Assets catalog
    func preloadImages(_ imageNames: [String]) async {
        print("🖼️ Preloading \(imageNames.count) images...")

        await withTaskGroup(of: (String, UIImage?).self) { group in
            for imageName in imageNames {
                group.addTask {
                    if let image = UIImage(named: imageName) {
                        print("  ✅ Loaded: \(imageName)")
                        return (imageName, image)
                    } else {
                        print("  ❌ Failed to load: \(imageName)")
                        return (imageName, nil)
                    }
                }
            }

            for await (name, image) in group {
                if let image = image {
                    imageCache[name] = image
                }
            }
        }

        await MainActor.run {
            isReady = true
            print("✅ All images preloaded and cached!")
        }
    }

    /// Get cached image
    func getCachedImage(_ name: String) -> UIImage? {
        return imageCache[name]
    }
}

/// SwiftUI wrapper for preloaded images
struct PreloadedImage: View {
    let imageName: String
    @StateObject private var preloader = ImagePreloader.shared

    var body: some View {
        if let cachedImage = preloader.getCachedImage(imageName) {
            Image(uiImage: cachedImage)
                .resizable()
        } else {
            // Fallback to regular Image if not cached yet
            Image(imageName)
                .resizable()
        }
    }
}
