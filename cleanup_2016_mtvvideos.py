#!/usr/bin/env python3
"""
Clean up MTvVideos table for 2016 to match Billboard Year-End Hot 100.
"""

import csv
import json
import urllib.request
import urllib.parse
import ssl
import time
import re
import sys

sys.stdout.reconfigure(line_buffering=True)

YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
MTVVIDEOS_TABLE_ID = "tbl3waFYL7jfER18L"

ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE


def normalize(s):
    """Normalize string for comparison"""
    s = s.lower().strip()
    s = re.sub(r'[^\w\s]', '', s)
    s = re.sub(r'\s+', ' ', s)
    return s


def get_all_records():
    all_records = []
    offset = None
    while True:
        url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{MTVVIDEOS_TABLE_ID}?filterByFormula=year=2016&pageSize=100"
        if offset:
            url += f"&offset={offset}"
        req = urllib.request.Request(url)
        req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')
        with urllib.request.urlopen(req, timeout=30, context=ssl_context) as response:
            data = json.loads(response.read().decode('utf-8'))
            all_records.extend(data.get('records', []))
            offset = data.get('offset')
            if not offset:
                break
    return all_records


def delete_records(record_ids):
    """Delete records in batches of 10."""
    deleted = 0
    for i in range(0, len(record_ids), 10):
        batch = record_ids[i:i+10]
        params = '&'.join([f'records[]={rid}' for rid in batch])
        url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{MTVVIDEOS_TABLE_ID}?{params}"
        req = urllib.request.Request(url, method='DELETE')
        req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')
        try:
            with urllib.request.urlopen(req, timeout=30, context=ssl_context) as response:
                json.loads(response.read().decode('utf-8'))
                deleted += len(batch)
                print(f"  Deleted {deleted}/{len(record_ids)} records")
        except Exception as e:
            print(f"  Error deleting: {e}")
        time.sleep(0.25)
    return deleted


def search_youtube(title, artist):
    """Search YouTube for a music video."""
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
        print(f"  YouTube error: {e}")
    return None


def create_artist_id(artist_name):
    """Create a simple artist ID."""
    main_artist = artist_name.split(' featuring ')[0].split(' feat.')[0].split(' and ')[0].split(' & ')[0]
    artist_id = ''.join(c for c in main_artist if c.isalnum() or c == ' ').strip().lower().replace(' ', '-')
    return artist_id


def add_records(records):
    """Add records in batches of 10."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{MTVVIDEOS_TABLE_ID}"
    added = 0

    for i in range(0, len(records), 10):
        batch = records[i:i+10]
        payload = {"records": [{"fields": r} for r in batch]}
        data = json.dumps(payload).encode('utf-8')

        req = urllib.request.Request(url, data=data, method='POST')
        req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')
        req.add_header('Content-Type', 'application/json')

        try:
            with urllib.request.urlopen(req, timeout=30, context=ssl_context) as response:
                json.loads(response.read().decode('utf-8'))
                added += len(batch)
                print(f"  Added {added}/{len(records)} records")
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8')
            print(f"  Airtable error: {e.code} - {error_body}")
        except Exception as e:
            print(f"  Error adding: {e}")
        time.sleep(0.25)
    return added


def update_records(updates):
    """Update records in batches of 10."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{MTVVIDEOS_TABLE_ID}"
    updated = 0

    for i in range(0, len(updates), 10):
        batch = updates[i:i+10]
        payload = {"records": batch}
        data = json.dumps(payload).encode('utf-8')

        req = urllib.request.Request(url, data=data, method='PATCH')
        req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')
        req.add_header('Content-Type', 'application/json')

        try:
            with urllib.request.urlopen(req, timeout=30, context=ssl_context) as response:
                json.loads(response.read().decode('utf-8'))
                updated += len(batch)
                print(f"  Updated {updated}/{len(updates)} records")
        except Exception as e:
            print(f"  Error updating: {e}")
        time.sleep(0.25)
    return updated


def main():
    # Load Billboard data
    print("Loading Billboard data...")
    billboard_2016 = {}
    with open('Full_Billboard_year_end_hot_100_USA.csv', 'r', encoding='latin-1') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['Year'] == '2016':
                rank_str = row['No.'].replace('(Tie)', '').strip()
                try:
                    rank = int(rank_str)
                except:
                    continue
                if rank <= 100:
                    title_norm = normalize(row['Title'])
                    billboard_2016[title_norm] = {
                        'rank': rank,
                        'title': row['Title'],
                        'artist': row['Artist(s)']
                    }

    print(f"Billboard 2016: {len(billboard_2016)} songs")

    # Get existing records
    print("\nFetching existing MTvVideos records...")
    existing = get_all_records()
    print(f"Found {len(existing)} records for 2016")

    # Match records
    matched = []
    to_delete = []
    matched_billboard_titles = set()

    for r in existing:
        title = r.get('fields', {}).get('title', '')
        title_norm = normalize(title)

        found = False
        for bb_title_norm, bb_data in billboard_2016.items():
            if title_norm in bb_title_norm or bb_title_norm in title_norm or \
               (len(title_norm) > 5 and title_norm[:10] == bb_title_norm[:10]):
                matched.append({
                    'id': r.get('id'),
                    'fields': {'Rank': bb_data['rank']}
                })
                matched_billboard_titles.add(bb_title_norm)
                found = True
                break

        if not found:
            to_delete.append(r.get('id'))

    # Find missing songs
    missing = []
    for title_norm, data in billboard_2016.items():
        if title_norm not in matched_billboard_titles:
            missing.append(data)

    print(f"\nMatched: {len(matched)}")
    print(f"To delete: {len(to_delete)}")
    print(f"To add: {len(missing)}")

    # Step 1: Delete non-Billboard records
    if to_delete:
        print(f"\n{'='*50}")
        print("STEP 1: Deleting non-Billboard records...")
        print(f"{'='*50}")
        delete_records(to_delete)

    # Step 2: Update ranks for matched records
    if matched:
        print(f"\n{'='*50}")
        print("STEP 2: Updating ranks for matched records...")
        print(f"{'='*50}")
        update_records(matched)

    # Step 3: Add missing Billboard songs
    if missing:
        print(f"\n{'='*50}")
        print("STEP 3: Adding missing Billboard songs...")
        print(f"{'='*50}")

        records_to_add = []
        for i, song in enumerate(sorted(missing, key=lambda x: x['rank'])):
            print(f"\n[{i+1}/{len(missing)}] Rank {song['rank']}: {song['title']} - {song['artist']}")

            video_url = search_youtube(song['title'], song['artist'])
            if video_url:
                print(f"  Found: {video_url}")
                records_to_add.append({
                    'title': song['title'],
                    'url': video_url,
                    'Rank': song['rank'],
                    'artistName': song['artist'],
                    'year': 2016,
                    'artistID': create_artist_id(song['artist'])
                })
            else:
                print("  Not found on YouTube")

            time.sleep(1.1)  # Rate limiting

        if records_to_add:
            print(f"\nAdding {len(records_to_add)} new records...")
            add_records(records_to_add)

    # Final count
    print(f"\n{'='*50}")
    print("COMPLETE!")
    print(f"{'='*50}")
    final = get_all_records()
    print(f"Final 2016 record count: {len(final)}")


if __name__ == "__main__":
    main()
