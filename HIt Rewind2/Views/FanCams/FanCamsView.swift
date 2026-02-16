//
//  FanCamsView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI
import SuperwallKit

struct FanCamsView: View {
    @StateObject private var airtableService = AirtableService()
    @StateObject private var youtubeService = YouTubeService()

    @State private var selectedCategory: FanCamCategory?
    @State private var selectedArtist: Playlist?
    @State private var visibleVideoIndices: [Int] = []
    @State private var isLoadingVideos: Bool = false

    // Device and orientation detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var body: some View {
        NavigationStack {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            await airtableService.fetchCategories()

            // Default to "Pop" category on load
            if let popCategory = airtableService.categories.first(where: { $0.name == "Pop" }) {
                selectedCategory = popCategory
                await airtableService.fetchVideoCounts(for: popCategory.artists)
            }
        }
    }

    // MARK: - iPad Layout
    private var iPadLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Custom header row
            HStack {
                Color.clear
                    .frame(width: 60, height: 22)

                Spacer()

                // Logo centered
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(Color.hitRewindBackground)

            contentView
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        contentView
            .navigationTitle("")
            .navigationBarHidden(true)
    }

    // MARK: - Content View
    private var contentView: some View {
        Group {
            if airtableService.isLoading {
                LoadingView()
            } else if let errorMessage = airtableService.errorMessage {
                ErrorView(message: errorMessage) {
                    Task {
                        await airtableService.fetchArtists()
                    }
                }
            } else {
                threeColumnLayout
            }
        }
    }

    // MARK: - Three Column Layout (Categories | Artists | Videos)
    private var threeColumnLayout: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Column 1: Categories list
                categoriesColumn
                    .frame(width: geometry.size.width * 0.22)
                    .background(Color.hitRewindBackground)

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)

                // Column 2: Artists list for selected category
                artistsColumn
                    .frame(width: geometry.size.width * 0.28 - 1)
                    .background(Color.hitRewindBackground.opacity(0.7))

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)

                // Column 3: Videos for selected artist
                videosColumn
                    .frame(width: geometry.size.width * 0.50 - 1)
                    .background(Color.hitRewindBackground.opacity(0.5))
            }
        }
    }

    // MARK: - Categories Column
    private var categoriesColumn: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(availableCategories) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            handleCategorySelection(category)
                        }
                    }) {
                        HStack {
                            Text(formattedCategoryName(category.name))
                                .font(.custom(AppFont.ticketingName(), size: 18))
                                .fontWeight(selectedCategory?.id == category.id ? .semibold : .regular)
                                .foregroundColor(selectedCategory?.id == category.id ? .hitRewindPurple : .hitRewindPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 4)
                        .padding(.vertical, 12)
                        .background(selectedCategory?.id == category.id ? Color.hitRewindPurple.opacity(0.15) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Artists Column
    private var artistsColumn: some View {
        Group {
            if selectedCategory != nil {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(artistsInCategory) { artist in
                            let isSelected = selectedArtist?.fields.title == artist.fields.title
                            Button(action: {
                                handleArtistSelection(artist)
                            }) {
                                HStack {
                                    Text(artist.fields.title)
                                        .font(.system(size: 14))
                                        .fontWeight(isSelected ? .semibold : .regular)
                                        .foregroundColor(isSelected ? .hitRewindPurple : .hitRewindPrimaryText)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(airtableService.artistVideoCounts[artist.fields.title] ?? 0)")
                                        .font(.system(size: 12))
                                        .foregroundColor(isSelected ? .hitRewindPurple.opacity(0.7) : .hitRewindSecondaryText)
                                }
                                .padding(.leading, 8)
                                .padding(.trailing, 4)
                                .padding(.vertical, 12)
                                .background(isSelected ? Color.hitRewindPurple.opacity(0.15) : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select a genre")
                        .font(.system(size: 16))
                        .foregroundColor(.hitRewindSecondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Videos Column
    private var videosColumn: some View {
        Group {
            if isLoadingVideos {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.system(size: 14))
                        .foregroundColor(.hitRewindSecondaryText)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if selectedArtist != nil && !visibleVideos.isEmpty {
                ScrollView {
                    LazyVGrid(columns: videoGridColumns, spacing: 12) {
                        ForEach(visibleVideos) { item in
                            Button(action: {
                                handleVideoTap(item: item)
                            }) {
                                VideoThumbnailView(
                                    videoId: item.id,
                                    title: item.title,
                                    artist: item.artist,
                                    year: item.year,
                                    onTap: {},
                                    hideArtistName: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "music.mic")
                        .font(.system(size: 36))
                        .foregroundColor(.hitRewindSecondaryText.opacity(0.5))
                    Text("Select an artist")
                        .font(.system(size: 16))
                        .foregroundColor(.hitRewindSecondaryText)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Computed Properties
    private var availableCategories: [FanCamCategory] {
        return airtableService.categories
    }

    private var artistsInCategory: [Playlist] {
        guard let selectedCategory = selectedCategory else { return [] }
        let names = selectedCategory.artists
        let placeholder = URL(string: "https://via.placeholder.com/300x200")!
        let playlists = names.map { name in
            Playlist(
                id: name,
                fields: PlaylistFields(
                    thumbnail: placeholder,
                    year: 0,
                    title: name,
                    videoUrls: [],
                    artistNames: [],
                    videoTitles: [],
                    isVisible: []
                )
            )
        }
        return playlists.sorted { $0.fields.title.localizedCaseInsensitiveCompare($1.fields.title) == .orderedAscending }
    }

    private var videoGridColumns: [GridItem] {
        // 2 columns in the video area
        return [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var videoYearRange: String? {
        guard !visibleVideos.isEmpty else { return nil }

        let years = visibleVideos.compactMap { Int($0.year) }
        guard !years.isEmpty else { return nil }

        let minYear = years.min() ?? 0
        let maxYear = years.max() ?? 0

        if minYear == maxYear {
            return "\(minYear)"
        } else {
            return "\(minYear)-\(maxYear)"
        }
    }


    // MARK: - Helper Methods

    private func formattedCategoryName(_ name: String) -> String {
        let lowercased = name.lowercased()

        switch lowercased {
        case "pop":
            return "💋 Pop"
        case "modern rock":
            return "🎸 Modern Rock"
        case "classic rock":
            return "🤘 Classic Rock"
        case "jam bands":
            return "🍄 Jam Bands"
        case "jazz":
            return "🎺 Jazz"
        case "country":
            return "👢 Country"
        case "latin":
            return "🌶️ Latin"
        case "indi", "indie":
            return "☕ Indi"
        case "r&b":
            return "🕯️ R&B"
        case "electronic":
            return "🎧 Electronic"
        case "hip hop":
            return "🍑 Hip Hop"
        default:
            return name
        }
    }

    private func handleVideoTap(item: VisibleVideo) {
        print("🎥 Fan Cam video \(item.id) tapped")

        if PaywallService.shared.testSubscriberMode {
            print("🧪 Test subscriber mode enabled - playing video")
            openVideoInMiniPlayer(item: item)
            return
        }

        Task { @MainActor in
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()

            if isSubscribed {
                print("✅ User subscribed - playing video")
                openVideoInMiniPlayer(item: item)
            } else {
                print("🔒 User not subscribed - showing paywall")
                PaywallService.shared.presentPaywallWithOrientation {
                    print("✅ Purchase complete - playing video")
                    openVideoInMiniPlayer(item: item)
                }
            }
        }
    }

    private func openVideoInMiniPlayer(item: VisibleVideo) {
        let playlistVideos = visibleVideos.map { video in
            PlaylistVideo(
                id: video.id,
                youtubeURL: video.originalURL,
                title: video.title,
                artist: video.artist,
                year: video.year
            )
        }

        guard let currentIndex = playlistVideos.firstIndex(where: { $0.id == item.id }) else { return }

        let categoryArtists = selectedCategory?.artists ?? []
        let artistName = selectedArtist?.fields.title ?? item.artist
        var allArtistVideos: [String: [PlaylistVideo]] = [:]
        allArtistVideos[artistName] = playlistVideos

        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex,
            sourceType: .live(artistName: artistName, categoryArtists: categoryArtists, allArtistVideos: allArtistVideos)
        )

        let initialVideo = playlistVideos[currentIndex]

        MiniPlayerManager.shared.openVJMode(
            video: initialVideo,
            videos: playlistVideos,
            playlistContext: playlistContext
        )
    }

    private func handleCategorySelection(_ category: FanCamCategory) {
        print("📂 Category selected: \(category.name)")
        selectedCategory = category
        selectedArtist = nil
        visibleVideoIndices = []

        Task {
            await airtableService.fetchVideoCounts(for: category.artists)
        }
    }

    private func handleArtistSelection(_ artist: Playlist) {
        print("👤 Artist selected: \(artist.fields.title)")
        isLoadingVideos = true

        Task {
            print("🔎 Loading videos for artist: \(artist.fields.title)")
            if let loaded = try? await airtableService.fetchArtist(byName: artist.fields.title) {
                await MainActor.run {
                    selectedArtist = loaded
                    updateVisibleVideoIndices()
                    isLoadingVideos = false
                    print("🎵 Loaded artist: \(loaded.fields.title) with \(visibleVideoIndices.count) videos")
                }
            } else {
                print("⚠️ Failed to load artist: \(artist.fields.title)")
                await MainActor.run {
                    selectedArtist = artist
                    visibleVideoIndices = []
                    isLoadingVideos = false
                }
            }
        }
    }

    private func updateVisibleVideoIndices() {
        guard let artist = selectedArtist else {
            visibleVideoIndices = []
            return
        }
        let isVisibleFlags = artist.fields.isVisible
        let urlsCount = artist.fields.videoUrls?.count ?? 0
        if isVisibleFlags.isEmpty && urlsCount > 0 {
            visibleVideoIndices = Array(0..<urlsCount)
            return
        }
        let indices = isVisibleFlags.enumerated().compactMap { index, flag in (flag ?? false) ? index : nil }
        visibleVideoIndices = indices
    }
}

// MARK: - Visible Video Model
private struct VisibleVideo: Identifiable, Hashable {
    let id: String
    let originalURL: String
    let title: String
    let artist: String
    let year: String
}

private extension FanCamsView {
    var visibleVideos: [VisibleVideo] {
        guard let artist = selectedArtist else { return [] }
        var result: [VisibleVideo] = []
        for index in visibleVideoIndices {
            if let url = artist.fields.videoUrls?[safe: index],
               let videoId = extractYouTubeVideoID(from: url) {
                let title = artist.fields.videoTitles?[safe: index] ?? "Unknown Title"
                let artistName = artist.fields.artistNames?[safe: index] ?? artist.fields.title
                let videoYear = artist.fields.videoYears?[safe: index] ?? String(artist.fields.year)
                result.append(VisibleVideo(id: videoId, originalURL: url, title: title, artist: artistName, year: videoYear))
            }
        }
        return result.sorted { first, second in
            if let firstYear = Int(first.year), let secondYear = Int(second.year) {
                if firstYear != secondYear {
                    return firstYear > secondYear
                }
            }
            return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
        }
    }
}

// MARK: - Preview
#Preview {
    FanCamsView()
        .preferredColorScheme(.dark)
}
