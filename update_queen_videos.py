#!/usr/bin/env python3
"""Find and update blocked Queen concert videos in Airtable."""

import urllib.request
import urllib.parse
import urllib.error
import json
import ssl
import time
import sys

YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"

# Videos table (main table with LegendaryShow multi-select field)
VIDEOS_TABLE_URL = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/Videos"

ssl_context = ssl.create_default_context()


def make_request(url: str, headers: dict = None, data: bytes = None, method: str = None) -> dict:
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(req, context=ssl_context, timeout=30) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        return {'error': {'code': e.code, 'message': error_body}}
    except Exception as e:
        return {'error': {'code': 0, 'message': str(e)}}


def check_youtube_video_status(video_id: str) -> dict:
    """Check if a YouTube video is available and get its details."""
    params = urllib.parse.urlencode({
        'part': 'status,snippet',
        'id': video_id,
        'key': YOUTUBE_API_KEY,
    })
    url = f'https://www.googleapis.com/youtube/v3/videos?{params}'
    data = make_request(url)

    if 'error' in data:
        return {'available': False, 'error': data['error']}

    items = data.get('items', [])
    if not items:
        return {'available': False, 'reason': 'Video not found or deleted'}

    item = items[0]
    status = item.get('status', {})
    snippet = item.get('snippet', {})

    return {
        'available': status.get('uploadStatus') == 'processed' and status.get('privacyStatus') == 'public',
        'title': snippet.get('title', ''),
        'channel': snippet.get('channelTitle', ''),
        'embeddable': status.get('embeddable', False),
        'privacyStatus': status.get('privacyStatus', ''),
        'uploadStatus': status.get('uploadStatus', ''),
    }


def search_youtube_for_replacement(query: str, exclude_channels: list = None) -> list:
    """Search YouTube for replacement videos."""
    exclude_channels = exclude_channels or ['Queen Official']

    params = urllib.parse.urlencode({
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': 10,
        'key': YOUTUBE_API_KEY,
    })
    url = f'https://www.googleapis.com/youtube/v3/search?{params}'
    data = make_request(url)

    if 'error' in data:
        return []

    results = []
    for item in data.get('items', []):
        snippet = item.get('snippet', {})
        video_id = item.get('id', {}).get('videoId', '')
        channel = snippet.get('channelTitle', '')

        # Skip official Queen channel (likely blocked)
        if any(exc.lower() in channel.lower() for exc in exclude_channels):
            continue

        results.append({
            'videoId': video_id,
            'title': snippet.get('title', ''),
            'channel': channel,
            'url': f'https://www.youtube.com/watch?v={video_id}'
        })

    return results


def fetch_videos_with_legendary_show() -> list:
    """Fetch all videos that have LegendaryShow field set."""
    headers = {'Authorization': f'Bearer {AIRTABLE_API_KEY}'}
    all_records = []
    offset = None

    # Request specific fields only
    fields = ['Title', 'artistName', 'Year', 'URL', 'videoImage', 'LegendaryShow']

    while True:
        params = ['pageSize=100']
        for f in fields:
            params.append(f'fields[]={urllib.parse.quote(f)}')
        if offset:
            params.append(f'offset={offset}')

        url = f"{VIDEOS_TABLE_URL}?{'&'.join(params)}"
        data = make_request(url, headers=headers)

        if 'error' in data:
            print(f"  Error fetching videos: {data['error']}")
            return all_records

        records = data.get('records', [])
        all_records.extend(records)
        print(f"  Fetched {len(records)} records (total: {len(all_records)})")

        offset = data.get('offset')
        if not offset:
            break
        time.sleep(0.2)

    return all_records


def update_airtable_record(record_id: str, fields: dict) -> dict:
    """Update a single Airtable record in Videos table."""
    url = f"{VIDEOS_TABLE_URL}/{record_id}"
    headers = {
        'Authorization': f'Bearer {AIRTABLE_API_KEY}',
        'Content-Type': 'application/json'
    }
    payload = json.dumps({'fields': fields}).encode('utf-8')
    return make_request(url, headers=headers, data=payload, method='PATCH')


