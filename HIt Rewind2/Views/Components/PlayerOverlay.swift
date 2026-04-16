//
//  PlayerOverlay.swift
//  HIt Rewind2
//
//  Persistent player overlay that sits above the TabView in ContentView.
//  ONE VideoPlayerView lives here — its frame animates between full-screen
//  (VJ mode) and a small pip (mini mode). The WKWebView never leaves the
//  view hierarchy so playback is never interrupted.
//

import SwiftUI
import AVKit

struct PlayerOverlay: View {
    @ObservedObject var manager: MiniPlayerManager
    @StateObject private var favoritesService = FavoritesService.shared
    @StateObject private var authService = AuthenticationService.shared

    @State private var isAirPlayActive: Bool = false
    @State private var showScreenShareTutorial: Bool = false
    @State private var timeUpdateTimer: Timer?

    // VJ control widths
    private let controlStripWidth: CGFloat = 70
    private let videoStackWidth: CGFloat = 140
    private var rightPanelWidth: CGFloat { controlStripWidth + 12 + videoStackWidth }

    // Bottom bar
    private var progressBarHeight: CGFloat { 36 }
    private var pickerHeight: CGFloat { 28 }
    private var bottomBarHeight: CGFloat { manager.showPicker ? progressBarHeight + pickerHeight : progressBarHeight }

