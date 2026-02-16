#!/usr/bin/env python3
import json

# Helper function to extract artist name (before featuring)
def extract_artist_name(artist):
    patterns = [' featuring ', ' feat. ', ' feat ', ' ft. ', ' ft ', ' with ']
    for pattern in patterns:
        if pattern in artist.lower():
            idx = artist.lower().index(pattern)
            return artist[:idx].strip()
    return artist.strip()

# Load the video data
with open('2002_videos_data.json', 'r') as f:
    videos = json.load(f)

# Split into batches of 10 (Airtable limit)
batches = [videos[i:i+10] for i in range(0, len(videos), 10)]

print(f"Processing {len(videos)} videos in {len(batches)} batches\n")

for batch_num, batch in enumerate(batches, 1):
    print(f"=== Batch {batch_num}/{len(batches)} ===")
    print("Records to add:")

    for video in batch:
        artist_name = extract_artist_name(video['artist'])
        url = f"https://www.youtube.com/watch?v={video['videoId']}"

        print(f"  [{video['rank']}] {video['title']} - {artist_name}")
        print(f"      URL: {url}")

    print()

print("\nTo add these records, use the Airtable MCP tool 'batch_create_records' with:")
print("  baseId: appxCBIOkiJEZiph7")
print("  tableId: tblNwqwVyflL8hNDy")
print("\nEach record should have fields:")
print("  - title: string")
print("  - url: string (full YouTube URL)")
print("  - Rank: number")
print("  - artistName: string (cleaned)")
print("  - Year: string (\"2002\")")
print("  - artistID: string (empty)")
