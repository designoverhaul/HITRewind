//
//  SearchView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/27/25.
//

import SwiftUI
import SuperwallKit

struct SearchView: View {
    let initialSearchText: String?
    let autoSearch: Bool

    @StateObject private var searchService = SearchService.shared
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFieldFocused: Bool

    init(initialSearchText: String? = nil, autoSearch: Bool = false) {
        self.initialSearchText = initialSearchText
        self.autoSearch = autoSearch
    }

    // Fixed 3-column grid to match other pages (app is landscape-only)
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header row for all devices
                HStack {
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


                // Search Bar
                searchBar
                
                // Content
                if searchText.isEmpty {
                    emptySearchView
                } else if searchService.isLoading {
                    loadingView
                } else if let errorMessage = searchService.errorMessage {
                    errorView(message: errorMessage)
                } else if searchService.searchResults.isEmpty {
                    noResultsView
                } else {
                    searchResultsView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
        }
        .onChange(of: searchText) { _, newValue in
            // Cancel previous search task
            searchTask?.cancel()
            
            // Start new debounced search
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
                if !Task.isCancelled {
                    await MainActor.run {
                        searchService.searchContent(query: newValue)
                    }
                }
            }
        }
        .onAppear {
            if let initialText = initialSearchText {
                print("🔍 SearchView appeared with initial search text: '\(initialText)'")
                searchText = initialText
                if autoSearch {
                    print("🔍 Auto-search triggered for: '\(initialText)'")
                    // Add small delay to ensure UI is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        searchService.searchContent(query: initialText)
                    }
                }
            } else {
                print("🔍 SearchView appeared with no initial search text")
                // Auto-focus search field when view appears (with slight delay for smooth animation)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSearchFieldFocused = true
                }
            }

            // Listen for artist search notifications
            NotificationCenter.default.addObserver(forName: .searchArtist, object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let artistName = userInfo["artistName"] as? String {
                    print("🔍 Received artist search notification for: '\(artistName)'")
                    searchText = artistName
                    Task { @MainActor in
                        searchService.searchContent(query: artistName)
                    }
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .searchArtist, object: nil)
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.hitRewindSecondaryText)
                .frame(width: 20, height: 20)
            
            TextField("Search artists, songs, or years...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.body)
                .foregroundColor(.hitRewindPrimaryText)
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    searchService.searchContent(query: searchText)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isSearchFieldFocused = false
                        }
                        .foregroundColor(.hitRewindPurple)
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchService.searchContent(query: "")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.hitRewindSecondaryText)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.hitRewindCardBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Content Views
    
    private var emptySearchView: some View {
        Spacer()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.hitRewindPurple)

            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.hitRewindSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Search Error")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)

            Text(message)
                .font(.caption)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                searchService.searchContent(query: searchText)
            }
            .font(.subheadline)
            .foregroundColor(.hitRewindPurple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.hitRewindSecondaryText)

            Text("No Results Found")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)

            Text("No videos found for \"\(searchText)\"")
                .font(.caption)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(searchService.searchResults) { result in
                    Button(action: {
                        handleSearchResultTap(result: result)
                    }) {
                        SearchResultCard(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Helper Methods

    private func handleSearchResultTap(result: SearchResult) {
        print("🔍 Search result tapped: \(result.title) by \(result.artistName)")

        if PaywallService.shared.testSubscriberMode {
            print("🧪 Test subscriber mode enabled - playing video")
            openSearchResultInMiniPlayer(result: result)
            return
        }

        Task { @MainActor in
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()

            if isSubscribed {
                print("✅ User subscribed - playing video")
                openSearchResultInMiniPlayer(result: result)
            } else {
                print("🔒 User not subscribed - showing paywall")
                PaywallService.shared.presentPaywallWithOrientation {
                    print("✅ Purchase complete - playing video")
                    openSearchResultInMiniPlayer(result: result)
                }
            }
        }
    }

    private func openSearchResultInMiniPlayer(result: SearchResult) {
        let playlistVideos = searchService.searchResults.map { searchResult in
            PlaylistVideo(
                id: searchResult.videoId,
                youtubeURL: searchResult.url,
                title: searchResult.title,
                artist: searchResult.artistName,
                year: searchResult.year,
                rank: searchResult.rank
            )
        }

        guard let currentIndex = playlistVideos.firstIndex(where: { $0.id == result.videoId }) else { return }

        let initialVideo = playlistVideos[currentIndex]

        let sourceType: VideoSourceType
        if result.type == .top100Video {
            sourceType = .musicVideos
        } else {
            let liveResults = searchService.searchResults.filter { $0.type == .video }
            let artistNames = Array(Set(liveResults.map { $0.artistName })).sorted()
            var allArtistVideos: [String: [PlaylistVideo]] = [:]
            for liveResult in liveResults {
                let video = PlaylistVideo(
                    id: liveResult.videoId, youtubeURL: liveResult.url,
                    title: liveResult.title, artist: liveResult.artistName,
                    year: liveResult.year
                )
                allArtistVideos[liveResult.artistName, default: []].append(video)
            }
            sourceType = .live(
                artistName: result.artistName,
                categoryArtists: artistNames,
                allArtistVideos: allArtistVideos
            )
        }

        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex,
            sourceType: sourceType
        )

        MiniPlayerManager.shared.openVJMode(
            video: initialVideo,
            videos: playlistVideos,
            playlistContext: playlistContext
        )
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let result: SearchResult
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var youTubeService = YouTubeService()
    @State private var duration: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Video thumbnail
                AsyncImage(url: youtubeImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.hitRewindCardBackground.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    // Rank overlay for Billboard Top 100 videos
                    if let rank = result.rank {
                        Text("#\(rank)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.hitRewindPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    // Duration overlay
                    if let duration = duration {
                        Text(duration)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }

                // Favorite heart icon
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isFavorite ? .red : .white)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 32, height: 32)
                        )
                }
                .padding(8)
                .onTapGesture {
                    // Prevent tap from propagating to card
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.hitRewindPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(result.artistName)
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.hitRewindPurple)
                    .lineLimit(1)
            }
        }
        .task {
            await loadVideoDuration()
        }
    }
    
    private func loadVideoDuration() async {
        guard !result.videoId.isEmpty else { return }
        
        do {
            let videoInfo = try await youTubeService.getVideoInfo(videoId: result.videoId)
            await MainActor.run {
                if let contentDetails = videoInfo.contentDetails {
                    self.duration = youTubeService.formatDuration(contentDetails.duration)
                }
            }
        } catch {
            print("Failed to load duration for video \(result.videoId): \(error)")
        }
    }
    
    private var youtubeImageURL: URL? {
        if !result.videoId.isEmpty {
            // Use high quality thumbnail (480x360) which is more reliable than maxresdefault
            return URL(string: "https://img.youtube.com/vi/\(result.videoId)/hqdefault.jpg")
        }
        return nil
    }
    
    private var isFavorite: Bool {
        favoritesService.isFavorited(result.videoId)
    }
    
    private func toggleFavorite() {
        favoritesService.toggleFavorite(
            videoId: result.videoId,
            title: result.title,
            artist: result.artistName,
            year: result.year
        )
    }
}


// MARK: - Preview

#Preview {
    SearchView()
        .preferredColorScheme(.dark)
}