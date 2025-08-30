//
//  ArtistSongsView.swift
//  HIt Rewind2
//
//  Created by Assistant on 8/25/25.
//

import SwiftUI

// MARK: - Reusable Headline Component
struct HitRewindHeadline: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.custom(AppFont.ticketingName(), size: 20))
            .fontWeight(.bold)
            .foregroundColor(.hitRewindPrimaryText)
    }
}

struct ArtistVideo: Identifiable {
    let id: String // use videoId as stable id
    let title: String
    let videoId: String
    let year: String
}

struct ArtistSongsView: View {
    let artistName: String
    @StateObject private var airtableService = AirtableService()
    @State private var videos: [ArtistVideo] = []
    
    // Device and orientation detection for grid layout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        Group {
            if videos.isEmpty {
                ProgressView()
                    .tint(.hitRewindPurple)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HitRewindHeadline(text: artistName)
                            .padding(.horizontal, gridPadding)
                    }
                    .padding(.top, gridPadding)
                    
                    LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                        ForEach(videos) { item in
                            NavigationLink(
                                destination: SingleVideoView(
                                    videoId: item.videoId,
                                    videoTitle: item.title,
                                    artistName: artistName,
                                    year: item.year
                                )
                            ) {
                                VideoThumbnailView(
                                    videoId: item.videoId,
                                    title: item.title,
                                    artist: artistName,
                                    year: item.year,
                                    onTap: {},
                                    hideArtistName: true
                                )
                            }
                        }
                    }
                    .padding(gridPadding)
                }
            }
        }
        .navigationTitle(artistName)
        .task {
            await loadArtistVideos()
        }
    }
    
    private func loadArtistVideos() async {
        await airtableService.fetchPlaylists()
        var results: [ArtistVideo] = []
        for playlist in airtableService.playlists {
            let titles = playlist.fields.videoTitles ?? []
            let urls = playlist.fields.videoUrls ?? []
            let artists = playlist.fields.artistNames ?? []
            let years = playlist.fields.videoYears ?? []
            for (idx, artist) in artists.enumerated() {
                if artist.caseInsensitiveCompare(artistName) == .orderedSame,
                   let url = urls[safe: idx],
                   let id = extractYouTubeVideoID(from: url) {
                    let title = titles[safe: idx] ?? "Unknown Title"
                    // Use individual video year if available, fallback to playlist year
                    let videoYear = years[safe: idx] ?? String(playlist.fields.year)
                    results.append(ArtistVideo(id: id, title: title, videoId: id, year: videoYear))
                }
            }
        }
        // Sort by year (newest first), then by title
        videos = results.sorted { first, second in
            if let firstYear = Int(first.year), let secondYear = Int(second.year) {
                if firstYear != secondYear {
                    return firstYear > secondYear // Newest first
                }
            }
            return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
        }
    }
    
    // MARK: - Grid helpers
    private var gridColumns: [GridItem] {
        let count = columnCount
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: count)
    }
    
    private var columnCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return horizontalSizeClass == .regular ? 4 : 3
        } else {
            return verticalSizeClass == .regular ? 1 : 2
        }
    }
    
    private var gridSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
    }
    
    private var gridPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
    }
}

#Preview {
    NavigationView {
        ArtistSongsView(artistName: "Taylor Swift")
    }
    .preferredColorScheme(.dark)
}


