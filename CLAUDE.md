# Hit Rewind 2 - iOS App

## Project Overview
Hit Rewind is a music video streaming app featuring Billboard Hot 100 songs, concert footage, and live performances. The app is built with SwiftUI, uses Airtable as the backend, and features a VJ Mode for immersive video playback.

## Architecture

### Core Stack
- **SwiftUI** - UI framework
- **Airtable** - Backend database via REST API
- **YouTube iOS Player Helper** - Video playback (YouTubeiOSPlayerHelper)
- **Superwall** - Paywall/subscription management
- **Firebase** - Analytics
- **CloudKit** - Favorites sync across devices
- **Sign in with Apple** - Authentication

### Orientation & Display
- **Landscape-only** for main app (locked to landscape-right)
- **Portrait mode** only for onboarding and paywall
- **Dark mode only** - no light mode support
- Managed by `OrientationManager.shared`

## Tab Structure

| Tab | View | Description |
|-----|------|-------------|
| Collections | `EpicShowsView` | Concert banners and featured shows |
| Top 100 | `NEWVideosView` | Billboard Hot 100 music videos by year (segmented picker: Top 100 / Charts) |
| Artists | `FanCamsView` | Artist-based concert footage and fan cams |
| Favorites | `FavoritesView` | User's favorited videos (requires sign-in) |
| More | `MoreMenuView` | Search and Settings access |

## Key Features

### VJ Mode (`VJModeView`)
The primary video player experience. Landscape-only interface with:
- YouTube video playback via `YouTubePlayerCoordinator`
- Control strip (play/pause, skip, favorite, AirPlay)
- Video queue/stack for browsing
- Year/artist picker for navigation
- Screen share tutorial for AirPlay

### Onboarding Flow
- `OnboardingView` - Main onboarding container
- `OnboardingPageView` - Individual onboarding pages
- `PostOnboardingPaywallView` - Paywall after onboarding
- Runs in **portrait mode**, then locks to landscape after completion

### Paywall System
- `PaywallService` - Manages Superwall integration
- Switches to portrait for paywall display
- Test modes: `testSubscriberMode` and `testUnsubscriberMode`
- Subscription check via StoreKit in `HIt_Rewind2App.hasActiveSubscription()`

### Favorites System
- `FavoritesService` - CloudKit-based with local fallback
- `AuthenticationService` - Sign in with Apple
- Heart icons on all video thumbnails
- Syncs across devices when signed in

## File Structure

