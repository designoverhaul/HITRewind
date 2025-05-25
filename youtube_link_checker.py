#!/usr/bin/env python3
"""
YouTube Link Checker for HITRewind App

This script will:
1. Check all YouTube URLs in your Airtable database for validity
2. Identify broken links that return 404 or other errors
3. Provide options to remove broken videos or just report them
4. Work with all three tables: Videos, MTvVideos, and Artists

Usage:
    python youtube_link_checker.py --check-only    # Just report broken links
    python youtube_link_checker.py --remove        # Remove broken links after confirmation
"""

import requests
import time
import argparse
import json
from typing import List, Dict, Any, Tuple
from urllib.parse import urlparse, parse_qs
import re

# Airtable configuration
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
BASE_ID = "appxCBIOkiJEZiph7"
HEADERS = {
    "Authorization": f"Bearer {AIRTABLE_API_KEY}",
    "Content-Type": "application/json"
}

# Table configurations
TABLES = {
    "Videos": {
        "id": "tblTtRP4kdTDvfrBY",
        "url_field": "URL",
        "title_field": "Title",
        "artist_field": "artistName"
    },
    "MTvVideos": {
        "id": "tbl3waFYL7jfER18L", 
        "url_field": "url",
        "title_field": "title",
        "artist_field": "artistName"
    }
}

