//
//  VJModeControlStrip.swift
//  HIt Rewind2
//
//  Vertical control strip for VJ Mode with artist info and playback controls
//

import SwiftUI

/// Vertical control strip with artist button, favorite, play/pause, skip 10s, skip 60s, and next video buttons
struct VJModeControlStrip: View {
    @ObservedObject var playerCoordinator: YouTubePlayerCoordinator
    @Binding var isFavorited: Bool
    let artistName: String
    let showArtistButton: Bool // False for live mode
    let onFavoriteToggle: () -> Void
    let onArtistTap: () -> Void
    let onNextVideo: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // Artist section (hidden for live mode)
            if showArtistButton {
                Button(action: onArtistTap) {
                    VStack(spacing: 0) {
                        // Right arrow icon (no background)
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.hitRewindPurple)
                            .frame(width: 48, height: 36)

                        // Artist name
                        Text(artistName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.hitRewindPurple)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .frame(width: 65)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 4)
            }

            // 1. Favorite button (heart)
            controlButton(
                icon: isFavorited ? "heart.fill" : "heart",
                color: isFavorited ? .red : .hitRewindPurple,
                action: onFavoriteToggle
            )

            // 2. Play/Pause button
            controlButton(
                icon: playerCoordinator.isPlaying ? "pause.fill" : "play.fill",
                color: .hitRewindPurple,
                action: { playerCoordinator.togglePlayPause() }
            )

            // 3. Skip forward 10s
            controlButton(
                icon: "goforward.10",
                color: .hitRewindPurple,
                fontSize: 25,
                action: { playerCoordinator.skipForward(seconds: 10) }
            )

            // 4. Skip forward 60s
            controlButton(
                icon: "goforward.60",
                color: .hitRewindPurple,
                fontSize: 22,
                action: { playerCoordinator.skipForward(seconds: 60) }
            )

            // 5. Skip to next video
            controlButton(
                icon: "forward.end.fill",
                color: .hitRewindPurple,
                action: onNextVideo
            )

            Spacer()
        }
    }

    @ViewBuilder
    private func controlButton(
        icon: String,
        color: Color,
        fontSize: CGFloat = 20,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: fontSize))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VJModeControlStrip(
            playerCoordinator: YouTubePlayerCoordinator(),
            isFavorited: .constant(false),
            artistName: "Bruno Mars",
            showArtistButton: true,
            onFavoriteToggle: {},
            onArtistTap: {},
            onNextVideo: {}
        )
        .frame(width: 60, height: 400)
    }
}
