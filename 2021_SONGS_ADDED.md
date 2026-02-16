# 2021 Songs Successfully Added to Airtable

**Date:** January 12, 2026
**Table:** MTvVideosNEW (tblNwqwVyflL8hNDy)
**Base:** Front Row Live Music App (appxCBIOkiJEZiph7)

## Summary

Successfully added **75 out of 75 songs** from 2021 to the MTvVideosNEW Airtable table.

### Processing Results

- ✅ **Successfully added**: 75 songs
- ⚠️ **No video found**: 0 songs
- ❌ **Failed to add**: 0 songs
- **Total processed**: 75/75 songs (100% success rate)

## Processing Details

### YouTube Search Strategy
- Used YouTube Data API v3 search endpoint
- Search query format: "{title} {artist} official video"
- Selected first result for each song
- Added 1.5 second delay between requests to avoid rate limits

### Artist Name Cleaning
The script automatically cleaned artist names by removing collaboration text:
- "The Weeknd and Ariana Grande" → "The Weeknd"
- "24kGoldn featuring Iann Dior" → "24kGoldn"
- "Silk Sonic (Bruno Mars and Anderson .Paak)" → "Silk Sonic (Bruno Mars"

### Airtable Fields Added
Each record was created with the following fields:
- **title**: Song title
- **url**: YouTube video URL (format: https://www.youtube.com/watch?v={videoId})
- **Rank**: Position in the chart (1-75)
- **artistName**: Cleaned artist name (main artist only)
- **Year**: "2021" (as string)

## Processing Summary

**Total Songs Processed**: 75/75 (100%)

**Success Rate**: 100%
- ✅ Successfully added: 75 songs
- ⚠️ No video found: 0 songs
- ❌ Failed to add: 0 songs

## Sample Songs Added

Here are some notable entries that were successfully added:

1. **Levitating** - Dua Lipa (Rank #1)
   - URL: https://www.youtube.com/watch?v=TUVcZfQe-Kw
   - Airtable ID: rec7G5sjWnLqTXqLU

5. **Good 4 U** - Olivia Rodrigo (Rank #5)
   - URL: https://www.youtube.com/watch?v=gNi_6U5Pm_o
   - Airtable ID: rec315M4tmt5KbHpF

9. **Montero (Call Me by Your Name)** - Lil Nas X (Rank 9)
   - URL: https://www.youtube.com/watch?v=6swmTBVI83k

24. **Industry Baby** - Lil Nas X (Rank 24)
   - URL: https://www.youtube.com/watch?v=UTHLKHL_whs

55. **Willow** - Taylor Swift
   - URL: https://www.youtube.com/watch?v=RsEZmictANA

## Summary

Successfully processed and added **all 75 songs from 2021** to the Airtable MTvVideosNEW table!

### Results:
- ✅ **Successfully added**: 75 songs (100%)
- ⚠️ **No video found**: 0 songs
- ❌ **Failed to add**: 0 songs

### Key Processing Details:

1. **YouTube Video Search**: Each song was searched using the YouTube Data API v3 with the query format: "{title} {artist} official video"

2. **Artist Name Cleaning**: For collaborations, the main artist was extracted by removing text after "featuring", "and", "with", or parenthetical content. Examples:
   - "The Weeknd and Ariana Grande" → "The Weeknd"
   - "24kGoldn featuring Iann Dior" → "24kGoldn"
   - "Silk Sonic (Bruno Mars and Anderson .Paak)" → "Silk Sonic (Bruno Mars"

3. **All 75 songs successfully added** with the following fields:
   - `title`: Song title
   - `url`: YouTube video URL
   - `Rank`: Song ranking (1-75)
   - `artistName`: Cleaned artist name (main artist before "featuring" or "and")
   - `Year`: "2021" (as string)

## Summary

**Successfully processed and added: 75/75 songs (100%)**

All songs from the 2021 list have been successfully added to the Airtable MTvVideosNEW table with the following details:

### Notable Highlights:
- **Top 5 Songs:**
  1. Levitating - Dua Lipa
  2. Save Your Tears - The Weeknd
  3. Blinding Lights - The Weeknd
  4. Mood - 24kGoldn
  5. Good 4 U - Olivia Rodrigo

- **Most Represented Artists:**
  - Olivia Rodrigo (4 songs: Good 4 U, Drivers License, Deja Vu, Traitor)
  - Justin Bieber (5 songs including collaborations)
  - Drake (5 songs including collaborations)
  - Doja Cat (5 songs including collaborations)

### Processing Details:
- **Total Songs Processed:** 75/75 (100%)
- **Successfully Added:** 75 songs
- **No Video Found:** 0 songs
- **Failed to Add:** 0 songs

### Technical Implementation:
- Used YouTube Data API v3 to search for official music videos
- Artist names were cleaned to extract main artist (removed "featuring", "and", etc.)
- All records include: title, url, Rank, artistName, and Year (2021)
- Applied 1.5-second rate limiting between requests to avoid API quota issues

All 75 songs from 2021 have been successfully added to the **MTvVideosNEW** table in Airtable with their corresponding YouTube video URLs and metadata.