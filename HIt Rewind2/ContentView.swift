//
//  ContentView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI
import AVFoundation
import AVKit

// MARK: - Notification Extensions
extension Notification.Name {
    static let videoPlayerPresented = Notification.Name("videoPlayerPresented")
    static let videoPlayerDismissed = Notification.Name("videoPlayerDismissed")
    static let playerSkipBackward = Notification.Name("playerSkipBackward")
    static let playerTogglePlayPause = Notification.Name("playerTogglePlayPause")
    static let playerSkipForward = Notification.Name("playerSkipForward")
}

struct ContentView: View {
    @State private var heartAnimationTrigger = false
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showingVideoPlayer = false
    @State private var currentVideoInfo: (id: String, title: String, artist: String, year: String)?
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var isAirPlayActive = false
    
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
                    Text("Music Videos")
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
                    Text("Live Shows")
                }
                .tag(3)
            
            FavoritesView()
                .tabItem {
                    AnimatedHeartTabIcon(animationTrigger: heartAnimationTrigger)
                    Text("Favorites")
                }
                .tag(4)
        }
        .overlay(
            // Video player controls overlay - positioned above tab bar
            Group {
                if showingVideoPlayer, let videoInfo = currentVideoInfo {
                    VStack {
                        Spacer() // Push controls to bottom
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.orange, lineWidth: 2) // DEBUG: Orange border around Spacer
                            )
                        VStack(spacing: 8) {
                        // Video info
                        VStack(spacing: 4) {
                            Text(videoInfo.year)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
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
                        .padding(.horizontal, 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.green, lineWidth: 2) // DEBUG: Green border
                        )

                        // Control buttons
                        HStack(spacing: 16) {
                            Button(action: {
                                if authService.isAuthenticated {
                                    favoritesService.toggleFavorite(videoId: videoInfo.id, title: videoInfo.title, artist: videoInfo.artist, year: videoInfo.year)
                                } else {
                                    authService.signInWithApple()
                                }
                            }) {
                                Image(systemName: favoritesService.isFavorited(videoInfo.id) ? "heart.fill" : "heart")
                                    .font(.system(size: 20))
                                    .foregroundColor(favoritesService.isFavorited(videoInfo.id) ? .red : Color(red: 0.65, green: 0.53, blue: 0.99))
                                    .frame(width: 60, height: 60)
                                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }

                            Button(action: {
                                // Send notification to VideoPlayerView to skip backward
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
                                // Send notification to VideoPlayerView to toggle play/pause
                                NotificationCenter.default.post(name: .playerTogglePlayPause, object: nil)
                            }) {
                                Image(systemName: "play.fill") // Static icon for now
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                                    .frame(width: 60, height: 60)
                                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }

                            Button(action: {
                                // Send notification to VideoPlayerView to skip forward
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
                                AirPlayHelper.shared.showAirPlayPicker()
                            }) {
                                Image(systemName: "airplayvideo")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(red: 0.65, green: 0.53, blue: 0.99))
                                    .frame(width: 60, height: 60)
                                    .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow, lineWidth: 2) // DEBUG: Yellow border
                        )
                        }
                        .padding(.horizontal, 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red, lineWidth: 3) // DEBUG: Red border around controls
                        )
                        
                        // Fixed height spacer to keep controls above tab bar
                        Color.clear
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.purple, lineWidth: 2) // DEBUG: Purple border for tab bar spacer
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.blue, lineWidth: 4) // DEBUG: Blue border around full VStack
                    )
                }
            }
        )
        .accentColor(Color.hitRewindPurple)
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
            showingVideoPlayer = false
            currentVideoInfo = nil
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
}

// MARK: - Animated Heart Tab Icon
struct AnimatedHeartTabIcon: View {
    let animationTrigger: Bool
    
    var body: some View {
        Image(systemName: "heart.fill")
            .scaleEffect(animationTrigger ? 1.3 : 1.0)
            .foregroundColor(animationTrigger ? .red : .primary)
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
        NavigationView {
            Group {
                if !authService.isAuthenticated {
                    signInPromptView
                } else if favoritesService.favoriteVideos.isEmpty {
                    emptyFavoritesView
                } else {
                    favoritesGridView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Favorites")
                        .font(.custom(AppFont.ticketingName(), size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(.hitRewindPrimaryText)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if authService.isAuthenticated && !favoritesService.favoriteVideos.isEmpty {
                        Button(action: {
                            showingSortOptions = true
                        }) {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.hitRewindPurple)
                        }
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
                    NavigationLink(destination: SingleVideoView(
                        videoId: favorite.videoId,
                        videoTitle: favorite.title,
                        artistName: favorite.artist,
                        year: favorite.year
                    )) {
                        VideoThumbnailView(
                            videoId: favorite.videoId,
                            title: favorite.title,
                            artist: favorite.artist,
                            year: favorite.year,
                            onTap: {}
                        )
                    }
                }
            }
            .padding(gridSpacing)
        }
        .refreshable {
            favoritesService.syncWithCloud()
        }
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
            
            if let deviceName = airPlayService.connectedDeviceName, airPlayService.isConnected {
                Text(deviceName)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "FFF61D"))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}


#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
