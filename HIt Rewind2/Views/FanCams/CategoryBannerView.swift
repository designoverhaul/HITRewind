//
//  CategoryBannerView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI

struct CategoryBannerView: View {
    let category: FanCamCategory
    let onTap: () -> Void
    
    private let bannerAspectRatio: CGFloat = 990.0 / 408.0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background image or fallback gradient
                if let imageUrl = category.imageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            Color.black
                            .overlay(
                                SpinningRecordView(size: 30)
                            )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        case .failure(_):
                            // Graceful fallback if the attachment URL is expired or unavailable
                            LinearGradient(
                                colors: [
                                    category.color.opacity(0.8),
                                    category.color.opacity(0.3),
                                    Color.black.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        @unknown default:
                            LinearGradient(
                                colors: [
                                    category.color.opacity(0.8),
                                    category.color.opacity(0.3),
                                    Color.black.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                } else {
                    // Fallback gradient when no image URL
                    LinearGradient(
                        colors: [
                            category.color.opacity(0.8),
                            category.color.opacity(0.3),
                            Color.black.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                
                // Dark overlay for text readability
                Color.black.opacity(0.4)
                    .blendMode(.multiply)
                
                // Category name overlay
                VStack {
                    Spacer()
                    HStack {
                        Text(category.name)
                            .font(.custom(AppFont.ticketingName(), size: categoryTitleSize))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 4, x: 2, y: 2)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .aspectRatio(bannerAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
    
    private var categoryTitleSize: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 28
        } else {
            return 24
        }
    }
    
    // Height is derived from width using bannerAspectRatio
}

// MARK: - Preview
#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(FanCamCategory.allCategories) { category in
                CategoryBannerView(category: category) {
                    print("Tapped: \(category.name)")
                }
            }
        }
        .padding()
    }
    .background(Color.hitRewindBackground)
    .preferredColorScheme(.dark)
}