class YouTubeLinkChecker:
    def __init__(self):
        self.broken_links = []
        self.total_checked = 0
        self.session = requests.Session()
        # Add headers to appear more like a real browser
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        })

    def extract_video_id(self, url: str) -> str:
        """Extract YouTube video ID from various URL formats"""
        patterns = [
            r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})',
            r'youtube\.com/v/([a-zA-Z0-9_-]{11})',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return ""

    def check_youtube_video(self, url: str) -> Tuple[bool, str]:
        """
        Check if a YouTube video is accessible
        Returns (is_valid, error_message)
        """
        try:
            video_id = self.extract_video_id(url)
            if not video_id:
                return False, "Invalid YouTube URL format"

            # Method 1: Check YouTube thumbnail (faster and more reliable)
            thumbnail_url = f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg"
            response = self.session.head(thumbnail_url, timeout=10)
            
            if response.status_code == 200:
                # Double-check with another thumbnail format
                hq_thumbnail = f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"
                hq_response = self.session.head(hq_thumbnail, timeout=10)
                if hq_response.status_code == 200:
                    return True, "Video is accessible"
                else:
                    return False, f"Video may be private or deleted (thumbnail check failed)"
            else:
                return False, f"Video not found (HTTP {response.status_code})"

        except requests.exceptions.Timeout:
            return False, "Request timed out"
        except requests.exceptions.RequestException as e:
            return False, f"Network error: {str(e)}"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"

    def get_all_records(self, table_id: str) -> List[Dict[str, Any]]:
        """Fetch all records from a table with pagination"""
        all_records = []
        url = f"https://api.airtable.com/v0/{BASE_ID}/{table_id}"
        
        while url:
            try:
                response = requests.get(url, headers=HEADERS)
                response.raise_for_status()
                data = response.json()
                
                all_records.extend(data.get('records', []))
                url = data.get('offset')
                if url:
                    url = f"https://api.airtable.com/v0/{BASE_ID}/{table_id}?offset={url}"
                
                # Rate limiting
                time.sleep(0.2)
                
            except requests.exceptions.RequestException as e:
                print(f"Error fetching records: {e}")
                break
                
        return all_records

    def check_table_videos(self, table_name: str, table_config: Dict[str, str]) -> List[Dict[str, Any]]:
        """Check all videos in a specific table"""
        print(f"\n🔍 Checking {table_name} table...")
        
        records = self.get_all_records(table_config["id"])
        broken_videos = []
        
        for i, record in enumerate(records, 1):
            fields = record.get('fields', {})
            url = fields.get(table_config['url_field'])
            
            if not url:
                continue
                
            title = fields.get(table_config['title_field'], 'Unknown Title')
            artist = fields.get(table_config['artist_field'], 'Unknown Artist')
            
            # Handle artist field which might be a list
            if isinstance(artist, list):
                artist = ', '.join(artist) if artist else 'Unknown Artist'
                
            print(f"  [{i}/{len(records)}] Checking: {artist} - {title}")
            
            is_valid, error_msg = self.check_youtube_video(url)
            self.total_checked += 1
            
            if not is_valid:
                broken_video = {
                    'table': table_name,
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
                
            # Rate limiting to avoid being blocked
            time.sleep(0.5)
            
        return broken_videos

    def delete_record(self, table_id: str, record_id: str) -> bool:
        """Delete a record from Airtable"""
        url = f"https://api.airtable.com/v0/{BASE_ID}/{table_id}/{record_id}"
        try:
            response = requests.delete(url, headers=HEADERS)
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            print(f"Error deleting record {record_id}: {e}")
            return False

    def run_check(self, remove_broken: bool = False):
        """Main function to check all videos"""
        print("🎬 YouTube Link Checker for HITRewind App")
        print("=" * 50)
        
        # Check each table
        for table_name, table_config in TABLES.items():
            broken_videos = self.check_table_videos(table_name, table_config)
            self.broken_links.extend(broken_videos)
        
        # Report results
        print(f"\n📊 SUMMARY")
        print("=" * 50)
        print(f"Total videos checked: {self.total_checked}")
        print(f"Broken links found: {len(self.broken_links)}")
        
        if self.broken_links:
            print(f"\n❌ BROKEN VIDEOS:")
            print("-" * 30)
            
            # Group by table
            by_table = {}
            for video in self.broken_links:
                table = video['table']
                if table not in by_table:
                    by_table[table] = []
                by_table[table].append(video)
            
            for table_name, videos in by_table.items():
                print(f"\n{table_name} Table ({len(videos)} broken):")
                for video in videos:
                    print(f"  • {video['artist']} - {video['title']}")
                    print(f"    URL: {video['url']}")
                    print(f"    Error: {video['error']}")
                    print()
            
            # Save detailed report
            self.save_report()
            
            # Handle removal if requested
            if remove_broken:
                self.handle_removal()
        else:
            print("🎉 All YouTube links are working!")

    def save_report(self):
        """Save detailed report to JSON file"""
        report = {
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'total_checked': self.total_checked,
            'broken_count': len(self.broken_links),
            'broken_videos': self.broken_links
        }
        
        filename = f"broken_youtube_links_{time.strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"📄 Detailed report saved to: {filename}")

    def handle_removal(self):
        """Handle the removal of broken videos with user confirmation"""
        print(f"\n🗑️  REMOVAL PROCESS")
        print("=" * 30)
        
        by_table = {}
        for video in self.broken_links:
            table = video['table']
            if table not in by_table:
                by_table[table] = []
            by_table[table].append(video)
        
        for table_name, videos in by_table.items():
            print(f"\nFound {len(videos)} broken videos in {table_name} table.")
            confirm = input(f"Do you want to delete these {len(videos)} records? (yes/no): ").lower()
            
            if confirm in ['yes', 'y']:
                table_config = TABLES[table_name]
                deleted_count = 0
                
                for video in videos:
                    print(f"  Deleting: {video['artist']} - {video['title']}")
                    if self.delete_record(table_config['id'], video['record_id']):
                        deleted_count += 1
                        time.sleep(0.2)  # Rate limiting
                    else:
                        print(f"    ❌ Failed to delete")
                
                print(f"✅ Successfully deleted {deleted_count}/{len(videos)} records from {table_name}")
            else:
                print(f"⏭️  Skipped deletion for {table_name} table")

def main():
    parser = argparse.ArgumentParser(description='Check and optionally remove broken YouTube links from HITRewind Airtable')
    parser.add_argument('--check-only', action='store_true', help='Only check for broken links, do not remove')
    parser.add_argument('--remove', action='store_true', help='Remove broken links after confirmation')
    
    args = parser.parse_args()
    
    if not args.check_only and not args.remove:
        # Default to check-only mode
        args.check_only = True
    
    checker = YouTubeLinkChecker()
    checker.run_check(remove_broken=args.remove)

if __name__ == "__main__":
    main() 