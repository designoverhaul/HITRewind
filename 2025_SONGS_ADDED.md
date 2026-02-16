# 2025 Songs Added to MTvVideosNEW

## Summary
Successfully processed and added **75 songs from 2025** to the Airtable MTvVideosNEW table.

**Date**: January 12, 2026
**Table**: MTvVideosNEW (tblNwqwVyflL8hNDy)
**Base**: Front Row Live Music App (appxCBIOkiJEZiph7)

## Process Details

### What Was Done
1. Created a Swift script to automate the entire process
2. Used YouTube Data API v3 to search for official music videos
3. Extracted main artist names (removed featuring/collaboration artists)
4. Added all records to Airtable with proper field mapping

### Fields Added
- **title**: Song title
- **url**: YouTube video URL (format: https://www.youtube.com/watch?v={videoId})
- **Rank**: Song ranking (1-75)
- **artistName**: Primary artist name (collaborations removed)
- **Year**: "2025"

### Results
- **Successfully added**: 75/75 songs (100%)
- **Failed**: 0/75 songs (0%)
- **API quota used**: ~75 YouTube API calls
- **Processing time**: ~45 seconds

## Technical Notes

### Field Mapping
The script correctly mapped to the MTvVideosNEW table schema:
- `Year` field uses capital Y (not lowercase)
- `url` field is type URL (validates YouTube URLs)
- `Rank` field is numeric with precision 0
- `artistID` field was NOT included (not in MTvVideosNEW schema)

### Artist Name Processing
For collaboration songs, only the primary artist was stored:
- "Lady Gaga and Bruno Mars" → "Lady Gaga"
- "Kendrick Lamar and SZA" → "Kendrick Lamar"
- "Post Malone featuring Morgan Wallen" → "Post Malone"
- "Tyler, the Creator featuring GloRilla, Sexyy Red and Lil Wayne" → "Tyler, the Creator"

### YouTube Video Selection
- Search query format: "{title} {artist} official video"
- Selected first search result (most relevant)
- All videos successfully found

## Sample Records Added

### Top 10 Songs
1. **Die with a Smile** - Lady Gaga and Bruno Mars
   - URL: https://www.youtube.com/watch?v=kPa7bsKwL-c
   - Artist stored: Lady Gaga

2. **Luther** - Kendrick Lamar and SZA
   - URL: https://www.youtube.com/watch?v=sNY_2TEmzho
   - Artist stored: Kendrick Lamar

3. **A Bar Song (Tipsy)** - Shaboozey
   - URL: https://www.youtube.com/watch?v=t7bQwwqW-Hc
   - Artist stored: Shaboozey

4. **Lose Control** - Teddy Swims
   - URL: https://www.youtube.com/watch?v=GZ3zL7kT6_c
   - Artist stored: Teddy Swims

5. **Birds of a Feather** - Billie Eilish
   - URL: https://www.youtube.com/watch?v=V9PVRfjEBTI
   - Artist stored: Billie Eilish

6. **Beautiful Things** - Benson Boone
   - URL: https://www.youtube.com/watch?v=Oa_RSwwpPaA
   - Artist stored: Benson Boone

7. **Ordinary** - Alex Warren
   - URL: https://www.youtube.com/watch?v=u2ah9tWTkmk
   - Artist stored: Alex Warren

8. **I Had Some Help** - Post Malone featuring Morgan Wallen
   - URL: https://www.youtube.com/watch?v=4QIZE708gJ4
   - Artist stored: Post Malone

9. **APT.** - Rosé and Bruno Mars
   - URL: https://www.youtube.com/watch?v=ekr2nIex040
   - Artist stored: Rosé

10. **Pink Pony Club** - Chappell Roan
    - URL: https://www.youtube.com/watch?v=GR3Liudev18
    - Artist stored: Chappell Roan

## Notable Songs Included
- Christmas classics: "All I Want for Christmas Is You" (Mariah Carey), "Last Christmas" (Wham!), "Rockin' Around the Christmas Tree" (Brenda Lee)
- Multiple Kendrick Lamar tracks: "Luther", "Not Like Us", "TV Off", "Squabble Up", "30 for 30", "Peekaboo"
- Multiple Sabrina Carpenter tracks: "Espresso", "Taste", "Manchild", "Bed Chem", "Please Please Please"
- Multiple Morgan Wallen tracks: "Love Somebody", "I'm the Problem", "Just in Case", "What I Want", "I Got Better", "Smile", "I Ain't Comin' Back"

## Files Created
- `/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/process_2025_songs.swift` - Processing script (can be reused for future batches)

## Verification
All records verified in Airtable:
```bash
curl "https://api.airtable.com/v0/appxCBIOkiJEZiph7/tblNwqwVyflL8hNDy?filterByFormula={Year}='2025'" \
  -H "Authorization: Bearer [TOKEN]"
```

Records are sorted by Rank field and ready for use in the iOS app.

## Next Steps
The 2025 songs are now available in the MTvVideosNEW table and should appear in the app's NEW tab when filtering by year 2025.
