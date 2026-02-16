//
//  EpicShowsView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI
import SuperwallKit

struct EpicShowsView: View {
    @StateObject private var airtableService = AirtableService()
    @StateObject private var youtubeService = YouTubeService()
    @State private var lastDataLoadDate: Date?

    // Cached shuffled data for performance
    @State private var cachedRandomConcerts: [Concert] = []
    @State private var cachedSortedLegendaryCategories: [LegendaryCategory] = []
    @State private var cachedShuffledShows: [String: [LegendaryShow]] = [:] // categoryId -> shuffled shows

    // Cached YouTube data for batch loading
    @State private var cachedVideoData: [String: YouTubeVideo] = [:]

    // Header hide/show offset and scroll tracking
    @State private var headerOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0

    // Device and orientation detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var headerHeight: CGFloat { 56 }
    private var iPadHeaderHeight: CGFloat { 52 } // 8 top padding + 28 logo + 16 bottom padding

    var body: some View {
        NavigationStack {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Simple layout with static header
                iPadLayout
            } else {
                // iPhone: Headroom-style header that hides on scroll
                iPhoneLayout
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - iPad Layout (no headroom effect)
    private var iPadLayout: some View {
        ZStack(alignment: .top) {
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
                .padding(.top, iPadHeaderHeight + contentPadding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            // Static iPad header
            HStack {
                Spacer()
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
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .task {
            await loadEpicShowsDataIfNeeded()
        }
    }

    // MARK: - iPhone Layout (with headroom effect)
    private var iPhoneLayout: some View {
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HeadroomHeader(height: headerHeight)
                .offset(y: headerOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: headerOffset)
        }
        .headroomScrollTracking(
            headerOffset: $headerOffset,
            lastScrollOffset: $lastScrollOffset,
            headerHeight: headerHeight
        )
        .navigationTitle("")
        .navigationBarHidden(true)
        .task {
            await loadEpicShowsDataIfNeeded()
        }
    }

    // MARK: - Epic Shows Content
    private var epicShowsContent: some View {
        LazyVStack(alignment: .leading, spacing: sectionSpacing) {
            // Calculate how many banner pairs we need
            let bannerPairCount = cachedSortedLegendaryCategories.count + 1
            let concertsNeeded = bannerPairCount * 2
            let uniqueRandomConcerts = Array(cachedRandomConcerts.prefix(concertsNeeded))

            // First banner pair (before first category)
            if uniqueRandomConcerts.count >= 2 {
                doubleConcertBannerRow(concerts: Array(uniqueRandomConcerts.prefix(2)))
            }

            // Dynamic Legendary categories from Videos table (Last Dance always last)
            ForEach(Array(cachedSortedLegendaryCategories.enumerated()), id: \.element.id) { index, category in
                legendaryCategorySection(category: category)
                // Insert another banner pair between sections (but not after the last section)
                if index < cachedSortedLegendaryCategories.count - 1 {
                    let startIndex = (index + 1) * 2
                    let endIndex = min(startIndex + 2, uniqueRandomConcerts.count)
                    if startIndex < uniqueRandomConcerts.count {
                        doubleConcertBannerRow(concerts: Array(uniqueRandomConcerts[startIndex..<endIndex]))
                    }
                }
            }
        }
    }

    // MARK: - Double Concert Banner Row (two side by side, full width)
    private func doubleConcertBannerRow(concerts: [Concert]) -> some View {
        HStack(spacing: 10) {
            if concerts.count >= 1 {
                NavigationLink(destination: ConcertDetailView(concert: concerts[0])) {
                    ConcertBannerView(concert: concerts[0])
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }

            if concerts.count >= 2 {
                NavigationLink(destination: ConcertDetailView(concert: concerts[1])) {
                    ConcertBannerView(concert: concerts[1])
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            } else {
                // If only one concert, add empty spacer for balance
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea(edges: .horizontal)
    }
    
    // MARK: - Legendary Category Section (no title above banner, dynamic title shown inline above row)
    private func legendaryCategorySection(category: LegendaryCategory) -> some View {
        let shows = getShuffledShows(for: category)
        return VStack(alignment: .leading, spacing: 12) {
            // Category title only above the row, no extra section title headers
            Text(category.name)
                .font(.custom(AppFont.ticketingName(), size: sectionTitleFontSize))
                .fontWeight(.bold)
                .foregroundColor(.hitRewindPrimaryText)
                .padding(.horizontal, contentPadding)
                .padding(.top, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: videoSpacing) {
                    ForEach(shows, id: \.id) { show in
                        if let videoId = extractYouTubeVideoID(from: show.fields.youtubeUrl) {
                            Button(action: {
                                handleVideoTap(show: show, videoId: videoId)
                            }) {
                                LegendaryShowThumbnailView(
                                    show: show,
                                    videoId: videoId,
                                    showDuration: true,
                                    showHeart: true,
                                    cachedVideoData: cachedVideoData[videoId]
                                )
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
            TuningIndicatorView()
            
            Text("Tuning...")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
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
            return 31
        } else {
            return verticalSizeClass == .regular ? 27 : 23
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

    private func getShuffledShows(for category: LegendaryCategory) -> [LegendaryShow] {
        // Check if we have cached shuffled shows for this category
        if let cached = cachedShuffledShows[category.id] {
            return cached
        }

        // Create and cache shuffled shows
        let shuffled = Array(category.shows.shuffled().prefix(20))
        cachedShuffledShows[category.id] = shuffled
        return shuffled
    }

    private func openVideoInMiniPlayer(show: LegendaryShow, videoId: String) {
        guard let category = cachedSortedLegendaryCategories.first(where: { cat in
            cat.shows.contains(where: { $0.id == show.id })
        }) else {
            let fallbackVideo = PlaylistVideo(
                id: videoId, youtubeURL: show.fields.youtubeUrl,
                title: show.fields.title, artist: show.fields.artist,
                year: "\(show.fields.year)"
            )
            MiniPlayerManager.shared.openVJMode(video: fallbackVideo, videos: [fallbackVideo], playlistContext: nil)
            return
        }

        let categoryShows = getShuffledShows(for: category)
        let playlistVideos = categoryShows.compactMap { legendaryShow -> PlaylistVideo? in
            guard let id = extractYouTubeVideoID(from: legendaryShow.fields.youtubeUrl) else { return nil }
            return PlaylistVideo(
                id: id, youtubeURL: legendaryShow.fields.youtubeUrl,
                title: legendaryShow.fields.title, artist: legendaryShow.fields.artist,
                year: "\(legendaryShow.fields.year)"
            )
        }

        guard let currentIndex = playlistVideos.firstIndex(where: { $0.id == videoId }) else { return }

        let currentVideo = playlistVideos[currentIndex]

        let allCategoryVideos = category.shows.compactMap { legendaryShow -> PlaylistVideo? in
            guard let id = extractYouTubeVideoID(from: legendaryShow.fields.youtubeUrl) else { return nil }
            return PlaylistVideo(
                id: id, youtubeURL: legendaryShow.fields.youtubeUrl,
                title: legendaryShow.fields.title, artist: legendaryShow.fields.artist,
                year: "\(legendaryShow.fields.year)"
            )
        }

        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex,
            sourceType: .epicShows(categoryName: category.name, allCategoryVideos: allCategoryVideos)
        )

        MiniPlayerManager.shared.openVJMode(
            video: currentVideo,
            videos: playlistVideos,
            playlistContext: playlistContext
        )
    }

    private func handleVideoTap(show: LegendaryShow, videoId: String) {
        print("🎥 Epic Shows video \(videoId) tapped")

        Task { @MainActor in
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()

            if isSubscribed {
                print("✅ User subscribed - playing video")
                openVideoInMiniPlayer(show: show, videoId: videoId)
            } else {
                print("🔒 User not subscribed - showing paywall")
                PaywallService.shared.presentPaywallWithOrientation {
                    print("✅ Purchase complete - playing video")
                    openVideoInMiniPlayer(show: show, videoId: videoId)
                }
            }
        }
    }

    private func loadEpicShowsDataIfNeeded() async {
        // Check if we need to reload data (once per day)
        let now = Date()
        if let lastLoad = lastDataLoadDate {
            let daysSinceLastLoad = Calendar.current.dateComponents([.day], from: lastLoad, to: now).day ?? 0
            if daysSinceLastLoad < 1 {
                print("🎬 Using cached Epic Shows data (loaded \(lastLoad.formatted(.dateTime)))")
                print("⏱️ [Epic Shows] Cache hit - no network load needed")
                return
            }
        }

        print("⏱️ [Epic Shows] Cache miss - starting fresh data load")
        let totalTimer = PerformanceTimer("Epic Shows - Total Load")
        await loadEpicShowsData()
        lastDataLoadDate = now
        totalTimer.end()
    }
    
    private func loadEpicShowsData() async {
        print("🎬 Loading fresh Epic Shows data...")
        let airtableTimer = PerformanceTimer("Epic Shows - Airtable Parallel Fetch")

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let timer = PerformanceTimer("Epic Shows - Fetch Legendary Categories")
                await self.airtableService.fetchLegendaryCategoriesFromVideos()
                timer.end()
            }
            group.addTask {
                let timer = PerformanceTimer("Epic Shows - Fetch Concerts")
                await self.airtableService.fetchConcerts()
                timer.end()
            }
        }

        airtableTimer.end()
        print("🎬 Loaded \(airtableService.legendaryCategories.count) legendary categories and \(airtableService.concerts.count) concerts")

        // Update cached shuffled data
        await updateCachedData()
    }
    
    private func updateCachedData() async {
        let cacheTimer = PerformanceTimer("Epic Shows - Update Cached Data")

        await MainActor.run {
            cachedRandomConcerts = airtableService.concerts.shuffled()
            cachedShuffledShows = [:] // Clear cached shuffled shows when data is updated

            let categories = airtableService.legendaryCategories
            var otherCategories = categories.filter { $0.name != "Last Dance" }
            let lastDanceCategory = categories.first { $0.name == "Last Dance" }

            // Randomly pick up to 4 from other categories, then add Last Dance as the 5th
            otherCategories.shuffle()
            let maxOther = lastDanceCategory != nil ? 4 : 5
            otherCategories = Array(otherCategories.prefix(maxOther))

            // Add "Last Dance" at the end if it exists
            if let lastDance = lastDanceCategory {
                otherCategories.append(lastDance)
            }

            cachedSortedLegendaryCategories = otherCategories
            print("⏱️ [Epic Shows] Shuffled \(cachedRandomConcerts.count) concerts, sorted \(cachedSortedLegendaryCategories.count) categories")
        }

        cacheTimer.end()

        // Batch load YouTube data for all videos
        await loadYouTubeBatchData()
    }
    
    private func loadYouTubeBatchData() async {
        let youtubeTimer = PerformanceTimer("Epic Shows - YouTube Batch Load (with retries)")

        // Emergency disable: Skip YouTube API if persistent network issues
        // Uncomment this line if YouTube API keeps failing:
        // return

        // Collect all video IDs from legendary shows (max 8 per category)
        // Epic Shows displays 6 categories × 8 videos = 48 videos max
        // This fits perfectly in YouTube's 50-video batch limit!
        var allVideoIds: [String] = []

        for category in cachedSortedLegendaryCategories {
            // Take first 8 shuffled shows per category (matching UI display)
            let shows = Array(category.shows.shuffled().prefix(8))
            for show in shows {
                if let videoId = extractYouTubeVideoID(from: show.fields.youtubeUrl) {
                    allVideoIds.append(videoId)
                }
            }
        }

        // Only load if we have video IDs and cache is empty
        guard !allVideoIds.isEmpty else {
            print("⏱️ [Epic Shows] No video IDs to load")
            return
        }

        print("⏱️ [Epic Shows] Collected \(allVideoIds.count) video IDs for batch loading")

        // Retry logic for network failures
        let maxRetries = 2
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                print("🎬 Batch loading YouTube data for \(allVideoIds.count) videos (≤48, single API call) - attempt \(attempt)...")
                let attemptTimer = PerformanceTimer("Epic Shows - YouTube API Call (attempt \(attempt))")
                let videoData = try await youtubeService.getBatchVideoInfo(videoIds: allVideoIds)
                attemptTimer.end()

                await MainActor.run {
                    cachedVideoData = videoData
                    print("🎬 Successfully cached YouTube data for \(videoData.count) videos in single batch")
                }
                youtubeTimer.end()
                return // Success - exit retry loop

            } catch {
                lastError = error
                let errorDesc = error.localizedDescription

                // Check if this is a retryable network error
                if errorDesc.contains("network connection was lost") ||
                   errorDesc.contains("cannot parse response") ||
                   errorDesc.contains("timed out") {

                    if attempt < maxRetries {
                        print("🎬 Network error (attempt \(attempt)/\(maxRetries)): \(errorDesc)")
                        print("🎬 Retrying YouTube batch load in 2 seconds...")
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                        continue
                    }
                }

                // Non-retryable error or max retries reached
                break
            }
        }

        // All retries failed
        if let error = lastError {
            print("🎬 Failed to batch load YouTube data after \(maxRetries) attempts: \(error.localizedDescription)")
        }
        print("🎬 Epic Shows will display without video durations")
        youtubeTimer.end()
        // Continue without YouTube data - thumbnails will still work with Airtable data
    }
}

struct SettingsView: View {
    @Environment(\.onboardingRestart) private var onboardingRestart
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var paywallService = PaywallService.shared // Only for testSubscriberMode
    @State private var showingCopyrightAlert = false
    @State private var showingContactSheet = false
    @State private var showingDeleteAccountAlert = false
    @State private var isRestoringPurchases = false
    @State private var showingRestoreSuccess = false
    @State private var subscriptionStatus: SubscriptionStatus = .unknown

    // Check Superwall directly instead of PaywallService
    private var hasActiveSubscription: Bool {
        if case .active = subscriptionStatus {
            return true
        }
        return false
    }

    var body: some View {
        List {
            // Account Section
            if authService.isAuthenticated {
                accountSection
            }

            // Data & Sync Section
            dataSection

            // Subscription Section
            subscriptionSection

            // Legal & Privacy Section
            legalSection

            // Support Section
            supportSection

            // App Information Section
            appInfoSection

            // Developer Section (DEBUG only)
            #if DEBUG
            developerSection
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showingContactSheet) {
            contactSupportView
        }
        .alert("Copyright Notice", isPresented: $showingCopyrightAlert) {
            Button("OK") { }
        } message: {
            Text(copyrightNotice)
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                authService.deleteAccount()
            }
        } message: {
            Text("This will permanently delete your account and all associated data from this device. Your favorites will be cleared and you will be signed out. This action cannot be undone.")
        }
        .alert("Purchases Restored", isPresented: $showingRestoreSuccess) {
            Button("OK") { }
        } message: {
            Text(hasActiveSubscription ? "Your subscription has been restored successfully!" : "No active subscription found. If you previously purchased a subscription, please contact support.")
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

            Button(action: {
                showingDeleteAccountAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.hitRewindPurple)
                    Text("Delete Account")
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
                    NotificationCenter.default.post(name: .showSignInSheet, object: nil)
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
            case .offline:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.hitRewindSecondaryText)
            case .unknown:
                Image(systemName: "cloud")
                    .foregroundColor(.hitRewindSecondaryText)
            }
        }
    }

    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        Section("Subscription") {
            // Restore purchases button
            Button(action: {
                Task {
                    isRestoringPurchases = true
                    do {
                        _ = try await Superwall.shared.restorePurchases()
                        isRestoringPurchases = false
                        // Update local state
                        subscriptionStatus = Superwall.shared.subscriptionStatus
                        showingRestoreSuccess = true
                    } catch {
                        isRestoringPurchases = false
                        // The error alert is shown by the system
                    }
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.hitRewindPurple)
                    Text("Restore Purchases")
                        .foregroundColor(.white)

                    Spacer()

                    if isRestoringPurchases {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isRestoringPurchases)
        }
        .onAppear {
            // Update subscription status from Superwall when view appears
            subscriptionStatus = Superwall.shared.subscriptionStatus
        }
    }

    // MARK: - Legal Section
    private var legalSection: some View {
        Section("Legal & Privacy") {
            Link(destination: URL(string: "https://designoverhaul.com/privacy-policy-hit-rewind/")!) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(.hitRewindPurple)
                    Text("Privacy Policy")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.hitRewindSecondaryText)
                        .font(.caption)
                }
            }
            
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
        }
    }
    
    // MARK: - Testing Section (Hidden for Production)
    /*
    private var testingSection: some View {
        Section("Testing & Development") {
            // Test Subscriber Mode Toggle
            Toggle(isOn: Binding(
                get: { paywallService.testSubscriberMode },
                set: { paywallService.setTestSubscriberMode($0) }
            )) {
                HStack {
                    Image(systemName: paywallService.testSubscriberMode ? "checkmark.seal.fill" : "checkmark.seal")
                        .foregroundColor(.hitRewindPurple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Test Subscriber Mode")
                            .foregroundColor(.white)
                        Text("Unlock all videos for testing")
                            .font(.caption)
                            .foregroundColor(.hitRewindSecondaryText)
                    }
                }
            }
            .tint(.hitRewindPurple)

            Button(action: {
                // Update UserDefaults
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                // Trigger onboarding by updating the environment binding
                onboardingRestart.wrappedValue = false
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.hitRewindPurple)
                    Text("Restart Onboarding")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.hitRewindSecondaryText)
                        .font(.caption)
                }
            }
        }
    }
    */

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

    // MARK: - Developer Section (DEBUG only)
    #if DEBUG
    private var developerSection: some View {
        Section("Developer") {
            // Force Subscribed Mode
            Toggle(isOn: Binding(
                get: { paywallService.testSubscriberMode },
                set: { paywallService.setTestSubscriberMode($0) }
            )) {
                HStack {
                    Image(systemName: paywallService.testSubscriberMode ? "checkmark.seal.fill" : "checkmark.seal")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Force Subscribed")
                            .foregroundColor(.white)
                        Text("Bypass paywall, unlock all videos")
                            .font(.caption)
                            .foregroundColor(.hitRewindSecondaryText)
                    }
                }
            }
            .tint(.green)

            // Force Unsubscribed Mode
            Toggle(isOn: Binding(
                get: { paywallService.testUnsubscriberMode },
                set: { paywallService.setTestUnsubscriberMode($0) }
            )) {
                HStack {
                    Image(systemName: paywallService.testUnsubscriberMode ? "xmark.seal.fill" : "xmark.seal")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Force Unsubscribed")
                            .foregroundColor(.white)
                        Text("Always show paywall")
                            .font(.caption)
                            .foregroundColor(.hitRewindSecondaryText)
                    }
                }
            }
            .tint(.red)

            // Restart Onboarding
            Button(action: {
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                onboardingRestart.wrappedValue = false
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.hitRewindPurple)
                    Text("Restart Onboarding")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.hitRewindSecondaryText)
                        .font(.caption)
                }
            }
        }
    }
    #endif

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
    let cachedVideoData: YouTubeVideo?
    
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var youtubeService = YouTubeService()
    @State private var duration: String = ""
    @State private var showingRemoveFavoriteConfirmation = false

    private var displayTitle: String {
        show.fields.title
    }

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
                        LegendaryFavoriteButton(
                            videoId: videoId,
                            show: show,
                            showingRemoveConfirmation: $showingRemoveFavoriteConfirmation
                        )
                        .environmentObject(authService)
                        .environmentObject(favoritesService)
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

                // Only show year if it's valid (non-zero)
                if show.fields.year > 0 {
                    Text(String(show.fields.year))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.hitRewindPurple)
                }
            }
            
            // Title smaller underneath
            Text(displayTitle)
                .font(.caption)
                .foregroundColor(.hitRewindSecondaryText)
                .lineLimit(1)
        }
    }
    
    private func loadVideoData() async {
        // Only load video duration from cached data if showDuration is true
        guard showDuration else { return }
        
        // Use cached data if available, otherwise skip duration
        if let cachedVideo = cachedVideoData,
           let contentDetails = cachedVideo.contentDetails {
            let formattedDuration = youtubeService.formatDuration(contentDetails.duration)
            await MainActor.run {
                duration = formattedDuration
            }
        }
        // No fallback to individual API calls - rely on batch loading
    }
}

