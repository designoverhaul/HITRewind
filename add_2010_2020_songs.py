#!/usr/bin/env python3
"""
Add Billboard Year-End Hot 100 songs (ranks 76-100) for years 2010-2020 to Airtable.
Uses YouTube Data API v3 to search for official music videos.
"""

import csv
import json
import time
import urllib.request
import urllib.parse
import ssl
import sys

# Force unbuffered output
sys.stdout.reconfigure(line_buffering=True)

# API Keys
YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"  # MTvVideosNEW

# Create SSL context that doesn't verify certificates (for development)
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE


def search_youtube(title, artist):
    """Search YouTube for a music video and return the video URL."""
    query = f"{title} {artist} official music video"
    encoded_query = urllib.parse.quote(query)

    url = f"https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q={encoded_query}&maxResults=1&videoCategoryId=10&key={YOUTUBE_API_KEY}"

    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=30, context=ssl_context) as response:
            data = json.loads(response.read().decode('utf-8'))

            if data.get('items') and len(data['items']) > 0:
                video_id = data['items'][0]['id']['videoId']
                return f"https://www.youtube.com/watch?v={video_id}"
    except Exception as e:
        print(f"  YouTube search error for '{title}' by '{artist}': {e}")

    return None


def create_artist_id(artist_name):
    """Create a simple artist ID from the artist name."""
    # Take first artist if there are multiple
    main_artist = artist_name.split(' featuring ')[0].split(' feat.')[0].split(' and ')[0].split(' & ')[0]
    # Remove special characters and convert to lowercase
    artist_id = ''.join(c for c in main_artist if c.isalnum() or c == ' ').strip().lower().replace(' ', '-')
    return artist_id


def add_to_airtable(records):
    """Add records to Airtable in batches of 10."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"

    # Process in batches of 10
    for i in range(0, len(records), 10):
        batch = records[i:i+10]

        payload = {
            "records": [
                {
                    "fields": {
                        "title": record['title'],
                        "url": record['url'],
                        "Rank": record['rank'],
                        "artistName": record['artist'],
                        "Year": str(record['year'])  # Capital Y, string type
                    }
                }
                for record in batch
            ]
        }

        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(url, data=data, method='POST')
        req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')
        req.add_header('Content-Type', 'application/json')

        try:
            with urllib.request.urlopen(req, timeout=30, context=ssl_context) as response:
                result = json.loads(response.read().decode('utf-8'))
                print(f"  Added batch of {len(batch)} records to Airtable")
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8')
            print(f"  Airtable error: {e.code} - {error_body}")
        except Exception as e:
            print(f"  Airtable error: {e}")

        # Rate limiting
        time.sleep(0.25)


def process_year(year, songs):
    """Process all songs for a given year."""
    print(f"\n{'='*60}")
    print(f"Processing year {year} - {len(songs)} songs")
    print(f"{'='*60}")

    records_to_add = []

    for i, song in enumerate(songs):
        rank, title, artist = song
        print(f"\n[{i+1}/{len(songs)}] Rank {rank}: {title} - {artist}")

        # Search YouTube for the video
        video_url = search_youtube(title, artist)

        if video_url:
            print(f"  Found: {video_url}")
            records_to_add.append({
                'title': title,
                'url': video_url,
                'rank': rank,
                'artist': artist,
                'year': year,
                'artistID': create_artist_id(artist)
            })
        else:
            print(f"  Not found on YouTube")

        # Rate limiting for YouTube API (100 queries per 100 seconds)
        time.sleep(1.1)

    # Add records to Airtable
    if records_to_add:
        print(f"\nAdding {len(records_to_add)} records to Airtable for year {year}...")
        add_to_airtable(records_to_add)

    return len(records_to_add)


def main():
    # Check command line arguments for specific year
    target_year = None
    if len(sys.argv) > 1:
        try:
            target_year = int(sys.argv[1])
            print(f"Processing only year {target_year}")
        except ValueError:
            print(f"Invalid year: {sys.argv[1]}")
            return

    # Read the CSV file and extract songs for 2010-2020, ranks 76-100
    songs_by_year = {}

    with open('Full_Billboard_year_end_hot_100_USA.csv', 'r', encoding='latin-1') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                year = int(row['Year'])
            except ValueError:
                continue

            rank_str = row['No.'].replace('(Tie)', '').strip()
            try:
                rank = int(rank_str)
            except ValueError:
                continue

            # Filter for 2010-2020 and ranks 76-100
            if 2010 <= year <= 2020 and 76 <= rank <= 100:
                if target_year and year != target_year:
                    continue

                if year not in songs_by_year:
                    songs_by_year[year] = []
                songs_by_year[year].append((rank, row['Title'], row['Artist(s)']))

    print(f"Found songs for years: {sorted(songs_by_year.keys())}")
    for year in sorted(songs_by_year.keys()):
        print(f"  {year}: {len(songs_by_year[year])} songs")

    # Process each year
    total_added = 0
    for year in sorted(songs_by_year.keys()):
        added = process_year(year, songs_by_year[year])
        total_added += added

    print(f"\n{'='*60}")
    print(f"COMPLETE: Added {total_added} songs total")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
