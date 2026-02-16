# Missing Banners Fix

## Issue
Custom banners for categories (Fan Cams) and concerts (Epic Shows) were not loading after implementing API optimization with fields filtering.

## Root Cause
When adding fields filtering to reduce API payload sizes, the wrong field names were requested for the Concerts table:

**Incorrect Fields Requested:**
- ❌ `concertDate` (doesn't exist in Airtable)
- Missing: `largeImage`, `eventDescription`

**Correct Fields:**
- ✅ `eventYear` (actual Airtable field name)
- ✅ `bannerImage` (for concert banners)
- ✅ `largeImage` (additional banner option)
- ✅ `eventDescription` (concert details)

## Fix Applied

### 1. Updated Concerts Fields Filter
**File**: `AirtableService.swift` → `performConcertsRequest()`

**Changed from:**
```swift
items.append(URLQueryItem(name: "fields[]", value: "concertDate"))
items.append(URLQueryItem(name: "fields[]", value: "bannerImage"))
items.append(URLQueryItem(name: "fields[]", value: "Concert Videos"))
```

**Changed to:**
```swift
items.append(URLQueryItem(name: "fields[]", value: "eventYear"))
items.append(URLQueryItem(name: "fields[]", value: "bannerImage"))
items.append(URLQueryItem(name: "fields[]", value: "largeImage"))
items.append(URLQueryItem(name: "fields[]", value: "eventDescription"))
items.append(URLQueryItem(name: "fields[]", value: "Concert Videos"))
```

### 2. Added Selective Cache Clearing
Created `clearCache(for:)` method to clear specific cache types without wiping all cached data.

**Usage:**
```swift
// Clear only concerts cache
AirtableService.shared.clearCache(for: .concerts)

// Clear only categories cache
AirtableService.shared.clearCache(for: .categories)

// Clear all cache
AirtableService.shared.clearCache()
```

## How to Test the Fix

### Option 1: Clear Cache in Xcode
Run this in a breakpoint or test:
```swift
AirtableService.shared.clearCache(for: .concerts)
AirtableService.shared.clearCache(for: .categories)
```

### Option 2: Delete App and Reinstall
1. Delete app from simulator/device
2. Rebuild and run
3. Fresh install will fetch data with correct fields

### Option 3: Wait for Cache to Expire
Cache expires after 7 days, so data will automatically refresh with correct fields after the cache period.

## Verification

After clearing cache, you should see:

### Fan Cams Page (Live)
- ✅ Category banners load from Airtable `CategoryImage` field
- ✅ Custom images display for each category (Pop, Rock, Hip Hop, etc.)
- ✅ Fallback gradient if image URL is missing

### Epic Shows Page
- ✅ Concert banners load from Airtable `bannerImage` field
- ✅ Custom banners display for each concert
- ✅ Fallback placeholder if banner is missing

## Fields Now Being Fetched

### Categories (Fan Cams)
```
- CategoryName ✅
- CategoryImage ✅ (banner images)
- ArtistNames ✅
```
**Note**: `description` field omitted - doesn't exist in Airtable table

### Concerts (Epic Shows)
```
- artistName ✅
- venueName ✅
- eventYear ✅ (was requesting wrong field "concertDate")
- bannerImage ✅ (concert banners)
- largeImage ✅ (additional banner option)
- eventDescription ✅
- Concert Videos ✅
```

### Legendary Categories
```
- Title ✅
- artistName ✅
- Year ✅
- URL ✅
- videoImage ✅
- LegendaryShow ✅ (multi-select grouping)
```

## Prevention
Always verify field names in Airtable match the CodingKeys in Swift models before adding fields filtering:

**Example:**
```swift
struct ConcertFields: Codable {
    let eventYear: Int

    enum CodingKeys: String, CodingKey {
        case eventYear = "eventYear"  // ← This is the Airtable field name
    }
}
```

Use the Airtable field name (`"eventYear"`) in the fields filter, not the Swift property name.

## Status
✅ **Fixed** - Correct field names are now being requested
✅ **Build verified** - App compiles successfully
⏳ **Requires cache clear** - Old cache has incomplete data

## Next Steps
1. Clear the concerts and categories cache (or delete app and reinstall)
2. Launch app to fetch fresh data with correct fields
3. Verify banners load on both Fan Cams and Epic Shows pages
4. Test on both iPhone and iPad layouts
