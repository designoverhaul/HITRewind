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

    private let tvImages = ["tv1", "tv2", "tv3", "tv4", "tv5", "tv6"]
    private let intervalSeconds: Double = 2.2

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(0..<tvImages.count, id: \.self) { index in
                    Image(tvImages[index])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: isIPad ? geometry.size.width * 0.55 : geometry.size.width * 0.80)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity)
            .onAppear {
                startAutoScroll()
            }
            .onDisappear {
                stopAutoScroll()
            }
        }
    }

    private func startAutoScroll() {
        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % tvImages.count
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
