//
//  MiniPlayerManager.swift
//  HIt Rewind2
//
//  Manages the persistent mini player state across the app.
//  The single YouTubePlayerCoordinator lives here so the player
//  never gets recreated when transitioning between VJ mode and mini mode.
//

import SwiftUI
import Combine

/// Possible states for the persistent player overlay
enum PlayerOverlayState: Equatable {
    case hidden
    case vjMode
    case mini
    case portrait
}

/// Video source tabs for Artists/Live mode (Live Library / New Releases / Charts)
enum LiveVideoSource: String, CaseIterable {
    case liveLibrary = "Live Library"
    case official = "New Releases"
    case charts = "Charts"
}

/// Singleton that owns the persistent player and its state
@MainActor
final class MiniPlayerManager: ObservableObject {
    static let shared = MiniPlayerManager()

    // MARK: - Published State

    @Published var state: PlayerOverlayState = .hidden
    @Published var currentVideo: PlaylistVideo?
    @Published var displayedVideos: [PlaylistVideo] = []

    // VJ Mode UI state (kept here so it survives mini→VJ transitions)
    @Published var selectedYear: Int?
    @Published var selectedArtist: String?
    @Published var controlsVisible: Bool = true
    @Published var isFavorited: Bool = false
    @Published var isPortraitFullscreen: Bool = false

    // Artists/Live mode: tab state + genre categories
    @Published var selectedLiveTab: LiveVideoSource = .liveLibrary
    @Published var liveLibraryVideos: [PlaylistVideo] = []  // cached live library videos
    @Published var officialVideos: [PlaylistVideo] = []
    @Published var chartVideos: [PlaylistVideo] = []
    @Published var isLoadingOfficialVideos: Bool = false
    @Published var isLoadingChartVideos: Bool = false
    @Published var hasOfficialVideos: Bool = false  // whether artist has youtubeChannelId
    @Published var categories: [FanCamCategory] = []
    @Published var selectedCategoryName: String?

    // MARK: - Persistent Player

    /// THE single coordinator – lives as long as the app
    let playerCoordinator = YouTubePlayerCoordinator()

    // MARK: - Playlist Context

    @Published var playlistContext: PlaylistContext?

    // MARK: - Callbacks

    var onClose: (() -> Void)?

    // Forward coordinator's objectWillChange so PlayerOverlay re-renders
    // when currentTime/duration change
    private var coordinatorCancellable: AnyCancellable?

    // MARK: - Init

    private init() {
        coordinatorCancellable = playerCoordinator.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Source Type Helpers

    var sourceType: VideoSourceType {
        playlistContext?.sourceType ?? .musicVideos
    }

    var isMusicVideosMode: Bool {
        if case .musicVideos = sourceType { return true }
        return false
    }

    var isLiveMode: Bool {
        if case .live = sourceType { return true }
        return false
    }

    var isConcertMode: Bool {
        if case .concert = sourceType { return true }
        return false
    }

    var isEpicShowsMode: Bool {
        if case .epicShows = sourceType { return true }
        return false
    }

    var concertBannerImageURL: String? {
        if case .concert(let url) = sourceType { return url }
        return nil
    }

    var showPicker: Bool {
        !isConcertMode && !isEpicShowsMode
    }

    var availableYears: [Int] {
        DirectVideoService.shared.availableYears
    }

    var availableArtists: [String] {
        (playlistContext?.liveArtists ?? []).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Public Methods

    /// Called by tab views when a video is tapped (after paywall check)
    func openVJMode(video: PlaylistVideo, videos: [PlaylistVideo], playlistContext: PlaylistContext?) {
        print("🎬 MiniPlayerManager: openVJMode - \(video.title)")
        let sourceName: String
        switch playlistContext?.sourceType {
        case .musicVideos: sourceName = "Top 100"
        case .live: sourceName = "Artists"
        case .concert: sourceName = "Concert"
        case .epicShows: sourceName = "Collections"
        case .none: sourceName = "Unknown"
        }
        AnalyticsService.logVideoPlayed(title: video.title, artist: video.artist, year: video.year, source: sourceName)
        AnalyticsService.logVJModeOpened(source: sourceName)
        self.playlistContext = playlistContext
        self.displayedVideos = videos
        self.controlsVisible = true

        // If switching to a different video, load it
        if currentVideo?.id != video.id {
            currentVideo = video
            playerCoordinator.resetPreservedPosition()
            isFavorited = FavoritesService.shared.isFavorited(video.id)
        }

        // Setup source-specific state
        setupDisplayedVideos()

        // Check current orientation to pick the right layout
        let isLandscape: Bool = {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return windowScene.interfaceOrientation.isLandscape
            }
            return false
        }()

        withAnimation(.easeInOut(duration: 0.3)) {
            state = isLandscape ? .vjMode : .portrait
        }

        // Setup autoplay
        playerCoordinator.onVideoEnd = { [weak self] in
            self?.playNextVideo()
        }
    }

    /// Back button in VJ Mode → shrink to mini player
    func minimizeToMini() {
        print("🎬 MiniPlayerManager: minimizeToMini")
        isPortraitFullscreen = false
        OrientationManager.shared.exitVJMode()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = .mini
        }
    }

