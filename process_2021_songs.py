#!/usr/bin/env python3
"""
Process 2021 songs and add them to Airtable MTvVideosNEW table
"""

import requests
import time
import json
import re
from urllib.parse import quote

# Configuration
YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"  # MTvVideosNEW

# Songs data (Rank, Title, Artist)
SONGS_2021 = [
    (1, "Levitating", "Dua Lipa"),
    (2, "Save Your Tears", "The Weeknd and Ariana Grande"),
    (3, "Blinding Lights", "The Weeknd"),
    (4, "Mood", "24kGoldn featuring Iann Dior"),
    (5, "Good 4 U", "Olivia Rodrigo"),
    (6, "Kiss Me More", "Doja Cat featuring SZA"),
    (7, "Leave the Door Open", "Silk Sonic (Bruno Mars and Anderson .Paak)"),
    (8, "Drivers License", "Olivia Rodrigo"),
    (9, "Montero (Call Me by Your Name)", "Lil Nas X"),
    (10, "Peaches", "Justin Bieber featuring Daniel Caesar and Giveon"),
    (11, "Butter", "BTS"),
    (12, "Stay", "The Kid Laroi and Justin Bieber"),
    (13, "Deja Vu", "Olivia Rodrigo"),
    (14, "Positions", "Ariana Grande"),
    (15, "Bad Habits", "Ed Sheeran"),
    (16, "Heat Waves", "Glass Animals"),
    (17, "Without You", "The Kid Laroi"),
    (18, "Forever After All", "Luke Combs"),
    (19, "Go Crazy", "Chris Brown and Young Thug"),
    (20, "Astronaut in the Ocean", "Masked Wolf"),
    (21, "34+35", "Ariana Grande featuring Doja Cat and Megan Thee Stallion"),
    (22, "What You Know Bout Love", "Pop Smoke"),
    (23, "My Ex's Best Friend", "Machine Gun Kelly featuring Blackbear"),
    (24, "Industry Baby", "Lil Nas X and Jack Harlow"),
    (25, "Therefore I Am", "Billie Eilish"),
    (26, "Up", "Cardi B"),
    (27, "Fancy Like", "Walker Hayes"),
    (28, "Dakiti", "Bad Bunny and Jhay Cortez"),
    (29, "Best Friend", "Saweetie featuring Doja Cat"),
    (30, "Rapstar", "Polo G"),
    (31, "Heartbreak Anniversary", "Giveon"),
    (32, "For the Night", "Pop Smoke featuring Lil Baby and DaBaby"),
    (33, "Calling My Phone", "Lil Tjay and 6lack"),
    (34, "Beautiful Mistakes", "Maroon 5 featuring Megan Thee Stallion"),
    (35, "Holy", "Justin Bieber featuring Chance the Rapper"),
    (36, "On Me", "Lil Baby"),
    (37, "You Broke Me First", "Tate McRae"),
    (38, "Traitor", "Olivia Rodrigo"),
    (39, "Back in Blood", "Pooh Shiesty featuring Lil Durk"),
    (40, "I Hope", "Gabby Barrett featuring Charlie Puth"),
    (41, "Dynamite", "BTS"),
    (42, "Wockesha", "Moneybagg Yo"),
    (43, "You Right", "Doja Cat and the Weeknd"),
    (44, "Beat Box 2", "SpotemGottem featuring Pooh Shiesty"),
    (45, "Laugh Now Cry Later", "Drake featuring Lil Durk"),
    (46, "Need to Know", "Doja Cat"),
    (47, "Wants and Needs", "Drake featuring Lil Baby"),
    (48, "Way 2 Sexy", "Drake featuring Future and Young Thug"),
    (49, "Telepatía", "Kali Uchis"),
    (50, "Whoopty", "CJ"),
    (51, "Lemonade", "Internet Money and Gunna featuring Don Toliver and Nav"),
    (52, "Good Days", "SZA"),
    (53, "Starting Over", "Chris Stapleton"),
    (54, "Body", "Megan Thee Stallion"),
    (55, "Willow", "Taylor Swift"),
    (56, "Bang!", "AJR"),
    (57, "Better Together", "Luke Combs"),
    (58, "You're Mines Still", "Yung Bleu featuring Drake"),
    (59, "Every Chance I Get", "DJ Khaled featuring Lil Baby and Lil Durk"),
    (60, "Essence", "Wizkid featuring Justin Bieber and Tems"),
    (61, "Chasing After You", "Ryan Hurd and Maren Morris"),
    (62, "The Good Ones", "Gabby Barrett"),
    (63, "Leave Before You Love Me", "Marshmello and Jonas Brothers"),
    (64, "Glad You Exist", "Dan + Shay"),
    (65, "Lonely", "Justin Bieber and Benny Blanco"),
    (66, "Beggin'", "Måneskin"),
    (67, "Streets", "Doja Cat"),
    (68, "What's Next", "Drake"),
    (69, "Famous Friends", "Chris Young and Kane Brown"),
    (70, "Lil Bit", "Nelly and Florida Georgia Line"),
    (71, "Thot Shit", "Megan Thee Stallion"),
    (72, "Late at Night", "Roddy Ricch"),
    (73, "Kings & Queens", "Ava Max"),
    (74, "Anyone", "Justin Bieber"),
    (75, "Track Star", "Mooski"),
]


