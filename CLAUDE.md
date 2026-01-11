# Hit Rewind 2 - iOS Implementation Notes

## Project Overview
This is the iOS SwiftUI conversion of the Hit Rewind Apple TV app. The focus has been on implementing the **Music Videos** page first, with responsive layouts that work across iPhone and iPad.

## Architecture
- **SwiftUI-based** with dark mode only
- **TabView navigation** with 6 tabs matching Apple TV version
- **Responsive layouts** that adapt from 1 column (iPhone portrait) to 4 columns (iPad landscape)
- **Airtable backend** integration preserved from Apple TV version
- **YouTube Data API v3** integration for video metadata and thumbnails

## Completed Implementation

### ✅ Core Structure
- SwiftUI TabView with all 6 tabs from Apple TV app
- Dark mode theming with Hit Rewind purple accent color (#A789FD)
- Color extensions for consistent theming throughout app

### ✅ Data Layer
- **Models**: Adapted `PlaylistModel.swift` from Apple TV for SwiftUI compatibility
- **AirtableService**: ObservableObject for async data fetching with proper error handling
- **YouTubeService**: API v3 integration for video info, thumbnails, and duration
- **Constants**: API keys and configuration (copied from Apple TV version)

### ✅ Authentication & Cloud Storage
- **AuthenticationService**: Sign in with Apple integration
- **FavoritesService**: CloudKit-based favorites with local storage fallback
- **User Management**: Secure authentication state with automatic validation

### ✅ Music Videos Implementation
- **MusicVideosView**: Main implementation with responsive LazyVGrid
- **YearSidebarView**: Year filtering sidebar (permanent on iPad, sliding on iPhone)
- **VideoThumbnailView**: Reusable video card component with heart icons and AsyncImage loading
- **VideoPlayerView**: UIViewControllerRepresentable for video playback with favorites integration

### ✅ Favorites System
- **Heart Icons**: Added to all video thumbnails with tap-to-favorite functionality
- **Sign-in Integration**: Requires Sign in with Apple for cloud sync
- **FavoritesView**: Complete implementation with empty states and sign-in prompts
- **CloudKit Sync**: Automatic syncing across devices with local storage fallback
- **Visual Feedback**: Animated heart icons with haptic feedback

### ✅ Sharing Features
- **ShareLink Integration**: Native iOS share functionality on video player screen
- **YouTube Links**: Direct sharing of YouTube video URLs with metadata

### ✅ Responsive Design
- **iPhone Portrait**: 1 column grid with sliding year sidebar
- **iPhone Landscape**: 2 column grid with compact year picker
- **iPad Portrait**: 2-3 column grid with permanent NavigationSplitView sidebar
- **iPad Landscape**: 4 column grid matching Apple TV layout closely

### ✅ Features
- Automatic year selection (newest first)
- Video thumbnail loading with fallbacks for missing videos
- Duration display on thumbnails
- Heart icons for favoriting videos
- Share functionality for music videos
- Sign in with Apple authentication
- CloudKit-based favorites syncing
- Loading and error states throughout
- Smooth animations and transitions
- Dark mode only (no light mode support)

## File Structure
```
HitRewind2/
├── HIt_Rewind2App.swift (main app with dark mode)
├── ContentView.swift (TabView container with FavoritesView)
├── HIt Rewind2.entitlements (Sign in with Apple + CloudKit capabilities)
├── Extensions/
│   ├── AppFont.swift (custom font loading)
│   ├── Color+Extensions.swift (Hit Rewind colors)
│   ├── FontLoader.swift (font utilities)
│   └── NavigationConfigurator.swift (navigation customization)
├── Models/
│   ├── FanCamCategory.swift (fan cam data structures)
│   └── PlaylistModel.swift (Airtable data structures)
├── Services/
│   ├── AirtableService.swift (API integration)
│   ├── AuthenticationService.swift (Sign in with Apple)
│   ├── FavoritesService.swift (CloudKit favorites with local fallback)
│   └── YouTubeService.swift (YouTube Data API v3)
├── Views/
│   ├── FanCams/ (fan cam related views)
│   └── MusicVideos/
│       ├── ArtistSongsView.swift (artist-specific videos)
│       ├── MusicVideosView.swift (main responsive layout)
│       ├── VideoPlayerView.swift (video playback + favorites + sharing)
│       ├── VideoThumbnailView.swift (video cards with heart icons)
│       └── YearSidebarView.swift (year filtering)
└── Constants/
    └── Constants.swift (API keys and config)
```

## Next Steps for Full App

### Immediate Tasks
1. ✅ **YouTube Data API v3 key configured** (copied from Apple TV project)
2. ✅ **Airtable integration ready** (using same credentials as Apple TV project)
3. ✅ **Video playback implemented** (using YouTube web player for best compatibility)
4. ✅ **Sign in with Apple configured** (requires Xcode project capability setup)
5. ✅ **Favorites system complete** (CloudKit integration with local fallback)
6. ✅ **Share functionality implemented** (native iOS ShareLink integration)

### Future Pages (Coming Soon)
1. **Epic Shows** - Large banners and featured video rows
2. **Fan Cams** - Artist-based grouping with categories (partially implemented)
3. **Search** - Full text search across all content
4. **Settings** - App preferences, terms, and user management

### Setup Requirements
1. **Xcode Project Setup**:
   - Add Sign in with Apple capability in project settings
   - Add CloudKit capability in project settings  
   - Ensure entitlements file is properly linked
   - Configure App ID with Sign in with Apple on Apple Developer portal

2. **CloudKit Setup**:
   - Create CloudKit container in developer console
   - Add `FavoriteVideo` record type with fields: videoId, title, artist, year, dateAdded

### Enhancement Opportunities
- Add pull-to-refresh functionality
- Implement video offline downloading
- Add haptic feedback for interactions  
- Optimize thumbnail loading and caching
- Add accessibility improvements
- Implement proper YouTube player integration

## Key Design Decisions

### SwiftUI Over UIKit
- Modern iOS development approach
- Built-in responsive layout system
- Better state management with @State/@StateObject
- Native dark mode and animation support

### Responsive Grid System
- Uses SwiftUI's LazyVGrid with dynamic column counts
- Automatically adapts to device size and orientation
- Maintains visual hierarchy across all screen sizes

### Service-Oriented Architecture  
- Separate services for Airtable and YouTube operations
- ObservableObject pattern for reactive UI updates
- Proper error handling and loading states

## Build Status
✅ **Project builds successfully** for iOS simulator and device targets (requires capability setup)
✅ **All SwiftUI components compile** without errors
✅ **Responsive layouts tested** across different device configurations
✅ **Debug logging implemented** for troubleshooting data loading and video playback
✅ **Authentication system ready** for Sign in with Apple integration
✅ **Favorites system complete** with CloudKit sync and local fallback
✅ **Share functionality operational** using native iOS ShareLink

## Favorites & Authentication System
- **Sign in with Apple** - secure authentication with automatic credential validation
- **CloudKit Integration** - favorites sync across devices with local storage fallback
- **Heart Icons** - visible on all video thumbnails with tap-to-favorite functionality
- **Complete Favorites Page** - with sign-in prompts, empty states, and full video grid
- **Haptic Feedback** - enhanced user experience with tactile responses
- **Auto-Sync** - favorites automatically sync when user signs in

## Share Implementation
- **Native ShareLink** - uses iOS built-in sharing with YouTube URLs
- **Rich Metadata** - includes video title and artist information
- **Easy Access** - share button in video player toolbar for quick sharing

## Video Playback Solution
- **Standard YouTube Web Player** - loads full YouTube page in web view for maximum compatibility
- **Full-screen video experience** with native YouTube controls and features  
- **Simple and reliable** - no complex embed restrictions to worry about
- **Integrated Controls** - favorites and share functionality built into player interface

The app now includes a complete favorites system with Sign in with Apple authentication and CloudKit cloud sync!

## Airtable MCP Integration

This project uses the [Airtable MCP Server](https://github.com/rashidazarang/airtable-mcp) for AI-powered Airtable operations. The MCP server provides comprehensive access to Airtable bases, tables, records, and schema management.

### Available Operations

#### Data Operations
- **list_records** - Query records with filtering and pagination
- **get_record** - Retrieve a single record by ID
- **create_record** - Add new records to any table
- **update_records** - Modify existing record fields (up to 10 at once)
- **delete_records** - Remove records from a table (up to 10 at once)
- **search_records** - Advanced search with Airtable formulas

#### Schema Discovery
- **list_bases** - List all accessible bases with permissions
- **list_tables** - Get all tables in a base with schema information
- **describe_table** - Get detailed table and field specifications
- **get_base_schema** - Get complete schema for any base

#### Schema Management (Requires Token Permissions)
- **create_table** - Create tables with custom field definitions
- **update_table** - Modify table names and descriptions
- **create_field** - Add fields to existing tables
- **update_field** - Modify field properties and options
- **delete_field** - Remove fields (requires confirmation)

#### Batch Operations
- **batch_create_records** - Create up to 10 records at once
- **batch_update_records** - Update up to 10 records simultaneously
- **batch_delete_records** - Delete up to 10 records in one operation
- **batch_upsert_records** - Update or create records based on key fields

### Current Airtable Setup

**Base ID**: `appxCBIOkiJEZiph7` (Front Row Live Music App)

**Tables**:
- `MTvVideos` (original) - `tbl3waFYL7jfER18L`
- `MTvVideosNEW` (new version) - `tblNwqwVyflL8hNDy`
- `MTvPlaylists` - `tblByi6o9LzE3bkc4`
- `Artists` - `tblu9a6MnrdzECJFJ`
- `Category` - `tblhHeWHex8DXdq3R`
- `Concerts` - `tbl9umYOUTEVUZKnh`
- `Concert Videos` - `tbloVr52R37ZRNLFS`

### MTvVideosNEW Table Structure

**Required Fields** (matching MTvVideos, excluding channelName, thumbnail, Find Replace):
- `title` (Single line text)
- `url` (Single line text) - YouTube video URL
- `Rank` (Number, precision 1)
- `artistName` (Single line text)
- `year` (Number, precision 0)
- `playlist` (Multiple record links → MTvPlaylists)
- `artistID` (Single line text)
- `videoImage` (Formula) - Generates YouTube thumbnail URL (mqdefault.jpg)
- `videoImage0` (Formula) - Generates YouTube thumbnail URL (0.jpg)

**Excluded Fields** (not in NEW table):
- `channelName`
- `thumbnail`
- `Find Replace` (formula)
- `80sFeatured` (checkbox)
- `isVisible` (checkbox)

### Token Permissions

To enable schema management operations (create_field, update_field, etc.), the Airtable Personal Access Token needs these scopes:
- `schema.bases:read` - Read table structure
- `schema.bases:write` - Modify table structure
- `data.records:read` - Read records
- `data.records:write` - Write records

### Usage Notes

- **Record Updates**: Can update up to 10 records at once using `update_records`
- **Field Types**: Formula fields cannot be created via MCP (Airtable API limitation)
- **URL Fields**: The `url` field in MTvVideosNEW should be Single line text (not URL type) to match MTvVideos structure
- **Video Thumbnails**: The `videoImage` and `videoImage0` formula fields generate YouTube thumbnail URLs dynamically - they don't store images, just generate URLs

### Common Operations

**List records from MTvVideosNEW**:
```
list_records with baseId: appxCBIOkiJEZiph7, tableId: tblNwqwVyflL8hNDy
```

**Create new video record**:
```
create_record with fields: {title, url, Rank, artistName, year, artistID}
```

**Update multiple records**:
```
update_records with array of record objects (max 10)
```

**Check table structure**:
```
describe_table with baseId and tableId
```