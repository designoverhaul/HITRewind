//
//  CategorySidebarView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI

struct CategorySidebarView: View {
    let categories: [FanCamCategory]
    @Binding var selectedCategory: FanCamCategory?
    let onCategorySelected: (FanCamCategory) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(categories) { category in
                    CategoryRowView(
                        category: category,
                        isSelected: selectedCategory?.id == category.id
                    ) {
                        onCategorySelected(category)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.hitRewindBackground)
    }
}

struct CategoryRowView: View {
    let category: FanCamCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.custom(AppFont.ticketingName(), size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(.hitRewindPrimaryText)
                        .multilineTextAlignment(.leading)
                    
                    if !category.description.isEmpty {
                        Text(category.description)
                            .font(.caption)
                            .foregroundColor(.hitRewindSecondaryText)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.hitRewindPurple.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.hitRewindPurple.opacity(0.2) : Color.hitRewindCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.hitRewindPurple : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    CategorySidebarView(
        categories: FanCamCategory.allCategories,
        selectedCategory: .constant(FanCamCategory.allCategories.first)
    ) { category in
        print("Selected: \(category.name)")
    }
    .preferredColorScheme(.dark)
}