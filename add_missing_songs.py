#!/usr/bin/env python3
"""
Add missing Billboard Hot 100 songs (ranks 76-100) to Airtable MTvVideosNEW table.
Uses YouTube Data API v3 to find the best official music video for each song.
Uses only built-in Python libraries (no external dependencies).
"""

import urllib.request
import urllib.parse
import urllib.error
import time
import json
import re
import sys
import ssl

# API Configuration
YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"  # MTvVideosNEW

# Rate limiting delays (in seconds)
YOUTUBE_DELAY = 1.5
AIRTABLE_DELAY = 0.5

# SSL context for HTTPS
ssl_context = ssl.create_default_context()


def clean_artist_name(artist: str) -> str:
    """Extract the main artist name from collaboration credits."""
    patterns = [
        r'\s+featuring\s+.*$',
        r'\s+feat\.\s+.*$',
        r'\s+ft\.\s+.*$',
        r'\s+with\s+.*$',
        r'\s+and\s+.*$',
        r'\s+&\s+.*$',
        r'\s+x\s+.*$',
    ]

    cleaned = artist
    for pattern in patterns:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE)

    cleaned = re.sub(r'\s*\(.*\)$', '', cleaned)
    return cleaned.strip()


def make_request(url: str, headers: dict = None, data: bytes = None, method: str = None) -> dict:
    """Make an HTTP request and return JSON response."""
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)

    try:
        with urllib.request.urlopen(req, context=ssl_context, timeout=30) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        return {'error': {'code': e.code, 'message': error_body}}
    except Exception as e:
        return {'error': {'code': 0, 'message': str(e)}}


def search_youtube_video(title: str, artist: str) -> dict | None:
    """
    Search YouTube for the best official music video.
    Uses multiple search strategies and prioritizes official channels.
    """
    cleaned_artist = clean_artist_name(artist)

    search_queries = [
        f'"{title}" "{cleaned_artist}" official music video',
        f'{title} {cleaned_artist} official video',
        f'{title} {cleaned_artist} music video',
        f'{title} {cleaned_artist}',
    ]

    for query in search_queries:
        try:
            params = urllib.parse.urlencode({
                'part': 'snippet',
                'q': query,
                'type': 'video',
                'videoCategoryId': '10',
                'maxResults': 5,
                'key': YOUTUBE_API_KEY,
            })

            url = f'https://www.googleapis.com/youtube/v3/search?{params}'
            data = make_request(url)

            if 'error' in data:
                print(f"  YouTube API error: {data['error']}")
                continue

            items = data.get('items', [])
            if not items:
                continue

            best_result = None
            best_score = -1

            for item in items:
                snippet = item.get('snippet', {})
                video_id = item.get('id', {}).get('videoId', '')
                channel_title = snippet.get('channelTitle', '').lower()
                video_title = snippet.get('title', '').lower()

                if not video_id:
                    continue

                score = 0

                # Prioritize official channels
                if 'vevo' in channel_title:
                    score += 100
                if cleaned_artist.lower() in channel_title:
                    score += 80
                if 'official' in channel_title:
                    score += 50

                # Check video title
                if 'official' in video_title:
                    score += 30
                if 'music video' in video_title:
                    score += 20
                if 'official video' in video_title:
                    score += 25
                if 'official music video' in video_title:
                    score += 35

                # Penalize non-official content
                if 'cover' in video_title and cleaned_artist.lower() not in channel_title:
                    score -= 100
                if 'remix' in video_title:
                    score -= 20
                if 'live' in video_title and 'official' not in video_title:
                    score -= 10
                if 'karaoke' in video_title:
                    score -= 100
                if 'lyrics' in video_title and 'official' not in video_title:
                    score -= 5

                # Strong bonus for title match (required for good match)
                title_words = title.lower().split()
                title_match_count = sum(1 for word in title_words if len(word) > 2 and word in video_title)
                title_match_ratio = title_match_count / len(title_words) if title_words else 0

                if title.lower() in video_title:
                    score += 100  # Exact title match
                elif title_match_ratio >= 0.7:
                    score += 60  # Most words match
                elif title_match_ratio >= 0.5:
                    score += 30  # Half words match
                else:
                    score -= 50  # Penalize if title doesn't match well

                if score > best_score:
                    best_score = score
                    best_result = {
                        'videoId': video_id,
                        'title': snippet.get('title', ''),
                        'channelTitle': snippet.get('channelTitle', ''),
                        'score': score
                    }

            if best_result and best_score >= 0:
                return best_result

            time.sleep(YOUTUBE_DELAY)

        except Exception as e:
            print(f"  Search error: {e}")
            continue

    return None


