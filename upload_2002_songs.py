#!/usr/bin/env python3
import json
import urllib.request
import urllib.error
import time

API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
BASE_ID = "appxCBIOkiJEZiph7"
TABLE_ID = "tblNwqwVyflL8hNDy"
ENDPOINT = f"https://api.airtable.com/v0/{BASE_ID}/{TABLE_ID}"

def extract_artist_name(artist):
    """Extract main artist name before featuring"""
    patterns = [' featuring ', ' feat. ', ' feat ', ' ft. ', ' ft ', ' with ']
    artist_lower = artist.lower()
    for pattern in patterns:
        if pattern in artist_lower:
            idx = artist_lower.index(pattern)
            return artist[:idx].strip()
    return artist.strip()

def upload_batch(batch, batch_num, total_batches):
    """Upload a batch of records to Airtable"""
    records = []
    for video in batch:
        artist_name = extract_artist_name(video['artist'])
        url = f"https://www.youtube.com/watch?v={video['videoId']}"

        records.append({
            "fields": {
                "title": video['title'],
                "url": url,
                "Rank": video['rank'],
                "artistName": artist_name,
                "Year": "2002"
            }
        })

    payload = {"records": records}
    data = json.dumps(payload).encode('utf-8')

    print(f"\n{'='*60}")
    print(f"Batch {batch_num}/{total_batches}: Uploading songs {batch[0]['rank']}-{batch[-1]['rank']}")
    print(f"{'='*60}")

    for video in batch:
        print(f"  [{video['rank']}] {video['title']} - {extract_artist_name(video['artist'])}")

    try:
        req = urllib.request.Request(ENDPOINT, data=data)
        req.add_header("Authorization", f"Bearer {API_KEY}")
        req.add_header("Content-Type", "application/json")

        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            print(f"\n✅ Successfully added {len(result.get('records', []))} records")
            return True

    except urllib.error.HTTPError as e:
        print(f"\n❌ HTTP Error: {e.code}")
        print(e.read().decode('utf-8'))
        return False
    except Exception as e:
        print(f"\n❌ Exception: {str(e)}")
        return False

def main():
    # Load video data
    with open('2002_videos_data.json', 'r') as f:
        videos = json.load(f)

    # Split into batches of 10
    batches = [videos[i:i+10] for i in range(0, len(videos), 10)]

    print(f"\n🎵 Starting upload of {len(videos)} songs from 2002")
    print(f"📦 Processing {len(batches)} batches of up to 10 songs each\n")

    successful_batches = 0
    failed_batches = 0

    for batch_num, batch in enumerate(batches, 1):
        if upload_batch(batch, batch_num, len(batches)):
            successful_batches += 1
        else:
            failed_batches += 1
            print(f"\n⚠️  Stopping due to error in batch {batch_num}")
            break

        # Rate limiting: wait between batches
        if batch_num < len(batches):
            print(f"\n⏸️  Waiting 2 seconds before next batch...")
            time.sleep(2)

    # Summary
    print(f"\n{'='*60}")
    print(f"📊 UPLOAD SUMMARY")
    print(f"{'='*60}")
    print(f"✅ Successful batches: {successful_batches}")
    print(f"❌ Failed batches: {failed_batches}")
    print(f"📝 Total songs added: {successful_batches * 10 if successful_batches == len(batches) else (successful_batches - 1) * 10 + len(batches[successful_batches - 1])}")
    print(f"{'='*60}\n")

if __name__ == "__main__":
    main()
