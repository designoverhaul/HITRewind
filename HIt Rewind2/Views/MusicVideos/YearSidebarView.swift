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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                // Hardcoded "Top Today" row at the top
                YearRowView(
                    year: kSpotifyTop50Year,
                    isSelected: selectedYear == kSpotifyTop50Year,
                    onTap: {
                        onYearSelected(kSpotifyTop50Year)
                    }
                )

                // Regular year rows
                ForEach(years.filter { $0 != kSpotifyTop50Year }, id: \.self) { year in
                    YearRowView(
                        year: year,
                        isSelected: selectedYear == year,
                        onTap: {
                            onYearSelected(year)
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.hitRewindBackground)
    }
}

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