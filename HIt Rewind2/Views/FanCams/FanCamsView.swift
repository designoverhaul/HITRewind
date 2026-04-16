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
    @StateObject private var youtubeService = YouTubeService.shared

    @State private var selectedCategory: FanCamCategory?
    @State private var selectedArtist: Playlist?

    // Persist user's last selection so it's restored on next launch
    @AppStorage("fancams.lastCategoryName") private var lastCategoryName: String = ""
    @AppStorage("fancams.lastArtistName") private var lastArtistName: String = ""
    @State private var visibleVideoIndices: [Int] = []
    @State private var isLoadingVideos: Bool = false
    @State private var selectedTab: VideoSource = .liveLibrary
    @State private var officialChannelVideos: [YouTubeChannelVideo] = []
    @State private var isLoadingOfficialVideos: Bool = false
    @State private var chartVideos: [DirectVideoRecord] = []
    @State private var isLoadingChartVideos: Bool = false

    // 0 = channel avatar fully visible at full size, 1 = scrolled fully off-screen.
    // Drives the shrink in the channel header AND the grow in the artists row.
    @State private var channelHeaderScrollProgress: CGFloat = 0
    private let bigAvatarSize: CGFloat = 119
    private let listAvatarSize: CGFloat = 38

    private enum VideoSource {
        case liveLibrary
        case official
        case charts
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

            // Restore last category if it still exists, otherwise default to "Pop"
            let initialCategory = airtableService.categories.first(where: { $0.name == lastCategoryName })
                ?? airtableService.categories.first(where: { $0.name == "Pop" })

            if let category = initialCategory {
                selectedCategory = category
                await airtableService.fetchVideoCounts(for: category.artists)

                // Restore last artist if it's in this category, otherwise pick a random one
                let artistName = category.artists.first(where: {
                    $0.localizedCaseInsensitiveCompare(lastArtistName) == .orderedSame
                }) ?? category.artists.randomElement()

                if let name = artistName {
                    let placeholder = URL(string: "https://via.placeholder.com/300x200")!
                    let artist = Playlist(
                        id: name,
                        fields: PlaylistFields(
                            thumbnail: placeholder, year: 0, title: name,
                            videoUrls: [], artistNames: [], videoTitles: [], isVisible: []
                        )
                    )
                    handleArtistSelection(artist)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vjPickerArtistChanged)) { notification in
            guard let artistName = notification.userInfo?["artistName"] as? String else { return }
            print("📡 FanCamsView received vjPickerArtistChanged: \(artistName)")

            // Search current category first
            if let currentCategory = selectedCategory,
               currentCategory.artists.contains(where: { $0.localizedCaseInsensitiveCompare(artistName) == .orderedSame }) {
                let placeholder = URL(string: "https://via.placeholder.com/300x200")!
                let artist = Playlist(
                    id: artistName,
                    fields: PlaylistFields(
                        thumbnail: placeholder, year: 0, title: artistName,
                        videoUrls: [], artistNames: [], videoTitles: [], isVisible: []
                    )
                )
                handleArtistSelection(artist)
                return
            }

            // Search all categories
            for category in airtableService.categories {
                if category.artists.contains(where: { $0.localizedCaseInsensitiveCompare(artistName) == .orderedSame }) {
                    handleCategorySelection(category)
                    let placeholder = URL(string: "https://via.placeholder.com/300x200")!
                    let artist = Playlist(
                        id: artistName,
                        fields: PlaylistFields(
                            thumbnail: placeholder, year: 0, title: artistName,
                            videoUrls: [], artistNames: [], videoTitles: [], isVisible: []
                        )
                    )
                    handleArtistSelection(artist)
                    return
                }
            }
            print("⚠️ Artist '\(artistName)' not found in any category")
        }
    }

    // MARK: - iPad Layout
    private var iPadLayout: some View {
        contentView
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
            if verticalSizeClass == .regular {
                // Portrait: top half = categories + artists, bottom half = videos
                portraitLayout(geometry: geometry)
            } else {
                // Landscape: original 3-column side by side
                landscapeLayout(geometry: geometry)
            }
        }
    }

    // MARK: - Portrait Layout (Top/Bottom Split)
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top half: Categories + Artists side by side
            HStack(spacing: 0) {
                categoriesColumn
                    .frame(width: geometry.size.width * 0.4)
                    .background(Color.hitRewindBackground)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)

                artistsColumn
                    .frame(maxWidth: .infinity)
                    .background(Color.hitRewindBackground.opacity(0.7))
            }
            .frame(height: geometry.size.height * 0.3)

            // Divider between top and bottom
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            // Bottom half: Videos
            videosColumn
                .padding(.leading, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.hitRewindBackground.opacity(0.5))
        }
    }

    // MARK: - Landscape Layout (3 columns)
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            categoriesColumn
                .frame(width: geometry.size.width * 0.22)
                .background(Color.hitRewindBackground)

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)

            artistsColumn
                .frame(width: max(1, geometry.size.width * 0.23 - 1))
                .background(Color.hitRewindBackground.opacity(0.7))

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)

            videosColumn
                .padding(.leading, 6)
                .frame(maxWidth: .infinity)
                .background(Color.hitRewindBackground.opacity(0.5))
        }
        .ignoresSafeArea(.container, edges: .trailing)
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
                                HStack(spacing: 0) {
                                    // Avatar grows in next to the selected artist's name as
                                    // the channel-header avatar is scrolled off-screen.
                                    if isSelected,
                                       let iconUrl = selectedArtist?.fields.youtubeChannelIcon,
                                       let url = URL(string: iconUrl) {
                                        let size = listAvatarSize * channelHeaderScrollProgress
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Circle().fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: size, height: size)
                                        .clipShape(Circle())
                                        .padding(.trailing, size > 0 ? 6 : 0)
                                    }

                                    Text(artist.fields.title)
                                        .font(.system(size: 14))
                                        .fontWeight(isSelected ? .semibold : .regular)
                                        .foregroundColor(isSelected ? .hitRewindPurple : .hitRewindPrimaryText)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.leading, 8)
                                .padding(.trailing, 4)
                                .padding(.vertical, 6)
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
                    SpinningRecordView()
                    Text("Loading...")
                        .font(.system(size: 14))
                        .foregroundColor(.hitRewindSecondaryText)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if selectedArtist != nil {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        scrollableChannelHeader

                        Section(header: stickyVideoPicker) {
                            tabContent
                        }
                    }
                }
                .id(selectedArtist?.fields.title ?? "")
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newValue in
                    // Map scroll [0 ... avatar+padding] → progress [0 ... 1]
                    let triggerDistance = bigAvatarSize + 14
                    channelHeaderScrollProgress = max(0, min(1, newValue / triggerDistance))
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
            // Charts are preloaded during artist selection
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
                .frame(width: bigAvatarSize, height: bigAvatarSize)
                .clipShape(Circle())
                // Shrink from 1.0 → 0.2 in place (vertically centered)
                .scaleEffect(1.0 - 0.8 * channelHeaderScrollProgress)
            }

            Text(selectedArtist?.fields.title ?? "")
                .font(.custom(AppFont.ticketingName(), size: 20))
                .foregroundColor(.hitRewindPurple)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Video Source Picker
    private var availableTabs: [(label: String, tag: VideoSource)] {
        var tabs: [(label: String, tag: VideoSource)] = [("Live Library", .liveLibrary)]
        if selectedArtist?.fields.youtubeChannelId != nil {
            tabs.append(("New Releases", .official))
        }
        if !chartVideos.isEmpty {
            tabs.append(("Charts", .charts))
        }
        return tabs
    }

    // MARK: - Sticky Video Picker (pinned section header)
    private var stickyVideoPicker: some View {
        HStack(spacing: 6) {
            ForEach(availableTabs, id: \.tag) { tab in
                let isSelected = selectedTab == tab.tag
                Button(action: { selectedTab = tab.tag }) {
                    Text(tab.label)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .black : .hitRewindPrimaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.hitRewindPurple : Color.hitRewindSecondaryBackground)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Blur layer (blurs whatever videos pass underneath)
                Rectangle().fill(.ultraThinMaterial)
                // Black tint kills the bluish-gray Material cast — invisible
                // against the black background, dims videos when they're behind.
                Color.black.opacity(0.7)
            }
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.6),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: - Tab Content (switches content without rebuilding scroll view)
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .charts:
            chartsGridContent
        case .official:
            if selectedArtist?.fields.youtubeChannelId != nil {
                officialChannelGridContent
            } else {
                liveLibraryGridContent
            }
        case .liveLibrary:
            liveLibraryGridContent
        }
    }

    // MARK: - Scrollable Channel Header (avatar + name, scrolls normally)
    @ViewBuilder
    private var scrollableChannelHeader: some View {
        if let channelId = selectedArtist?.fields.youtubeChannelId, !channelId.isEmpty {
            channelHeader
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)
        }
    }

    // MARK: - Live Library Grid Content
    @ViewBuilder
    private var liveLibraryGridContent: some View {
        if !visibleVideos.isEmpty {
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
        } else {
            VStack {
                Spacer().frame(height: 40)
                Text("No videos")
                    .font(.system(size: 16))
                    .foregroundColor(.hitRewindSecondaryText)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Official Channel Grid Content
    @ViewBuilder
    private var officialChannelGridContent: some View {
        if isLoadingOfficialVideos {
            VStack {
                Spacer().frame(height: 40)
                SpinningRecordView()
                Text("Loading...")
                    .font(.system(size: 14))
                    .foregroundColor(.hitRewindSecondaryText)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        } else if officialChannelVideos.isEmpty {
            VStack(spacing: 8) {
                Spacer().frame(height: 40)
                Image(systemName: "video.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.hitRewindSecondaryText.opacity(0.5))
                Text("No videos found")
                    .font(.system(size: 16))
                    .foregroundColor(.hitRewindSecondaryText)
            }
            .frame(maxWidth: .infinity)
        } else {
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

            Spacer().frame(height: 16)
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
                year: video.year,
                duration: video.duration
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
        lastCategoryName = category.name
        selectedArtist = nil
        visibleVideoIndices = []
        selectedTab = .liveLibrary
        officialChannelVideos = []
        chartVideos = []

        Task {
            await airtableService.fetchVideoCounts(for: category.artists)
        }
    }

    private func handleArtistSelection(_ artist: Playlist) {
        print("👤 Artist selected: \(artist.fields.title)")
        AnalyticsService.logArtistViewed(artist: artist.fields.title)
        lastArtistName = artist.fields.title
        isLoadingVideos = true
        selectedTab = .liveLibrary
        officialChannelVideos = []
        chartVideos = []
        channelHeaderScrollProgress = 0

        Task {
            print("🔎 Loading videos for artist: \(artist.fields.title)")
            do {
                if let loaded = try await airtableService.fetchArtist(byName: artist.fields.title) {
                    await MainActor.run {
                        selectedArtist = loaded
                        updateVisibleVideoIndices()
                        isLoadingVideos = false
                        print("🎵 Loaded artist: \(loaded.fields.title) with \(visibleVideoIndices.count) videos, videoUrls: \(loaded.fields.videoUrls?.count ?? 0)")
                    }
                } else {
                    print("⚠️ fetchArtist returned nil for: \(artist.fields.title)")
                    await MainActor.run {
                        selectedArtist = artist
                        visibleVideoIndices = []
                        isLoadingVideos = false
                    }
                }
            } catch {
                print("❌ Error loading artist \(artist.fields.title): \(error)")
                await MainActor.run {
                    selectedArtist = artist
                    visibleVideoIndices = []
                    isLoadingVideos = false
                }
            }

            // Preload chart videos to determine if Charts tab should show
            await loadChartVideos()
        }
    }

    // MARK: - Official Channel Video Loading (from Airtable)
    @MainActor
    private func loadOfficialChannelVideos() async {
        guard let artistName = selectedArtist?.fields.title else { return }

        isLoadingOfficialVideos = true
        do {
            officialChannelVideos = try await AirtableService.shared.fetchOfficialVideos(artistName: artistName)
        } catch {
            print("❌ Error loading official videos from Airtable: \(error)")
            officialChannelVideos = []
        }
        isLoadingOfficialVideos = false
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
                year: v.publishedAt.count >= 4 ? String(v.publishedAt.prefix(4)) : "",
                duration: v.duration.isEmpty ? nil : v.duration
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

    // MARK: - Charts Tab

    @MainActor
    private func loadChartVideos() async {
        guard let artistName = selectedArtist?.fields.title else { return }
        isLoadingChartVideos = true

        // Ensure DirectVideoService has data loaded
        if DirectVideoService.shared.videos.isEmpty {
            await DirectVideoService.shared.fetchVideos()
        }

        let allVideos = DirectVideoService.shared.videos
        var addedVideoIds = Set<String>()
        var matched: [DirectVideoRecord] = []

        for record in allVideos {
            guard let recordArtist = record.fields.artistName,
                  let _ = record.fields.url,
                  let videoId = record.fields.youtubeVideoId,
                  record.fields.rank != nil,
                  record.fields.yearInt != nil else { continue }

            let parsedNames = parseArtistNames(from: recordArtist)
            let normalizedArtistName = normalizeForComparison(artistName).lowercased().trimmingCharacters(in: .whitespaces)
            let strippedArtistName = stripPunctuation(normalizedArtistName)
            let matches = parsedNames.contains { name in
                let normalized = normalizeForComparison(name).lowercased().trimmingCharacters(in: .whitespaces)
                // Exact match first, then try with punctuation stripped (R.E.M. ↔ REM)
                return normalized == normalizedArtistName || stripPunctuation(normalized) == strippedArtistName
            }

            if matches && !addedVideoIds.contains(videoId) {
                addedVideoIds.insert(videoId)
                matched.append(record)
            }
        }

        chartVideos = matched
        isLoadingChartVideos = false
    }

    private func parseArtistNames(from artistField: String) -> [String] {
        let separators = [" & ", " feat. ", " feat ", " featuring ", " and ", ", ", " / "]
        var names = [artistField]
        for separator in separators {
            names = names.flatMap { $0.components(separatedBy: separator) }
        }
        return names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Normalize quotes/apostrophes for reliable string matching
    private func normalizeForComparison(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2019}", with: "'")  // ' → '
            .replacingOccurrences(of: "\u{2018}", with: "'")  // ' → '
            .replacingOccurrences(of: "\u{201C}", with: "\"") // " → "
            .replacingOccurrences(of: "\u{201D}", with: "\"") // " → "
    }

    /// Strip punctuation for fuzzy artist name matching (R.E.M. → REM, AC/DC → ACDC)
    private func stripPunctuation(_ text: String) -> String {
        text.replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " + ", with: " and ")
            .trimmingCharacters(in: .whitespaces)
    }

    private var chartVideosByYear: [(year: Int, videos: [DirectVideoRecord])] {
        let grouped = Dictionary(grouping: chartVideos) { $0.fields.yearInt ?? 0 }
        return grouped.sorted { $0.key > $1.key }.map { (year: $0.key, videos: $0.value.sorted { ($0.fields.rank ?? 999) < ($1.fields.rank ?? 999) }) }
    }

    // MARK: - Charts Grid Content
    @ViewBuilder
    private var chartsGridContent: some View {
        if isLoadingChartVideos {
            VStack {
                Spacer().frame(height: 40)
                SpinningRecordView()
                Text("Loading...")
                    .font(.system(size: 14))
                    .foregroundColor(.hitRewindSecondaryText)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        } else if chartVideos.isEmpty {
            VStack(spacing: 8) {
                Spacer().frame(height: 40)
                Image(systemName: "chart.bar")
                    .font(.system(size: 36))
                    .foregroundColor(.hitRewindSecondaryText.opacity(0.5))
                Text("No chart hits found")
                    .font(.system(size: 16))
                    .foregroundColor(.hitRewindSecondaryText)
            }
            .frame(maxWidth: .infinity)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(chartVideosByYear, id: \.year) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(group.year))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.hitRewindPrimaryText)
                            .padding(.horizontal, 8)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 8)

                        LazyVGrid(columns: videoGridColumns, spacing: 12) {
                            ForEach(group.videos) { record in
                                if let videoId = record.fields.youtubeVideoId {
                                    Button(action: {
                                        handleChartVideoTap(record: record)
                                    }) {
                                        VideoThumbnailView(
                                            videoId: videoId,
                                            title: record.fields.title ?? "Unknown",
                                            artist: record.fields.artistName ?? "",
                                            year: record.fields.year ?? "",
                                            onTap: {},
                                            hideArtistAndYear: true,
                                            rank: record.fields.rank,
                                            hideDuration: true
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    private func handleChartVideoTap(record: DirectVideoRecord) {
        guard let videoId = record.fields.youtubeVideoId,
              let url = record.fields.url else { return }

        print("🎥 Chart video \(videoId) tapped")

        let playAction = {
            let allPlaylistVideos = self.chartVideos
                .sorted { a, b in
                    let yearA = a.fields.yearInt ?? 0
                    let yearB = b.fields.yearInt ?? 0
                    if yearA != yearB { return yearA > yearB }
                    return (a.fields.rank ?? 999) < (b.fields.rank ?? 999)
                }
                .compactMap { rec -> PlaylistVideo? in
                    guard let vid = rec.fields.youtubeVideoId,
                          let vidUrl = rec.fields.url else { return nil }
                    return PlaylistVideo(
                        id: vid,
                        youtubeURL: vidUrl,
                        title: rec.fields.title ?? "Unknown",
                        artist: rec.fields.artistName ?? "",
                        year: rec.fields.year ?? "",
                        rank: rec.fields.rank
                    )
                }

            guard let currentIndex = allPlaylistVideos.firstIndex(where: { $0.id == videoId }) else { return }

            let artistName = self.selectedArtist?.fields.title ?? ""
            let categoryArtists = self.selectedCategory?.artists ?? []
            var allArtistVideos: [String: [PlaylistVideo]] = [:]
            allArtistVideos[artistName] = allPlaylistVideos

            let playlistContext = PlaylistContext(
                videos: allPlaylistVideos,
                currentIndex: currentIndex,
                sourceType: .live(artistName: artistName, categoryArtists: categoryArtists, allArtistVideos: allArtistVideos)
            )

            MiniPlayerManager.shared.openVJMode(
                video: allPlaylistVideos[currentIndex],
                videos: allPlaylistVideos,
                playlistContext: playlistContext
            )
        }

        if PaywallService.shared.testSubscriberMode {
            playAction()
            return
        }

        Task { @MainActor in
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()
            if isSubscribed {
                playAction()
            } else {
                PaywallService.shared.presentPaywallWithOrientation {
                    playAction()
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
    let duration: String?
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
                let videoDuration = artist.fields.videoDurations?[safe: index]
                result.append(VisibleVideo(id: videoId, originalURL: url, title: title, artist: artistName, year: videoYear, duration: videoDuration))
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
