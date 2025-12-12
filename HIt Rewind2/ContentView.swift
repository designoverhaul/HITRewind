//
//  ContentView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import AVFoundation
import AVKit
import SuperwallKit

// MARK: - Notification Extensions
extension Notification.Name {
    static let videoPlayerPresented = Notification.Name("videoPlayerPresented")
    static let videoPlayerDismissed = Notification.Name("videoPlayerDismissed")
    static let playerSkipBackward = Notification.Name("playerSkipBackward")
    static let playerTogglePlayPause = Notification.Name("playerTogglePlayPause")
    static let playerSkipForward = Notification.Name("playerSkipForward")
    static let playerSkip60Forward = Notification.Name("playerSkip60Forward")
    static let playerStateChanged = Notification.Name("playerStateChanged")
    static let  searchArtist = Notification.Name("searchArtist")
    static let switchToSearch = Notification.Name("switchToSearch")
    static let showSignInSheet = Notification.Name("showSignInSheet")
}

struct ContentView: View {
    @Binding var shouldRestartOnboarding: Bool
    @State private var heartAnimationTrigger = false
    @State private var selectedTab = 1  // Start with MTV (Music Videos) page
    @State private var previousTab = 1
    @State private var showingVideoPlayer = false
    @State private var currentVideoInfo: (id: String, title: String, artist: String, year: String)?
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var isAirPlayActive = false
    @State private var isVideoPlaying = false
    @State private var navigateToSearch = false
    @State private var searchArtistName = ""
    @State private var showingSignInSheet = false
    @State private var isLandscape = false

    // Size class detection for landscape mode
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private func videoInfoSection(for videoInfo: (id: String, title: String, artist: String, year: String)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Year
            Text(videoInfo.year)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Video name and artist name row - horizontally aligned
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(videoInfo.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Text(videoInfo.artist)
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func controlButtonsSection(for videoInfo: (id: String, title: String, artist: String, year: String)) -> some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            FavoriteButton(videoInfo: videoInfo)
                .environmentObject(authService)
                .environmentObject(favoritesService)

            Button(action: {
                NotificationCenter.default.post(name: .playerSkipBackward, object: nil)
            }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                    .frame(width: 60, height: 60)
                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            Button(action: {
                NotificationCenter.default.post(name: .playerTogglePlayPause, object: nil)
            }) {
                Image(systemName: isVideoPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                    .frame(width: 60, height: 60)
                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            Button(action: {
                NotificationCenter.default.post(name: .playerSkipForward, object: nil)
            }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                    .frame(width: 60, height: 60)
                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            Button(action: {
                NotificationCenter.default.post(name: .playerSkip60Forward, object: nil)
            }) {
                Image(systemName: "goforward.60")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                    .frame(width: 60, height: 60)
                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            Spacer(minLength: 0)
        }
    }
    
    private var videoPlayerControlsOverlay: some View {
        Group {
            let shouldShow = showingVideoPlayer && (currentVideoInfo != nil) && !isLandscape
            if shouldShow {
                VStack {
                    Spacer()

                    VStack(spacing: 14) {
                        if let videoInfo = currentVideoInfo {
                            videoInfoSection(for: videoInfo)
                            controlButtonsSection(for: videoInfo)
                        }
                    }
                    .padding(.horizontal, 12)

                    Color.clear
                        .frame(height: 80)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    print("🎬 Showing video player controls overlay for: \(currentVideoInfo?.title ?? "unknown")")
                }
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            EpicShowsView()
                .tabItem {
                    Image(systemName: "music.mic")
                    Text("Epic Shows")
                }
                .tag(0)
            
            MusicVideosView()
                .tabItem {
                    Image(systemName: "movieclapper")
                    Text("MTV")
                }
                .tag(1)
            
            // AirPlay tab - empty view, picker is handled by custom tab item
            Color.clear
                .tabItem {
                    AirPlayTabItem()
                }
                .tag(2)
            
            FanCamsView()
                .tabItem {
                    Image(systemName: "ticket")
                    Text("Live")
                }
                .tag(3)
            
            FavoritesView()
                .tabItem {
                    AnimatedHeartTabIcon(animationTrigger: heartAnimationTrigger, isSelected: selectedTab == 4)
                    Text("Favorites")
                }
                .tag(4)
        }
        .environment(\.onboardingRestart, $shouldRestartOnboarding)
        .overlay(videoPlayerControlsOverlay)
        .accentColor(Color.hitRewindPurple)
        .onAppear {
            detectOrientation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            detectOrientation()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                // AirPlay tab tapped - reset to previous tab immediately and trigger AirPlay picker
                selectedTab = previousTab
                // Trigger AirPlay picker
                AirPlayHelper.shared.showAirPlayPicker()
            } else {
                // Update previous tab for any other tab selection
                previousTab = newValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .favoriteAdded)) { _ in
            triggerHeartAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoPlayerPresented)) { notification in
            if let userInfo = notification.userInfo,
               let videoId = userInfo["videoId"] as? String,
               let title = userInfo["title"] as? String,
               let artist = userInfo["artist"] as? String,
               let year = userInfo["year"] as? String {
                currentVideoInfo = (videoId, title, artist, year)
                showingVideoPlayer = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoPlayerDismissed)) { _ in
            print("🎬 Video player dismissed, hiding overlay")
            showingVideoPlayer = false
            currentVideoInfo = nil
            isVideoPlaying = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerStateChanged)) { notification in
            if let userInfo = notification.userInfo,
               let isPlaying = userInfo["isPlaying"] as? Bool {
                isVideoPlaying = isPlaying
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToSearch)) { _ in
            // Search is now only accessible through header navigation
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSignInSheet)) { _ in
            showingSignInSheet = true
        }
        .sheet(isPresented: $showingSignInSheet) {
            SignInSheetView()
        }
    }
    
    private func triggerHeartAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.3, blendDuration: 0)) {
            heartAnimationTrigger.toggle()
        }
        
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            heartAnimationTrigger = false
        }
    }
    
    private func detectOrientation() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let orientation = windowScene.interfaceOrientation
        let newLandscapeState = orientation.isLandscape
        
        if newLandscapeState != isLandscape {
            withAnimation {
                isLandscape = newLandscapeState
            }
            print("🎬 Orientation changed to: \(isLandscape ? "landscape" : "portrait")")
        }
    }
    
}