```
HIt Rewind2/
├── HIt_Rewind2App.swift          # App entry, Firebase/Superwall config
├── ContentView.swift             # TabView container, FavoritesView, MoreMenuView
├── HIt Rewind2.entitlements      # Sign in with Apple + CloudKit
│
├── Constants/
│   └── Constants.swift           # API keys, Superwall config
│
├── Extensions/
│   ├── AppFont.swift             # Custom Ticketing font
│   ├── Array+SafeAccess.swift    # Safe array subscripting
│   ├── Color+Extensions.swift    # hitRewindPurple, theme colors
│   ├── FontLoader.swift          # Font registration
│   ├── NavigationConfigurator.swift
│   ├── OnboardingEnvironment.swift
│   └── PerformanceTimer.swift    # Debug timing
│
├── Models/
│   ├── Concert.swift             # Concert data model
│   ├── ConcertVideo.swift        # Concert video model
│   ├── FanCamCategory.swift      # Fan cam categories
│   ├── LegendaryCategory.swift   # Legendary show categories
│   ├── LegendaryShow.swift       # Legendary show model
│   ├── OnboardingPage.swift      # Onboarding page data
│   ├── PlaylistContext.swift     # Video playlist for autoplay
│   ├── PlaylistModel.swift       # Airtable playlist structures
│   ├── SpotifyChartVideo.swift   # Spotify chart data
│   └── VideoModel.swift          # Generic video model
│
├── Services/
│   ├── AirtableService.swift     # Main Airtable API client
│   ├── AuthenticationService.swift # Sign in with Apple
│   ├── DirectVideoService.swift  # MTvVideosNEW table access
│   ├── FavoritesService.swift    # CloudKit favorites
│   ├── ImageCache.swift          # Image caching
│   ├── ImagePreloader.swift      # Preload thumbnails
│   ├── OnboardingAudioService.swift # Onboarding audio
│   ├── PaywallService.swift      # Superwall integration
│   ├── SearchService.swift       # Search functionality
│   ├── VideoPlayerManager.swift  # Player state management
│   └── YouTubeService.swift      # YouTube Data API v3
│
├── Utilities/
│   └── OrientationManager.swift  # Device orientation control
│
└── Views/
    ├── Components/
    │   └── HeadroomHeader.swift  # Reusable header component
    │
    ├── EpicShows/
    │   ├── ConcertBannerView.swift
    │   ├── ConcertDetailView.swift
    │   └── EpicShowsView.swift
    │
    ├── FanCams/
    │   ├── ArtistSidebarView.swift
    │   ├── CategoryBannerView.swift
    │   ├── CategorySidebarView.swift
    │   └── FanCamsView.swift
    │
    ├── MusicVideos/
    │   ├── ArtistSongsView.swift
    │   ├── MusicVideosView.swift    # Legacy view
    │   ├── NEWVideosView.swift      # Current Top 100 view
    │   ├── VideoPlayerView.swift    # Legacy player
    │   ├── VideoThumbnailView.swift # Video card component
    │   └── YearSidebarView.swift
    │
    ├── VJMode/
    │   ├── ScreenShareTutorialView.swift
    │   ├── VJModeControlStrip.swift
    │   ├── VJModeOverlay.swift
    │   ├── VJModePicker.swift
    │   ├── VJModeVideoStack.swift
    │   └── VJModeView.swift         # Main video player
    │
    ├── AnimatedGIFView.swift
    ├── GIFCarouselView.swift
    ├── LoopingVideoPlayerView.swift
    ├── OnboardingPageView.swift
    ├── OnboardingView.swift
    ├── PanningImageView.swift
    ├── PostOnboardingPaywallView.swift
    ├── SearchView.swift
    ├── SignInSheetView.swift
    └── TVCarouselView.swift
```

## Theme Colors

```swift
Color.hitRewindPurple      // #A789FD - Primary accent
Color.hitRewindBackground  // Dark background
Color.hitRewindPrimaryText // Primary text
Color.hitRewindSecondaryText // Secondary/muted text
```

## Airtable Integration

### Base & Tables
- **Base ID**: `appxCBIOkiJEZiph7`
- **MTvVideosNEW** (active): `tblNwqwVyflL8hNDy` - Billboard Hot 100 music videos
- **MTvVideos** (**DEPRECATED — DO NOT USE**): `tbl3waFYL7jfER18L` — All music video data lives in **MTvVideosNEW**
- **Videos**: `tblTtRP4kdTDvfrBY` — Source for **Collections page legendary categories** (`LegendaryShow` multi-select field). Do NOT confuse with MTvVideosNEW.
- **Concerts**: `tbl9umYOUTEVUZKnh`
- **Concert Videos**: `tbloVr52R37ZRNLFS`
- **Artists**: `tblu9a6MnrdzECJFJ`
- **Category**: `tblhHeWHex8DXdq3R`
- **MTvPlaylists** (**DEPRECATED — DO NOT USE**): `tblByi6o9LzE3bkc4` — All music video data lives in **MTvVideosNEW**

### MTvVideosNEW Fields
- `title` - Song title
- `url` - YouTube video URL
- `Rank` - Billboard chart position (1-100)
- `artistName` - Primary artist
- `year` - Chart year
- `videoImage` - Formula: YouTube thumbnail URL

## Billboard Hot 100 Video Collection

The video library is sourced from Billboard Year-End Hot 100 charts.

### Reference Data
- **Source**: `Full_Billboard_year_end_hot_100_USA.csv` (1946-2025)
- **Format**: `No., Title, Artist(s), Year`
- **Digital Dream Door**: Use `https://digitaldreamdoor.com/pages/bg_hits/bg_hits_YY.html` (where YY = 2-digit year) as the canonical song list for each year. Cross-reference DB records against this list.

### Years Completed
- 1973-1979 (pre-MTV era)
- 1980s (full decade)
- 1990s (full decade)
- 2001, 2002, 2021, 2022, 2023, 2024, 2025

