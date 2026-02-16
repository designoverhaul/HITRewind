#!/usr/bin/env python3
"""
Script to add 2023 songs to Airtable MTvVideosNEW table.
Uses YouTube Data API v3 to search for official music videos.
"""

import requests
import json
import time
from typing import Dict, List, Tuple, Optional

# Configuration
YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"

# 2023 Songs Data (Rank, Title, Artist)
SONGS_2023 = [
    (1, "Last Night", "Morgan Wallen"),
    (2, "Flowers", "Miley Cyrus"),
    (3, "Kill Bill", "SZA"),
    (4, "Anti-Hero", "Taylor Swift"),
    (5, "Creepin'", "Metro Boomin, the Weeknd and 21 Savage"),
    (6, "Calm Down", "Rema and Selena Gomez"),
    (7, "Die for You", "The Weeknd and Ariana Grande"),
    (8, "Fast Car", "Luke Combs"),
    (9, "Snooze", "SZA"),
    (10, "I'm Good (Blue)", "David Guetta and Bebe Rexha"),
    (11, "Unholy", "Sam Smith and Kim Petras"),
    (12, "You Proof", "Morgan Wallen"),
    (13, "Something in the Orange", "Zach Bryan"),
    (14, "Rich Flex", "Drake and 21 Savage"),
    (15, "As It Was", "Harry Styles"),
    (16, "Rock and a Hard Place", "Bailey Zimmerman"),
    (17, "Under the Influence", "Chris Brown"),
    (18, "Cruel Summer", "Taylor Swift"),
    (19, "Thinkin' Bout Me", "Morgan Wallen"),
    (20, "Boy's a Liar Pt. 2", "PinkPantheress and Ice Spice"),
    (21, "Favorite Song", "Toosii"),
    (22, "Thought You Should Know", "Morgan Wallen"),
    (23, "Thank God", "Kane Brown and Katelyn Brown"),
    (24, "Sure Thing", "Miguel"),
    (25, "All My Life", "Lil Durk featuring J. Cole"),
    (26, "Ella Baila Sola", "Eslabon Armado and Peso Pluma"),
    (27, "Karma", "Taylor Swift featuring Ice Spice"),
    (28, "Just Wanna Rock", "Lil Uzi Vert"),
    (29, "Cuff It", "Beyoncé"),
    (30, "Vampire", "Olivia Rodrigo"),
    (31, "FukUMean", "Gunna"),
    (32, "Lavender Haze", "Taylor Swift"),
    (33, "Players", "Coi Leray"),
    (34, "Need a Favor", "Jelly Roll"),
    (35, "Dance the Night", "Dua Lipa"),
    (36, "Love You Anyway", "Luke Combs"),
    (37, "One Thing at a Time", "Morgan Wallen"),
    (38, "Superhero (Heroes & Villains)", "Metro Boomin, Future and Chris Brown"),
    (39, "Bad Habit", "Steve Lacy"),
    (40, "La Bebé", "Yng Lvcas and Peso Pluma"),
    (41, "Golden Hour", "Jvke"),
    (42, "Religiously", "Bailey Zimmerman"),
    (43, "Spin Bout U", "Drake and 21 Savage"),
    (44, "Cupid", "Fifty Fifty"),
    (45, "Search & Rescue", "Drake"),
    (46, "Barbie World", "Nicki Minaj and Ice Spice with Aqua"),
    (47, "Next Thing You Know", "Jordan Davis"),
    (48, "Escapism", "Raye featuring 070 Shake"),
    (49, "Un x100to", "Grupo Frontera and Bad Bunny"),
    (50, "Until I Found You", "Stephen Sanchez"),
    (51, "Shirt", "SZA"),
    (52, "Paint the Town Red", "Doja Cat"),
    (53, "Made You Look", "Meghan Trainor"),
    (54, "Wait in the Truck", "Hardy featuring Lainey Wilson"),
    (55, "All I Want for Christmas Is You", "Mariah Carey"),
    (56, "Everything I Love", "Morgan Wallen"),
    (57, "Chemical", "Post Malone"),
    (58, "Heart Like a Truck", "Lainey Wilson"),
    (59, "Goin', Going, Gone", "Luke Combs"),
    (60, "Rockin' Around the Christmas Tree", "Brenda Lee"),
    (61, "Dancin' in the Country", "Tyler Hubbard"),
    (62, "Daylight", "David Kushner"),
    (63, "Lift Me Up", "Rihanna"),
    (64, "Eyes Closed", "Ed Sheeran"),
    (65, "TQG", "Karol G and Shakira"),
    (66, "Try That in a Small Town", "Jason Aldean"),
    (67, "Tennessee Orange", "Megan Moroney"),
    (68, "Jingle Bell Rock", "Bobby Helms"),
    (69, "Princess Diana", "Ice Spice and Nicki Minaj"),
    (70, "Tomorrow 2", "GloRilla and Cardi B"),
    (71, "A Holly Jolly Christmas", "Burl Ives"),
    (72, "Where She Goes", "Bad Bunny"),
    (73, "Bebe Dame", "Fuerza Regida and Grupo Frontera"),
    (74, "I Remember Everything", "Zach Bryan featuring Kacey Musgraves"),
    (75, "I Like You (A Happier Song)", "Post Malone featuring Doja Cat"),
]


