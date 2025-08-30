//
//  FanCamsView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI

struct FanCamsView: View {
    @StateObject private var airtableService = AirtableService()
    @StateObject private var youtubeService = YouTubeService()
    
    @State private var selectedCategory: FanCamCategory?
    @State private var selectedArtist: Playlist?
    @State private var visibleVideoIndices: [Int] = []
    @State private var showCategorySidebar = false
    @State private var currentMode: FanCamMode = .categories
    
    // Device and orientation detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    enum FanCamMode {
        case categories
        case artist
    }
    
    var body: some View {
        NavigationView {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad layout with permanent sidebar
                iPadLayout
            } else {
                // iPhone layout with sliding sidebar
                iPhoneLayout
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await airtableService.fetchCategories() // Lazy: no full artist fetch here
        }
    }
    
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        NavigationSplitView {
            if currentMode == .categories {
                CategorySidebarView(
                    categories: availableCategories,
                    selectedCategory: $selectedCategory,
                    onCategorySelected: handleCategorySelection
                )
                .navigationTitle("Genre")
            } else {
                ArtistSidebarView(
                    artists: artistsInCategory,
                    selectedArtist: $selectedArtist,
                    onArtistSelected: handleArtistSelection,
                    onBackToCategories: {
                        currentMode = .categories
                        selectedCategory = nil
                        selectedArtist = nil
                    }
                )
                .navigationTitle(selectedCategory?.name ?? "Artists")
            }
        } detail: {
            contentView
                .navigationTitle(navigationTitleString)
                .navigationBarTitleDisplayMode(.large)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
    }
    
    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        ZStack(alignment: .leading) {
            contentView
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            // Swipe right (positive translation) to go back
                            if value.translation.width > 100 && abs(value.translation.height) < 50 {
                                withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
                                    handleSwipeBack()
                                }
                            }
                        }
                )
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 8) {
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 28)
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Group {
                            if currentMode == .artist && selectedArtist != nil {
                                // Video feed by artist → "Artist" back button (back to artist list)
                                Button("Artist") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedArtist = nil
                                        visibleVideoIndices = []
                                    }
                                }
                                .foregroundColor(.hitRewindPurple)
                            } else if currentMode == .artist && selectedArtist == nil {
                                // List of artists → "Genre" back button (back to categories)
                                Button("Genre") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentMode = .categories
                                        selectedCategory = nil
                                    }
                                }
                                .foregroundColor(.hitRewindPurple)
                            }
                            // Removed Genre button for top-level categories screen
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            NavigationLink(destination: SearchView()) {
                                Text("🔍")
                            }
                            NavigationLink(destination: SettingsView()) {
                                Text("⚙️")
                            }
                        }
                    }
                }
                .background(
                    NavigationConfigurator { nc in
                        nc.hidesBarsOnSwipe = true
                    }
                )
            
            // Sliding sidebar for iPhone
            if showCategorySidebar {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCategorySidebar = false
                        }
                    }
                
                if currentMode == .categories {
                    CategorySidebarView(
                        categories: availableCategories,
                        selectedCategory: $selectedCategory,
                        onCategorySelected: { category in
                            handleCategorySelection(category)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCategorySidebar = false
                            }
                        }
                    )
                    .frame(width: UIScreen.main.bounds.width)
                    .background(Color.hitRewindBackground)
                    .transition(.move(edge: .leading))
                } else {
                    ArtistSidebarView(
                        artists: artistsInCategory,
                        selectedArtist: $selectedArtist,
                        onArtistSelected: { artist in
                            handleArtistSelection(artist)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCategorySidebar = false
                            }
                        },
                        onBackToCategories: {
                            currentMode = .categories
                            selectedCategory = nil
                            selectedArtist = nil
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCategorySidebar = false
                            }
                        }
                    )
                    .frame(width: UIScreen.main.bounds.width)
                    .background(Color.hitRewindBackground)
                    .transition(.move(edge: .leading))
                }
            }
        }
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
            } else if currentMode == .categories {
                categoryGridView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if currentMode == .artist && selectedArtist == nil {
                artistListView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else if selectedArtist != nil && !visibleVideoIndices.isEmpty {
                fanCamVideosGrid
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                ContentUnavailableView(
                    "No Fan Cams Available",
                    systemImage: "person.2.crop.square.stack",
                    description: Text("Select an artist to view fan cam videos")
                )
            }
        }
        .animation(.easeInOut(duration: 0.5), value: currentMode)
        .animation(.easeInOut(duration: 0.5), value: selectedArtist?.id)
    }
    
    // MARK: - Category Grid View
    private var categoryGridView: some View {
        ScrollView {
            LazyVGrid(columns: categoryGridColumns, spacing: gridSpacing) {
                ForEach(availableCategories) { category in
                    CategoryBannerView(category: category) {
                        handleCategorySelection(category)
                    }
                }
            }
            .padding(gridPadding)
        }
    }
    
    // MARK: - Fan Cam Videos Grid
    private var fanCamVideosGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(selectedArtist?.fields.title ?? "Fan Cam Videos")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.hitRewindPrimaryText)
                    .padding(.horizontal, gridPadding)
            }
            .padding(.top, gridPadding)
            
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(visibleVideos) { item in
                    NavigationLink(destination: SingleVideoView(
                        videoId: item.id,
                        videoTitle: item.title,
                        artistName: item.artist,
                        year: item.year
                    )) {
                        VideoThumbnailView(
                            videoId: item.id,
                            title: item.title,
                            artist: item.artist,
                            year: item.year,
                            onTap: {},
                            hideArtistAndYear: true
                        )
                    }
                }
            }
            .id(selectedArtist?.id)
            .padding(gridPadding)
        }
    }

    // MARK: - Artist List View (after selecting a category)
    private var artistListView: some View {
        List(artistsInCategory) { artist in
            Button(action: {
                handleArtistSelection(artist)
            }) {
                HStack {
                    Text(artist.fields.title)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(airtableService.artistVideoCounts[artist.fields.title] ?? 0)")
                        .foregroundColor(.secondary)
                }
            }
            .listRowBackground(Color.hitRewindBackground)
        }
        .listStyle(.plain)
        .background(Color.hitRewindBackground)
    }
    
    // MARK: - Computed Properties
    private var availableCategories: [FanCamCategory] {
        return airtableService.categories
    }
    
    private var artistsInCategory: [Playlist] {
        guard let selectedCategory = selectedCategory else { return [] }
        // Build lightweight artist list purely from category names; no videos loaded yet
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
    
    private var gridColumns: [GridItem] {
        let count = columnCount
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: count)
    }
    
    private var categoryGridColumns: [GridItem] {
        let count = categoryColumnCount
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: count)
    }
    
    private var columnCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return horizontalSizeClass == .regular ? 4 : 3
        } else {
            return verticalSizeClass == .regular ? 1 : 2
        }
    }
    
    private var categoryColumnCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return horizontalSizeClass == .regular ? 3 : 2
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
    
    private var navigationTitleString: String {
        switch currentMode {
        case .categories:
            return ""
        case .artist:
            return selectedArtist?.fields.title ?? "Fan Cam Videos"
        }
    }
    
    // MARK: - Helper Methods
    private func handleCategorySelection(_ category: FanCamCategory) {
        print("📂 Category selected: \(category.name)")
        selectedCategory = category
        currentMode = .artist
        selectedArtist = nil
        visibleVideoIndices = []
        Task {
            await airtableService.fetchVideoCounts(for: category.artists)
        }
    }
    
    private func handleArtistSelection(_ artist: Playlist) {
        print("👤 Artist selected: \(artist.fields.title)")
        Task {
            print("🔎 Loading videos for artist: \(artist.fields.title)")
            if let loaded = try? await airtableService.fetchArtist(byName: artist.fields.title) {
                await MainActor.run {
                    selectedArtist = loaded
                    updateVisibleVideoIndices()
                    let visibleFlags = loaded.fields.isVisible
                    let urlsCount = loaded.fields.videoUrls?.count ?? 0
                    let titlesCount = loaded.fields.videoTitles?.count ?? 0
                    print("🎵 Loaded artist: \(loaded.fields.title) urls=\(urlsCount) titles=\(titlesCount) isVisibleCount=\(visibleFlags.count) visibleIndices=\(visibleVideoIndices.count)")
                }
            } else {
                print("⚠️ Failed to load artist from all sources: \(artist.fields.title)")
                await MainActor.run {
                    selectedArtist = artist
                    visibleVideoIndices = []
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
            // Fallback: if no flags provided, show all videos we have URLs for
            visibleVideoIndices = Array(0..<urlsCount)
            print("ℹ️ No isVisible flags; defaulting to all indices 0..<(\(urlsCount))")
            return
        }
        let indices = isVisibleFlags.enumerated().compactMap { index, flag in (flag ?? false) ? index : nil }
        visibleVideoIndices = indices
        print("ℹ️ Computed visible indices: \(visibleVideoIndices)")
    }
    
    private func handleSwipeBack() {
        if currentMode == .artist && selectedArtist != nil {
            // From video feed → back to artist list
            selectedArtist = nil
            visibleVideoIndices = []
        } else if currentMode == .artist && selectedArtist == nil {
            // From artist list → back to categories
            currentMode = .categories
            selectedCategory = nil
        }
        // No action for top level (categories) as there's nothing to go back to
    }
}

// MARK: - Visible Video Model
private struct VisibleVideo: Identifiable {
    let id: String   // YouTube videoId
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
                // Use individual video year if available, fallback to artist year
                let videoYear = artist.fields.videoYears?[safe: index] ?? String(artist.fields.year)
                result.append(VisibleVideo(id: videoId, title: title, artist: artistName, year: videoYear))
            }
        }
        // Sort by year (newest first), then by title
        return result.sorted { first, second in
            if let firstYear = Int(first.year), let secondYear = Int(second.year) {
                if firstYear != secondYear {
                    return firstYear > secondYear // Newest first
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