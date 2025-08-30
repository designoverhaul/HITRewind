//
//  MusicVideosView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI

struct MusicVideosView: View {
    @StateObject private var airtableService = AirtableService()
    @StateObject private var youtubeService = YouTubeService()
    
    @State private var selectedYear: Int?
    @State private var selectedPlaylist: Playlist?
    @State private var visibleVideoIndices: [Int] = []
    @State private var showYearSidebar = false
    
    // Device and orientation detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
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
            await airtableService.fetchPlaylists()
            selectFirstAvailableYear()
        }
    }
    
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        NavigationSplitView {
            YearSidebarView(
                years: availableYears,
                selectedYear: $selectedYear,
                onYearSelected: handleYearSelection
            )
            .navigationTitle("Years")
        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                // Custom title header
                HStack {
                    Text("New Music Videos \(String(selectedYear ?? 2025))")
                        .font(.custom(AppFont.ticketingName(), size: 28))
                        .fontWeight(.bold)
                        .foregroundColor(.hitRewindPrimaryText)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    Spacer()
                    
                    // Search and Settings buttons
                    HStack(spacing: 16) {
                        NavigationLink(destination: SearchView()) {
                            Text("🔍")
                        }
                        NavigationLink(destination: SettingsView()) {
                            Text("⚙️")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                
                videoGridView
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
    }
    
    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        ZStack(alignment: .leading) {
            videoGridView
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
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showYearSidebar.toggle()
                            }
                        }) {
                            Text(selectedYear != nil ? String(selectedYear!) : "Years")
                                .font(.custom(AppFont.ticketingName(), size: 20))
                                .foregroundColor(.hitRewindPurple)
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
            if showYearSidebar {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showYearSidebar = false
                        }
                    }
                
                YearSidebarView(
                    years: availableYears,
                    selectedYear: $selectedYear,
                    onYearSelected: { year in
                        handleYearSelection(year)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showYearSidebar = false
                        }
                    }
                )
                .frame(width: 220)
                .background(Color.hitRewindBackground)
                .transition(.move(edge: .leading))
            }
        }
    }
    
    // MARK: - Video Grid View
    private var videoGridView: some View {
        Group {
            if airtableService.isLoading {
                LoadingView()
            } else if let errorMessage = airtableService.errorMessage {
                ErrorView(message: errorMessage) {
                    Task {
                        await airtableService.fetchPlaylists()
                    }
                }
            } else if selectedPlaylist != nil && !visibleVideoIndices.isEmpty {
                videoGrid
            } else {
                ContentUnavailableView(
                    "No Videos Available",
                    systemImage: "music.note.list",
                    description: Text("Select a year to view music videos")
                )
            }
        }
    }
    
    private var videoGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("New Music Videos \(String(selectedYear ?? 2025))")
                    .font(.custom(AppFont.ticketingName(), size: 28))
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
                            onTap: {}
                        )
                    }
                }
            }
            .id(selectedPlaylist?.id)
            .padding(gridPadding)
        }
    }
    
    // MARK: - Computed Properties
    private var availableYears: [Int] {
        let years = airtableService.playlists.map { $0.fields.year }
        return Array(Set(years)).sorted(by: >)
    }
    
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
    
    // MARK: - Helper Methods
    private var navigationTitleString: String {
        return "Top Music Videos"
    }
    private func selectFirstAvailableYear() {
        guard selectedYear == nil, let firstYear = availableYears.first else { return }
        selectedYear = firstYear
        handleYearSelection(firstYear)
    }
    
    private func handleYearSelection(_ year: Int) {
        print("📅 Year selected: \(String(year))")
        selectedYear = year
        selectedPlaylist = airtableService.playlists.first { $0.fields.year == year }
        updateVisibleVideoIndices()
        print("🎵 Found playlist: \(selectedPlaylist?.fields.title ?? "None") with \(visibleVideoIndices.count) visible videos")
    }
    
    private func updateVisibleVideoIndices() {
        guard let playlist = selectedPlaylist else {
            visibleVideoIndices = []
            return
        }
        
        visibleVideoIndices = playlist.fields.isVisible.enumerated().compactMap { index, isVisible in
            (isVisible ?? false) ? index : nil
        }
    }
}

// MARK: - Visible Video Model
private struct VisibleVideo: Identifiable {
    let id: String   // YouTube videoId
    let title: String
    let artist: String
    let year: String
}

private extension MusicVideosView {
    var visibleVideos: [VisibleVideo] {
        guard let playlist = selectedPlaylist else { return [] }
        var result: [VisibleVideo] = []
        for index in visibleVideoIndices {
            if let url = playlist.fields.videoUrls?[safe: index],
               let videoId = extractYouTubeVideoID(from: url) {
                let title = playlist.fields.videoTitles?[safe: index] ?? "Unknown Title"
                let artist = playlist.fields.artistNames?[safe: index] ?? "Unknown Artist"
                result.append(VisibleVideo(id: videoId, title: title, artist: artist, year: String(playlist.fields.year)))
            }
        }
        return result
    }
}

// MARK: - Supporting Views
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.hitRewindPurple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.hitRewindSecondaryText)
                .padding(.horizontal)
            
            Button("Try Again") {
                retry()
            }
            .buttonStyle(HitRewindButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Structures

struct HitRewindButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .hitRewindPurple.opacity(0.7) : .hitRewindPurple)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.hitRewindPurple, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Array Extension

// MARK: - Preview
#Preview {
    MusicVideosView()
        .preferredColorScheme(.dark)
}