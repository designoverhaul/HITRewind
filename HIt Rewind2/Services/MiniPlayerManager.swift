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

    // MARK: - Persistent Player

    /// THE single coordinator – lives as long as the app
    let playerCoordinator = YouTubePlayerCoordinator()

    // MARK: - Playlist Context

    var playlistContext: PlaylistContext?

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

    var showPicker: Bool {
        !isConcertMode && !isEpicShowsMode
    }

    var availableYears: [Int] {
        DirectVideoService.shared.availableYears
    }

    var availableArtists: [String] {
        playlistContext?.liveArtists ?? []
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

        withAnimation(.easeInOut(duration: 0.3)) {
            state = .vjMode
        }

        // Lock to landscape
        OrientationManager.shared.lockToLandscapeRight()

        // Setup autoplay
        playerCoordinator.onVideoEnd = { [weak self] in
            self?.playNextVideo()
        }
    }

    /// Back button in VJ Mode → shrink to mini player
    func minimizeToMini() {
        print("🎬 MiniPlayerManager: minimizeToMini")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = .mini
        }
    }

    /// Tap mini player → expand back to VJ Mode
    func expandToVJMode() {
        print("🎬 MiniPlayerManager: expandToVJMode")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = .vjMode
        }
        OrientationManager.shared.lockToLandscapeRight()

        // Re-setup autoplay callback
        playerCoordinator.onVideoEnd = { [weak self] in
            self?.playNextVideo()
        }
    }

    /// Close the mini player entirely
    func close() {
        print("🎬 MiniPlayerManager: close")
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
            // displayedVideos already set from openVJMode (Live Library/Official/Charts)
            break

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
                }
            }
        } else if let context = playlistContext {
            displayedVideos = context.liveVideosForArtist(artist)
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
        }
    }

    private func parseArtistNames(from artistField: String) -> [String] {
        let separators = [" & ", " feat. ", " feat ", " featuring ", " and ", ", ", "/"]
        var names = [artistField]
        for separator in separators {
            names = names.flatMap { $0.components(separatedBy: separator) }
        }
        return names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
