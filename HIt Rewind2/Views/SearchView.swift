//
//  SearchView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/27/25.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var searchService = SearchService.shared
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedResult: SearchResult?
    
    // Responsive grid columns
    private var gridColumns: [GridItem] {
        let screenWidth = UIScreen.main.bounds.width
        let minItemWidth: CGFloat = 150
        let spacing: CGFloat = 12
        let padding: CGFloat = 32 // Total horizontal padding
        
        let availableWidth = screenWidth - padding
        let columnsCount = max(1, Int(availableWidth / (minItemWidth + spacing)))
        
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnsCount)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                    }
                }
            }
        }
        .navigationDestination(item: $selectedResult) { result in
            SingleVideoView(
                videoId: result.videoId,
                videoTitle: result.title,
                artistName: result.artistName,
                year: result.year
            )
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
                .onSubmit {
                    searchService.searchContent(query: searchText)
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
        VStack(spacing: 24) {
            Text("Find your favorite artists, music videos, and live performances. Search by artist name, song title, or year.")
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 80)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.hitRewindPurple)
            
            Text("Searching...")
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
        }
        .padding(.top, 80)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Search Error")
                .font(.headline)
                .foregroundColor(.hitRewindPrimaryText)
            
            Text(message)
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Try Again") {
                searchService.searchContent(query: searchText)
            }
            .foregroundColor(.hitRewindPurple)
        }
        .padding(.top, 80)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.hitRewindSecondaryText)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)
            
            Text("No videos found for \"\(searchText)\". Try searching for different keywords or check your spelling.")
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 80)
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(searchService.searchResults) { result in
                    SearchResultCard(result: result)
                        .onTapGesture {
                            selectedResult = result
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
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
                        .aspectRatio(16/9, contentMode: .fill)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.hitRewindCardBackground.opacity(0.5))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay {
                            ProgressView()
                                .tint(.hitRewindPurple)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.hitRewindPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(result.artistName)
                    .font(.caption2)
                    .foregroundColor(.hitRewindSecondaryText)
                    .lineLimit(1)
                
                HStack {
                    Text(result.year)
                        .font(.caption2)
                        .foregroundColor(.hitRewindSecondaryText)
                    
                    Spacer()
                    
                    // Content type indicator
                    if result.type == .mtvVideo {
                        // Music Videos (MTV Videos table)
                        Image(systemName: "movieclapper")
                            .font(.caption2)
                            .foregroundColor(.hitRewindSecondaryText)
                    } else {
                        // Live Shows (Videos table)
                        Image(systemName: "ticket")
                            .font(.caption2)
                            .foregroundColor(.hitRewindSecondaryText)
                    }
                }
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