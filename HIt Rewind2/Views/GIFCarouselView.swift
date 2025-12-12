import SwiftUI

/// Auto-scrolling carousel of animated GIFs for onboarding
struct GIFCarouselView: View {
    let gifNames: [String] = ["alanis", "beck", "bruno", "hayley", "mm", "post", "red", "sassy", "weekend"]

    @State private var currentIndex = 0
    @State private var timer: Timer?
    @Environment(\.isPageActive) private var isPageActive

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<gifNames.count, id: \.self) { index in
                AnimatedGIFView(gifName: gifNames[index], contentMode: .fill)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: isPageActive) { oldValue, newValue in
            if newValue {
                // Resume timer when page becomes active
                startTimer()
            } else {
                // Stop timer when page becomes inactive
                stopTimer()
            }
        }
    }

    private func startTimer() {
        // Avoid creating multiple timers
        guard timer == nil else { return }

        // Only start if page is active
        guard isPageActive else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation {
                // Circular loop: when we reach the end, jump to start
                if currentIndex == gifNames.count - 1 {
                    currentIndex = 0
                } else {
                    currentIndex += 1
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    GIFCarouselView()
        .frame(height: 400)
        .background(Color.black)
}
