# Video Thumbnail Customization - Rank Badges & Duration Display

## Changes Made (2026-01-11)

### Summary
Customized video thumbnails to display Billboard Hot 100 rank badges and conditionally hide duration badges based on content type.

### Files Modified

#### 1. VideoThumbnailView.swift
**New Parameters Added:**
- `rank: Int?` - Optional Billboard rank to display (e.g., 1-100)
- `hideDuration: Bool` - Flag to conditionally hide the duration badge

**Visual Changes:**
- **Rank Badge** (Top-Left Corner):
  - Shows as `#14` format in purple badge
  - Only appears when rank value is provided
  - Purple background (`Color.hitRewindPurple`)
  - White bold text
  - Rounded corners with padding

- **Duration Badge** (Bottom-Right Corner):
  - Now hidden when `hideDuration: true`
  - Still visible for Epic Shows, Live content, and Fan Cams
  - Black semi-transparent background
  - White semibold text

**Layout:**
```
┌─────────────────────┐
│ #14        ❤️       │  ← Rank badge (left), Heart button (right)
│                     │
│    Video Image      │
│                     │
│              3:45   │  ← Duration badge (hidden for music videos)
└─────────────────────┘
```

#### 2. NEWVideosView.swift
**Updated to:**
- Pass `rank: video.fields.rank` from DirectVideoRecord
- Set `hideDuration: true` for all NEW tab videos

#### 3. MusicVideosView.swift
**Updated to:**
- Set `hideDuration: true` for all MTV tab videos
- Rank not shown (original MTvVideos table doesn't have rank data)

#### 4. ArtistSongsView.swift
**Updated to:**
- Set `hideDuration: true` for artist-specific music videos
- Rank not shown (no rank data in this context)

#### 5. ContentView.swift (Favorites Page)
**Updated to:**
- Set `hideDuration: true` for favorite music videos
- Rank not shown (favorites don't store rank data)

### Content Type Behavior

| View/Tab | Duration Badge | Rank Badge | Notes |
|----------|---------------|------------|-------|
| NEW Videos | ❌ Hidden | ✅ Shown | Shows Billboard rank 1-75 |
| MTV Videos | ❌ Hidden | ❌ Not shown | Original table has no rank |
| Artist Songs | ❌ Hidden | ❌ Not shown | Music videos without rank |
| Favorites | ❌ Hidden | ❌ Not shown | Favorites don't store rank |
| Epic Shows | ✅ Visible | ❌ Not shown | Concert content, not music videos |
| Fan Cams | ✅ Visible | ❌ Not shown | User-generated content |
| Live | ✅ Visible | ❌ Not shown | Live stream content |

### Why These Changes?

1. **Hide Duration for Music Videos**:
   - Most users know music videos are 3-4 minutes
   - Duration information is less important for music videos vs. concerts/live streams
   - Cleaner, less cluttered thumbnail appearance

2. **Show Rank for Billboard Songs**:
   - Provides valuable context (this was #1 hit vs. #50)
   - Helps users discover top-charting videos
   - Unique data from MTvVideosNEW table (2001-2020 Billboard Hot 100)

3. **Keep Duration for Other Content**:
   - Concert videos vary widely in length (3 min - 2 hours)
   - Live streams and fan cams need duration info
   - Users want to know time commitment before watching

### Example Usage

**With rank badge (NEW Videos tab):**
```swift
VideoThumbnailView(
    videoId: "dQw4w9WgXcQ",
    title: "Never Gonna Give You Up",
    artist: "Rick Astley",
    year: "2020",
    onTap: {},
    rank: 14,              // Shows "#14" badge
    hideDuration: true     // Hides "3:45" badge
)
```

**Without rank (MTV Videos tab):**
```swift
VideoThumbnailView(
    videoId: "dQw4w9WgXcQ",
    title: "Never Gonna Give You Up",
    artist: "Rick Astley",
    year: "2020",
    onTap: {},
    hideDuration: true     // Hides duration, no rank shown
)
```

**Epic Shows (duration visible):**
```swift
VideoThumbnailView(
    videoId: "abc123",
    title: "Taylor Swift - Eras Tour",
    artist: "Taylor Swift",
    year: "2023",
    onTap: {},
    hideArtistAndYear: true  // Duration shown by default
)
```

### Testing

✅ **Build Status**: Compiles successfully with no errors
✅ **NEW Tab**: Rank badges display correctly (e.g., #1, #14, #75)
✅ **NEW Tab**: Duration badges are hidden
✅ **MTV Tab**: Duration badges are hidden, no rank shown
✅ **Epic Shows**: Duration badges still visible
✅ **Fan Cams**: Duration badges still visible
✅ **Favorites**: Duration badges hidden for music videos

### Visual Example

**Before:**
```
┌─────────────────────┐
│                  ❤️  │
│                     │
│    Video Image      │
│                     │
│              3:45   │
└─────────────────────┘
```

**After (NEW Videos with rank #14):**
```
┌─────────────────────┐
│ #14              ❤️  │
│                     │
│    Video Image      │
│                     │
│                     │
└─────────────────────┘
```

### Data Source

- **Rank data**: From `MTvVideosNEW` Airtable table
- **Range**: Ranks 1-75 for years 2001-2020
- **Source**: Billboard Year-End Hot 100 charts
- **Coverage**: 1,575 total songs (21 years × 75 songs, minus 4 missing URLs)

### Notes

- Rank badge uses `Color.hitRewindPurple` to match app theme
- Duration badge continues to use black semi-transparent background
- Heart (favorite) button position unchanged
- All changes are backward compatible (optional parameters with defaults)
- No breaking changes to existing VideoThumbnailView usage
