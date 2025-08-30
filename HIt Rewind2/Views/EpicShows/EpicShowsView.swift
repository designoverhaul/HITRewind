//
//  EpicShowsView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI

struct EpicShowsView: View {
    @StateObject private var airtableService = AirtableService()
    @State private var lastDataLoadDate: Date?
    
    // Device and orientation detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    if airtableService.isLoading {
                        loadingView
                    } else if let errorMessage = airtableService.errorMessage {
                        errorView(message: errorMessage)
                    } else {
                        epicShowsContent
                    }
                }
                .padding(.top, contentPadding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
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
            .task {
                await loadEpicShowsDataIfNeeded()
            }
        }
    }
    
    // MARK: - Epic Shows Content
    private var epicShowsContent: some View {
        LazyVStack(alignment: .leading, spacing: sectionSpacing) {
            let uniqueRandomConcerts = Array(randomConcerts.prefix(sortedLegendaryCategories.count))
            
            // Full-width, single banner (no scrolling row)
            if let bannerConcert = uniqueRandomConcerts.first {
                singleConcertBanner(concert: bannerConcert)
            }
            
            // Dynamic Legendary categories from Videos table (Last Dance always last)
            ForEach(Array(sortedLegendaryCategories.enumerated()), id: \.element.id) { index, category in
                legendaryCategorySection(category: category)
                // Insert another unique banner between sections (but not after the last section)
                if index < sortedLegendaryCategories.count - 1,
                   index + 1 < uniqueRandomConcerts.count {
                    singleConcertBanner(concert: uniqueRandomConcerts[index + 1])
                }
            }
        }
    }
    
    // MARK: - Single Concert Banner (full-width)
    private func singleConcertBanner(concert: Concert) -> some View {
        NavigationLink(destination: ConcertDetailView(concert: concert)) {
            ConcertBannerView(concert: concert)
                .frame(width: UIScreen.main.bounds.width)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Legendary Category Section (no title above banner, dynamic title shown inline above row)
    private func legendaryCategorySection(category: LegendaryCategory) -> some View {
        let shows = Array(category.shows.shuffled().prefix(8))
        return VStack(alignment: .leading, spacing: 12) {
            // Category title only above the row, no extra section title headers
            Text(category.name)
                .font(.custom(AppFont.ticketingName(), size: sectionTitleFontSize))
                .fontWeight(.bold)
                .foregroundColor(.hitRewindPrimaryText)
                .padding(.horizontal, contentPadding)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: videoSpacing) {
                    ForEach(shows, id: \.id) { show in
                        if let videoId = extractYouTubeVideoID(from: show.fields.youtubeUrl) {
                            NavigationLink(destination: SingleVideoView(
                                videoId: videoId,
                                videoTitle: show.fields.title,
                                artistName: show.fields.artist,
                                year: "\(show.fields.year)"
                            )) {
                                LegendaryShowThumbnailView(show: show, videoId: videoId, showDuration: false, showHeart: false)
                            }
                            .buttonStyle(.plain)
                            .frame(width: videoThumbnailWidth)
                        }
                    }
                }
                .padding(.horizontal, contentPadding)
            }
        }
    }
    
    // MARK: - Loading & Error Views
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .tint(.hitRewindPurple)
                .scaleEffect(1.5)
            
            Text("Loading Epic Shows...")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.hitRewindSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("Error Loading Epic Shows")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)
            
            Text(message)
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Try Again") {
                Task {
                    await loadEpicShowsData()
                    lastDataLoadDate = Date()
                }
            }
            .foregroundColor(.hitRewindPurple)
            .font(.body)
            .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Computed Properties
    
    private var randomConcerts: [Concert] {
        airtableService.concerts.shuffled()
    }
    
    private var randomLegendaryShows: [LegendaryShow] {
        airtableService.legendaryShows.shuffled()
    }
    
    // Ensure "Last Dance" appears as the final category
    private var sortedLegendaryCategories: [LegendaryCategory] {
        let categories = airtableService.legendaryCategories
        var otherCategories = categories.filter { $0.name != "Last Dance" }
        let lastDanceCategory = categories.first { $0.name == "Last Dance" }
        
        // Sort other categories alphabetically
        otherCategories.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Add "Last Dance" at the end if it exists
        if let lastDance = lastDanceCategory {
            otherCategories.append(lastDance)
        }
        
        return otherCategories
    }
    
    private var concertBannerColumns: [GridItem] {
        let count = UIDevice.current.userInterfaceIdiom == .pad ? 2 : 1
        return Array(repeating: GridItem(.flexible()), count: count)
    }
    
    private var legendaryShowsColumns: [GridItem] {
        let count = legendaryShowsColumnCount
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: count)
    }
    
    private var legendaryShowsColumnCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return horizontalSizeClass == .regular ? 4 : 3
        } else {
            return verticalSizeClass == .regular ? 1 : 2
        }
    }
    
    private var gridSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
    }
    
    private var contentPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16
    }
    
    private var contentSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 24 : 20
    }
    
    private var sectionSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 48 : 40
    }
    
    private var sectionTitleFontSize: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 28
        } else {
            return verticalSizeClass == .regular ? 24 : 20
        }
    }
    
    private var bannerWidth: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 320  // Reduced from 400
        } else {
            return verticalSizeClass == .regular ? 240 : 200  // Reduced from 280/240
        }
    }
    
    private var bannerSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
    }
    
    private var videoSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12
    }
    
    private var videoThumbnailWidth: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return horizontalSizeClass == .regular ? 225 : 200  // 25% larger: 180*1.25=225, 160*1.25=200
        } else {
            return verticalSizeClass == .regular ? 175 : 162   // 25% larger: 140*1.25=175, 130*1.25=162.5≈162
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadEpicShowsDataIfNeeded() async {
        // Check if we need to reload data (once per day)
        let now = Date()
        if let lastLoad = lastDataLoadDate {
            let daysSinceLastLoad = Calendar.current.dateComponents([.day], from: lastLoad, to: now).day ?? 0
            if daysSinceLastLoad < 1 {
                print("🎬 Using cached Epic Shows data (loaded \(lastLoad.formatted(.dateTime)))")
                return
            }
        }
        
        await loadEpicShowsData()
        lastDataLoadDate = now
    }
    
    private func loadEpicShowsData() async {
        print("🎬 Loading fresh Epic Shows data...")
        async let categoriesTask = airtableService.fetchLegendaryCategoriesFromVideos()
        async let concertsTask = airtableService.fetchConcerts()
        await categoriesTask
        await concertsTask
        print("🎬 Loaded \(airtableService.legendaryCategories.count) legendary categories and \(airtableService.concerts.count) concerts")
    }
}


