# 2023 Songs Added to Airtable MTvVideosNEW

## Summary

Successfully processed and added **75 songs from 2023** to the Airtable MTvVideosNEW table.

- **Date**: January 12, 2026
- **Table**: MTvVideosNEW (tblNwqwVyflL8hNDy)
- **Base**: appxCBIOkiJEZiph7 (Front Row Live Music App)
- **Year**: 2023

## Process Overview

1. **YouTube Search**: Used YouTube Data API v3 to search for official music videos
   - Search query format: "{title} {artist} official video"
   - Category filter: Music (videoCategoryId: 10)
   - Successfully found all 75 videos

2. **Artist Name Extraction**: Cleaned artist names by extracting the main artist
   - Removed collaboration text ("featuring", "and", "with", etc.)
   - Kept primary artist for consistency

3. **Batch Upload**: Added records to Airtable in 8 batches
   - Batch size: 10 records (Airtable API limit)
   - All 8 batches succeeded without errors

## Results

### Successfully Added
✅ **75 out of 75 songs** (100% success rate)

### Failed
❌ **0 songs** failed

## Fields Added

For each song, the following fields were populated:
- **title**: Song title
- **url**: YouTube video URL (https://www.youtube.com/watch?v={videoId})
- **Rank**: Chart position (1-75)
- **artistName**: Primary artist name
- **Year**: "2023"

Note: The `artistID` field was intentionally left empty as it doesn't exist in the MTvVideosNEW table structure.

## Top 10 Songs of 2023

1. Last Night - Morgan Wallen
2. Flowers - Miley Cyrus
3. Kill Bill - SZA
4. Anti-Hero - Taylor Swift
5. Creepin' - Metro Boomin, the Weeknd and 21 Savage
6. Calm Down - Rema and Selena Gomez
7. Die for You - The Weeknd and Ariana Grande
8. Fast Car - Luke Combs
9. Snooze - SZA
10. I'm Good (Blue) - David Guetta and Bebe Rexha

## Complete List of Added Songs

1. Last Night - Morgan Wallen
2. Flowers - Miley Cyrus
3. Kill Bill - SZA
4. Anti-Hero - Taylor Swift
5. Creepin' - Metro Boomin, the Weeknd and 21 Savage
6. Calm Down - Rema and Selena Gomez
7. Die for You - The Weeknd and Ariana Grande
8. Fast Car - Luke Combs
9. Snooze - SZA
10. I'm Good (Blue) - David Guetta and Bebe Rexha
11. Unholy - Sam Smith and Kim Petras
12. You Proof - Morgan Wallen
13. Something in the Orange - Zach Bryan
14. Rich Flex - Drake and 21 Savage
15. As It Was - Harry Styles
16. Rock and a Hard Place - Bailey Zimmerman
17. Under the Influence - Chris Brown
18. Cruel Summer - Taylor Swift
19. Thinkin' Bout Me - Morgan Wallen
20. Boy's a Liar Pt. 2 - PinkPantheress and Ice Spice
21. Favorite Song - Toosii
22. Thought You Should Know - Morgan Wallen
23. Thank God - Kane Brown and Katelyn Brown
24. Sure Thing - Miguel
25. All My Life - Lil Durk featuring J. Cole
26. Ella Baila Sola - Eslabon Armado and Peso Pluma
27. Karma - Taylor Swift featuring Ice Spice
28. Just Wanna Rock - Lil Uzi Vert
29. Cuff It - Beyoncé
30. Vampire - Olivia Rodrigo
31. FukUMean - Gunna
32. Lavender Haze - Taylor Swift
33. Players - Coi Leray
34. Need a Favor - Jelly Roll
35. Dance the Night - Dua Lipa
36. Love You Anyway - Luke Combs
37. One Thing at a Time - Morgan Wallen
38. Superhero (Heroes & Villains) - Metro Boomin, Future and Chris Brown
39. Bad Habit - Steve Lacy
40. La Bebé - Yng Lvcas and Peso Pluma
41. Golden Hour - Jvke
42. Religiously - Bailey Zimmerman
43. Spin Bout U - Drake and 21 Savage
44. Cupid - Fifty Fifty
45. Search & Rescue - Drake
46. Barbie World - Nicki Minaj and Ice Spice with Aqua
47. Next Thing You Know - Jordan Davis
48. Escapism - Raye featuring 070 Shake
49. Un x100to - Grupo Frontera and Bad Bunny
50. Until I Found You - Stephen Sanchez
51. Shirt - SZA
52. Paint the Town Red - Doja Cat
53. Made You Look - Meghan Trainor
54. Wait in the Truck - Hardy featuring Lainey Wilson
55. All I Want for Christmas Is You - Mariah Carey
56. Everything I Love - Morgan Wallen
57. Chemical - Post Malone
58. Heart Like a Truck - Lainey Wilson
59. Goin', Going, Gone - Luke Combs
60. Rockin' Around the Christmas Tree - Brenda Lee
61. Dancin' in the Country - Tyler Hubbard
62. Daylight - David Kushner
63. Lift Me Up - Rihanna
64. Eyes Closed - Ed Sheeran
65. TQG - Karol G and Shakira
66. Try That in a Small Town - Jason Aldean
67. Tennessee Orange - Megan Moroney
68. Jingle Bell Rock - Bobby Helms
69. Princess Diana - Ice Spice and Nicki Minaj
70. Tomorrow 2 - GloRilla and Cardi B
71. A Holly Jolly Christmas - Burl Ives
72. Where She Goes - Bad Bunny
73. Bebe Dame - Fuerza Regida and Grupo Frontera
74. I Remember Everything - Zach Bryan featuring Kacey Musgraves
75. I Like You (A Happier Song) - Post Malone featuring Doja Cat

## Technical Details

### API Usage
- **YouTube Data API v3**: ~75 search requests (within quota limits)
- **Airtable REST API**: 8 batch create requests

### Scripts Created
1. `/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/process_song.sh` - Individual song search script
2. `/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/process_all_2023.sh` - Batch processing script
3. `/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/add_to_airtable.sh` - Airtable upload script

### Output Files
1. `/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/results.txt` - Search results for all 75 songs
2. `/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/2023_SONGS_ADDED.md` - This summary document

## Verification

Verified all 75 records were successfully added to Airtable:
```bash
curl -s 'https://api.airtable.com/v0/appxCBIOkiJEZiph7/MTvVideosNEW?filterByFormula={Year}="2023"'
```

Result: **75 total records** with Year="2023" confirmed in database.

## Notes

- All songs successfully found YouTube official videos
- Artist names were cleaned to show primary artist only
- No manual intervention was required
- All records include valid YouTube URLs
- The `artistID` field was not populated as it doesn't exist in the MTvVideosNEW table structure (differs from original MTvVideos table)

## Next Steps

The 2023 songs are now available in the app's Music Videos section and can be:
- Filtered by year (2023)
- Searched by title or artist
- Played directly via YouTube integration
- Added to favorites (with Sign in with Apple)
- Shared via iOS share sheet