// MARK: - Favorite Button
struct FavoriteButton: View {
    let videoInfo: (id: String, title: String, artist: String, year: String)
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var favoritesService: FavoritesService

    @State private var isFavorited: Bool = false

    var body: some View {
        Button(action: {
            print("🎬 Favorite button tapped for video: \(videoInfo.title)")
            if authService.isAuthenticated {
                print("🎬 User authenticated, toggling favorite...")
                favoritesService.toggleFavorite(videoId: videoInfo.id, title: videoInfo.title, artist: videoInfo.artist, year: videoInfo.year)
                // Update local state immediately for better UX
                isFavorited.toggle()
                print("🎬 Local state updated to: \(isFavorited)")
            } else {
                print("🎬 User not authenticated, showing sign-in sheet")
                // Show sign-in sheet instead of direct sign-in
                NotificationCenter.default.post(name: .showSignInSheet, object: nil)
            }
        }) {
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .font(.system(size: 20))
                .foregroundColor(isFavorited ? .red : Color(red: 0.65, green: 0.53, blue: 0.99))
                .frame(width: 60, height: 60)
                .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .onAppear {
            // Initialize the state when the view appears
            let currentState = favoritesService.isFavorited(videoInfo.id)
            isFavorited = currentState
            print("🎬 FavoriteButton appeared for \(videoInfo.title), isFavorited: \(currentState)")
        }
        .onReceive(favoritesService.objectWillChange) { _ in
            // Update state when favorites change
            let newState = favoritesService.isFavorited(videoInfo.id)
            print("🎬 Favorite state changed for \(videoInfo.title), new state: \(newState)")
            isFavorited = newState
        }
    }
}

// MARK: - Animated Heart Tab Icon
struct AnimatedHeartTabIcon: View {
    let animationTrigger: Bool
    let isSelected: Bool