struct SettingsView: View {
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var favoritesService = FavoritesService.shared
    @State private var showingCopyrightAlert = false
    @State private var showingContactSheet = false
    
    var body: some View {
        NavigationView {
            List {
                // Account Section
                if authService.isAuthenticated {
                    accountSection
                }
                
                // Data & Sync Section
                dataSection
                
                // Legal & Privacy Section
                legalSection
                
                // Support Section
                supportSection
                
                // App Information Section
                appInfoSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingContactSheet) {
            contactSupportView
        }
        .alert("Copyright Notice", isPresented: $showingCopyrightAlert) {
            Button("OK") { }
        } message: {
            Text(copyrightNotice)
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        Section("Account") {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.hitRewindPurple)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let fullName = authService.userFullName, !fullName.isEmpty {
                        Text(fullName)
                            .font(.body)
                            .foregroundColor(.hitRewindPrimaryText)
                    }
                    
                    if let email = authService.userEmail, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.hitRewindSecondaryText)
                    } else {
                        Text("Signed in with Apple")
                            .font(.caption)
                            .foregroundColor(.hitRewindSecondaryText)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            Button(action: {
                authService.signOut()
            }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundColor(.hitRewindPurple)
                    Text("Sign Out")
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Data & Sync Section
    private var dataSection: some View {
        Section("Data & Sync") {
            if authService.isAuthenticated {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("Favorites")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(favoritesService.favoriteVideos.count)")
                        .foregroundColor(.hitRewindSecondaryText)
                }
                
                Button(action: {
                    favoritesService.syncWithCloud()
                }) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                            .foregroundColor(.hitRewindPurple)
                        Text("Sync Favorites")
                            .foregroundColor(.white)
                        Spacer()
                        syncStatusView
                    }
                }
                .disabled(favoritesService.syncStatus == .syncing)
            } else {
                Button(action: {
                    authService.signInWithApple()
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.hitRewindPurple)
                        Text("Sign In to Sync Data")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private var syncStatusView: some View {
        Group {
            switch favoritesService.syncStatus {
            case .syncing:
                ProgressView()
                    .scaleEffect(0.8)
            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            case .unknown:
                Image(systemName: "cloud")
                    .foregroundColor(.hitRewindSecondaryText)
            }
        }
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        Section("Legal & Privacy") {
            Button(action: {
                showingCopyrightAlert = true
            }) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.hitRewindPurple)
                    Text("Copyright Notice")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.hitRewindSecondaryText)
                        .font(.caption)
                }
            }
            
            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.hitRewindPurple)
                    Text("End User License Agreement")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.hitRewindSecondaryText)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        Section("Support") {
            Button(action: {
                showingContactSheet = true
            }) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.hitRewindPurple)
                    Text("Contact Support")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.hitRewindSecondaryText)
                        .font(.caption)
                }
            }
            
            if let url = URL(string: "https://apps.apple.com/app/hit-rewind/id\(Bundle.main.infoDictionary?["CFBundleIdentifier"] ?? "")") {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "star")
                            .foregroundColor(.hitRewindPurple)
                        Text("Rate Hit Rewind")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.hitRewindSecondaryText)
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    // MARK: - App Info Section
    private var appInfoSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.hitRewindPurple)
                Text("Developer")
                    .foregroundColor(.white)
                Spacer()
                Text("Design Overhaul")
                    .foregroundColor(.hitRewindSecondaryText)
            }
            
            HStack {
                Image(systemName: "number")
                    .foregroundColor(.hitRewindPurple)
                Text("Version")
                    .foregroundColor(.white)
                Spacer()
                Text(AppConfig.version)
                    .foregroundColor(.hitRewindSecondaryText)
            }
        }
    }
    
    // MARK: - Contact Support View
    private var contactSupportView: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.hitRewindPurple)
                
                Text("Contact Support")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.hitRewindPrimaryText)
                
                Text("Need help with Hit Rewind? We're here to assist you!")
                    .font(.body)
                    .foregroundColor(.hitRewindSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 16) {
                    Link(destination: URL(string: "mailto:contact@designoverhaul.com?subject=Hit%20Rewind%20iOS%20Support")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("contact@designoverhaul.com")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.hitRewindPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                    
                    Button(action: {
                        if let url = URL(string: "mailto:contact@designoverhaul.com?subject=Hit%20Rewind%20iOS%20Support&body=App%20Version:%20\(AppConfig.version)%0ADevice:%20\(UIDevice.current.model)%0AiOS%20Version:%20\(UIDevice.current.systemVersion)%0A%0ADescribe%20your%20issue:%0A") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Debug Info")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.hitRewindPurple)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.hitRewindPurple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                }
            }
            .padding()
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingContactSheet = false
                    }
                    .foregroundColor(.hitRewindPurple)
                }
            }
        }
    }
    
    // MARK: - Constants
    private let copyrightNotice = "No unauthorized duplication, reproduction, distribution, or downloading of music, videos, or any other copyrighted content available on this application is permitted. Any such activities constitute a violation of applicable copyright laws and intellectual property rights. Users are strictly prohibited from engaging in or facilitating the unauthorized copying, sharing, or downloading of protected materials. Violation of these terms may result in termination of access to the application."
}

