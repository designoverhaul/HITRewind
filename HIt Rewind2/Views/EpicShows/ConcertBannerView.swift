//
//  ConcertBannerView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI

struct ConcertBannerView: View {
    let concert: Concert
    
    @State private var isLoading = true
    
    var body: some View {
        bannerContent
    }
    
    private var bannerContent: some View {
        Group {
            // Banner image only - no overlays
            if let bannerImageUrl = concert.fields.bannerImage?.first?.url {
                AsyncImage(url: URL(string: bannerImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .onAppear { isLoading = false }
                } placeholder: {
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
    }
    
    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color.hitRewindDarkGray)
            .aspectRatio(2108/556, contentMode: .fit)  // Match banner dimensions
            .overlay {
                ProgressView()
                    .tint(.hitRewindPurple)
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
            largeImage: nil,
            eventDescription: "The Eras Tour",
            concertVideos: nil
        )
    )
    
    ConcertBannerView(concert: sampleConcert)
    .frame(width: 300, height: 200)
    .preferredColorScheme(.dark)
}