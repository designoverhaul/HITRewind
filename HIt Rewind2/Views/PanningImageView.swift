//
//  PanningImageView.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/6/25.
//

import SwiftUI

/// Continuously pans a wide image from left to right for onboarding carousel effect
struct PanningImageView: View {
    @State private var offset: CGFloat = 0
    @Environment(\.isPageActive) private var isPageActive

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        GeometryReader { geometry in
            // Get the image to determine its aspect ratio
            if let uiImage = UIImage(named: "tvAll") {
                let imageAspectRatio = uiImage.size.width / uiImage.size.height

                // Calculate image dimensions - make image 4x taller than container
                let containerHeight = geometry.size.height
                let imageHeight = containerHeight * 4  // 4x taller
                let imageWidth = imageHeight * imageAspectRatio
                let containerWidth = geometry.size.width

                // Only pan if image is wider than container
                let shouldPan = imageWidth > containerWidth
                let panDistance = shouldPan ? (imageWidth - containerWidth) : 0

                ZStack {
                    Image("tvAll")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: imageHeight)
                        .offset(x: offset)
                }
                .frame(width: containerWidth, height: containerHeight)
                .clipped() // Clip the overflowing parts
                .onAppear {
                    if shouldPan && isPageActive {
                        startPanning(distance: panDistance)
                    }
                }
                .onChange(of: isPageActive) { oldValue, newValue in
                    if newValue && shouldPan {
                        // Resume panning when page becomes active
                        startPanning(distance: panDistance)
                    } else {
                        // Stop animation when page becomes inactive
                        stopPanning()
                    }
                }
            } else {
                // Fallback if image not found
                Text("Image not found: tvAll")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func startPanning(distance: CGFloat) {
        // Reset to starting position
        offset = 0

        // Start panning animation after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard isPageActive else { return }

            // Animate to end position over 10 seconds
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                offset = -distance
            }
        }
    }

    private func stopPanning() {
        // Stop animation by removing it
        withAnimation(.linear(duration: 0)) {
            offset = offset // This effectively stops the animation
        }
    }
}

#Preview {
    PanningImageView()
        .frame(height: 400)
        .background(Color.black)
        .environment(\.isPageActive, true)
}
