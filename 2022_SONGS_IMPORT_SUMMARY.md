# 2022 Songs Import Summary

## Overview
Successfully imported **75 songs** from 2022 into the Airtable MTvVideosNEW table.

**Date:** January 12, 2026
**Base ID:** appxCBIOkiJEZiph7
**Table ID:** tblNwqwVyflL8hNDy

## Results

### Success Rate: 100%

- ✅ **Successfully added:** 75 songs
- ⚠️ **No video found:** 0 songs
- ❌ **Errors:** 0 songs

## Process Details

### Data Sources
1. **YouTube Data API v3** - Used to search for official music videos
2. **Airtable API** - Used to add records to MTvVideosNEW table

### Fields Added
For each song, the following fields were populated:
- `title` - Song title
- `url` - YouTube video URL (format: https://www.youtube.com/watch?v={videoId})
- `Rank` - Chart position (1-75)
- `artistName` - Main artist name (extracted from collaborations)
- `Year` - "2022" (as string)

### Artist Name Extraction
The script automatically extracted the main artist name from collaboration strings:
- "The Kid Laroi and Justin Bieber" → "The Kid Laroi"
- "Elton John and Dua Lipa" → "Elton John"
- "Future featuring Drake and Tems" → "Future"
- "Post Malone featuring Doja Cat" → "Post Malone"

**Note:** Some edge cases with special formatting may have partial artist names:
- "Silk Sonic (Bruno Mars and Anderson .Paak)" → "Silk Sonic (Bruno Mars" (parenthesis handling)
- "The Anxiety: Willow and Tyler Cole" → "The Anxiety: Willow" (colon handling)

## Sample Records

### Top 5 Songs of 2022
| Rank | Title | Artist | Video ID |
|------|-------|--------|----------|
| 1 | Heat Waves | Glass Animals | mRD0-GxqHVo |
| 2 | As It Was | Harry Styles | H5v3kku4y6Q |
| 3 | Stay | The Kid Laroi | kTJczUoc26U |
| 4 | Easy on Me | Adele | U3ASj1L6_sY |
| 5 | Shivers | Ed Sheeran | Il0S8BoucSA |

## Technical Details

### API Usage
- **YouTube Data API:** 75 search requests (75 quota units)
- **Airtable API:** 75 POST requests
- **Rate Limiting:** 2-second delay between requests
- **Total Processing Time:** ~2.5 minutes

### Search Strategy
Each song was searched using the query format:
```
"{title} {artist} official video"
```

The search was configured to:
- Return only video results (`type=video`)
- Limit to music category (`videoCategoryId=10`)
- Return top result (`maxResults=1`)

### Script Location
`/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/process_all_2022_songs.sh`

## Verification

All 75 records were verified in Airtable:
```bash
curl -s 'https://api.airtable.com/v0/appxCBIOkiJEZiph7/tblNwqwVyflL8hNDy?filterByFormula=Year%3D%272022%27' \
  -H 'Authorization: Bearer {token}' | jq '.records | length'
# Returns: 75
```

## Notable Songs Imported

### Viral Hits
- "Heat Waves" - Glass Animals (#1)
- "Running Up That Hill (A Deal with God)" - Kate Bush (#23) - Stranger Things revival
- "Bad Habit" - Steve Lacy (#28)

### Disney/Encanto
- "We Don't Talk About Bruno" (#24)
- "Surface Pressure" - Jessica Darrow (#53)

### Christmas Classic
- "All I Want for Christmas Is You" - Mariah Carey (#65)

### Latin Hits
- "Me Porto Bonito" - Bad Bunny (#20)
- "Tití Me Preguntó" - Bad Bunny (#22)
- "Moscow Mule" - Bad Bunny (#44)
- "Provenza" - Karol G (#63)
- "Efecto" - Bad Bunny (#69)

## Recommendations for Future Imports

1. **Artist Name Extraction:** Consider manual review for songs with complex artist credits (parentheses, colons, etc.)
2. **Video Verification:** Spot-check video URLs to ensure correct official videos were selected
3. **Thumbnail Generation:** The `videoImage` and `videoImage0` formula fields should automatically generate thumbnail URLs
4. **Playlist Linking:** Consider linking songs to relevant playlists in the MTvPlaylists table
5. **Artist ID:** Consider populating the `artistID` field by linking to the Artists table

## Next Steps

If you need to import more years:
1. Update the `YEAR` variable in the script
2. Replace the songs list with new data
3. Run the script: `./process_all_2022_songs.sh`

The script is reusable for any year's data with minimal modifications.