    /// Tap mini player → expand back to portrait mode
    func expandToPortrait() {
        print("🎬 MiniPlayerManager: expandToPortrait")
        controlsVisible = true
        isPortraitFullscreen = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = .portrait
        }
        playerCoordinator.onVideoEnd = { [weak self] in
            self?.playNextVideo()
        }
    }

    /// VJ Mode → portrait mode (when device rotates to portrait)
    func minimizeToPortrait() {
        print("🎬 MiniPlayerManager: minimizeToPortrait")
        OrientationManager.shared.exitVJMode()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = .portrait
        }
    }

    /// Switch to VJ layout without locking orientation (for auto-rotation)
    func switchToVJLayout() {
        print("🎬 MiniPlayerManager: switchToVJLayout (no orientation lock)")
        isPortraitFullscreen = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = .vjMode
        }
        playerCoordinator.onVideoEnd = { [weak self] in
            self?.playNextVideo()
        }
    }

    /// Expand to full VJ Mode (landscape) — locks orientation
    func expandToVJMode() {
        print("🎬 MiniPlayerManager: expandToVJMode")
        isPortraitFullscreen = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = .vjMode
        }
        OrientationManager.shared.enterVJMode()

        // Re-setup autoplay callback
        playerCoordinator.onVideoEnd = { [weak self] in
            self?.playNextVideo()
        }
    }

    /// Close the mini player entirely
    func close() {
        print("🎬 MiniPlayerManager: close")
        OrientationManager.shared.exitVJMode()
        AnalyticsService.logVJModeClosed()
        playerCoordinator.stopVideo()
        playerCoordinator.onVideoEnd = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            state = .hidden
        }
        currentVideo = nil
        displayedVideos = []
        playlistContext = nil
        selectedYear = nil
        selectedArtist = nil
        selectedLiveTab = .liveLibrary
        liveLibraryVideos = []
        officialVideos = []
        chartVideos = []
        hasOfficialVideos = false
        selectedCategoryName = nil
    }

    /// Switch to a different video within the current session
    func playVideo(_ video: PlaylistVideo) {
        print("🎬 MiniPlayerManager: playVideo - \(video.title)")
        withAnimation(.easeInOut(duration: 0.2)) {
            currentVideo = video
        }
        isFavorited = FavoritesService.shared.isFavorited(video.id)
        playerCoordinator.resetPreservedPosition()
    }

    /// Autoplay next video in the displayed list
    func playNextVideo() {
        print("🎬 MiniPlayerManager: playNextVideo")
        guard let current = currentVideo,
              let currentIndex = displayedVideos.firstIndex(where: { $0.id == current.id }) else {
            if let first = displayedVideos.first {
                playVideo(first)
            }
            return
        }

        if currentIndex + 1 < displayedVideos.count {
            playVideo(displayedVideos[currentIndex + 1])
        } else if let first = displayedVideos.first {
            // Loop back to first
            playVideo(first)
        }
    }

    /// Toggle favorite for current video
    func toggleFavorite() {
        guard let video = currentVideo else { return }
        if AuthenticationService.shared.isAuthenticated {
            let willBeFavorited = !isFavorited
            FavoritesService.shared.toggleFavorite(
                videoId: video.id,
                title: video.title,
                artist: video.artist,
                year: video.year
            )
            isFavorited.toggle()
            AnalyticsService.logFavoriteToggled(title: video.title, artist: video.artist, isFavorited: willBeFavorited)
        } else {
            NotificationCenter.default.post(name: .showSignInSheet, object: nil)
        }
    }

    // MARK: - Video List Management

    func setupDisplayedVideos() {
        switch sourceType {
        case .musicVideos:
            let yearInt = Int(currentVideo?.year ?? "") ?? availableYears.first ?? 2000
            selectedYear = yearInt
            fetchVideosForYear(yearInt)

        case .live(let artistName, _, _):
            selectedArtist = artistName
            // displayedVideos already set from openVJMode
            setupLiveModeTabs()

        case .concert:
            // displayedVideos already set from openVJMode
            break

        case .epicShows:
            // displayedVideos already set from openVJMode
            break
        }
    }

    func fetchVideosForYear(_ year: Int, fromPicker: Bool = false) {
        if fromPicker {
            NotificationCenter.default.post(name: .vjPickerYearChanged, object: nil, userInfo: ["year": year])
        }
        let directVideos = DirectVideoService.shared.videos(forYear: year)

        if directVideos.isEmpty {
            Task { @MainActor in
                await DirectVideoService.shared.fetchVideos()
                let reloadedVideos = DirectVideoService.shared.videos(forYear: year)
                self.displayedVideos = reloadedVideos.compactMap { record -> PlaylistVideo? in
                    guard let url = record.fields.url,
                          let videoId = record.fields.youtubeVideoId,
                          let title = record.fields.title else { return nil }
                    return PlaylistVideo(
                        id: videoId, youtubeURL: url, title: title,
                        artist: record.fields.artistName ?? "Unknown Artist",
                        year: String(year), rank: record.fields.rank
                    )
                }
            }
            return
        }

        displayedVideos = directVideos.compactMap { record -> PlaylistVideo? in
            guard let url = record.fields.url,
                  let videoId = record.fields.youtubeVideoId,
                  let title = record.fields.title else { return nil }
            return PlaylistVideo(
                id: videoId, youtubeURL: url, title: title,
                artist: record.fields.artistName ?? "Unknown Artist",
                year: String(year), rank: record.fields.rank
            )
        }
    }

    func fetchVideosForArtist(_ artist: String, fromPicker: Bool = false) {
        if fromPicker {
            NotificationCenter.default.post(name: .vjPickerArtistChanged, object: nil, userInfo: ["artistName": artist])
        }
        if isLiveMode {
            Task { @MainActor in
                let airtableService = AirtableService.shared
                if let loadedArtist = try? await airtableService.fetchArtist(byName: artist) {
                    var artistVideos: [PlaylistVideo] = []
                    let videoUrls = loadedArtist.fields.videoUrls ?? []
                    let videoTitles = loadedArtist.fields.videoTitles ?? []
                    let artistNames = loadedArtist.fields.artistNames ?? []
                    let videoYears = loadedArtist.fields.videoYears ?? []
                    let isVisible = loadedArtist.fields.isVisible

                    for index in 0..<videoUrls.count {
                        let visible = isVisible.isEmpty || (isVisible[safe: index].flatMap { $0 } ?? true)
                        guard visible else { continue }
                        let url = videoUrls[index]
                        guard let videoId = extractYouTubeVideoID(from: url) else { continue }
                        let title = videoTitles[safe: index] ?? "Unknown Title"
                        let artistName = artistNames[safe: index] ?? artist
                        let year = videoYears[safe: index] ?? String(loadedArtist.fields.year)
                        artistVideos.append(PlaylistVideo(
                            id: videoId, youtubeURL: url, title: title,
                            artist: artistName, year: year
                        ))
                    }

                    artistVideos.sort {
                        if let y1 = Int($0.year), let y2 = Int($1.year) { return y1 > y2 }
                        return $0.year > $1.year
                    }

                    self.displayedVideos = artistVideos
                    self.refreshLiveTabsForArtist(artist, liveVideos: artistVideos)
                }
            }
        } else if let context = playlistContext {
            let videos = context.liveVideosForArtist(artist)
            displayedVideos = videos
            refreshLiveTabsForArtist(artist, liveVideos: videos)
        }
    }

    /// Load all videos by the current artist from DirectVideoService
    func loadArtistVideos() {
        guard let artistName = currentVideo?.artist else { return }

        if DirectVideoService.shared.videos.isEmpty {
            Task { @MainActor in
                await DirectVideoService.shared.fetchVideos()
                self.performArtistSearch(for: artistName)
            }
        } else {
            performArtistSearch(for: artistName)
        }
    }

    private func performArtistSearch(for artistName: String) {
        var artistVideos: [PlaylistVideo] = []
        var addedVideoIds = Set<String>()

        let artistNames = parseArtistNames(from: artistName)
        let allVideos = DirectVideoService.shared.videos

        for record in allVideos {
            guard let recordArtist = record.fields.artistName,
                  let url = record.fields.url,
                  let videoId = record.fields.youtubeVideoId,
                  let title = record.fields.title else { continue }

            let matchesAnyArtist = artistNames.contains { targetArtist in
                recordArtist.localizedCaseInsensitiveContains(targetArtist)
            }

            if matchesAnyArtist && !addedVideoIds.contains(videoId) {
                addedVideoIds.insert(videoId)
                artistVideos.append(PlaylistVideo(
                    id: videoId, youtubeURL: url, title: title,
                    artist: recordArtist,
                    year: String(record.fields.yearInt ?? 0),
                    rank: record.fields.rank
                ))
            }
        }

        artistVideos.sort { $0.year > $1.year }

        if !artistVideos.isEmpty {
            displayedVideos = artistVideos
            refreshLiveTabsForArtist(artistName, liveVideos: artistVideos)
        }
    }

    /// Reset and reload all tab data when the artist changes
    private func refreshLiveTabsForArtist(_ artistName: String, liveVideos: [PlaylistVideo]) {
        selectedArtist = artistName
        selectedLiveTab = .liveLibrary
        liveLibraryVideos = liveVideos
        officialVideos = []
        chartVideos = []
        hasOfficialVideos = false

        // Check for official videos
        Task { @MainActor in
            if let artist = try? await AirtableService.shared.fetchArtist(byName: artistName) {
                self.hasOfficialVideos = artist.fields.youtubeChannelId != nil && !(artist.fields.youtubeChannelId?.isEmpty ?? true)
            }
        }

        // Preload chart videos
        loadChartVideosForCurrentArtist()
    }

    private func parseArtistNames(from artistField: String) -> [String] {
        let separators = [" & ", " feat. ", " feat ", " featuring ", " and ", ", ", "/"]
        var names = [artistField]
        for separator in separators {
            names = names.flatMap { $0.components(separatedBy: separator) }
        }
        return names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // MARK: - Live Mode Tab Management

    /// Called when opening from Artists page — load categories and preload chart data
    func setupLiveModeTabs() {
        guard isLiveMode else { return }
        selectedLiveTab = .liveLibrary
        liveLibraryVideos = displayedVideos  // cache current live library videos

        // Load categories if needed
        if categories.isEmpty {
            Task { @MainActor in
                await AirtableService.shared.fetchCategories()
                self.categories = AirtableService.shared.categories
                self.selectCategoryForCurrentArtist()
            }
        } else {
            selectCategoryForCurrentArtist()
        }

        // Check if artist has official videos (youtubeChannelId)
        if let artistName = selectedArtist {
            Task { @MainActor in
                if let artist = try? await AirtableService.shared.fetchArtist(byName: artistName) {
                    self.hasOfficialVideos = artist.fields.youtubeChannelId != nil && !(artist.fields.youtubeChannelId?.isEmpty ?? true)
                }
            }
        }

        // Preload chart videos
        loadChartVideosForCurrentArtist()
    }

    /// Find which category the current artist belongs to and select it
    private func selectCategoryForCurrentArtist() {
        guard let artistName = selectedArtist else { return }
        for cat in categories {
            if cat.containsArtist(artistName) {
                selectedCategoryName = cat.name
                return
            }
        }
    }

    /// Switch the live tab and update displayedVideos accordingly
    func switchLiveTab(_ tab: LiveVideoSource) {
        selectedLiveTab = tab
        switch tab {
        case .liveLibrary:
            displayedVideos = liveLibraryVideos
        case .official:
            if officialVideos.isEmpty && !isLoadingOfficialVideos {
                loadOfficialVideosForCurrentArtist()
            } else {
                displayedVideos = officialVideos
            }
        case .charts:
            displayedVideos = chartVideos
        }
    }

    /// Load official/new release videos from Airtable
    private func loadOfficialVideosForCurrentArtist() {
        guard let artistName = selectedArtist else { return }
        isLoadingOfficialVideos = true
        Task { @MainActor in
            do {
                let videos = try await AirtableService.shared.fetchOfficialVideos(artistName: artistName)
                self.officialVideos = videos.map { v in
                    PlaylistVideo(
                        id: v.videoId,
                        youtubeURL: "https://www.youtube.com/watch?v=\(v.videoId)",
                        title: v.title,
                        artist: artistName,
                        year: v.publishedAt,  // full ISO date for relative formatting
                        duration: v.duration.isEmpty ? nil : v.duration
                    )
                }
                self.isLoadingOfficialVideos = false
                if self.selectedLiveTab == .official {
                    self.displayedVideos = self.officialVideos
                }
            } catch {
                print("❌ MiniPlayerManager: Error loading official videos: \(error)")
                self.officialVideos = []
                self.isLoadingOfficialVideos = false
            }
        }
    }

    /// Load chart videos (from DirectVideoService/MTvVideosNEW) for current artist
    private func loadChartVideosForCurrentArtist() {
        guard let artistName = selectedArtist else { return }
        isLoadingChartVideos = true
        Task { @MainActor in
            if DirectVideoService.shared.videos.isEmpty {
                await DirectVideoService.shared.fetchVideos()
            }

            let allVideos = DirectVideoService.shared.videos
            var addedVideoIds = Set<String>()
            var matched: [PlaylistVideo] = []

            for record in allVideos {
                guard let recordArtist = record.fields.artistName,
                      let url = record.fields.url,
                      let videoId = record.fields.youtubeVideoId,
                      let title = record.fields.title,
                      record.fields.rank != nil else { continue }

                let parsedNames = self.parseArtistNames(from: recordArtist)
                let matches = parsedNames.contains { name in
                    name.localizedCaseInsensitiveContains(artistName)
                }

                if matches && !addedVideoIds.contains(videoId) {
                    addedVideoIds.insert(videoId)
                    matched.append(PlaylistVideo(
                        id: videoId, youtubeURL: url, title: title,
                        artist: recordArtist,
                        year: String(record.fields.yearInt ?? 0),
                        rank: record.fields.rank
                    ))
                }
            }

            // Sort by year desc, then rank asc
            matched.sort {
                let y1 = Int($0.year) ?? 0
                let y2 = Int($1.year) ?? 0
                if y1 != y2 { return y1 > y2 }
                return ($0.rank ?? 999) < ($1.rank ?? 999)
            }

            self.chartVideos = matched
            self.isLoadingChartVideos = false

            if self.selectedLiveTab == .charts {
                self.displayedVideos = self.chartVideos
            }
        }
    }

    /// Handle genre category change from portrait mode
    func handleCategoryChange(_ category: FanCamCategory) {
        selectedCategoryName = category.name

        // Update the playlist context with the new category's artists
        let newArtists = category.artists.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if case .live(_, _, let allArtistVideos) = sourceType {
            let firstArtist = newArtists.first ?? ""
            playlistContext = PlaylistContext(
                videos: playlistContext?.videos ?? [],
                currentIndex: 0,
                sourceType: .live(artistName: firstArtist, categoryArtists: newArtists, allArtistVideos: allArtistVideos)
            )

            // Auto-select first artist and load their videos
            if !firstArtist.isEmpty {
                selectedArtist = firstArtist
                fetchVideosForArtist(firstArtist, fromPicker: true)
            }
        }
    }
}