# Known good replacement videos (pre-researched)
KNOWN_REPLACEMENTS = {
    'Live Aid': {
        'video_id': 'frdBb9Slu1A',
        'title': 'Queen - Live Aid 1985 Full Concert',
        'channel': 'uploader.JP8'
    },
    'Hammersmith': {
        'video_id': 'm2FUPfUMpAM',
        'title': 'Queen - Live in London - December 1979',
        'channel': 'My Melancholy Boots'
    },
    'Rainbow': {
        'video_id': 'vjVe6txk-6I',
        'title': 'Queen: Live at the Rainbow \'74',
        'channel': 'Front Row Music'
    },
    'Hyde Park': {
        'video_id': '4p7d-UitRMQ',
        'title': 'Queen - Live at Hyde Park 1976',
        'channel': 'uploader.JP8'
    },
    'Houston': {
        'video_id': 'HVOgUEtE150',
        'title': 'Queen - Live In Houston 1977 - Full Concert',
        'channel': 'Queen Enhanced Music Videos'
    },
    'Wembley': {
        'video_id': 'poiwqYcFqYY',
        'title': 'Queen: Live at Wembley Stadium',
        'channel': 'Front Row Music'
    },
    'Montreal': {
        'video_id': 'N0dbGGvsjf8',
        'title': 'Queen - Bohemian Rhapsody (Live at Rock Montreal)',
        'channel': 'Vander'
    },
}


