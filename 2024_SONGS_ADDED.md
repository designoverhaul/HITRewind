# 2024 Songs Added to MTvVideosNEW Table

## Summary
Successfully processed and added 75 songs from 2024 to the Airtable MTvVideosNEW table.

**Date:** January 12, 2026
**Status:** ✅ Complete
**Records Added:** 75 out of 75
**Videos Not Found:** 0
**Errors:** 0

## Processing Details

### Airtable Configuration
- **Base ID:** appxCBIOkiJEZiph7
- **Table:** MTvVideosNEW (tblNwqwVyflL8hNDy)
- **Year:** 2024

### Fields Added
- `title` - Song title
- `url` - YouTube video URL (format: https://www.youtube.com/watch?v={videoId})
- `Rank` - Billboard rank (1-75)
- `artistName` - Main artist name (extracted from full artist credits)
- `Year` - "2024"

### Artist Name Extraction
The script automatically extracted the main artist name from collaboration credits:
- "Post Malone featuring Morgan Wallen" → "Post Malone"
- "Lady Gaga and Bruno Mars" → "Lady Gaga"
- "Drake featuring J. Cole" → "Drake"

## Sample Records

### Top 10 Songs Added
1. Lose Control - Teddy Swims (https://www.youtube.com/watch?v=GZ3zL7kT6_c)
2. A Bar Song (Tipsy) - Shaboozey (https://www.youtube.com/watch?v=t7bQwwqW-Hc)
3. Beautiful Things - Benson Boone (https://www.youtube.com/watch?v=Oa_RSwwpPaA)
4. I Had Some Help - Post Malone (https://www.youtube.com/watch?v=4QIZE708gJ4)
5. Lovin on Me - Jack Harlow (https://www.youtube.com/watch?v=Iq8h3GEe22o)
6. Not Like Us - Kendrick Lamar (https://www.youtube.com/watch?v=H58vbez_m4E)
7. Espresso - Sabrina Carpenter (https://www.youtube.com/watch?v=eVli-tstM5E)
8. Million Dollar Baby - Tommy Richman (https://www.youtube.com/watch?v=Zf1d8SGuxfs)
9. I Remember Everything - Zach Bryan (https://www.youtube.com/watch?v=ZVVvJjwzl6c)
10. Too Sweet - Hozier (https://www.youtube.com/watch?v=NTpbbQUBbuo)

## Technical Implementation

### YouTube Search Process
For each song:
1. Searched YouTube using query: "{title} {artist} official video"
2. Retrieved first search result's video ID
3. Constructed YouTube URL: https://www.youtube.com/watch?v={videoId}

### Batch Upload Strategy
- Uploaded records in batches of 10 to Airtable
- Rate limiting: 200ms between YouTube searches, 1 second between Airtable batches
- Total processing time: ~25 seconds

### Error Resolution
Initial attempt failed with 422 error due to including non-existent `artistID` field. Fixed by:
1. Checking table schema via Airtable Meta API
2. Removing `artistID` from the data structure
3. Successfully re-running with corrected field structure

## Verification
All 75 records confirmed in Airtable with Year="2024" filter.

## Script Location
`/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/add_2024_songs.swift`

## Notes
- All 75 songs had official music videos available on YouTube
- No manual intervention required after initial field structure correction
- Videos are ready to display in the Hit Rewind iOS app
