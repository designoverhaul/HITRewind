#!/usr/bin/env python3
"""
Debug 80s Thumbnails Script
Tests all YouTube thumbnail URLs for 80s videos to identify which ones fail
"""

import requests
import json
import re
from urllib.parse import urlparse, parse_qs

# Airtable configuration
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
BASE_ID = "appxCBIOkiJEZiph7"
TABLE_ID = "tbl3waFYL7jfER18L"  # MTvVideos table

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
    return None

def get_80s_videos():
    """Fetch 80s featured videos from Airtable"""
    url = f"https://api.airtable.com/v0/{BASE_ID}/{TABLE_ID}"
    params = {
        "filterByFormula": "{80sFeatured}=1",
        "maxRecords": 50
    }
    headers = {
        "Authorization": f"Bearer {AIRTABLE_API_KEY}"
    }
    
    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
        
        videos = []
        for record in data.get('records', []):
            fields = record.get('fields', {})
            video_data = {
                'id': record['id'],
                'title': fields.get('title', 'Unknown'),
                'artist': fields.get('artistName', 'Unknown'),
                'thumbnail': fields.get('thumbnail'),
                'url': fields.get('url')
            }
            videos.append(video_data)
        
        print(f"✅ Found {len(videos)} 80s videos")
        return videos
        
    except Exception as e:
        print(f"❌ Error fetching videos: {e}")
        return []

def test_thumbnail(video):
    """Test if a video's thumbnail loads successfully"""
    title = video['title']
    artist = video['artist']
    thumbnail_url = video['thumbnail']
    
    if not thumbnail_url:
        print(f"❌ [{title}] No thumbnail URL")
        return False
    
    try:
        response = requests.head(thumbnail_url, timeout=10)
        if response.status_code == 200:
            print(f"✅ [{title}] Thumbnail OK")
            return True
        else:
            print(f"❌ [{title}] HTTP {response.status_code} - {thumbnail_url}")
            return False
    except Exception as e:
        print(f"❌ [{title}] Error: {e}")
        return False

def generate_youtube_thumbnail(video):
    """Generate YouTube thumbnail URL from video URL"""
    video_url = video.get('url')
    if not video_url:
        return None
    
    video_id = extract_video_id(video_url)
    if not video_id:
        return None
    
    # Try different YouTube thumbnail qualities
    thumbnail_urls = [
        f"https://i.ytimg.com/vi/{video_id}/mqdefault.jpg",  # Medium quality
        f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg",  # High quality
        f"https://i.ytimg.com/vi/{video_id}/sddefault.jpg",  # Standard quality
        f"https://i.ytimg.com/vi/{video_id}/maxresdefault.jpg"  # Max quality
    ]
    
    return thumbnail_urls

def main():
    print("🎸 80s Thumbnails Debug Tool")
    print("=" * 50)
    
    # Get 80s videos
    videos = get_80s_videos()
    if not videos:
        return
    
    # Test each thumbnail
    failed_videos = []
    success_count = 0
    
    for i, video in enumerate(videos, 1):
        print(f"\n[{i}/{len(videos)}] Testing: {video['title']} - {video['artist']}")
        
        if test_thumbnail(video):
            success_count += 1
        else:
            failed_videos.append(video)
            
            # Try generating YouTube thumbnails
            print(f"  🔄 Trying YouTube thumbnail generation...")
            youtube_thumbnails = generate_youtube_thumbnail(video)
            if youtube_thumbnails:
                for thumb_url in youtube_thumbnails:
                    try:
                        response = requests.head(thumb_url, timeout=5)
                        if response.status_code == 200:
                            print(f"  ✅ Alternative thumbnail found: {thumb_url}")
                            break
                    except:
                        continue
    
    # Summary
    print(f"\n📊 SUMMARY")
    print("=" * 50)
    print(f"Total videos: {len(videos)}")
    print(f"Successful thumbnails: {success_count}")
    print(f"Failed thumbnails: {len(failed_videos)}")
    print(f"Success rate: {(success_count/len(videos)*100):.1f}%")
    
    if failed_videos:
        print(f"\n❌ FAILED VIDEOS:")
        for video in failed_videos:
            print(f"  - {video['title']} ({video['artist']})")
            print(f"    URL: {video.get('thumbnail', 'No thumbnail URL')}")

if __name__ == "__main__":
    main() 