    var body: some View {
        Image(systemName: "heart.fill")
            .scaleEffect(animationTrigger ? 1.3 : 1.0)
            .foregroundColor((animationTrigger || isSelected) ? .red : .primary)
            .animation(.spring(response: 0.6, dampingFraction: 0.3, blendDuration: 0), value: animationTrigger)
    }
}

// Epic Shows view is now implemented in its own file

// MusicVideosView and FanCamsView are now implemented in their own files

enum FavoritesSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case artist = "Artist"
    case year = "Year (Newest)"
    case yearReverse = "Year (Oldest)"
    case dateAdded = "Date Added"
    case dateAddedReverse = "Date Added (Oldest)"
    
    var id: String { rawValue }
}

struct FavoritesView: View {
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var sortOption: FavoritesSortOption = .dateAdded
    @State private var showingSortOptions = false
    @State private var selectedFavoriteVideoId: String?

    // Simplified 2-column grid
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private let gridSpacing: CGFloat = 16
    
    private var sortedFavorites: [FavoriteVideo] {
        let favorites = favoritesService.favoriteVideos
        
        switch sortOption {
        case .name:
            return favorites.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return favorites.sorted { 
                if $0.artist == $1.artist {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
            }
        case .year:
            return favorites.sorted {
                if let year1 = Int($0.year), let year2 = Int($1.year) {
                    if year1 == year2 {
                        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                    return year1 > year2 // Newest first
                }
                return $0.year > $1.year
            }
        case .yearReverse:
            return favorites.sorted {
                if let year1 = Int($0.year), let year2 = Int($1.year) {
                    if year1 == year2 {
                        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                    return year1 < year2 // Oldest first
                }
                return $0.year < $1.year
            }
        case .dateAdded:
            return favorites.sorted { $0.dateAdded > $1.dateAdded } // Most recent first
        case .dateAddedReverse:
            return favorites.sorted { $0.dateAdded < $1.dateAdded } // Oldest first
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
            // iPad only: Custom header row (Row 2)
            if UIDevice.current.userInterfaceIdiom == .pad {
                HStack {
                    // Sort button (left aligned) - only show when authenticated and has favorites
                    if authService.isAuthenticated && !favoritesService.favoriteVideos.isEmpty {
                        Button(action: {
                            showingSortOptions = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 18))
                                    .foregroundColor(.hitRewindPurple)
                                Text("Sort")
                                    .font(.custom(AppFont.ticketingName(), size: 16))
                                    .foregroundColor(.hitRewindPurple)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Logo centered
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                    
                    Spacer()
                    
                    // Search and settings on right
                    HStack(spacing: 16) {
                        NavigationLink(destination: SearchView()) {
                            Text("🔍")
                        }
                        NavigationLink(destination: SettingsView()) {
                            Text("⚙️")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.hitRewindBackground)
            }
            
            Group {
                if !authService.isAuthenticated {
                    signInPromptView
                } else if favoritesService.favoriteVideos.isEmpty {
                    emptyFavoritesView
                } else {
                    favoritesGridView
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
.navigationBarHidden(false)
        .toolbar {
            // iPhone only: Keep existing toolbar structure
            if UIDevice.current.userInterfaceIdiom != .pad {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if authService.isAuthenticated && !favoritesService.favoriteVideos.isEmpty {
                        Button(action: {
                            showingSortOptions = true
                        }) {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.hitRewindPurple)
                        }
                    } else {
                        // Empty space to maintain layout
                        Color.clear
                            .frame(width: 44, height: 44)
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
        }
        .confirmationDialog("Sort favorites by", isPresented: $showingSortOptions) {
            ForEach(FavoritesSortOption.allCases) { option in
                Button(option.rawValue) {
                    sortOption = option
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        }
    }
    
    private var signInPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.circle")
                .font(.system(size: 64))
                .foregroundColor(.hitRewindPurple)
            
            Text("Sign In to Save Favorites")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)
            
            Text("Sign in with Apple to save your favorite music videos and sync them across all your devices.")
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                authService.signInWithApple()
            }) {
                HStack {
                    Image(systemName: "applelogo")
                    Text("Sign in with Apple")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 25))
            }
            .disabled(authService.isLoading)
        }
        .padding()
    }
    
    private var emptyFavoritesView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart")
                .font(.system(size: 64))
                .foregroundColor(.hitRewindSecondaryText)
            
            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.hitRewindPrimaryText)
            
            Text("Tap the heart icon on any music video to add it to your favorites.")
                .font(.body)
                .foregroundColor(.hitRewindSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
    
    private var favoritesGridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(sortedFavorites) { favorite in
                    Button(action: {
                        handleFavoriteVideoTap(favorite: favorite)
                    }) {
                        VideoThumbnailView(
                            videoId: favorite.videoId,
                            title: favorite.title,
                            artist: favorite.artist,
                            year: favorite.year,
                            onTap: {
                                print("🎥 Favorite video tapped: \(favorite.title) by \(favorite.artist)")
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(gridSpacing)
            .navigationDestination(isPresented: Binding(
                get: { selectedFavoriteVideoId != nil },
                set: { if !$0 { selectedFavoriteVideoId = nil } }
            )) {
                if let videoId = selectedFavoriteVideoId,
                   let favorite = sortedFavorites.first(where: { $0.videoId == videoId }) {
                    createVideoView(from: favorite)
                }
            }
        }
        .refreshable {
            favoritesService.syncWithCloud()
        }
    }

    // MARK: - Helper Methods

    private func handleFavoriteVideoTap(favorite: FavoriteVideo) {
        print("🎥 Favorite video \(favorite.videoId) tapped")

        Task { @MainActor in
            // Check StoreKit directly for active subscription
            let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()

            if isSubscribed {
                // User is subscribed - play video immediately
                print("✅ User subscribed - playing video")
                self.selectedFavoriteVideoId = favorite.videoId
            } else {
                // User not subscribed - show paywall
                print("🔒 User not subscribed - showing paywall")
                Superwall.shared.register(placement: "MainPlacement") {
                    // After successful purchase, play video
                    print("✅ Purchase complete - playing video")
                    self.selectedFavoriteVideoId = favorite.videoId
                }
            }
        }
    }

    private func createVideoView(from favorite: FavoriteVideo) -> SingleVideoView {
        // Build playlist context for autoplay (all favorites in current sort order)
        let playlistVideos = sortedFavorites.map { fav in
            PlaylistVideo(
                id: fav.videoId,
                youtubeURL: "https://www.youtube.com/watch?v=\(fav.videoId)",
                title: fav.title,
                artist: fav.artist,
                year: fav.year
            )
        }

        // Find current video index
        guard let currentIndex = playlistVideos.firstIndex(where: { $0.id == favorite.videoId }) else {
            print("⚠️ Could not find video index for autoplay")
            return SingleVideoView(
                youtubeURL: "https://www.youtube.com/watch?v=\(favorite.videoId)",
                videoTitle: favorite.title,
                artistName: favorite.artist,
                year: favorite.year,
                playlistContext: nil
            )
        }

        let playlistContext = PlaylistContext(
            videos: playlistVideos,
            currentIndex: currentIndex
        )

        return SingleVideoView(
            youtubeURL: "https://www.youtube.com/watch?v=\(favorite.videoId)",
            videoTitle: favorite.title,
            artistName: favorite.artist,
            year: favorite.year,
            playlistContext: playlistContext
        )
    }
}

// SettingsView is now implemented in EpicShowsView.swift

// MARK: - AirPlay Helper
class AirPlayHelper: NSObject, ObservableObject {
    static let shared = AirPlayHelper()
    
    private override init() {
        super.init()
    }
    
    func showAirPlayPicker() {
        DispatchQueue.main.async {
            // Create a temporary route picker view
            let routePickerView = AVRoutePickerView()
            routePickerView.tintColor = UIColor(red: 0.65, green: 0.53, blue: 0.99, alpha: 1.0)
            routePickerView.activeTintColor = UIColor(red: 0.65, green: 0.53, blue: 0.99, alpha: 1.0)
            routePickerView.backgroundColor = .clear
            
            // Add to the key window but hide it
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            routePickerView.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
            routePickerView.alpha = 0.01 // Nearly invisible but functional
            window.addSubview(routePickerView)
            
            // Trigger the picker after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Find and tap the button
                for subview in routePickerView.subviews {
                    if let button = subview as? UIButton {
                        button.sendActions(for: .touchUpInside)
                        break
                    }
                }
                
                // Remove the temporary view after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    routePickerView.removeFromSuperview()
                }
            }
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - AirPlay Service
class AirPlayService: ObservableObject {
    static let shared = AirPlayService()
    
    @Published var isConnected = false
    @Published var connectedDeviceName: String?
    
    private init() {
        setupRouteChangeNotification()
        checkInitialRoute()
    }
    
    private func setupRouteChangeNotification() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange:
            checkCurrentRoute()
        default:
            break
        }
    }
    
    private func checkInitialRoute() {
        checkCurrentRoute()
    }
    
    private func checkCurrentRoute() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        
        // Check for AirPlay devices
        let airPlayOutput = outputs.first { output in
            output.portType == .airPlay
        }
        
        DispatchQueue.main.async {
            self.isConnected = airPlayOutput != nil
            self.connectedDeviceName = airPlayOutput?.portName
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - AirPlay Tab Button
struct AirPlayTabButton: UIViewRepresentable {
    @StateObject private var airPlayService = AirPlayService.shared
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let routePickerView = AVRoutePickerView()
        // Set colors based on connection status
        let yellowColor = UIColor(red: 1.0, green: 0.96, blue: 0.11, alpha: 1.0) // #FFF61D
        let purpleColor = UIColor(red: 0.82, green: 0.76, blue: 1.0, alpha: 1.0)
        
        routePickerView.tintColor = airPlayService.isConnected ? yellowColor : purpleColor
        routePickerView.activeTintColor = airPlayService.isConnected ? yellowColor : purpleColor
        routePickerView.backgroundColor = .clear
        routePickerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Make the icon smaller for tab bar
        routePickerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        containerView.addSubview(routePickerView)
        context.coordinator.routePickerView = routePickerView
        
        // Center the AirPlay button in the container
        NSLayoutConstraint.activate([
            routePickerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            routePickerView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            routePickerView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            routePickerView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        
        // Add haptic feedback when AirPlay button is tapped
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.airPlayTapped))
        containerView.addGestureRecognizer(gesture)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update colors when connection status changes
        if let routePickerView = context.coordinator.routePickerView {
            let yellowColor = UIColor(red: 1.0, green: 0.96, blue: 0.11, alpha: 1.0) // #FFF61D
            let purpleColor = UIColor(red: 0.82, green: 0.76, blue: 1.0, alpha: 1.0)
            
            routePickerView.tintColor = airPlayService.isConnected ? yellowColor : purpleColor
            routePickerView.activeTintColor = airPlayService.isConnected ? yellowColor : purpleColor
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var routePickerView: AVRoutePickerView?
        
        @objc func airPlayTapped() {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
}


// MARK: - Custom AirPlay Tab Item
struct AirPlayTabItem: View {
    @StateObject private var airPlayService = AirPlayService.shared

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "music.note.tv.fill")
                .font(.system(size: 20))
                .foregroundColor(airPlayService.isConnected ? Color(hex: "FFF61D") : .primary)

            Text("Send To TV")
                .font(.caption2)
                .foregroundColor(airPlayService.isConnected ? Color(hex: "FFF61D") : .primary)
        }
    }
}


#Preview {
    ContentView(shouldRestartOnboarding: .constant(false))
        .preferredColorScheme(.dark)
}