if __name__ == "__main__":
    apply_updates = '--apply' in sys.argv

    print("=" * 60)
    print("QUEEN VIDEO STATUS CHECK AND REPLACEMENT FINDER")
    print("=" * 60)

    # Step 1: Fetch all videos with LegendaryShow field
    print("\n1. Fetching all videos with LegendaryShow field...")
    all_videos = fetch_videos_with_legendary_show()
    print(f"   Total videos fetched: {len(all_videos)}")

    # Step 2: Filter for Queen entries
    queen_videos = []
    for rec in all_videos:
        fields = rec.get('fields', {})
        legendary_show = fields.get('LegendaryShow', [])
        # LegendaryShow is a multi-select, check if "Queen" is in the list
        if legendary_show and any('Queen' in tag for tag in legendary_show):
            queen_videos.append({
                'record_id': rec.get('id'),
                'title': fields.get('Title', ''),
                'url': fields.get('URL', ''),
                'artistName': fields.get('artistName', ['Queen']),
                'year': fields.get('Year', ''),
                'legendaryShow': legendary_show,
            })

    print(f"\n2. Found {len(queen_videos)} Queen videos in LegendaryShow")
    print("-" * 60)

    if not queen_videos:
        print("\nNo Queen videos found! Checking what LegendaryShow values exist...")
        legendary_values = set()
        for rec in all_videos:
            fields = rec.get('fields', {})
            for tag in fields.get('LegendaryShow', []):
                legendary_values.add(tag)
        print(f"Available LegendaryShow values: {sorted(legendary_values)}")

    # Step 3: Check YouTube status for each Queen video
    print("\n3. Checking YouTube video status...")
    blocked_videos = []
    ok_videos = []

    for video in queen_videos:
        url = video.get('url', '')
        if not url:
            print(f"  [NO URL] {video['title'][:40]}")
            continue

        # Extract video ID
        if 'youtube.com/watch?v=' in url:
            video_id = url.split('v=')[1].split('&')[0]
        elif 'youtu.be/' in url:
            video_id = url.split('youtu.be/')[1].split('?')[0]
        else:
            video_id = url

        video['video_id'] = video_id
        status = check_youtube_video_status(video_id)
        video['status'] = status

        available = status.get('available', False)
        embeddable = status.get('embeddable', False)

        if not available:
            status_str = "UNAVAILABLE"
            blocked_videos.append(video)
        elif not embeddable:
            status_str = "NOT EMBEDDABLE"
            blocked_videos.append(video)
        else:
            status_str = "OK"
            ok_videos.append(video)

        print(f"  [{status_str:15}] {video['title'][:35]:<35} - {video_id}")
        time.sleep(0.3)

    print(f"\n4. STATUS SUMMARY:")
    print(f"   OK: {len(ok_videos)}")
    print(f"   Blocked/Unavailable: {len(blocked_videos)}")

    # Step 4: Find replacements for blocked videos
    updates_to_apply = []

    if blocked_videos:
        print("\n5. FINDING REPLACEMENTS FOR BLOCKED VIDEOS...")
        print("-" * 60)

        for video in blocked_videos:
            title = video['title']
            print(f"\n  Blocked: {title}")
            print(f"  Current URL: {video['url']}")

            # Check known replacements
            replacement = None
            for keyword, repl in KNOWN_REPLACEMENTS.items():
                if keyword.lower() in title.lower():
                    # Verify replacement is available
                    status = check_youtube_video_status(repl['video_id'])
                    if status.get('available') and status.get('embeddable'):
                        replacement = repl
                        break
                    time.sleep(0.3)

            if replacement:
                new_url = f"https://www.youtube.com/watch?v={replacement['video_id']}"
                print(f"  Replacement: {replacement['title']}")
                print(f"  New URL: {new_url}")
                updates_to_apply.append({
                    'record_id': video['record_id'],
                    'title': title,
                    'old_url': video['url'],
                    'new_url': new_url,
                })
            else:
                # Search YouTube for alternative
                search_query = f"Queen {title} full concert"
                results = search_youtube_for_replacement(search_query)
                if results:
                    for r in results[:3]:
                        status = check_youtube_video_status(r['videoId'])
                        if status.get('available') and status.get('embeddable'):
                            print(f"  Found: {r['title'][:50]}")
                            print(f"  Channel: {r['channel']}")
                            updates_to_apply.append({
                                'record_id': video['record_id'],
                                'title': title,
                                'old_url': video['url'],
                                'new_url': r['url'],
                            })
                            break
                        time.sleep(0.3)
                else:
                    print(f"  No replacement found!")
                time.sleep(1)

    # Step 5: Apply updates if requested
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Queen videos in database: {len(queen_videos)}")
    print(f"Currently working: {len(ok_videos)}")
    print(f"Need replacement: {len(blocked_videos)}")
    print(f"Replacements found: {len(updates_to_apply)}")

    if updates_to_apply:
        print("\nUPDATES TO APPLY:")
        for u in updates_to_apply:
            print(f"\n  {u['title']}")
            print(f"    Old: {u['old_url']}")
            print(f"    New: {u['new_url']}")

        if apply_updates:
            print("\n\nAPPLYING UPDATES TO AIRTABLE...")
            for u in updates_to_apply:
                print(f"  Updating: {u['title']}")
                result = update_airtable_record(u['record_id'], {'URL': u['new_url']})
                if 'error' in result:
                    print(f"    ERROR: {result['error']}")
                else:
                    print(f"    SUCCESS!")
                time.sleep(0.5)
        else:
            print("\nTo apply these updates, run with --apply flag:")
            print("  python3 update_queen_videos.py --apply")

    # Save results
    results = {
        'queen_videos': [{
            'title': v['title'],
            'url': v['url'],
            'record_id': v['record_id'],
            'video_id': v.get('video_id', ''),
            'api_available': v.get('status', {}).get('available', False),
            'embeddable': v.get('status', {}).get('embeddable', False),
        } for v in queen_videos],
        'blocked': [v['title'] for v in blocked_videos],
        'updates': updates_to_apply,
    }

    with open('queen_video_analysis.json', 'w') as f:
        json.dump(results, f, indent=2)
    print("\nResults saved to queen_video_analysis.json")
