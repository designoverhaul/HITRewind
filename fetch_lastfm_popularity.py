#!/usr/bin/env python3
"""
Fetch Last.fm play counts for music videos and update Airtable SpotifyRank field.
"""

import requests
import time
import json

# Configuration
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"  # MTvVideosNEW

LASTFM_API_KEY = "96b182b4bd9bf6338d52fcfec34022c4"

# Target year
TARGET_YEAR = 1998


def fetch_airtable_records(year):
    """Fetch all records from Airtable for a specific year."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"
    headers = {
        "Authorization": f"Bearer {AIRTABLE_API_KEY}",
        "Content-Type": "application/json"
    }

    # Filter by year
    params = {
        "filterByFormula": f"{{year}}={year}",
        "pageSize": 100
    }

    all_records = []
    offset = None

    while True:
        if offset:
            params["offset"] = offset

        response = requests.get(url, headers=headers, params=params)
        data = response.json()

        if "records" in data:
            all_records.extend(data["records"])
            print(f"Fetched {len(all_records)} records so far...")

        if "offset" in data:
            offset = data["offset"]
        else:
            break

    return all_records


def get_lastfm_playcount(title, artist):
    """Get play count for a track from Last.fm."""
    url = "http://ws.audioscrobbler.com/2.0/"
    params = {
        "method": "track.getInfo",
        "api_key": LASTFM_API_KEY,
        "artist": artist,
        "track": title,
        "format": "json"
    }

    try:
        response = requests.get(url, params=params)
        data = response.json()

        if "track" in data and "playcount" in data["track"]:
            return int(data["track"]["playcount"])
        else:
            # Try searching if exact match fails
            return search_lastfm_track(title, artist)
    except Exception as e:
        print(f"  Error fetching Last.fm data: {e}")
        return None


def search_lastfm_track(title, artist):
    """Search for a track on Last.fm if exact match fails."""
    url = "http://ws.audioscrobbler.com/2.0/"
    params = {
        "method": "track.search",
        "api_key": LASTFM_API_KEY,
        "track": title,
        "artist": artist,
        "limit": 1,
        "format": "json"
    }

    try:
        response = requests.get(url, params=params)
        data = response.json()

        if "results" in data and "trackmatches" in data["results"]:
            tracks = data["results"]["trackmatches"].get("track", [])
            if tracks and len(tracks) > 0:
                # Get the first match and fetch its info
                match = tracks[0] if isinstance(tracks, list) else tracks
                return get_lastfm_playcount_direct(match.get("name"), match.get("artist"))
    except Exception as e:
        print(f"  Search error: {e}")

    return None


def get_lastfm_playcount_direct(title, artist):
    """Direct playcount fetch without recursion."""
    url = "http://ws.audioscrobbler.com/2.0/"
    params = {
        "method": "track.getInfo",
        "api_key": LASTFM_API_KEY,
        "artist": artist,
        "track": title,
        "format": "json"
    }

    try:
        response = requests.get(url, params=params)
        data = response.json()

        if "track" in data and "playcount" in data["track"]:
            return int(data["track"]["playcount"])
    except:
        pass

    return None


def update_airtable_record(record_id, playcount):
    """Update the SpotifyRank field in Airtable."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}/{record_id}"
    headers = {
        "Authorization": f"Bearer {AIRTABLE_API_KEY}",
        "Content-Type": "application/json"
    }

    data = {
        "fields": {
            "SpotifyRank": playcount
        }
    }

    response = requests.patch(url, headers=headers, json=data)
    return response.status_code == 200


def main():
    print(f"Fetching {TARGET_YEAR} videos from Airtable...")
    records = fetch_airtable_records(TARGET_YEAR)
    print(f"Found {len(records)} videos for {TARGET_YEAR}\n")

    if not records:
        print("No records found!")
        return

    results = []

    for i, record in enumerate(records):
        fields = record.get("fields", {})
        title = fields.get("title", "")
        artist = fields.get("artistName", "")
        record_id = record.get("id")

        print(f"[{i+1}/{len(records)}] {title} - {artist}")

        # Get Last.fm playcount
        playcount = get_lastfm_playcount(title, artist)

        if playcount:
            print(f"  Play count: {playcount:,}")

            # Update Airtable
            if update_airtable_record(record_id, playcount):
                print(f"  Updated Airtable ✓")
            else:
                print(f"  Failed to update Airtable ✗")

            results.append({
                "title": title,
                "artist": artist,
                "playcount": playcount
            })
        else:
            print(f"  Not found on Last.fm")
            results.append({
                "title": title,
                "artist": artist,
                "playcount": 0
            })

        # Rate limiting
        time.sleep(0.5)

    # Sort by playcount and display results
    print("\n" + "="*60)
    print(f"RESULTS FOR {TARGET_YEAR} - SORTED BY LAST.FM PLAYS")
    print("="*60 + "\n")

    results.sort(key=lambda x: x["playcount"], reverse=True)

    for i, r in enumerate(results, 1):
        plays = f"{r['playcount']:,}" if r['playcount'] else "N/A"
        print(f"{i:3}. {r['title'][:40]:<40} - {r['artist'][:20]:<20} ({plays} plays)")

    # Save results to JSON
    with open(f"lastfm_results_{TARGET_YEAR}.json", "w") as f:
        json.dump(results, f, indent=2)

    print(f"\nResults saved to lastfm_results_{TARGET_YEAR}.json")


if __name__ == "__main__":
    main()