def clean_artist_name(artist: str) -> str:
    """Extract the main artist name from collaboration strings."""
    # Handle different collaboration formats
    for separator in [" featuring ", " and ", ", ", " with "]:
        if separator in artist:
            return artist.split(separator)[0].strip()
    return artist.strip()


def search_youtube_video(title: str, artist: str) -> Optional[str]:
    """Search for a music video on YouTube and return the video ID."""
    query = f"{title} {artist} official video"

    params = {
        "part": "snippet",
        "q": query,
        "type": "video",
        "maxResults": 1,
        "key": YOUTUBE_API_KEY,
        "videoCategoryId": "10",  # Music category
    }

    try:
        response = requests.get(YOUTUBE_SEARCH_URL, params=params)
        response.raise_for_status()
        data = response.json()

        if "items" in data and len(data["items"]) > 0:
            video_id = data["items"][0]["id"]["videoId"]
            video_title = data["items"][0]["snippet"]["title"]
            print(f"  ✅ Found: {video_title}")
            return video_id
        else:
            print(f"  ❌ No video found")
            return None

    except requests.exceptions.RequestException as e:
        print(f"  ❌ YouTube API error: {e}")
        return None
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return None


def process_songs_batch(songs: List[Tuple[int, str, str]], batch_num: int, total_batches: int) -> Dict:
    """Process a batch of songs and return results."""
    results = {
        "added": [],
        "not_found": [],
        "errors": []
    }

    print(f"\n{'='*60}")
    print(f"BATCH {batch_num}/{total_batches} - Processing {len(songs)} songs")
    print(f"{'='*60}")

    for rank, title, artist in songs:
        print(f"\n[{rank}] {title} - {artist}")

        # Search for video
        video_id = search_youtube_video(title, artist)

        if video_id:
            video_url = f"https://www.youtube.com/watch?v={video_id}"
            artist_name = clean_artist_name(artist)

            results["added"].append({
                "rank": rank,
                "title": title,
                "artist": artist,
                "artistName": artist_name,
                "url": video_url,
                "videoId": video_id
            })
        else:
            results["not_found"].append({
                "rank": rank,
                "title": title,
                "artist": artist
            })

        # Rate limiting - wait between requests
        time.sleep(0.5)

    return results


def main():
    """Main function to process all songs."""
    print("=" * 60)
    print("2023 SONGS - YouTube Video Search")
    print("=" * 60)
    print(f"Total songs to process: {len(SONGS_2023)}")
    print(f"YouTube API Key: {YOUTUBE_API_KEY[:20]}...")
    print()

    # Process songs in batches of 15 to manage API quota
    batch_size = 15
    all_results = {
        "added": [],
        "not_found": [],
        "errors": []
    }

    total_batches = (len(SONGS_2023) + batch_size - 1) // batch_size

    for i in range(0, len(SONGS_2023), batch_size):
        batch = SONGS_2023[i:i + batch_size]
        batch_num = (i // batch_size) + 1

        results = process_songs_batch(batch, batch_num, total_batches)

        all_results["added"].extend(results["added"])
        all_results["not_found"].extend(results["not_found"])
        all_results["errors"].extend(results["errors"])

        # Wait between batches
        if i + batch_size < len(SONGS_2023):
            print(f"\n⏸️  Waiting 3 seconds before next batch...")
            time.sleep(3)

    # Print summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"✅ Videos found: {len(all_results['added'])}")
    print(f"❌ Videos not found: {len(all_results['not_found'])}")
    print(f"⚠️  Errors: {len(all_results['errors'])}")

    if all_results["not_found"]:
        print("\nVideos not found:")
        for item in all_results["not_found"]:
            print(f"  [{item['rank']}] {item['title']} - {item['artist']}")

    if all_results["errors"]:
        print("\nErrors:")
        for item in all_results["errors"]:
            print(f"  [{item['rank']}] {item['title']} - {item['artist']}: {item.get('error', 'Unknown error')}")

    # Save results to JSON file for Airtable import
    output_file = "2023_songs_results.json"
    with open(output_file, "w") as f:
        json.dump(all_results, f, indent=2)
    print(f"\n💾 Results saved to: {output_file}")

    # Create Airtable records format
    airtable_records = []
    for item in all_results["added"]:
        record = {
            "fields": {
                "title": item["title"],
                "url": item["url"],
                "Rank": item["rank"],
                "artistName": item["artistName"],
                "Year": "2023",
                "artistID": ""
            }
        }
        airtable_records.append(record)

    output_airtable = "2023_songs_airtable_records.json"
    with open(output_airtable, "w") as f:
        json.dump({"records": airtable_records}, f, indent=2)
    print(f"💾 Airtable records saved to: {output_airtable}")

    print("\n✅ Processing complete!")


if __name__ == "__main__":
    main()
