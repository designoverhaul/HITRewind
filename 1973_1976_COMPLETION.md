# 1973-1976 Billboard Hot 100 Video Collection

## Summary
Successfully collected and uploaded 400 music videos (100 per year) from the Billboard Year-End Hot 100 charts for 1973, 1974, 1975, and 1976 to the Airtable MTvVideosNEW table.

## Completion Date
January 20, 2026

## Results

| Year | Songs Processed | Videos Found | Uploaded to Airtable |
|------|-----------------|--------------|---------------------|
| 1973 | 100 | 100 | 100 |
| 1974 | 100 | 100 | 100 |
| 1975 | 100 | 100 | 100 |
| 1976 | 100 | 100 | 100 |
| **Total** | **400** | **400** | **400** |

## Process

1. **Data Source**: Billboard Year-End Hot 100 from `Full_Billboard_year_end_hot_100_USA.csv`
2. **YouTube Search**: Used YouTube Data API v3 with multiple search strategies:
   - Primary: `"{title} {artist} official music video"`
   - Fallbacks: `"{title} {artist} official video"`, `"{title} {artist} music video"`
   - Filtered to music category (videoCategoryId: 10)
   - Prioritized official/VEVO channels
   - Skipped covers, tributes, karaoke, reactions
3. **Airtable Upload**: Records created with fields:
   - `title`: Song title
   - `url`: YouTube video URL
   - `Rank`: Billboard chart position
   - `artistName`: Primary artist name (cleaned)
   - `Year`: Chart year (as string)

## Scripts Created

- `process_1973_1976_songs.py` - Main processing script (YouTube search + Airtable upload)
- `upload_from_results.py` - Utility to re-upload from saved JSON results

## Result Files

- `1973_processing_results.json` / `1973_upload_results.json`
- `1974_processing_results.json`
- `1975_processing_results.json`
- `1976_processing_results.json`
- `1973_1976_complete_results.json`

## Notable Pre-MTV Considerations

Since MTV launched in August 1981, many songs from 1973-1976 don't have traditional music videos. The collection includes:
- Official VEVO remastered versions
- TV performance footage (Soul Train, TopPop, Midnight Special)
- Promotional clips made for TV
- Live performances from official artist channels
- Official audio with static images (for some songs)

## Airtable Details

- **Base ID**: `appxCBIOkiJEZiph7`
- **Table**: MTvVideosNEW (`tblNwqwVyflL8hNDy`)
- **Records Created**: 400 new records
