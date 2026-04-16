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

    /// Changes when the artist/year list changes, resetting scroll position
    private var pickerResetID: String {
        switch sourceType {
        case .musicVideos:
            return "years-\(availableYears.count)"
        case .live:
            return "artists-\(availableArtists.hashValue)"
        default:
            return "none"
        }
    }

    /// Index of the currently selected item, so we can scroll to it
    private var selectedItemIndex: Int? {
        switch sourceType {
        case .musicVideos:
            guard let year = selectedYear else { return nil }
            return availableYears.firstIndex(of: year)
        case .live:
            guard let artist = selectedArtist else { return nil }
            return availableArtists.firstIndex(of: artist)
        default:
            return nil
        }
    }

    private var itemCount: Int {
        switch sourceType {
        case .musicVideos: return availableYears.count
        case .live: return availableArtists.count
        default: return 0
        }
    }

    var body: some View {
        HorizontalOnlyScrollView(resetID: pickerResetID, scrollToItemIndex: selectedItemIndex, totalItems: itemCount) {
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
            .padding(.bottom, 3)
            .frame(maxHeight: .infinity, alignment: .bottom)
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
                .font(.system(size: 14))
                .fontWeight(selectedArtist == artist ? .bold : .medium)
                .foregroundColor(selectedArtist == artist ? .black : .hitRewindPrimaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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
    var resetID: String?
    var scrollToItemIndex: Int?
    var totalItems: Int

    init(resetID: String? = nil, scrollToItemIndex: Int? = nil, totalItems: Int = 0, @ViewBuilder content: () -> Content) {
        self.resetID = resetID
        self.scrollToItemIndex = scrollToItemIndex
        self.totalItems = totalItems
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
        hostingController.view.insetsLayoutMarginsFromSafeArea = false
        // Disable safe area insets so buttons aren't pushed up from screen edge
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }

        scrollView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.hostingController = hostingController
        context.coordinator.lastResetID = resetID

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content

        // Reset scroll position when resetID changes, scrolling to selected item
        if resetID != context.coordinator.lastResetID {
            context.coordinator.lastResetID = resetID
            scrollToItem(in: scrollView, animated: false)
        }
        // On first layout, scroll to selected item once content is sized
        if !context.coordinator.hasScrolledInitially && scrollView.contentSize.width > scrollView.bounds.width {
            context.coordinator.hasScrolledInitially = true
            scrollToItem(in: scrollView, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var hostingController: UIHostingController<Content>?
        var lastResetID: String?
        var hasScrolledInitially: Bool = false
    }

    /// Scroll to the selected item by estimating its position proportionally
    private func scrollToItem(in scrollView: UIScrollView, animated: Bool) {
        guard let index = scrollToItemIndex, totalItems > 0 else {
            scrollView.setContentOffset(.zero, animated: animated)
            return
        }
        // After a brief delay so content is laid out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let contentWidth = scrollView.contentSize.width
            let viewWidth = scrollView.bounds.width
            guard contentWidth > viewWidth else { return }

            // Estimate item position (evenly distributed)
            let itemFraction = CGFloat(index) / CGFloat(max(1, totalItems))
            let targetX = itemFraction * contentWidth - viewWidth / 2
            let clampedX = max(0, min(targetX, contentWidth - viewWidth))
            scrollView.setContentOffset(CGPoint(x: clampedX, y: 0), animated: animated)
        }
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
