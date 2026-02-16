#!/usr/bin/env python3
"""
Add remaining 1998 Billboard songs to Airtable with YouTube videos and Last.fm scores.
"""

import requests
import time
import re
import json

# Configuration
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"  # MTvVideosNEW

YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
LASTFM_API_KEY = "96b182b4bd9bf6338d52fcfec34022c4"

# Songs to add (rank 76-100 for 1998)
SONGS_TO_ADD = [
    {"rank": 76, "title": "All for You", "artist": "Sister Hazel"},
    {"rank": 77, "title": "Touch It", "artist": "Monifah"},
    {"rank": 78, "title": "Money, Power & Respect", "artist": "The Lox featuring DMX and Lil' Kim"},
    {"rank": 79, "title": "Bitter Sweet Symphony", "artist": "The Verve"},
    {"rank": 80, "title": "Dangerous", "artist": "Busta Rhymes"},
    {"rank": 81, "title": "Spice Up Your Life", "artist": "Spice Girls"},
    {"rank": 82, "title": "Because of You", "artist": "98 Degrees"},
    {"rank": 83, "title": "The Mummers' Dance", "artist": "Loreena McKennitt"},
    {"rank": 84, "title": "All Cried Out", "artist": "Allure featuring 112"},
    {"rank": 85, "title": "Still Not a Player", "artist": "Big Punisher featuring Joe"},
    {"rank": 86, "title": "The One I Gave My Heart To", "artist": "Aaliyah"},
    {"rank": 87, "title": "Foolish Games / You Were Meant for Me", "artist": "Jewel"},
    {"rank": 88, "title": "Love You Down", "artist": "INOJ"},
    {"rank": 89, "title": "Do for Love", "artist": "2Pac featuring Eric Williams"},
    {"rank": 90, "title": "Raise the Roof", "artist": "Luke featuring No Good But So Good"},
    {"rank": 91, "title": "Heaven", "artist": "Nu Flavor"},
    {"rank": 92, "title": "The Party Continues", "artist": "JD featuring Da Brat"},
    {"rank": 93, "title": "Sock It 2 Me", "artist": "Missy Elliott featuring Da Brat"},
    {"rank": 94, "title": "Butta Love", "artist": "Next"},
    {"rank": 95, "title": "A Rose Is Still a Rose", "artist": "Aretha Franklin"},
    {"rank": 96, "title": "4 Seasons of Loneliness", "artist": "Boyz II Men"},
    {"rank": 97, "title": "Father", "artist": "LL Cool J"},
    {"rank": 98, "title": "Thinkin' Bout It", "artist": "Gerald Levert"},
    {"rank": 99, "title": "Nobody's Supposed to Be Here", "artist": "Deborah Cox"},
    {"rank": 100, "title": "Westside", "artist": "TQ"},
]


def clean_artist_name(artist):
    """Remove featuring/with clauses for cleaner search."""
    # Remove featuring clauses
    artist = re.split(r'\s+(?:featuring|feat\.?|ft\.?|with|&)\s+', artist, flags=re.IGNORECASE)[0]
    return artist.strip()


def search_youtube_video(title, artist):
    """Search YouTube for a music video."""
    clean_artist = clean_artist_name(artist)

    # Try different search queries
    search_queries = [
        f"{title} {clean_artist} official music video",
        f"{title} {clean_artist} music video",
        f"{title} {artist} official video",
        f"{title} {clean_artist}",
    ]

    for query in search_queries:
        url = "https://www.googleapis.com/youtube/v3/search"
        params = {
            "part": "snippet",
            "q": query,
            "type": "video",
            "videoCategoryId": "10",  # Music category
            "maxResults": 5,
            "key": YOUTUBE_API_KEY
        }

        try:
            response = requests.get(url, params=params)
            data = response.json()

            if "items" in data and len(data["items"]) > 0:
                # Look for official/VEVO channels first
                for item in data["items"]:
                    channel = item["snippet"]["channelTitle"].lower()
                    video_title = item["snippet"]["title"].lower()

                    # Prioritize official channels
                    if "vevo" in channel or "official" in channel or clean_artist.lower() in channel:
                        video_id = item["id"]["videoId"]
                        return f"https://www.youtube.com/watch?v={video_id}"

                # Fall back to first result
                video_id = data["items"][0]["id"]["videoId"]
                return f"https://www.youtube.com/watch?v={video_id}"

        except Exception as e:
            print(f"  YouTube search error: {e}")

        time.sleep(0.5)

    return None


