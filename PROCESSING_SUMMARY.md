# Music Video Processing Summary

## Overview
This document tracks the batch processing of music videos added to the Airtable MTvVideosNEW table.

## Processing Scripts

The following reusable scripts were created for processing songs:
- `process_song.sh` - Searches YouTube for individual songs
- `add_to_airtable.sh` - Batch uploads records to Airtable
- `search_youtube.sh` - YouTube API testing script

## Completed Years

### 2023 Songs ✅
- **Status**: Complete
- **Date**: January 12, 2026
- **Records Added**: 75 songs
- **Success Rate**: 100% (75/75)
- **Documentation**: `2023_SONGS_ADDED.md`
- **Output**: `results.txt`

See `2023_SONGS_ADDED.md` for complete details.

## Technical Stack

- **YouTube Data API v3**: Video search and metadata
- **Airtable REST API**: Database storage
- **Bash Scripts**: Automation and batch processing
- **Python**: JSON parsing and data manipulation

## API Configuration

### YouTube API
- API Key: Configured in `/HIt Rewind2/Constants/Constants.swift`
- Base URL: `https://www.googleapis.com/youtube/v3`
- Search endpoint: `/search`

### Airtable API
- API Key: Configured in `/HIt Rewind2/Constants/Constants.swift`
- Base ID: `appxCBIOkiJEZiph7`
- Table: `MTvVideosNEW` (tblNwqwVyflL8hNDy)

## Table Structure

### MTvVideosNEW Fields
- `title` (Single line text)
- `url` (Single line text) - YouTube video URL
- `Rank` (Number)
- `artistName` (Single line text)
- `Year` (Single line text)
- `videoImage` (Formula) - Auto-generated from URL
- `videoImage0` (Formula) - Auto-generated from URL

Note: Unlike the original MTvVideos table, MTvVideosNEW does not include `artistID`, `channelName`, `thumbnail`, or `Find Replace` fields.

## Future Processing

To process additional years, use the existing scripts:
1. Update song data in `process_all_YYYY.sh`
2. Run `./process_all_YYYY.sh` to search YouTube
3. Run `./add_to_airtable.sh` to upload to Airtable
4. Verify records in Airtable web interface or via API

## Maintenance

- Keep API keys secure and rotate periodically
- Monitor YouTube API quota usage
- Check Airtable record limits and pricing
- Update documentation for each new batch of songs