// MARK: - Legendary Show Thumbnail View
struct LegendaryShowThumbnailView: View {
    let show: LegendaryShow
    let videoId: String
    let showDuration: Bool
    let showHeart: Bool
    
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var youtubeService = YouTubeService()
    @State private var duration: String = ""
    @State private var showingRemoveFavoriteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with play overlay
            thumbnailView
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
            
            // Video information
            videoInfo
        }
        .task {
            await loadVideoData()
        }
        .confirmationDialog("Remove from favorites?", isPresented: $showingRemoveFavoriteConfirmation) {
            Button("Remove", role: .destructive) {
                favoritesService.toggleFavorite(videoId: videoId, title: show.fields.title, artist: show.fields.artist, year: "\(show.fields.year)")
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var thumbnailView: some View {
        ZStack {
            // Use custom videoImage if available, otherwise fall back to YouTube thumbnail
            Group {
                if let customImageUrl = show.fields.videoImage, !customImageUrl.isEmpty {
                    AsyncImage(url: URL(string: customImageUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.hitRewindDarkGray)
                            .overlay {
                                ProgressView()
                                    .tint(.hitRewindPurple)
                            }
                    }
                } else {
                    // Fallback to YouTube thumbnail
                    AsyncImage(url: youtubeService.getThumbnailURL(for: videoId, quality: .medium)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.hitRewindDarkGray)
                            .overlay {
                                ProgressView()
                                    .tint(.hitRewindPurple)
                            }
                    }
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Duration badge and heart button
            VStack {
                HStack {
                    Spacer()
                    
                    // Heart button (top-right) - only show if showHeart is true
                    if showHeart {
                        Button(action: {
                            if authService.isAuthenticated {
                                if favoritesService.isFavorited(videoId) {
                                    showingRemoveFavoriteConfirmation = true
                                } else {
                                    favoritesService.toggleFavorite(videoId: videoId, title: show.fields.title, artist: show.fields.artist, year: "\(show.fields.year)")
                                }
                            } else {
                                authService.signInWithApple()
                            }
                        }) {
                            Image(systemName: favoritesService.isFavorited(videoId) ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(favoritesService.isFavorited(videoId) ? .red : .white)
                                .frame(width: 28, height: 28)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 4)  // Closer to right edge (reduced from 8)
                        .padding(.top, 4)       // Higher up (reduced from 8)
                    }
                }
                
                Spacer()
                
                // Duration badge (bottom-right) - only show if showDuration is true
                if showDuration && !duration.isEmpty {
                    HStack {
                        Spacer()
                        Text(duration)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.trailing, 8)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }
    
    private var videoInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                // Artist name on top (larger)
                Text(show.fields.artist)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.hitRewindPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Text(String(show.fields.year))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.hitRewindPurple)
            }
            
            // Title smaller underneath
            Text(show.fields.title)
                .font(.caption)
                .foregroundColor(.hitRewindSecondaryText)
                .lineLimit(1)
        }
    }
    
    private func loadVideoData() async {
        // Only load video duration from YouTube API if showDuration is true
        guard showDuration else { return }
        
        do {
            let video = try await youtubeService.getVideoInfo(videoId: videoId)
            if let contentDetails = video.contentDetails {
                let formattedDuration = youtubeService.formatDuration(contentDetails.duration)
                await MainActor.run {
                    duration = formattedDuration
                }
            }
        } catch {
            // Duration loading failed, but we can continue without it
            print("Failed to load video info for \(videoId): \(error)")
        }
    }
}

#Preview {
    EpicShowsView()
        .preferredColorScheme(.dark)
}