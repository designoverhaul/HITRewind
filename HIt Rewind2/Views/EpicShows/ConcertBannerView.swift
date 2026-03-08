//
//  ConcertBannerView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI
import UIKit

struct ConcertBannerView: View {
    let concert: Concert

    @State private var bannerImage: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        bannerContent
    }

    private var bannerContent: some View {
        Group {
            if let bannerImageUrl = concert.fields.bannerImage?.first?.url {
                if let uiImage = bannerImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if loadFailed {
                    defaultBannerPlaceholder
                } else {
                    loadingPlaceholder
                }
            } else {
                defaultBannerPlaceholder
            }
        }
        .clipped()
        .clipShape(Rectangle())
        .aspectRatio(2108/556, contentMode: .fit)  // Actual banner dimensions ~3.79:1
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .task(id: concert.id) {
            guard let urlString = concert.fields.bannerImage?.first?.url,
                  let url = URL(string: urlString) else { return }
            let cacheKey = "banner_\(concert.id)"
            let loaded = await ImageCache.shared.loadImage(from: url, cacheKey: cacheKey)
            if let loaded {
                bannerImage = loaded
                isLoading = false
            } else {
                loadFailed = true
                print("❌ Banner image failed to load for \(concert.fields.artistName)")
            }
        }
    }
    
    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color.hitRewindDarkGray)
            .aspectRatio(2108/556, contentMode: .fit)  // Match banner dimensions
            .overlay {
                SpinningRecordView(size: 30)
            }
            .clipShape(Rectangle())
    }
    
    private var defaultBannerPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.hitRewindDarkGray, .hitRewindBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(2108/556, contentMode: .fit)  // Match banner dimensions
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 32))
                        .foregroundColor(.hitRewindSecondaryText)
                    
                    Text("Concert Banner")
                        .font(.caption)
                        .foregroundColor(.hitRewindSecondaryText)
                }
            }
            .clipShape(Rectangle())
    }
}

#Preview {
    let sampleConcert = Concert(
        id: "preview",
        fields: ConcertFields(
            venueName: "Madison Square Garden",
            artistName: "Taylor Swift",
            eventYear: 2024,
            bannerImage: nil,
            eventDescription: "The Eras Tour",
            concertVideos: nil
        )
    )
    
    ConcertBannerView(concert: sampleConcert)
    .frame(width: 300, height: 200)
    .preferredColorScheme(.dark)
}