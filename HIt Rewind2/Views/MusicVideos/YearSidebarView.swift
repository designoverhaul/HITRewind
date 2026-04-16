//
//  YearSidebarView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI

// Special value for "Top Today" - Spotify chart
let kSpotifyTop50Year = 9999

struct YearSidebarView: View {
    let years: [Int]
    @Binding var selectedYear: Int?
    let onYearSelected: (Int) -> Void

    // Track whether the selected row is visible and its relative position
    @State private var selectedRowVisible: Bool = true
    @State private var selectedAboveViewport: Bool = false
    @State private var lastKnownAboveState: Bool = false  // remembers direction when row unloads

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// In landscape (compact vertical), stick to the very edge; in portrait, add margin
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    /// All years in display order: "Today" first, then the rest
    private var allYears: [Int] {
        [kSpotifyTop50Year] + years.filter { $0 != kSpotifyTop50Year }
    }

    var body: some View {
        GeometryReader { outerGeo in
            let sidebarHeight = outerGeo.size.height
            ZStack(alignment: selectedAboveViewport ? .top : .bottom) {
                // Main scrollable list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(allYears, id: \.self) { year in
                                YearRowView(
                                    year: year,
                                    isSelected: selectedYear == year,
                                    onTap: { onYearSelected(year) }
                                )
                                .id(year)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .preference(
                                                key: SelectedYearVisibilityKey.self,
                                                value: selectedYear == year
                                                    ? SelectedYearPosition(minY: geo.frame(in: .named("sidebarScroll")).minY,
                                                                           maxY: geo.frame(in: .named("sidebarScroll")).maxY)
                                                    : nil
                                            )
                                    }
                                )
                            }
                        }
                        .padding(.vertical, isLandscape ? 0 : 8)
                    }
                    .coordinateSpace(name: "sidebarScroll")
                    .onPreferenceChange(SelectedYearVisibilityKey.self) { position in
                        if let pos = position {
                            // Check if the selected row is within the sidebar's own bounds
                            let margin: CGFloat = isLandscape ? 0 : 8
                            let isVisible = pos.maxY > margin && pos.minY < sidebarHeight - margin
                            selectedRowVisible = isVisible
                            // Determine if the row is above or below the viewport
                            // Above: row's bottom edge is at or above the top margin
                            // Also consider "heading above" when minY < half the sidebar (top half of scroll)
                            let isAbove = pos.maxY <= margin
                            selectedAboveViewport = isAbove
                            // Track which half of the sidebar the row is in, so when LazyVStack
                            // unloads it we know which direction it went
                            lastKnownAboveState = pos.minY < sidebarHeight / 2
                        } else {
                            // Selected year not in lazy stack's loaded range (LazyVStack unloaded it)
                            // Use the last known direction to determine sticky position
                            selectedRowVisible = false
                            selectedAboveViewport = lastKnownAboveState
                        }
                    }
                    .onChange(of: selectedYear) { _, newYear in
                        guard let year = newYear else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(year, anchor: .center)
                        }
                    }
                }

                // Sticky selected year pinned to top or bottom when scrolled off-screen (landscape only)
                if isLandscape, !selectedRowVisible, let year = selectedYear {
                    YearRowView(
                        year: year,
                        isSelected: true,
                        onTap: { onYearSelected(year) }
                    )
                    .transition(.opacity)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: selectedAboveViewport ? 2 : -2)
                }
            }
        }
        .ignoresSafeArea(.container, edges: isLandscape ? [.top, .bottom] : [])
        .background(Color.hitRewindBackground)
    }
}

// MARK: - Preference Key for tracking selected row position

private struct SelectedYearPosition: Equatable {
    let minY: CGFloat
    let maxY: CGFloat
}

private struct SelectedYearVisibilityKey: PreferenceKey {
    static var defaultValue: SelectedYearPosition? = nil
    static func reduce(value: inout SelectedYearPosition?, nextValue: () -> SelectedYearPosition?) {
        value = value ?? nextValue()
    }
}

// MARK: - Year Row

struct YearRowView: View {
    let year: Int
    let isSelected: Bool
    let onTap: () -> Void

    // Display text for the row
    private var displayText: String {
        if year == kSpotifyTop50Year {
            return "Today"
        } else {
            return String(year)
        }
    }

    var body: some View {
        Button(action: onTap) {
            Text(displayText)
                .font(.custom(AppFont.ticketingName(), size: 20))
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .black : .hitRewindPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .background(
                    Rectangle()
                        .fill(isSelected ? Color.hitRewindPurple : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(YearButtonStyle())
    }
}

struct YearButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Rectangle()
                    .fill(configuration.isPressed ? Color.hitRewindPurple.opacity(0.3) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        YearSidebarView(
            years: [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015],
            selectedYear: .constant(2023),
            onYearSelected: { year in
                print("Selected year: \(String(year))")
            }
        )
        .frame(width: 280)
        .navigationTitle("Years")
    }
    .preferredColorScheme(.dark)
}
