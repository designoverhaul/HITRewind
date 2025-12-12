//
//  TVCarouselView.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/5/25.
//

import SwiftUI

struct TVCarouselView: View {
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @StateObject private var imagePreloader = ImagePreloader.shared
    @Environment(\.isPageActive) private var isPageActive

    private let tvImages = ["tv1", "tv2", "tv3", "tv4", "tv5", "tv6"]
    private let intervalSeconds: Double = 2.2

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(0..<tvImages.count, id: \.self) { index in
                    PreloadedImage(imageName: tvImages[index])
                        .aspectRatio(contentMode: .fit)
                        .frame(width: isIPad ? geometry.size.width * 0.55 : geometry.size.width * 0.80)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity)
            .onAppear {
                // Only start auto-scroll after images are preloaded
                if imagePreloader.isReady {
                    startAutoScroll()
                }
            }
            .onDisappear {
                stopAutoScroll()
            }
            .onChange(of: imagePreloader.isReady) { oldValue, newValue in
                if newValue && isPageActive {
                    // Start scrolling once images are ready
                    startAutoScroll()
                }
            }
            .onChange(of: isPageActive) { oldValue, newValue in
                if newValue && imagePreloader.isReady {
                    // Resume scrolling when page becomes active
                    startAutoScroll()
                } else {
                    // Pause scrolling when page becomes inactive
                    stopAutoScroll()
                }
            }
        }
    }

    private func startAutoScroll() {
        // Avoid creating multiple timers
        guard timer == nil else { return }

        // Only start if page is active
        guard isPageActive else { return }

        // Wait 1 second before starting carousel to let everything settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            // Double-check page is still active after delay
            guard self.isPageActive else { return }

            self.timer = Timer.scheduledTimer(withTimeInterval: self.intervalSeconds, repeats: true) { _ in
                // Shorter animation duration for smoother transitions
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentIndex = (self.currentIndex + 1) % self.tvImages.count
                }
            }
        }
    }

    private func stopAutoScroll() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    TVCarouselView()
        .frame(height: 400)
        .background(Color.black)
}
