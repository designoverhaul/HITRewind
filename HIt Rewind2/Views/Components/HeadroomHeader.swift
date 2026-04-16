//
//  HeadroomHeader.swift
//  HIt Rewind2
//
//  Shared header component with headroom scroll effect (hides on scroll up, shows on scroll down)
//  Used by Epic Shows, Top 100, and other pages
//

import SwiftUI

// MARK: - Headroom Header View
struct HeadroomHeader: View {
    let height: CGFloat
    var showBackButton: Bool = false
    var onBackTap: (() -> Void)? = nil

    init(height: CGFloat = 56, showBackButton: Bool = false, onBackTap: (() -> Void)? = nil) {
        self.height = height
        self.showBackButton = showBackButton
        self.onBackTap = onBackTap
    }

    var body: some View {
        VStack(spacing: 0) {
            // Logo centered in header area with optional back button
            HStack {
                if showBackButton {
                    Button(action: { onBackTap?() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                } else {
                    Spacer()
                        .frame(width: 44)
                }

                Spacer()

                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)

                Spacer()

                // More menu (Search / Settings)
                MoreMenu()
                    .frame(width: 44)
            }
            .padding(.horizontal, 8)
            .frame(height: height)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.hitRewindBackground.opacity(0.3), location: 0.0),
                    .init(color: Color.hitRewindBackground.opacity(0.25), location: 0.4),
                    .init(color: Color.hitRewindBackground.opacity(0.1), location: 0.7),
                    .init(color: Color.hitRewindBackground.opacity(0.0), location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height + 40) // Extend gradient below
            .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Headroom Scroll Modifier
struct HeadroomScrollModifier: ViewModifier {
    @Binding var headerOffset: CGFloat
    @Binding var lastScrollOffset: CGFloat
    let headerHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldValue, newValue in
                let offset = newValue
                let delta = offset - lastScrollOffset

                // Tiny dead-zone to filter pure jitter while staying responsive to fingertip motion
                guard abs(delta) > 1 else { return }

                // Hide header the moment the user scrolls up (content moving up), past the very top
                if delta > 0 && offset > 5 {
                    headerOffset = -headerHeight
                }
                // Show header when scrolling down (content moving down) or right at the top
                else if delta < 0 || offset < 5 {
                    headerOffset = 0
                }

                lastScrollOffset = offset
            }
    }
}

// MARK: - View Extension for Headroom
extension View {
    /// Applies headroom scroll tracking to a ScrollView
    func headroomScrollTracking(
        headerOffset: Binding<CGFloat>,
        lastScrollOffset: Binding<CGFloat>,
        headerHeight: CGFloat
    ) -> some View {
        self.modifier(HeadroomScrollModifier(
            headerOffset: headerOffset,
            lastScrollOffset: lastScrollOffset,
            headerHeight: headerHeight
        ))
    }
}

#Preview {
    ZStack(alignment: .top) {
        Color.hitRewindBackground.ignoresSafeArea()
        HeadroomHeader()
    }
    .preferredColorScheme(.dark)
}
