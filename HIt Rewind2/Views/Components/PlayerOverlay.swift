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

    // Mini player size (~10% larger than 192×108)
    private let miniWidth: CGFloat = 211
    private let miniHeight: CGFloat = 119

    private var isVJ: Bool { manager.state == .vjMode }
    private var isMini: Bool { manager.state == .mini }

    var body: some View {
        if manager.state != .hidden, let video = manager.currentVideo {
            GeometryReader { geo in
                let w = max(1, geo.size.width)
                let h = max(1, geo.size.height)

                let vjW = manager.controlsVisible ? max(1, w - rightPanelWidth) : w
                let vjH = manager.controlsVisible ? max(1, h - bottomBarHeight - bottomSafeArea) : h

                let videoW = isVJ ? vjW : miniWidth
                let videoH = isVJ ? vjH : miniHeight

                ZStack(alignment: .topLeading) {
                    // Black bg in VJ mode only
                    if isVJ {
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
                        .position(
                            x: isMini ? miniWidth / 2 - 13 : vjW / 2,
                            y: isMini ? h - miniHeight / 2 + 20 : vjH / 2
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
                                onVideoSelect: { v in manager.playVideo(v) }
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
                            Button(action: { manager.expandToVJMode() }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
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
                        .position(x: 6 + 16, y: h - miniHeight + 20 + 40)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: manager.controlsVisible)
            }
            .ignoresSafeArea()
            .statusBar(hidden: isVJ)
            .onAppear {
                // Timer must start here — .onChange won't fire if state is already .vjMode
                // when this view first renders
                if manager.state == .vjMode {
                    startTimeUpdateTimer()
                    detectAirPlayState()
                }
            }
            .onDisappear {
                stopTimeUpdateTimer()
            }
            .onChange(of: manager.state) { oldValue, newValue in
                if newValue == .vjMode {
                    startTimeUpdateTimer()
                    detectAirPlayState()
                } else if newValue == .hidden {
                    stopTimeUpdateTimer()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                if manager.state == .vjMode {
                    detectAirPlayState()
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
                    onYearSelected: { year in manager.fetchVideosForYear(year) },
                    onArtistSelected: { artist in manager.fetchVideosForArtist(artist) }
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
