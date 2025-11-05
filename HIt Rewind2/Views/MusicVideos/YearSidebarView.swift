//
//  YearSidebarView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI

struct YearSidebarView: View {
    let years: [Int]
    @Binding var selectedYear: Int?
    let onYearSelected: (Int) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(years, id: \.self) { year in
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

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(verbatim: String(year))
                    .font(.custom(AppFont.ticketingName(), size: 24))
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .black : .hitRewindPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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