    // Bottom safe area (home indicator in landscape)
    private var bottomSafeArea: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return 0 }
        return window.safeAreaInsets.bottom
    }

    // Mini player size (~10% larger than 192×108, 50% larger on iPad)
    private var miniWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 317 : 211
    }
    private var miniHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 179 : 119
    }

    /// Extra offset to push mini player above tab bar in portrait orientation
    private var miniBottomOffset: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return 0 }
        if windowScene.interfaceOrientation.isPortrait {
            return 69 + bottomSafeArea  // tab bar height + home indicator + extra clearance
        }
        return 0
    }

    private var isVJ: Bool { manager.state == .vjMode }
    private var isMini: Bool { manager.state == .mini }
    private var isPortrait: Bool { manager.state == .portrait }

    private var portraitSourceTitle: String? {
        switch manager.sourceType {
        case .musicVideos: return "TOP 100"
        case .live: return manager.selectedArtist?.uppercased() ?? "ARTISTS"
        case .epicShows, .concert: return nil
        }
    }

    private var topSafeArea: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return 0 }
        return window.safeAreaInsets.top
    }

    var body: some View {
        if manager.state != .hidden, let video = manager.currentVideo {
            GeometryReader { geo in
                let w = max(1, geo.size.width)
                let h = max(1, geo.size.height)

                let vjW = manager.controlsVisible ? max(1, w - rightPanelWidth) : w
                let vjH = manager.controlsVisible ? max(1, h - bottomBarHeight - bottomSafeArea) : h

                let portraitVideoH = w * 9 / 16
                // Fullscreen portrait: video rotated 90°, so swap w/h to fill screen
                let fullscreenVideoW = h  // screen height becomes video width
                let fullscreenVideoH = h * 9 / 16  // maintain 16:9 aspect
                let videoW = isPortrait ? (manager.isPortraitFullscreen ? fullscreenVideoW : w) : (isVJ ? vjW : miniWidth)
                let videoH = isPortrait ? (manager.isPortraitFullscreen ? fullscreenVideoH : portraitVideoH) : (isVJ ? vjH : miniHeight)

                ZStack(alignment: .topLeading) {
                    // Black bg in VJ mode, portrait mode, and portrait fullscreen
                    if isVJ || isPortrait {
                        Color.black.ignoresSafeArea()
                    }

                    // ── THE ONE VIDEO PLAYER ──
                    // .position() gives absolute screen coords inside ignoresSafeArea GeometryReader
                    // VJ: centered in its video area (top-left region)
                    // Mini: pinned to absolute bottom-left corner of screen
                    VideoPlayerView(youtubeURL: video.youtubeURL, coordinator: manager.playerCoordinator)
                        .frame(width: videoW, height: videoH)
                        .clipped()
                        .background(Color.black)
                        .rotationEffect(isPortrait && manager.isPortraitFullscreen ? .degrees(90) : .degrees(0))
                        .overlay {
                            if isMini {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        manager.expandToPortrait()
                                    }
                            } else {
                                // Block touches from reaching YouTube's WKWebView
                                // Prevents YouTube logo, title, and play icon overlays
                                Color.clear
                                    .contentShape(Rectangle())
                                    .allowsHitTesting(true)
                            }
                        }
                        .position(
                            x: isPortrait ? w / 2 : (isMini ? miniWidth / 2 - 13 : vjW / 2),
                            y: isPortrait ? (manager.isPortraitFullscreen ? h / 2 : topSafeArea + portraitTikTokSpace + portraitTopRowHeight + portraitContextHeight + 3 + portraitVideoH / 2) : (isMini ? h - miniHeight / 2 + 20 - miniBottomOffset : vjH / 2)
                        )

                    // ── VJ BOTTOM BAR ──
                    if isVJ && manager.controlsVisible {
                        VStack {
                            Spacer()
                            vjBottomBar(screenWidth: w)
                                .padding(.bottom, bottomSafeArea)
                        }
                    }

                    // ── VJ RIGHT PANELS ──
                    if isVJ {
                        HStack(spacing: 0) {
                            Spacer()

                            VJModeControlStrip(
                                playerCoordinator: manager.playerCoordinator,
                                isFavorited: $manager.isFavorited,
                                artistName: manager.currentVideo?.artist ?? "",
                                showArtistButton: !manager.isLiveMode,
                                onFavoriteToggle: { manager.toggleFavorite() },
                                onArtistTap: { manager.loadArtistVideos() },
                                onNextVideo: { manager.playNextVideo() }
                            )
                            .frame(width: controlStripWidth)
                            .padding(.horizontal, 6)

                            VJModeVideoStack(
                                videos: manager.displayedVideos,
                                currentVideoId: manager.currentVideo?.id ?? "",
                                onVideoSelect: { v in manager.playVideo(v) },
                                showYearSubtitle: manager.isLiveMode
                            )
                            .frame(width: videoStackWidth)
                        }
                        .offset(x: manager.controlsVisible ? 0 : rightPanelWidth + 20)
                        .animation(.easeInOut(duration: 0.35), value: manager.controlsVisible)

                        leftSideButtons

                        if !manager.controlsVisible {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        manager.controlsVisible = true
                                    }
                                }
                        }
                    }

                    // ── MINI BUTTONS (top-left, expand above close) ──
                    if isMini {
                        VStack(spacing: 6) {
                            Button(action: { manager.playerCoordinator.togglePlayPause() }) {
                                Image(systemName: manager.playerCoordinator.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }

                            Button(action: { manager.close() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                        }
                        .position(x: 6 + 16, y: h - miniHeight + 20 + 40 - miniBottomOffset)
                    }

                    // ── PORTRAIT FULLSCREEN: just a collapse button ──
                    if isPortrait && manager.isPortraitFullscreen {
                        // Tap anywhere to show/hide the collapse button
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    manager.controlsVisible.toggle()
                                }
                            }

                        if manager.controlsVisible {
                            VStack {
                                HStack {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            manager.isPortraitFullscreen = false
                                        }
                                    }) {
                                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                            .frame(width: 38, height: 38)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                    }
                                    .padding(.leading, 16)
                                    .padding(.top, topSafeArea + 8)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                    }

                    // ── PORTRAIT MODE UI ──
                    if isPortrait && !manager.isPortraitFullscreen {
                        // Main content layout
                        VStack(spacing: 0) {
                            // TikTok bar space (safe area + padding)
                            Color.clear.frame(height: topSafeArea + portraitTikTokSpace)

                            // Top button row — same 4 buttons as landscape left side
                            portraitTopButtonRow
                                .padding(.bottom, 4)

                            // Context area (varies by source type)
                            portraitContextArea(video: video, w: w)
                                .frame(height: portraitContextHeight)

                            // Small gap above video
                            Color.clear.frame(height: 3)

                            // Transparent gap for video (video is positioned absolutely)
                            Color.clear.frame(height: portraitVideoH)

                            Color.clear.frame(height: 6)

                            // Progress bar — same as landscape VJ bottom bar
                            VJModeProgressBar(
                                currentTime: manager.playerCoordinator.currentTime,
                                duration: manager.playerCoordinator.duration,
                                onSeek: { time in
                                    manager.playerCoordinator.seekTo(seconds: time)
                                }
                            )
                            .frame(height: 28)
                            .padding(.horizontal, 8)

                            // Controls row
                            portraitControlsRow(video: video)

                            // Artists-only: Live Library / New Release / Charts tabs
                            if manager.isLiveMode {
                                portraitArtistTabs
                            }

                            // Thumbnail scroll row
                            portraitThumbnailScroll(currentVideoId: video.id)
                                .padding(.top, 4)

                            Spacer() // Bottom empty space (TikTok covers this)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: manager.controlsVisible)
            }
            .ignoresSafeArea()
            .statusBar(hidden: isVJ || isPortrait)
            .onAppear {
                // Timer must start here — .onChange won't fire if state is already .vjMode
                // when this view first renders
                if manager.state == .vjMode || manager.state == .portrait {
                    startTimeUpdateTimer()
                    detectAirPlayState()
                }
            }
            .onDisappear {
                stopTimeUpdateTimer()
            }
            .onChange(of: manager.state) { oldValue, newValue in
                if newValue == .vjMode || newValue == .portrait {
                    startTimeUpdateTimer()
                    detectAirPlayState()
                } else if newValue == .hidden {
                    stopTimeUpdateTimer()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                if manager.state == .vjMode || manager.state == .portrait {
                    detectAirPlayState()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                // Auto-switch between portrait and VJ layout based on device orientation
                // Uses switchToVJLayout (no orientation lock) so user can freely rotate back
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    if manager.state == .portrait && windowScene.interfaceOrientation.isLandscape {
                        manager.switchToVJLayout()
                    } else if manager.state == .vjMode && windowScene.interfaceOrientation.isPortrait {
                        manager.minimizeToPortrait()
                    }
                }
            }
            .sheet(isPresented: $showScreenShareTutorial) {
                ScreenShareTutorialView(isPresented: $showScreenShareTutorial, onDismiss: {
                    showScreenShareTutorial = false
                })
            }
        }
    }

    // MARK: - VJ Bottom Bar

    private func vjBottomBar(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            VJModeProgressBar(
                currentTime: manager.playerCoordinator.currentTime,
                duration: manager.playerCoordinator.duration,
                onSeek: { time in
                    manager.playerCoordinator.seekTo(seconds: time)
                }
            )
            .frame(height: progressBarHeight)
            .padding(.trailing, 8)

            if manager.showPicker {
                VJModePicker(
                    sourceType: manager.sourceType,
                    selectedYear: $manager.selectedYear,
                    selectedArtist: $manager.selectedArtist,
                    availableYears: manager.availableYears,
                    availableArtists: manager.availableArtists,
                    onYearSelected: { year in manager.fetchVideosForYear(year, fromPicker: true) },
                    onArtistSelected: { artist in manager.fetchVideosForArtist(artist, fromPicker: true) }
                )
                .frame(height: pickerHeight)
            }
        }
        .padding(.leading, 50)
        .frame(width: max(1, screenWidth - rightPanelWidth), alignment: .leading)
        .transition(.opacity)
    }

    // MARK: - Left Side Buttons

    private var leftSideButtons: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 6) {
                    Button(action: { manager.minimizeToMini() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            manager.controlsVisible.toggle()
                        }
                    }) {
                        Image(systemName: manager.controlsVisible ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }

                Spacer().frame(height: 135)

                VStack(spacing: 6) {
                    Button(action: { AirPlayHelper.shared.showAirPlayPicker() }) {
                        Image(systemName: isAirPlayActive ? "airplayvideo.circle.fill" : "airplayvideo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isAirPlayActive ? .hitRewindPurple : .white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button(action: { showScreenShareTutorial = true }) {
                        Image(systemName: "music.note.tv")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }

                Spacer()
            }
            .padding(.leading, 8)

            Spacer()
        }
        .offset(x: manager.controlsVisible ? 0 : -80)
        .animation(.easeInOut(duration: 0.35), value: manager.controlsVisible)
    }

    // MARK: - Timer

    private func startTimeUpdateTimer() {
        stopTimeUpdateTimer()
        print("⏱️ PlayerOverlay: Starting time update timer")
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            manager.playerCoordinator.getCurrentTime()
            manager.playerCoordinator.getDuration()
        }
    }

    private func stopTimeUpdateTimer() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
    }

    // MARK: - Portrait Layout Constants

    private let portraitTikTokSpace: CGFloat = 28
    private let portraitTopRowHeight: CGFloat = 42  // 38 button + 4 bottom padding

    private var portraitContextHeight: CGFloat {
        switch manager.sourceType {
        case .musicVideos: return 44
        case .epicShows: return 89
        case .live: return 80  // genre row + artist picker
        case .concert: return manager.concertBannerImageURL != nil ? 100 : 8
        }
    }

    // MARK: - Portrait Context Areas (reuses existing VJModePicker / VJModeVideoStack styles)

    @ViewBuilder
    private func portraitContextArea(video: PlaylistVideo, w: CGFloat) -> some View {
        switch manager.sourceType {
        case .musicVideos:
            // Year picker — same VJModePicker component as landscape
            VJModePicker(
                sourceType: manager.sourceType,
                selectedYear: $manager.selectedYear,
                selectedArtist: $manager.selectedArtist,
                availableYears: manager.availableYears,
                availableArtists: [],
                onYearSelected: { year in manager.fetchVideosForYear(year, fromPicker: true) },
                onArtistSelected: { _ in }
            )
            .frame(height: 36)
            .padding(.top, 4)

        case .epicShows(let categoryName, _):
            // Category banner — same style as EpicShowsView banners
            VStack {
                Spacer()
                HStack {
                    Text(categoryName)
                        .font(.custom(AppFont.ticketingName(), size: 20))
                        .foregroundColor(.white)
                        .tracking(3)
                        .padding(.leading, 16)
                        .padding(.bottom, 10)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.35, green: 0.22, blue: 0.65).opacity(0.5), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.bottom, 4)

        case .live:
            VStack(spacing: 4) {
                // Genre/category scrolling row — same pill style as artist picker
                if !manager.categories.isEmpty {
                    ScrollViewReader { genreProxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(manager.categories) { category in
                                    let isSelected = manager.selectedCategoryName == category.name
                                    Button(action: {
                                        manager.handleCategoryChange(category)
                                    }) {
                                        Text(formattedCategoryName(category.name))
                                            .font(.custom(AppFont.ticketingName(), size: 14))
                                            .fontWeight(isSelected ? .bold : .medium)
                                            .foregroundColor(isSelected ? .black : .hitRewindPrimaryText)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(isSelected ? Color.hitRewindPurple : Color.hitRewindSecondaryBackground)
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .id(category.name)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .mask(
                            HStack(spacing: 0) {
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, .black]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 40)

                                Color.black

                                LinearGradient(
                                    gradient: Gradient(colors: [.black, .clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 40)
                            }
                        )
                        .onAppear {
                            if let selected = manager.selectedCategoryName {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation { genreProxy.scrollTo(selected, anchor: .center) }
                                }
                            }
                        }
                        .onChange(of: manager.selectedCategoryName) { _, newCat in
                            if let cat = newCat {
                                withAnimation { genreProxy.scrollTo(cat, anchor: .center) }
                            }
                        }
                    }
                    .frame(height: 36)
                    .padding(.top, 6)
                }

                // Artist picker — same VJModePicker component as landscape
                VJModePicker(
                    sourceType: manager.sourceType,
                    selectedYear: $manager.selectedYear,
                    selectedArtist: $manager.selectedArtist,
                    availableYears: [],
                    availableArtists: manager.availableArtists,
                    onYearSelected: { _ in },
                    onArtistSelected: { artist in manager.fetchVideosForArtist(artist, fromPicker: true) }
                )
                .frame(height: 36)
                .padding(.bottom, 4)
            }

        case .concert:
            if let bannerURL = manager.concertBannerImageURL,
               let url = URL(string: bannerURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    case .failure:
                        Image("missing")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    default:
                        Color.clear
                    }
                }
                .padding(.horizontal, 12)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Portrait Controls Row (same button style as VJModeControlStrip)

    private func portraitControlsRow(video: PlaylistVideo) -> some View {
        HStack(spacing: 0) {
            Spacer()

            // Favorite — same as VJModeControlStrip
            portraitControlButton(
                icon: manager.isFavorited ? "heart.fill" : "heart",
                color: manager.isFavorited ? .red : .hitRewindPurple
            ) {
                manager.toggleFavorite()
            }

            Spacer()

            // Skip forward 10s
            portraitControlButton(icon: "goforward.10", fontSize: 25) {
                manager.playerCoordinator.skipForward(seconds: 10)
            }

            Spacer()

            // Skip forward 60s
            portraitControlButton(icon: "goforward.60", fontSize: 22) {
                manager.playerCoordinator.skipForward(seconds: 60)
            }

            Spacer()

            // Play/Pause
            portraitControlButton(
                icon: manager.playerCoordinator.isPlaying ? "pause.fill" : "play.fill"
            ) {
                manager.playerCoordinator.togglePlayPause()
            }

            Spacer()

            // Skip to next
            portraitControlButton(icon: "forward.end.fill") {
                manager.playNextVideo()
            }

            Spacer()

            // Artist name + arrow (hidden when coming from Artists page)
            if !manager.isLiveMode {
                Button(action: { manager.loadArtistVideos() }) {
                    VStack(spacing: 0) {
                        Image(systemName: isPortrait ? "arrow.down.circle" : "arrow.right.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.hitRewindPurple)
                        Text(video.artist)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.hitRewindPurple)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                            .frame(width: 48)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 8)
    }

    /// Same button style as VJModeControlStrip.controlButton
    private func portraitControlButton(icon: String, color: Color = .hitRewindPurple, fontSize: CGFloat = 20, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: fontSize))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(Color(red: 0.06, green: 0.02, blue: 0.18))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Portrait Artist Tabs (Live Library / New Releases / Charts)

    private var portraitArtistTabs: some View {
        let tabs: [(label: String, tag: LiveVideoSource)] = {
            var t: [(String, LiveVideoSource)] = [("Live Library", .liveLibrary)]
            if manager.hasOfficialVideos { t.append(("New Releases", .official)) }
            if !manager.chartVideos.isEmpty { t.append(("Charts", .charts)) }
            return t
        }()

        return HStack(spacing: 6) {
            ForEach(tabs, id: \.tag) { tab in
                let isSelected = manager.selectedLiveTab == tab.tag
                Button(action: { manager.switchLiveTab(tab.tag) }) {
                    Text(tab.label)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .black : .hitRewindPrimaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.hitRewindPurple : Color.hitRewindSecondaryBackground)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Portrait Top Button Row (same 4 buttons as landscape left side)

    private var portraitTopButtonRow: some View {
        ZStack {
            // Centered source title (hidden for epic shows / concerts which have their own banner)
            if let title = portraitSourceTitle {
                Text(title)
                    .font(.custom(AppFont.ticketingName(), size: 18))
                    .foregroundColor(.white)
                    .tracking(2)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 16) {
                // Back / minimize
                Button(action: { manager.minimizeToMini() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                // Fullscreen toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        manager.isPortraitFullscreen = true
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                // AirPlay
                Button(action: { AirPlayHelper.shared.showAirPlayPicker() }) {
                    Image(systemName: isAirPlayActive ? "airplayvideo.circle.fill" : "airplayvideo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isAirPlayActive ? .hitRewindPurple : .white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                // Screen share tutorial
                Button(action: { showScreenShareTutorial = true }) {
                    Image(systemName: "music.note.tv")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Portrait Thumbnail Scroll (same thumbnail style as VJModeVideoStack)

    private func portraitThumbnailScroll(currentVideoId: String) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(manager.displayedVideos) { v in
                        let isCurrent = v.id == currentVideoId
                        Button { manager.playVideo(v) } label: {
                            VStack(spacing: 2) {
                                ZStack {
                                    YouTubeThumbnailImage(videoId: v.id)
                                        .frame(width: 120, height: 68)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                    if isCurrent {
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.hitRewindPurple, lineWidth: 2)
                                            .frame(width: 120, height: 68)

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.hitRewindPurple.opacity(0.9))
                                            .clipShape(Circle())
                                    }

                                    // Rank badge
                                    if let rank = v.rank {
                                        VStack {
                                            HStack {
                                                Spacer()
                                                Text("#\(rank)")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.black)
                                                    .padding(.horizontal, 3)
                                                    .padding(.vertical, 1)
                                                    .background(Color.hitRewindPurple)
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                                    .padding(.trailing, 2)
                                                    .padding(.top, 2)
                                            }
                                            Spacer()
                                        }
                                        .frame(width: 120, height: 68)
                                    }
                                }

                                // Title — same as VJModeVideoThumbnail
                                Text(v.title)
                                    .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                                    .foregroundColor(isCurrent ? .white : .white.opacity(0.8))
                                    .lineLimit(2)
                                    .frame(width: 120, alignment: .leading)

                                // Subtitle (artist, year, or relative date) + duration
                                HStack {
                                    Text(subtitleForVideo(v))
                                        .font(.system(size: 11))
                                        .foregroundColor(.hitRewindPurple)
                                        .lineLimit(1)
                                    Spacer()
                                    if let duration = v.duration, !duration.isEmpty {
                                        Text(duration)
                                            .font(.system(size: 10))
                                            .foregroundColor(.hitRewindSecondaryText)
                                    }
                                }
                                .frame(width: 120)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isCurrent ? Color.hitRewindPurple.opacity(0.15) : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id(v.id)
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: currentVideoId) { _, newId in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
            .onChange(of: manager.displayedVideos.map { $0.id }) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(currentVideoId, anchor: .center)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(currentVideoId, anchor: .center)
                }
            }
        }
        .frame(height: 120)
    }

    // MARK: - Category Name Formatting (same as FanCamsView)

    private func formattedCategoryName(_ name: String) -> String {
        switch name.lowercased() {
        case "pop": return "💋 Pop"
        case "modern rock": return "🎸 Modern Rock"
        case "classic rock": return "🤘 Classic Rock"
        case "jam bands": return "🍄 Jam Bands"
        case "jazz": return "🎺 Jazz"
        case "country": return "👢 Country"
        case "latin": return "🌶️ Latin"
        case "indi", "indie": return "☕ Indi"
        case "r&b": return "🕯️ R&B"
        case "electronic": return "🎧 Electronic"
        case "hip hop": return "🍑 Hip Hop"
        default: return name
        }
    }

    // MARK: - Thumbnail Subtitle

    private func subtitleForVideo(_ video: PlaylistVideo) -> String {
        // New Releases tab: show relative date (Today, Yesterday, weekday, or M/D/YYYY)
        if manager.isLiveMode && manager.selectedLiveTab == .official {
            return formatRelativeDate(video.year)
        }
        // Live mode (non-official): show year
        if manager.isLiveMode && !video.year.isEmpty {
            // If it's a full ISO date, extract just the year
            if video.year.count > 4 {
                return String(video.year.prefix(4))
            }
            return video.year
        }
        // Default: show artist
        return video.artist
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let fallbackDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func formatRelativeDate(_ dateString: String) -> String {
        guard !dateString.isEmpty else { return "" }

        // Parse the ISO date
        let date: Date?
        if let d = Self.isoDateFormatter.date(from: dateString) {
            date = d
        } else if let d = Self.fallbackDateFormatter.date(from: dateString) {
            date = d
        } else {
            // Not a date string, return as-is (e.g. just a year)
            return dateString
        }

        guard let parsed = date else { return dateString }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(parsed) {
            return "Today"
        } else if calendar.isDateInYesterday(parsed) {
            return "Yesterday"
        } else {
            // Within the last 7 days: show weekday name
            let daysAgo = calendar.dateComponents([.day], from: parsed, to: now).day ?? 999
            if daysAgo >= 0 && daysAgo < 7 {
                let weekdayFormatter = DateFormatter()
                weekdayFormatter.dateFormat = "EEEE"  // e.g. "Thursday"
                return weekdayFormatter.string(from: parsed)
            }
            // Older: show M/D/YYYY
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "M/d/yyyy"
            return displayFormatter.string(from: parsed)
        }
    }

    // MARK: - AirPlay

    private func detectAirPlayState() {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute
        let hasAirPlayOutput = currentRoute.outputs.contains { output in
            output.portType == .airPlay || output.portType == .HDMI || output.portType == .carAudio
        }
        DispatchQueue.main.async {
            isAirPlayActive = hasAirPlayOutput
        }
    }
}