def clean_artist_name(artist):
    """Extract the main artist name from collaboration strings"""
    # Remove everything after 'featuring', 'and', 'with', etc.
    patterns = [
        r'\s+featuring\s+.*',
        r'\s+feat\.\s+.*',
        r'\s+ft\.\s+.*',
        r'\s+and\s+.*',
        r'\s+with\s+.*',
        r'\s+\(.*\)',  # Remove parenthetical content
    ]

    cleaned = artist
    for pattern in patterns:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE)

    return cleaned.strip()


def search_youtube_video(title, artist):
    """Search YouTube for the official music video"""
    query = f"{title} {artist} official video"
    url = f"https://www.googleapis.com/youtube/v3/search"
    params = {
        'part': 'snippet',
        'type': 'video',
        'q': query,
        'maxResults': 1,
        'key': YOUTUBE_API_KEY,
        'videoCategoryId': '10',  # Music category
    }

    try:
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()

        if 'items' in data and len(data['items']) > 0:
            video_id = data['items'][0]['id']['videoId']
            video_url = f"https://www.youtube.com/watch?v={video_id}"
            video_title = data['items'][0]['snippet']['title']
            return video_url, video_title
        else:
            return None, None
    except Exception as e:
        print(f"  ❌ YouTube search error: {str(e)}")
        return None, None


def add_to_airtable(record_data):
    """Add a record to Airtable MTvVideosNEW table"""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"
    headers = {
        'Authorization': f'Bearer {AIRTABLE_API_KEY}',
        'Content-Type': 'application/json'
    }

    payload = {
        'fields': record_data
    }

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=10)
        response.raise_for_status()
        return True, response.json()
    except requests.exceptions.HTTPError as e:
        # Try to get detailed error message from response
        try:
            error_detail = response.json()
            return False, f"{str(e)} - {error_detail}"
        except:
            return False, str(e)
    except Exception as e:
        return False, str(e)


def process_songs():
    """Process all songs and add them to Airtable"""
    results = {
        'successful': [],
        'failed': [],
        'no_video_found': []
    }

    total_songs = len(SONGS_2021)
    print(f"\n🎵 Processing {total_songs} songs from 2021...\n")

    for rank, title, artist in SONGS_2021:
        print(f"[{rank}/{total_songs}] Processing: {title} - {artist}")

        # Search for YouTube video
        video_url, video_title = search_youtube_video(title, artist)

        if not video_url:
            print(f"  ⚠️  No video found for: {title}")
            results['no_video_found'].append({
                'rank': rank,
                'title': title,
                'artist': artist
            })
            time.sleep(0.5)  # Small delay to avoid rate limits
            continue

        print(f"  ✅ Found video: {video_title}")
        print(f"  🔗 URL: {video_url}")

        # Clean artist name
        cleaned_artist = clean_artist_name(artist)
        print(f"  👤 Artist: {cleaned_artist}")

        # Prepare Airtable record
        record_data = {
            'title': title,
            'url': video_url,
            'Rank': rank,
            'artistName': cleaned_artist,
            'Year': '2021'  # Field name is 'Year' (capital Y) and value is string
        }

        # Add to Airtable
        success, response = add_to_airtable(record_data)

        if success:
            print(f"  ✅ Added to Airtable")
            results['successful'].append({
                'rank': rank,
                'title': title,
                'artist': artist,
                'video_url': video_url,
                'airtable_id': response.get('id', 'unknown')
            })
        else:
            print(f"  ❌ Failed to add to Airtable: {response}")
            results['failed'].append({
                'rank': rank,
                'title': title,
                'artist': artist,
                'error': response
            })

        print()

        # Rate limiting: Add delay between requests
        time.sleep(1.5)  # 1.5 seconds between songs to be safe

    return results


def print_summary(results):
    """Print a summary of the processing results"""
    print("\n" + "="*70)
    print("📊 PROCESSING SUMMARY")
    print("="*70 + "\n")

    print(f"✅ Successfully added: {len(results['successful'])} songs")
    print(f"⚠️  No video found: {len(results['no_video_found'])} songs")
    print(f"❌ Failed to add: {len(results['failed'])} songs")
    print(f"📈 Total processed: {len(SONGS_2021)} songs\n")

    if results['no_video_found']:
        print("\n⚠️  Songs with no video found:")
        print("-" * 70)
        for song in results['no_video_found']:
            print(f"  {song['rank']}. {song['title']} - {song['artist']}")

    if results['failed']:
        print("\n❌ Failed to add to Airtable:")
        print("-" * 70)
        for song in results['failed']:
            print(f"  {song['rank']}. {song['title']} - {song['artist']}")
            print(f"     Error: {song['error']}")

    if results['successful']:
        print(f"\n✅ Successfully added {len(results['successful'])} songs to Airtable!")
        print("-" * 70)
        print("Sample entries:")
        for song in results['successful'][:5]:
            print(f"  {song['rank']}. {song['title']} - {song['artist']}")
            print(f"     URL: {song['video_url']}")
            print(f"     Airtable ID: {song['airtable_id']}")

    print("\n" + "="*70 + "\n")


if __name__ == "__main__":
    print("🎵 2021 Songs Processor for Hit Rewind")
    print("="*70)

    results = process_songs()
    print_summary(results)

    # Save results to JSON file for reference
    output_file = "/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/2021_processing_results.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"📄 Detailed results saved to: {output_file}\n")