// MARK: - Custom Tuning Indicator
struct TuningIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.hitRewindPurple)
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.1),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = 1
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 20
        let maxHeight: CGFloat = 40
        let progress = (sin(animationOffset + Double(index) * 0.5) + 1) / 2
        return baseHeight + (maxHeight - baseHeight) * progress
    }
}

// MARK: - Legendary Favorite Button
struct LegendaryFavoriteButton: View {
    let videoId: String
    let show: LegendaryShow
    @Binding var showingRemoveConfirmation: Bool

    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var favoritesService: FavoritesService

    @State private var isFavorited: Bool = false

    var body: some View {
        Button(action: {
            print("🎪 Legendary favorite button tapped for: \(show.fields.title)")
            if authService.isAuthenticated {
                print("🎪 User authenticated, current isFavorited: \(isFavorited)")
                if isFavorited {
                    print("🎪 Showing remove confirmation")
                    showingRemoveConfirmation = true
                } else {
                    print("🎪 Adding to favorites...")
                    favoritesService.toggleFavorite(videoId: videoId, title: show.fields.title, artist: show.fields.artist, year: "\(show.fields.year)")
                    // Update local state immediately
                    isFavorited = true
                    print("🎪 Local state set to favorited")
                }
            } else {
                print("🎪 User not authenticated, showing sign-in sheet")
                NotificationCenter.default.post(name: .showSignInSheet, object: nil)
            }
        }) {
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isFavorited ? .red : .hitRewindPurple)
                .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Initialize the state when the view appears
            isFavorited = favoritesService.isFavorited(videoId)
        }
        .onReceive(favoritesService.objectWillChange) { _ in
            // Update state when favorites change
            isFavorited = favoritesService.isFavorited(videoId)
        }
    }
}

#Preview {
    EpicShowsView()
        .preferredColorScheme(.dark)
}