def get_lastfm_playcount(title, artist):
    """Get play count from Last.fm."""
    clean_artist = clean_artist_name(artist)

    url = "http://ws.audioscrobbler.com/2.0/"
    params = {
        "method": "track.getInfo",
        "api_key": LASTFM_API_KEY,
        "artist": clean_artist,
        "track": title,
        "format": "json"
    }

    try:
        response = requests.get(url, params=params)
        data = response.json()

        if "track" in data and "playcount" in data["track"]:
            return int(data["track"]["playcount"])
    except Exception as e:
        print(f"  Last.fm error: {e}")

    return 0


def create_airtable_record(title, artist, url, rank, year):
    """Create a new record in Airtable."""
    api_url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"
    headers = {
        "Authorization": f"Bearer {AIRTABLE_API_KEY}",
        "Content-Type": "application/json"
    }

    # Clean artist name for storage (keep original with featuring)
    clean_artist = clean_artist_name(artist)

    data = {
        "fields": {
            "title": title,
            "artistName": clean_artist,  # Use cleaned artist name
            "url": url,
            "Rank": rank,
            "Year": str(year)  # Year is a string field, capitalized
        }
    }

    response = requests.post(api_url, headers=headers, json=data)

    if response.status_code == 200:
        return response.json()
    else:
        print(f"  Airtable error: {response.status_code} - {response.text}")
        return None


def update_airtable_record(record_id, playcount):
    """Update SpotifyRank field for a record."""
    api_url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}/{record_id}"
    headers = {
        "Authorization": f"Bearer {AIRTABLE_API_KEY}",
        "Content-Type": "application/json"
    }

    data = {
        "fields": {
            "SpotifyRank": playcount
        }
    }

    response = requests.patch(api_url, headers=headers, json=data)
    return response.status_code == 200


def main():
    print("="*60)
    print("ADDING REMAINING 1998 BILLBOARD SONGS (Rank 76-100)")
    print("="*60 + "\n")

    results = []

    for i, song in enumerate(SONGS_TO_ADD):
        title = song["title"]
        artist = song["artist"]
        rank = song["rank"]

        print(f"[{i+1}/{len(SONGS_TO_ADD)}] #{rank}: {title} - {artist}")

        # Search YouTube
        print("  Searching YouTube...")
        video_url = search_youtube_video(title, artist)

        if video_url:
            print(f"  Found: {video_url}")
        else:
            print("  No video found!")
            continue

        # Get Last.fm playcount
        print("  Getting Last.fm plays...")
        playcount = get_lastfm_playcount(title, artist)
        print(f"  Play count: {playcount:,}")

        # Create Airtable record
        print("  Adding to Airtable...")
        record = create_airtable_record(title, artist, video_url, rank, 1998)

        if record:
            record_id = record.get("id")
            print("  Added successfully ✓")

            # Update SpotifyRank field
            if playcount > 0 and record_id:
                if update_airtable_record(record_id, playcount):
                    print(f"  Updated SpotifyRank ✓")
                else:
                    print(f"  Failed to update SpotifyRank")

            results.append({
                "rank": rank,
                "title": title,
                "artist": artist,
                "url": video_url,
                "playcount": playcount
            })
        else:
            print("  Failed to add ✗")

        print()
        time.sleep(1)  # Rate limiting

    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print(f"Successfully added: {len(results)}/{len(SONGS_TO_ADD)} songs")

    # Sort by playcount
    results.sort(key=lambda x: x["playcount"], reverse=True)

    print("\nNew songs ranked by Last.fm plays:")
    for r in results:
        plays = f"{r['playcount']:,}" if r['playcount'] else "N/A"
        print(f"  #{r['rank']:3}: {r['title'][:35]:<35} - {r['artist'][:20]:<20} ({plays})")

    # Save results
    with open("1998_remaining_results.json", "w") as f:
        json.dump(results, f, indent=2)

    print("\nResults saved to 1998_remaining_results.json")


if __name__ == "__main__":
    main()
