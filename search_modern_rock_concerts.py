#!/usr/bin/env python3
"""
Search YouTube for full-length Modern Rock concert videos
"""

import json
import urllib.request
import urllib.parse
from typing import List, Dict

API_KEY = "AIzaSyBiNw2RoGEbxTMGNiApi3TBZ-EH8oQXy24"

ARTISTS = [
    "Arctic Monkeys",
    "Linkin Park",
    "Queens of the Stone Age",
    "System of a Down",
    "Weezer",
    "The Black Keys"
]

def search_concerts(artist: str, max_results: int = 10) -> List[Dict]:
    """Search YouTube for full concert videos by artist"""

    search_params = {
        "part": "snippet",
        "q": f"{artist} full concert live",
        "type": "video",
        "videoDuration": "long",  # 20+ minutes
        "maxResults": max_results,
        "key": API_KEY
    }

    try:
        search_url = f"https://www.googleapis.com/youtube/v3/search?{urllib.parse.urlencode(search_params)}"
        with urllib.request.urlopen(search_url) as response:
            data = json.loads(response.read())

        if "items" not in data:
            print(f"❌ No results for {artist}")
            return []

        video_ids = [item["id"]["videoId"] for item in data["items"]]

        # Get video details (duration, etc.)
        videos_params = {
            "part": "contentDetails,snippet",
            "id": ",".join(video_ids),
            "key": API_KEY
        }

        videos_url = f"https://www.googleapis.com/youtube/v3/videos?{urllib.parse.urlencode(videos_params)}"
        with urllib.request.urlopen(videos_url) as response:
            videos_data = json.loads(response.read())

        results = []
        for video in videos_data.get("items", []):
            video_id = video["id"]
            title = video["snippet"]["title"]
            duration_iso = video["contentDetails"]["duration"]
            published_at = video["snippet"]["publishedAt"][:4]  # Year

            # Convert ISO 8601 duration to readable format
            duration_str = parse_duration(duration_iso)
            duration_minutes = duration_to_minutes(duration_iso)

            # Only include videos 20+ minutes
            if duration_minutes >= 20:
                results.append({
                    "title": title,
                    "url": f"https://www.youtube.com/watch?v={video_id}",
                    "duration": duration_str,
                    "duration_minutes": duration_minutes,
                    "year": published_at,
                    "video_id": video_id
                })

        return results

    except Exception as e:
        print(f"❌ Error searching for {artist}: {e}")
        return []

def parse_duration(iso_duration: str) -> str:
    """Convert ISO 8601 duration (PT1H23M45S) to readable format (1:23:45)"""
    import re

    match = re.match(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', iso_duration)
    if not match:
        return "Unknown"

    hours = int(match.group(1) or 0)
    minutes = int(match.group(2) or 0)
    seconds = int(match.group(3) or 0)

    if hours > 0:
        return f"{hours}:{minutes:02d}:{seconds:02d}"
    else:
        return f"{minutes}:{seconds:02d}"

def duration_to_minutes(iso_duration: str) -> int:
    """Convert ISO 8601 duration to total minutes"""
    import re

    match = re.match(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', iso_duration)
    if not match:
        return 0

    hours = int(match.group(1) or 0)
    minutes = int(match.group(2) or 0)
    seconds = int(match.group(3) or 0)

    return hours * 60 + minutes + (1 if seconds > 0 else 0)

def main():
    all_results = {}

    for artist in ARTISTS:
        print(f"\n🔍 Searching for {artist} concerts...")
        concerts = search_concerts(artist, max_results=15)

        # Sort by duration (longest first) and take top 4
        concerts.sort(key=lambda x: x["duration_minutes"], reverse=True)
        top_concerts = concerts[:4]

        all_results[artist] = top_concerts
        print(f"✅ Found {len(top_concerts)} quality concerts for {artist}")

    # Save results
    output_file = "/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/modern_rock_concerts_results.json"
    with open(output_file, "w") as f:
        json.dump(all_results, f, indent=2)

    print(f"\n✅ Results saved to {output_file}")

    # Print summary
    print("\n" + "="*80)
    print("MODERN ROCK CONCERT VIDEOS FOUND")
    print("="*80)

    for artist, concerts in all_results.items():
        print(f"\n## {artist}")
        print("-" * 80)
        for i, concert in enumerate(concerts, 1):
            print(f"{i}. {concert['title']}")
            print(f"   URL: {concert['url']}")
            print(f"   Duration: {concert['duration']} | Year: {concert['year']}")
            print()

if __name__ == "__main__":
    main()