### Adding New Videos
1. Extract songs from Billboard CSV
2. Search YouTube via **web search** (NOT the YouTube Data API — do not use the app's YouTube API key for video searches, it burns quota needed for the app)
3. Clean artist name (remove "featuring", etc.)
4. Add to MTvVideosNEW via Airtable MCP or API

## Development Notes

### Orientation Handling
```swift
// Lock to landscape (main app)
OrientationManager.shared.lockToLandscape()

// Portrait for paywall
OrientationManager.shared.switchToPortraitForPaywall()

// Portrait for onboarding
OrientationManager.shared.switchToPortraitForOnboarding()
```

### Subscription Check
```swift
let isSubscribed = await HIt_Rewind2App.hasActiveSubscription()
if isSubscribed {
    // Play video
} else {
    PaywallService.shared.presentPaywallWithOrientation { /* success */ }
}
```

### Video Playback Flow
1. User taps video thumbnail
2. Check subscription status
3. If not subscribed, show paywall
4. On success, navigate to `VJModeView`
5. VJMode handles playback, controls, and queue

## Build Requirements

### Xcode Capabilities
- Sign in with Apple
- CloudKit (for favorites sync)
- Push Notifications (optional)

### Dependencies (SPM)
- YouTubeiOSPlayerHelper
- SuperwallKit
- Firebase (FirebaseAnalytics)

### API Keys (in Constants.swift)
- Airtable API key
- YouTube Data API v3 key
- Superwall API key

## VJ Mode Sidebar Subtitle Rules

The right-hand video stack sidebar (`VJModeVideoStack`) shows a subtitle under each video title. What to display depends on context:

| Page / Tab | Subtitle Shows | Why |
|------------|---------------|-----|
| Top 100 (any year) | **Artist name** | User already knows the year from the picker |
| Artists > Live Library | **Year** | User already knows the artist |
| Artists > Official | **Year** | User already knows the artist |
| Epic Shows / Concerts | **Artist name** | Mixed artists in a category |

Controlled by the `showYearSubtitle` parameter on `VJModeVideoStack`. When `true`, shows year; when `false` (default), shows artist.

## Known Patterns

### Singleton Services
Most services use the singleton pattern:
```swift
FavoritesService.shared
AuthenticationService.shared
DirectVideoService.shared
OrientationManager.shared
PaywallService.shared
```

### Video Thumbnail Loading
`VideoThumbnailView` handles:
- AsyncImage loading with fallbacks
- Heart icon overlay for favorites
- Duration badge (optional)
- Artist/title labels

### Notification-Based Communication
```swift
.videoPlayerPresented    // Video started
.videoPlayerDismissed    // Video ended
.playerTogglePlayPause   // Play/pause control
.playerSkipForward       // Skip 10s
.showSignInSheet         // Trigger sign-in
.favoriteAdded           // Animate heart
```

## Paywall Portrait Orientation System (WORKING SOLUTION)

### Goal
Show Superwall paywall in portrait mode while main app is landscape-locked on iPhone.

### Architecture Overview

The solution uses a **UIViewController wrapper** (`PortraitPaywallHost`) that:
1. Forces portrait orientation via `supportedInterfaceOrientations`
2. Presents itself fullscreen before showing Superwall
3. Uses Superwall's delegate to know when paywall dismisses
4. Switches orientation permissions before dismissing itself

### Key Files

| File | Purpose |
|------|---------|
| `PortraitPaywallHost.swift` | UIViewController that forces portrait, hosts Superwall |
| `PaywallService.swift` | Entry point, manages Superwall delegate |
| `OrientationManager.swift` | Tracks `isPaywallShowing` flag, returns allowed orientations |
| `HIt_Rewind2App.swift` | AppDelegate calls `OrientationManager.shared.supportedOrientations()` |

### Flow Diagram

```
User taps locked video
        ↓
PaywallService.presentPaywallWithOrientation()
        ↓
OrientationManager.isPaywallShowing = true  ← BLOCKS lockToLandscape()
        ↓
PortraitPaywallHost.present()
        ↓
Host presented fullscreen (.portrait locked)
        ↓
Host.viewDidAppear → Superwall.register("MainPlacement")
        ↓
Superwall shows paywall (in portrait)
        ↓
User dismisses or purchases
        ↓
SuperwallDelegate.paywallDidDismiss() fires
        ↓
PaywallService calls PortraitPaywallHost.current?.dismissHost()
        ↓
Host sets allowDismiss = true (unlocks orientation)
        ↓
Host sets OrientationManager.isPaywallShowing = false
        ↓
Host dismisses itself
        ↓
App returns to landscape
```

### Critical Implementation Details

#### 1. PortraitPaywallHost (Views/PortraitPaywallHost.swift)

```swift
class PortraitPaywallHost: UIViewController {
    private var allowDismiss = false

    // FORCE PORTRAIT - NO EXCEPTIONS (until allowDismiss = true)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return allowDismiss ? .all : .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return allowDismiss
    }

    // Static reference so Superwall delegate can find us
    static weak var current: PortraitPaywallHost?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        PortraitPaywallHost.current = self

        Task { @MainActor in
            await Superwall.shared.register(placement: "MainPlacement")
            // Fallback if delegate doesn't fire
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if !hasDismissed { dismissHost() }
        }
    }

    func dismissHost() {
        guard !hasDismissed else { return }
        hasDismissed = true

        Task { @MainActor in
            let subscribed = await HIt_Rewind2App.hasActiveSubscription()
            finishAndDismiss(subscribed: subscribed)
        }
    }

    private func finishAndDismiss(subscribed: Bool) {
        // CRITICAL: Allow rotation BEFORE dismissing
        allowDismiss = true
        OrientationManager.shared.isPaywallShowing = false
        setNeedsUpdateOfSupportedInterfaceOrientations()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.dismiss(animated: true) {
                self.completion?(subscribed)
            }
        }
    }
}
```

#### 2. PaywallService Delegate (Services/PaywallService.swift)

```swift
extension PaywallService: SuperwallDelegate {
    func paywallDidDismiss(withInfo paywallInfo: PaywallInfo) {
        // Tell the portrait host to dismiss itself
        PortraitPaywallHost.current?.dismissHost()
    }
}
```

#### 3. OrientationManager (Utilities/OrientationManager.swift)

```swift
final class OrientationManager {
    static let shared = OrientationManager()

    var isPaywallShowing: Bool = false
    var isOnboardingShowing: Bool = false

    func lockToLandscape() {
        // BLOCKED if paywall is showing
        if isPaywallShowing { return }
        // ... rotation code
    }

    func supportedOrientations() -> UIInterfaceOrientationMask {
        if isPaywallShowing || isOnboardingShowing {
            return .portrait
        }
        return UIDevice.current.userInterfaceIdiom == .pad ? .landscape : .landscapeRight
    }
}
```

#### 4. AppDelegate (HIt_Rewind2App.swift)

```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.supportedOrientations()
    }
}
```

### Why This Works

1. **UIViewController orientation overrides take precedence** - When a VC is presented fullscreen, iOS respects its `supportedInterfaceOrientations`

2. **The flag blocks competing rotation requests** - `isPaywallShowing = true` prevents `lockToLandscape()` from running while paywall is up

3. **Superwall delegate provides dismiss timing** - `paywallDidDismiss` fires reliably when user closes paywall

4. **Order matters on dismiss**:
   - First: `allowDismiss = true` (so VC allows landscape)
   - Second: `isPaywallShowing = false` (so AppDelegate allows landscape)
   - Third: `setNeedsUpdateOfSupportedInterfaceOrientations()` (notify system)
   - Fourth: Small delay, then `dismiss(animated: true)`

### Previous Failed Attempts

| Attempt | Problem |
|---------|---------|
| Flag + requestGeometryUpdate | Superwall.register() doesn't block, flag cleared too early |
| Multiple requestGeometryUpdate calls | Same issue |
| Simple VC wrapper without delegate | "None of the requested orientations supported" on dismiss |

### KEY DISCOVERY
**`Superwall.shared.register()` does NOT block!** It fires the paywall asynchronously and returns immediately. This is why the Superwall delegate is essential - it's the only reliable way to know when the paywall is actually dismissed.

### Debug Commands
```swift
// Check orientation state
print("📐 isPaywallShowing=\(OrientationManager.shared.isPaywallShowing)")
print("🎯 PortraitPaywallHost.current = \(PortraitPaywallHost.current != nil ? "exists" : "nil")")
```

## iPad Landscape Orientation Enforcement

### Goal
Force iPad to stay in landscape mode (main app), with portrait only for onboarding/paywall.

### Implementation

#### 1. UIRequiresFullScreen (Info.plist)
```xml
<key>UIRequiresFullScreen</key>
<true/>
```
- **Location**: `HIt-Rewind2-Info.plist`
- **Effect**: Disables iPad multitasking (Slide Over, Split View)
- **Why**: Without this, iPad may ignore AppDelegate orientation restrictions

#### 2. AppDelegate Orientation Control
```swift
func application(_ application: UIApplication,
                 supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return OrientationManager.shared.supportedOrientations()
}
```

#### 3. OrientationManager Configuration
```swift
func supportedOrientations() -> UIInterfaceOrientationMask {
    if isPaywallShowing || isOnboardingShowing {
        return .portrait
    }
    // iPad: either landscape direction
    // iPhone: landscape right only (dynamic island on left)
    return UIDevice.current.userInterfaceIdiom == .pad ? .landscape : .landscapeRight
}
```

#### 4. Scene Activation Observer
OrientationManager observes `UIScene.didActivateNotification` to re-enforce landscape when:
- App returns from background
- Scene becomes active after multitasking

```swift
private init() {
    sceneObserver = NotificationCenter.default.addObserver(
        forName: UIScene.didActivateNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.enforceOrientationIfNeeded()
    }
}
```

### Key Differences: iPad vs iPhone

| Aspect | iPhone | iPad |
|--------|--------|------|
| Preferred Landscape | `.landscapeRight` | `.landscape` (both) |
| Multitasking | N/A | Disabled via `UIRequiresFullScreen` |
| AppDelegate respected | Yes | Only with `UIRequiresFullScreen` |
| Extra enforcement | None needed | Scene activation observer |

### Troubleshooting iPad Orientation

**iPad rotates to portrait:**
1. Check `UIRequiresFullScreen = YES` in Info.plist
2. Verify `supportedOrientations()` returns `.landscape` for iPad
3. Check scene activation observer is firing

**iPad ignores orientation lock:**
1. Multitasking may be overriding - ensure `UIRequiresFullScreen`
2. Check for competing `requestGeometryUpdate` calls
3. Verify no other VCs are overriding `supportedInterfaceOrientations`

## Figma MCP Design System Rules

Rules for translating Figma designs into SwiftUI code that matches this project's conventions.

### Required Figma-to-Code Workflow

1. Run `get_design_context` for the target node(s)
2. If response is truncated, run `get_metadata` first, then re-fetch specific nodes
3. Run `get_screenshot` for visual reference
4. Download any image/SVG assets from the Figma MCP localhost URLs
5. Translate the output into SwiftUI using this project's conventions below
6. Validate against the Figma screenshot for 1:1 visual parity

### Color Tokens

IMPORTANT: Never hardcode hex colors. Use the project's color extensions from `Extensions/Color+Extensions.swift`:

| Figma Color | SwiftUI Token |
|-------------|---------------|
| `#A789FD` (purple accent) | `Color.hitRewindPurple` |
| `#000000` (backgrounds) | `Color.hitRewindBackground` |
| `#292631` (dark gray) | `Color.hitRewindDarkGray` |
| `#1C1C1E` (secondary bg) | `Color.hitRewindSecondaryBackground` |
| `#2C2C2E` (card bg) | `Color.hitRewindCardBackground` |
| `#FFFFFF` (primary text) | `Color.hitRewindPrimaryText` |
| Gray (secondary text) | `Color.hitRewindSecondaryText` |

For colors not in the palette, use `Color(hex:)` initializer.

### Typography

Defined in `Extensions/AppFont.swift` and `Extensions/FontLoader.swift`:

- **Display/section titles**: `.font(.custom(AppFont.ticketingName(), size: N))` — custom Ticketing font
- **Body text**: `.font(.body)` or `.font(.system(size: 13))`
- **Headings**: `.font(.title2)` or `.font(.system(size: N, weight: .bold))`
- **Captions/metadata**: `.font(.caption)`, `.font(.caption2)`
- **Common weights**: `.semibold` for buttons/labels, `.medium` for secondary, `.bold` for emphasis

### Reusable Components

IMPORTANT: Check these existing components before creating new ones:

| Component | Location | Use For |
|-----------|----------|---------|
| `VideoThumbnailView` | `Views/MusicVideos/VideoThumbnailView.swift` | Video cards with image, title, rank badge, heart icon |
| `HeadroomHeader` | `Views/Components/HeadroomHeader.swift` | Scroll-responsive sticky header with logo |
| `ConcertBannerView` | `Views/EpicShows/ConcertBannerView.swift` | Landscape banners (2108/556 aspect ratio) |
| `CategoryBannerView` | `Views/FanCams/CategoryBannerView.swift` | Category banners with gradient fallback (990/408 ratio) |
| `SpinningRecordView` | `Views/Components/SpinningRecordView.swift` | Loading spinner (rotating record) |
| `PlayerOverlay` | `Views/Components/PlayerOverlay.swift` | Persistent video player (VJ mode + mini player) |

### Icon System (SF Symbols)

Use SF Symbols exclusively. Do not import icon libraries.

**Standard button pattern (control buttons):**
```swift
Image(systemName: "chevron.left")
    .font(.system(size: 16, weight: .semibold))
    .foregroundColor(.white)
    .frame(width: 38, height: 38)
    .background(.ultraThinMaterial)
    .clipShape(Circle())
```

**Common icons:**
- Playback: `play.fill`, `pause.fill`, `goforward.10`, `forward.end.fill`
- Navigation: `chevron.left`, `arrow.up.left.and.arrow.down.right`, `xmark`
- Favorites: `heart` / `heart.fill` (red when filled)
- Media: `music.note`, `music.mic`, `airplayvideo`

### Styling Conventions

**Corner radii:**
- Small elements (badges, chips): `4pt`
- Cards, thumbnails: `8pt`
- Banners, larger containers: `12pt`

**Shadows:**
```swift
.shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)  // Cards
.shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)  // Text readability
```

**Backgrounds:**
- Control buttons: `.background(.ultraThinMaterial)`
- Overlays: `.background(Color.black.opacity(0.5))`
- Gradient fades: `LinearGradient` with `.hitRewindBackground` opacity stops

**Animations:**
- Standard transitions: `.easeInOut(duration: 0.35)`
- Spring: `.spring(response: 0.35, dampingFraction: 0.9)`
- Icon bounces: `.symbolEffect(.bounce, value: trigger)`

### Layout Rules

- **Dark mode only** — all views use the dark color palette
- **Landscape-first** — main app is landscape-locked
- **iPad vs iPhone detection**: `UIDevice.current.userInterfaceIdiom == .pad`
- **Video thumbnails**: 16:9 aspect ratio (`.aspectRatio(16/9, contentMode: .fit)`)
- **Safe areas**: Use `window.safeAreaInsets` for landscape home indicator spacing
- **Responsive positioning**: Use `GeometryReader` for dynamic layouts, not fixed coordinates
- **Spacing**: No centralized scale — use `4`, `8`, `10`, `12`, `16` as common values

### Asset Handling

- IMPORTANT: If Figma MCP returns localhost URLs for images/SVGs, download and use them directly
- IMPORTANT: Do not install new icon packages — use SF Symbols
- Store image assets in `HIt Rewind2/Assets.xcassets/`
- Use `AsyncImage` with `ImageCache.shared` for remote images

### Architecture Patterns

- **Singletons**: Services use `.shared` pattern (`FavoritesService.shared`, `MiniPlayerManager.shared`, etc.)
- **State**: `@StateObject` for service singletons, `@State` for local, `@Binding` for parent-child
- **Cross-view communication**: `NotificationCenter` with typed notification names (`.showSignInSheet`, `.switchToSearch`, etc.)
- **Navigation**: `NavigationStack` per tab, sheets for modals
- Place new views in the appropriate `Views/` subdirectory matching feature area
