#!/usr/bin/env python3
"""
Search YouTube for full-length indie artist concerts
"""

import requests
import json
from datetime import datetime
import re

API_KEY = "AIzaSyBiNw2RoGEbxTMGNiApi3TBZ-EH8oQXy24"

ARTISTS = [
    "LCD Soundsystem",
    "Phoebe Bridgers",
    "The National",
    "Khruangbin",
    "Mac DeMarco",
    "Death Cab for Cutie"
]

def parse_duration(duration):
    """Convert ISO 8601 duration to minutes"""
    match = re.match(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', duration)
    if not match:
        return 0
    hours = int(match.group(1) or 0)
    minutes = int(match.group(2) or 0)
    seconds = int(match.group(3) or 0)
    return hours * 60 + minutes + seconds / 60

def format_duration(minutes):
    """Format minutes to HH:MM:SS or MM:SS"""
    total_seconds = int(minutes * 60)
    hours = total_seconds // 3600
    mins = (total_seconds % 3600) // 60
    secs = total_seconds % 60

    if hours > 0:
        return f"{hours}:{mins:02d}:{secs:02d}"
    return f"{mins}:{secs:02d}"

def clean_title(title, artist):
    """Clean up video titles to venue/festival format"""
    # Remove common prefixes
    title = re.sub(r'^' + re.escape(artist) + r'\s*[-–—:]*\s*', '', title, flags=re.IGNORECASE)

    # Remove quality markers
    title = re.sub(r'\b(4K|HD|1080p|720p|Remastered|HQ)\b', '', title, flags=re.IGNORECASE)

    # Remove "Full Concert", "Full Set", etc.
    title = re.sub(r'\b(Full\s+(Concert|Set|Show|Performance))\b', '', title, flags=re.IGNORECASE)

    # Remove dates (various formats)
    title = re.sub(r'\b\d{4}\b', '', title)  # Year
    title = re.sub(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b', '', title)  # Date formats

    # Remove "Live at/from/in"
    title = re.sub(r'\b(Live\s+(at|from|in))\s*', '', title, flags=re.IGNORECASE)

    # Clean up extra spaces and punctuation
    title = re.sub(r'\s+', ' ', title)
    title = re.sub(r'^\s*[-–—:,]\s*', '', title)
    title = re.sub(r'\s*[-–—:,]\s*$', '', title)

    return title.strip()

def search_artist(artist, max_results=15):
    """Search YouTube for artist's full concerts"""
    print(f"\n{'='*60}")
    print(f"Searching for {artist}...")
    print(f"{'='*60}")

    # Try multiple search queries
    queries = [
        f"{artist} live concert full",
        f"{artist} festival full set",
        f"{artist} live full show"
    ]

    all_videos = []
    seen_ids = set()

    for query in queries:
        url = "https://www.googleapis.com/youtube/v3/search"
        params = {
            "part": "snippet",
            "q": query,
            "type": "video",
            "videoDuration": "long",
            "maxResults": max_results,
            "key": API_KEY
        }

        response = requests.get(url, params=params)
        if response.status_code != 200:
            print(f"❌ Error searching for '{query}': {response.status_code}")
            continue

        data = response.json()

        # Collect video IDs
        video_ids = []
        for item in data.get('items', []):
            video_id = item['id'].get('videoId')
            if video_id and video_id not in seen_ids:
                video_ids.append(video_id)
                seen_ids.add(video_id)

        if not video_ids:
            print(f"No videos found for '{query}'")
            continue

        # Get video details (duration, etc.)
        details_url = "https://www.googleapis.com/youtube/v3/videos"
        details_params = {
            "part": "contentDetails,snippet",
            "id": ",".join(video_ids),
            "key": API_KEY
        }

        details_response = requests.get(details_url, params=details_params)
        if details_response.status_code != 200:
            print(f"❌ Error getting video details: {details_response.status_code}")
            continue

        details_data = details_response.json()

        for video in details_data.get('items', []):
            video_id = video['id']
            snippet = video['snippet']
            duration_iso = video['contentDetails']['duration']
            duration_minutes = parse_duration(duration_iso)

            # Filter: must be at least 20 minutes
            if duration_minutes < 20:
                continue

            # Extract year from description or title
            year = None
            text = snippet['title'] + " " + snippet.get('description', '')
            year_match = re.search(r'\b(19\d{2}|20[0-2]\d)\b', text)
            if year_match:
                year = year_match.group(1)

            video_info = {
                'video_id': video_id,
                'title': snippet['title'],
                'url': f"https://www.youtube.com/watch?v={video_id}",
                'duration_minutes': duration_minutes,
                'duration_formatted': format_duration(duration_minutes),
                'year': year,
                'published': snippet['publishedAt'][:4]
            }

            all_videos.append(video_info)

    # Remove duplicates and sort by duration (longest first)
    all_videos = list({v['video_id']: v for v in all_videos}.values())
    all_videos.sort(key=lambda x: x['duration_minutes'], reverse=True)

    # Take top 10
    return all_videos[:10]

def main():
    results = {}

    for artist in ARTISTS:
        videos = search_artist(artist)
        results[artist] = videos

        if videos:
            print(f"\n✅ Found {len(videos)} videos for {artist}")
        else:
            print(f"\n⚠️  No suitable videos found for {artist}")

    # Save results
    output_file = "indie_concerts_results.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"\n{'='*60}")
    print(f"Results saved to {output_file}")
    print(f"{'='*60}\n")

    # Print formatted results
    print("\n" + "="*80)
    print("INDIE ARTIST CONCERT VIDEOS - SEARCH RESULTS")
    print("="*80 + "\n")

    for artist in ARTISTS:
        videos = results.get(artist, [])
        print(f"\n### {artist} ({len(videos)} videos)")
        print(f"| # | Title | URL | Duration | Year |")
        print(f"|---|-------|-----|----------|------|")

        for i, video in enumerate(videos, 1):
            # Clean the title
            clean = clean_title(video['title'], artist)
            if not clean or len(clean) < 5:
                clean = video['title']

            year = video['year'] or video['published']
            print(f"| {i} | {clean} | {video['url']} | {video['duration_formatted']} | {year} |")

        if not videos:
            print(f"| - | No videos found | - | - | - |")

    print("\n" + "="*80)
    print(f"Total videos found: {sum(len(v) for v in results.values())}")
    print("="*80 + "\n")

if __name__ == "__main__":
    main()
