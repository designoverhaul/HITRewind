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
    @State private var selectedTab: VideoSource = .liveLibrary
    @State private var officialChannelVideos: [YouTubeChannelVideo] = []
    @State private var isLoadingOfficialVideos: Bool = false
    @State private var officialNextPageToken: String?
    @State private var isLoadingMoreOfficialVideos: Bool = false
    @State private var officialQuotaReached: Bool = false

    private enum VideoSource {
        case liveLibrary
        case official
    }

    // MARK: - Official Video Daily Rate Limit
    private static let officialDailyLimit = 10
    private static let officialCountKey = "officialVideoFetchCount"
    private static let officialDateKey = "officialVideoFetchDate"

    private func canFetchOfficialVideos() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: Self.officialDateKey) as? Date ?? .distantPast
        if Calendar.current.startOfDay(for: lastDate) != today {
            // New day, reset counter
            UserDefaults.standard.set(0, forKey: Self.officialCountKey)
            UserDefaults.standard.set(today, forKey: Self.officialDateKey)
        }
        let count = UserDefaults.standard.integer(forKey: Self.officialCountKey)
        return count < Self.officialDailyLimit
    }

    private func incrementOfficialFetchCount() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: Self.officialDateKey) as? Date ?? .distantPast
        if Calendar.current.startOfDay(for: lastDate) != today {
            UserDefaults.standard.set(1, forKey: Self.officialCountKey)
            UserDefaults.standard.set(today, forKey: Self.officialDateKey)
        } else {
            let count = UserDefaults.standard.integer(forKey: Self.officialCountKey)
            UserDefaults.standard.set(count + 1, forKey: Self.officialCountKey)
        }
    }

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
                    .frame(width: max(1, geometry.size.width * 0.28 - 1))
                    .background(Color.hitRewindBackground.opacity(0.7))

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)

                // Column 3: Videos for selected artist
                videosColumn
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.hitRewindBackground.opacity(0.5))
            }
            .ignoresSafeArea(.container, edges: .trailing)
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
            } else if selectedArtist != nil {
                if selectedTab == .liveLibrary || selectedArtist?.fields.youtubeChannelId == nil {
                    liveLibraryGrid
                } else {
                    officialChannelGrid
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
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .official && officialChannelVideos.isEmpty && !isLoadingOfficialVideos {
                Task {
                    await loadOfficialChannelVideos()
                }
            }
        }
    }

    // MARK: - Channel Header
    private var channelHeader: some View {
        HStack(spacing: 10) {
            if let iconUrl = selectedArtist?.fields.youtubeChannelIcon,
               let url = URL(string: iconUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 119, height: 119)
                .clipShape(Circle())
            }

            Text(selectedArtist?.fields.title ?? "")
                .font(.custom(AppFont.ticketingName(), size: 20))
                .foregroundColor(.hitRewindPurple)

            Spacer()
        }
    }

    // MARK: - Video Source Picker
    private var videoPicker: some View {
        Picker("Source", selection: $selectedTab) {
            Text("Live Library").tag(VideoSource.liveLibrary)
            Text("Official").tag(VideoSource.official)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Scrollable Channel Header
    @ViewBuilder
    private var scrollableChannelHeader: some View {
        if let channelId = selectedArtist?.fields.youtubeChannelId, !channelId.isEmpty {
            channelHeader
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

            videoPicker
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Live Library Grid
    private var liveLibraryGrid: some View {
        Group {
            if !visibleVideos.isEmpty {
                ScrollView {
                    scrollableChannelHeader

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
                ScrollView {
                    scrollableChannelHeader

                    VStack {
                        Spacer().frame(height: 40)
                        Text("No videos")
                            .font(.system(size: 16))
                            .foregroundColor(.hitRewindSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Official Channel Grid
    private var officialChannelGrid: some View {
        Group {
            if officialQuotaReached {
                ScrollView {
                    scrollableChannelHeader

                    VStack(spacing: 8) {
                        Spacer().frame(height: 40)
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 36))
                            .foregroundColor(.hitRewindSecondaryText.opacity(0.5))
                        Text("Daily limit reached")
                            .font(.system(size: 16))
                            .foregroundColor(.hitRewindSecondaryText)
                        Text("Check back tomorrow")
                            .font(.system(size: 13))
                            .foregroundColor(.hitRewindSecondaryText.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if isLoadingOfficialVideos {
                ScrollView {
                    scrollableChannelHeader

                    VStack {
                        Spacer().frame(height: 40)
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading...")
                            .font(.system(size: 14))
                            .foregroundColor(.hitRewindSecondaryText)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if officialChannelVideos.isEmpty {
                ScrollView {
                    scrollableChannelHeader

                    VStack {
                        Spacer().frame(height: 40)
                        Image(systemName: "video.slash")
                            .font(.system(size: 36))
                            .foregroundColor(.hitRewindSecondaryText.opacity(0.5))
                        Text("No videos found")
                            .font(.system(size: 16))
                            .foregroundColor(.hitRewindSecondaryText)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ScrollView {
                    scrollableChannelHeader

                    LazyVGrid(columns: videoGridColumns, spacing: 12) {
                        ForEach(officialChannelVideos) { video in
                            Button(action: {
                                handleOfficialVideoTap(video: video)
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    VideoThumbnailView(
                                        videoId: video.videoId,
                                        title: video.title,
                                        artist: selectedArtist?.fields.title ?? "",
                                        year: "",
                                        onTap: {},
                                        hideArtistName: true
                                    )

                                    Text(video.formattedPublishDate)
                                        .font(.system(size: 11))
                                        .foregroundColor(.hitRewindSecondaryText)
                                        .padding(.leading, 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 12)

                    // Load More button
                    if officialNextPageToken != nil {
                        Button(action: {
                            Task {
                                await loadMoreOfficialVideos()
                            }
                        }) {
                            if isLoadingMoreOfficialVideos {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            } else {
                                Text("Load More")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.hitRewindPurple)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.hitRewindPurple.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                        .disabled(isLoadingMoreOfficialVideos)
                        .padding(.horizontal, 8)
                    }

                    Spacer().frame(height: 16)
                }
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
        // 2 columns in the video area, top-aligned so thumbnails stay in line
        return [
            GridItem(.flexible(), spacing: 12, alignment: .top),
            GridItem(.flexible(), spacing: 12, alignment: .top)
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
        selectedTab = .liveLibrary
        officialChannelVideos = []
        officialNextPageToken = nil

        Task {
            await airtableService.fetchVideoCounts(for: category.artists)
        }
    }

    private func handleArtistSelection(_ artist: Playlist) {
        print("👤 Artist selected: \(artist.fields.title)")
        isLoadingVideos = true
        selectedTab = .liveLibrary
        officialChannelVideos = []
        officialNextPageToken = nil
        officialQuotaReached = false

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

    // MARK: - Official Channel Video Loading
    @MainActor
    private func loadOfficialChannelVideos() async {
        guard let channelId = selectedArtist?.fields.youtubeChannelId, !channelId.isEmpty else { return }

        if !canFetchOfficialVideos() {
            officialQuotaReached = true
            return
        }

        isLoadingOfficialVideos = true
        officialQuotaReached = false
        incrementOfficialFetchCount()
        do {
            let result = try await youtubeService.fetchChannelVideos(channelId: channelId)
            officialChannelVideos = result.videos
            officialNextPageToken = result.nextPageToken
        } catch {
            print("❌ Error loading official channel videos: \(error)")
            officialChannelVideos = []
            officialNextPageToken = nil
        }
        isLoadingOfficialVideos = false
    }

    @MainActor
    private func loadMoreOfficialVideos() async {
        guard let channelId = selectedArtist?.fields.youtubeChannelId,
              let pageToken = officialNextPageToken else { return }

        isLoadingMoreOfficialVideos = true
        do {
            let result = try await youtubeService.fetchChannelVideos(channelId: channelId, pageToken: pageToken)
            officialChannelVideos.append(contentsOf: result.videos)
            officialNextPageToken = result.nextPageToken
        } catch {
            print("❌ Error loading more official videos: \(error)")
        }
        isLoadingMoreOfficialVideos = false
    }

    private func handleOfficialVideoTap(video: YouTubeChannelVideo) {
        print("🎥 Official video \(video.videoId) tapped")

        if PaywallService.shared.testSubscriberMode {
            openOfficialVideoInMiniPlayer(video: video)
            return
        }

        Task { @MainActor in
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()
            if isSubscribed {
                openOfficialVideoInMiniPlayer(video: video)
            } else {
                PaywallService.shared.presentPaywallWithOrientation {
                    openOfficialVideoInMiniPlayer(video: video)
                }
            }
        }
    }

    private func openOfficialVideoInMiniPlayer(video: YouTubeChannelVideo) {
        let allVideos = officialChannelVideos.map { v in
            PlaylistVideo(
                id: v.videoId,
                youtubeURL: "https://www.youtube.com/watch?v=\(v.videoId)",
                title: v.title,
                artist: selectedArtist?.fields.title ?? "",
                year: v.publishedAt.count >= 4 ? String(v.publishedAt.prefix(4)) : ""
            )
        }

        guard let currentIndex = allVideos.firstIndex(where: { $0.id == video.videoId }) else { return }

        let categoryArtists = selectedCategory?.artists ?? []
        let artistName = selectedArtist?.fields.title ?? ""
        var allArtistVideos: [String: [PlaylistVideo]] = [:]
        allArtistVideos[artistName] = allVideos

        let playlistContext = PlaylistContext(
            videos: allVideos,
            currentIndex: currentIndex,
            sourceType: .live(artistName: artistName, categoryArtists: categoryArtists, allArtistVideos: allArtistVideos)
        )

        MiniPlayerManager.shared.openVJMode(
            video: allVideos[currentIndex],
            videos: allVideos,
            playlistContext: playlistContext
        )
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
