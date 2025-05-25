#!/usr/bin/env python3
"""
Check all YouTube links in the Videos table only
"""

import requests
import re
import time
import json

# Airtable configuration
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
BASE_ID = "appxCBIOkiJEZiph7"
VIDEOS_TABLE_ID = "tblTtRP4kdTDvfrBY"
HEADERS = {
    "Authorization": f"Bearer {AIRTABLE_API_KEY}",
    "Content-Type": "application/json"
}

def extract_video_id(url):
    """Extract YouTube video ID from URL"""
    patterns = [
        r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})',
        r'youtube\.com/v/([a-zA-Z0-9_-]{11})',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return ""

def check_youtube_video(url):
    """Check if YouTube video is accessible"""
    try:
        video_id = extract_video_id(url)
        if not video_id:
            return False, "Invalid YouTube URL format"

        # Check thumbnail availability (fast and reliable method)
        thumbnail_url = f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg"
        response = requests.head(thumbnail_url, timeout=5)
        
        if response.status_code == 200:
            return True, "OK"
        else:
            return False, f"HTTP {response.status_code}"

    except requests.exceptions.Timeout:
        return False, "Request timed out"
    except requests.exceptions.RequestException as e:
        return False, f"Network error: {str(e)}"
    except Exception as e:
        return False, f"Error: {str(e)}"

def get_all_videos():
    """Fetch all records from Videos table"""
    all_records = []
    url = f"https://api.airtable.com/v0/{BASE_ID}/{VIDEOS_TABLE_ID}"
    
    while url:
        try:
            response = requests.get(url, headers=HEADERS)
            response.raise_for_status()
            data = response.json()
            
            all_records.extend(data.get('records', []))
            
            # Handle pagination
            if 'offset' in data:
                url = f"https://api.airtable.com/v0/{BASE_ID}/{VIDEOS_TABLE_ID}?offset={data['offset']}"
            else:
                url = None
                
            time.sleep(0.2)  # Rate limiting
            
        except requests.exceptions.RequestException as e:
            print(f"Error fetching records: {e}")
            break
            
    return all_records

def main():
    print("🎬 Checking Videos Table for Broken YouTube Links")
    print("=" * 60)
    
    # Get all records
    print("📥 Fetching all records from Videos table...")
    records = get_all_videos()
    print(f"✅ Found {len(records)} total records")
    
    broken_videos = []
    checked_count = 0
    
    print(f"\n🔍 Checking YouTube links...")
    
    for i, record in enumerate(records, 1):
        fields = record.get('fields', {})
        url = fields.get('URL')
        
        if not url:
            continue
            
        title = fields.get('Title', 'Unknown Title')
        artist = fields.get('artistName', ['Unknown Artist'])
        if isinstance(artist, list):
            artist = ', '.join(artist) if artist else 'Unknown Artist'
        
        print(f"  [{i}/{len(records)}] {artist} - {title}")
        
        is_valid, error_msg = check_youtube_video(url)
        checked_count += 1
        
        if not is_valid:
            broken_video = {
                'record_id': record['id'],
                'title': title,
                'artist': artist,
                'url': url,
                'error': error_msg
            }
            broken_videos.append(broken_video)
            print(f"    ❌ BROKEN: {error_msg}")
        else:
            print(f"    ✅ OK")
            
        # Rate limiting
        time.sleep(0.3)
    
    # Results
    print(f"\n📊 RESULTS")
    print("=" * 40)
    print(f"Total videos checked: {checked_count}")
    print(f"Broken links found: {len(broken_videos)}")
    print(f"Success rate: {((checked_count - len(broken_videos)) / checked_count * 100):.1f}%")
    
    if broken_videos:
        print(f"\n❌ BROKEN VIDEOS:")
        print("-" * 30)
        for video in broken_videos:
            print(f"• {video['artist']} - {video['title']}")
            print(f"  URL: {video['url']}")
            print(f"  Error: {video['error']}")
            print(f"  Record ID: {video['record_id']}")
            print()
        
        # Save report
        report = {
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'table': 'Videos',
            'total_checked': checked_count,
            'broken_count': len(broken_videos),
            'broken_videos': broken_videos
        }
        
        filename = f"videos_table_broken_links_{time.strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"📄 Report saved to: {filename}")
        
        # Show record IDs for easy deletion
        record_ids = [video['record_id'] for video in broken_videos]
        print(f"\n🗑️  Record IDs to delete:")
        print(json.dumps(record_ids, indent=2))
        
    else:
        print("🎉 All YouTube links in Videos table are working!")

if __name__ == "__main__":
    main() 