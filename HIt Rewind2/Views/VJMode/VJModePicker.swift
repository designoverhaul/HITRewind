//
//  VJModePicker.swift
//  HIt Rewind2
//
//  Horizontal picker for VJ Mode - years or artists depending on source type
//  ONLY scrolls horizontally (uses UIScrollView to guarantee this)
//

import SwiftUI
import UIKit

/// Horizontal picker shown at bottom of VJ Mode
/// Shows years for Music Videos mode, artists for Live/FanCams mode
struct VJModePicker: View {
    let sourceType: VideoSourceType
    @Binding var selectedYear: Int?
    @Binding var selectedArtist: String?
    let availableYears: [Int]
    let availableArtists: [String]
    let onYearSelected: (Int) -> Void
    let onArtistSelected: (String) -> Void

    var body: some View {
        HorizontalOnlyScrollView {
            HStack(alignment: .center, spacing: 8) {
                switch sourceType {
                case .musicVideos:
                    ForEach(availableYears, id: \.self) { year in
                        yearButton(year: year)
                    }

                case .live:
                    ForEach(availableArtists, id: \.self) { artist in
                        artistButton(artist: artist)
                    }

                case .epicShows, .concert:
                    EmptyView()
                }
            }
            .padding(.leading, 0)
            .padding(.trailing, 8)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .mask(
            HStack(spacing: 0) {
                // Left fade
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 40)

                // Full opacity middle
                Color.black

                // Right fade
                LinearGradient(
                    gradient: Gradient(colors: [.black, .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 40)
            }
        )
    }

    @ViewBuilder
    private func yearButton(year: Int) -> some View {
        Button(action: {
            selectedYear = year
            onYearSelected(year)
        }) {
            Text(String(year))
                .font(.custom(AppFont.ticketingName(), size: 16))
                .fontWeight(selectedYear == year ? .bold : .medium)
                .foregroundColor(selectedYear == year ? .black : .hitRewindPrimaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedYear == year ? Color.hitRewindPurple : Color.hitRewindSecondaryBackground)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func artistButton(artist: String) -> some View {
        Button(action: {
            selectedArtist = artist
            onArtistSelected(artist)
        }) {
            Text(artist)
                .font(.custom(AppFont.ticketingName(), size: 14))
                .fontWeight(selectedArtist == artist ? .bold : .medium)
                .foregroundColor(selectedArtist == artist ? .black : .hitRewindPrimaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedArtist == artist ? Color.hitRewindPurple : Color.hitRewindSecondaryBackground)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - UIKit-backed horizontal-only scroll view

struct HorizontalOnlyScrollView<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.hostingController = hostingController

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var hostingController: UIHostingController<Content>?
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            VJModePicker(
                sourceType: .musicVideos,
                selectedYear: .constant(2023),
                selectedArtist: .constant(nil),
                availableYears: [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017],
                availableArtists: [],
                onYearSelected: { _ in },
                onArtistSelected: { _ in }
            )
            .frame(height: 36)

            VJModePicker(
                sourceType: .live(artistName: "Artist B", categoryArtists: [], allArtistVideos: [:]),
                selectedYear: .constant(nil),
                selectedArtist: .constant("Artist B"),
                availableYears: [],
                availableArtists: ["Artist A", "Artist B", "Artist C", "Artist D"],
                onYearSelected: { _ in },
                onArtistSelected: { _ in }
            )
            .frame(height: 36)
        }
        .padding()
    }
}