def add_to_airtable(records: list) -> dict:
    """Add records to Airtable MTvVideosNEW table."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"
    headers = {
        'Authorization': f'Bearer {AIRTABLE_API_KEY}',
        'Content-Type': 'application/json'
    }

    results = {'success': 0, 'failed': 0, 'errors': []}

    batch_size = 10
    for i in range(0, len(records), batch_size):
        batch = records[i:i + batch_size]

        payload = json.dumps({
            'records': [{'fields': record} for record in batch]
        }).encode('utf-8')

        try:
            data = make_request(url, headers=headers, data=payload, method='POST')

            if 'error' in data:
                results['failed'] += len(batch)
                error_msg = data['error'].get('message', str(data['error']))
                results['errors'].append(f"Batch {i // batch_size + 1}: {error_msg}")
                print(f"  Error in batch {i // batch_size + 1}: {error_msg}")
            else:
                results['success'] += len(batch)
                print(f"  Added batch {i // batch_size + 1}: {len(batch)} records")

            time.sleep(AIRTABLE_DELAY)

        except Exception as e:
            results['failed'] += len(batch)
            results['errors'].append(str(e))
            print(f"  Exception in batch {i // batch_size + 1}: {e}")

    return results


def process_songs(songs: list, year: int, dry_run: bool = False) -> dict:
    """Process a list of songs: find YouTube videos and add to Airtable."""
    records_to_add = []
    not_found = []

    print(f"\nProcessing {len(songs)} songs for {year}...")
    print("=" * 60)

    for rank, title, artist in songs:
        print(f"\n[{rank}] {title} - {artist}")

        result = search_youtube_video(title, artist)

        if result:
            video_url = f"https://www.youtube.com/watch?v={result['videoId']}"
            cleaned_artist = clean_artist_name(artist)

            print(f"  ✓ Found: {result['title'][:60]}...")
            print(f"  Channel: {result['channelTitle']}")
            print(f"  Score: {result['score']}")

            record = {
                'title': title,
                'url': video_url,
                'Rank': rank,
                'artistName': cleaned_artist,
                'Year': str(year),
            }
            records_to_add.append(record)
        else:
            print(f"  ✗ NOT FOUND")
            not_found.append((rank, title, artist))

        time.sleep(YOUTUBE_DELAY)

    print("\n" + "=" * 60)
    print(f"YouTube search complete: {len(records_to_add)} found, {len(not_found)} not found")

    if not_found:
        print("\nSongs not found:")
        for rank, title, artist in not_found:
            print(f"  [{rank}] {title} - {artist}")

    if not dry_run and records_to_add:
        print(f"\nAdding {len(records_to_add)} records to Airtable...")
        airtable_results = add_to_airtable(records_to_add)
        print(f"Airtable results: {airtable_results['success']} success, {airtable_results['failed']} failed")

        if airtable_results['errors']:
            print("Errors:")
            for error in airtable_results['errors']:
                print(f"  - {error}")
    elif dry_run:
        print("\n[DRY RUN] Skipping Airtable upload")

    return {
        'year': year,
        'processed': len(songs),
        'found': len(records_to_add),
        'not_found': len(not_found),
        'not_found_songs': not_found,
        'records': records_to_add
    }


# 2021 missing songs (ranks 76-100) from Billboard CSV
SONGS_2021 = [
    (76, "Time Today", "Moneybagg Yo"),
    (77, "Cry Baby", "Megan Thee Stallion featuring DaBaby"),
    (78, "All I Want for Christmas Is You", "Mariah Carey"),
    (79, "No More Parties", "Coi Leray featuring Lil Durk"),
    (80, "What's Your Country Song", "Thomas Rhett"),
    (81, "One Too Many", "Keith Urban and Pink"),
    (82, "Arcade", "Duncan Laurence"),
    (83, "Yonaguni", "Bad Bunny"),
    (84, "Good Time", "Niko Moon"),
    (85, "If I Didn't Love You", "Jason Aldean and Carrie Underwood"),
    (86, "Knife Talk", "Drake featuring 21 Savage and Project Pat"),
    (87, "POV", "Ariana Grande"),
    (88, "Just the Way", "Parmalee and Blanco Brown"),
    (89, "Take My Breath", "The Weeknd"),
    (90, "We're Good", "Dua Lipa"),
    (91, "Hell of a View", "Eric Church"),
    (92, "Rockin' Around the Christmas Tree", "Brenda Lee"),
    (93, "Put Your Records On", "Ritt Momney"),
    (94, "Happier Than Ever", "Billie Eilish"),
    (95, "Single Saturday Night", "Cole Swindell"),
    (96, "Things a Man Oughta Know", "Lainey Wilson"),
    (97, "Throat Baby (Go Baby)", "BRS Kash"),
    (98, "Tombstone", "Rod Wave"),
    (99, "Drinkin' Beer. Talkin' God. Amen.", "Chase Rice featuring Florida Georgia Line"),
    (100, "Todo de Ti", "Rauw Alejandro"),
]


if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv

    if dry_run:
        print("Running in DRY RUN mode - will not add to Airtable")

    results = process_songs(SONGS_2021, 2021, dry_run=dry_run)

    with open('2021_missing_songs_results.json', 'w') as f:
        json.dump(results, f, indent=2, default=str)

    print(f"\nResults saved to 2021_missing_songs_results.json")
