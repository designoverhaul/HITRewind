#!/usr/bin/env python3
"""
Test script to diagnose thumbnail loading issues in the 80s section
This script will:
1. Fetch 80s videos from Airtable
2. Test thumbnail URL accessibility
3. Measure download speeds
4. Identify potential performance bottlenecks
"""

import requests
import time
import json
import os
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor
import threading

# Configuration
AIRTABLE_API_KEY = "YOUR_AIRTABLE_API_KEY"  # Replace with your actual API key
BASE_ID = "appxCBIOkiJEZiph7"
TABLE_NAME = "MTvVideos"
FILTER_FORMULA = "{80sFeatured}=1"

class ThumbnailTester:
    def __init__(self, api_key):
        self.api_key = api_key
        self.session = requests.Session()
        self.results = []
        self.lock = threading.Lock()
        
    def fetch_80s_videos(self):
        """Fetch 80s featured videos from Airtable"""
        url = f"https://api.airtable.com/v0/{BASE_ID}/{TABLE_NAME}"
        params = {
            "filterByFormula": FILTER_FORMULA,
            "maxRecords": 50
        }
        headers = {
            "Authorization": f"Bearer {self.api_key}"
        }
        
        try:
            response = self.session.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
            
            videos = []
            for record in data.get('records', []):
                fields = record.get('fields', {})
                if 'thumbnail' in fields and fields['thumbnail']:
                    videos.append({
                        'id': record['id'],
                        'title': fields.get('title', 'Unknown'),
                        'artist': fields.get('artistName', 'Unknown'),
                        'thumbnail': fields['thumbnail']
                    })
            
            print(f"✅ Found {len(videos)} 80s videos with thumbnails")
            return videos
            
        except Exception as e:
            print(f"❌ Error fetching videos: {e}")
            return []
    
    def test_thumbnail_url(self, video):
        """Test a single thumbnail URL"""
        thumbnail_url = video['thumbnail']
        start_time = time.time()
        
        try:
            # Test HEAD request first (faster)
            response = self.session.head(thumbnail_url, timeout=10)
            if response.status_code == 200:
                content_length = response.headers.get('content-length')
                size_kb = int(content_length) // 1024 if content_length else 0
                
                # Now test actual download
                start_download = time.time()
                response = self.session.get(thumbnail_url, timeout=15)
                download_time = time.time() - start_download
                
                actual_size_kb = len(response.content) // 1024
                speed_kbps = actual_size_kb / download_time if download_time > 0 else 0
                
                result = {
                    'video_id': video['id'],
                    'title': video['title'],
                    'artist': video['artist'],
                    'url': thumbnail_url,
                    'status': 'SUCCESS',
                    'response_time': time.time() - start_time,
                    'download_time': download_time,
                    'size_kb': actual_size_kb,
                    'speed_kbps': speed_kbps,
                    'status_code': response.status_code
                }
                
                print(f"✅ {video['title'][:30]:30} | {actual_size_kb:3d}KB | {speed_kbps:6.1f}KB/s | {download_time:.2f}s")
                
            else:
                result = {
                    'video_id': video['id'],
                    'title': video['title'],
                    'artist': video['artist'],
                    'url': thumbnail_url,
                    'status': 'HTTP_ERROR',
                    'response_time': time.time() - start_time,
                    'status_code': response.status_code,
                    'error': f"HTTP {response.status_code}"
                }
                print(f"❌ {video['title'][:30]:30} | HTTP {response.status_code}")
                
        except requests.exceptions.Timeout:
            result = {
                'video_id': video['id'],
                'title': video['title'],
                'artist': video['artist'],
                'url': thumbnail_url,
                'status': 'TIMEOUT',
                'response_time': time.time() - start_time,
                'error': 'Request timeout'
            }
            print(f"⏰ {video['title'][:30]:30} | TIMEOUT")
            
        except Exception as e:
            result = {
                'video_id': video['id'],
                'title': video['title'],
                'artist': video['artist'],
                'url': thumbnail_url,
                'status': 'ERROR',
                'response_time': time.time() - start_time,
                'error': str(e)
            }
            print(f"❌ {video['title'][:30]:30} | ERROR: {str(e)[:40]}")
        
        with self.lock:
            self.results.append(result)
        
        return result
    
    def run_concurrent_tests(self, videos, max_workers=10):
        """Run thumbnail tests concurrently"""
        print(f"\n🔄 Testing {len(videos)} thumbnails with {max_workers} concurrent workers...")
        print("=" * 80)
        print(f"{'Title':30} | {'Size':>8} | {'Speed':>10} | {'Time':>8}")
        print("=" * 80)
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            executor.map(self.test_thumbnail_url, videos)
    
    def analyze_results(self):
        """Analyze test results and provide recommendations"""
        if not self.results:
            print("❌ No results to analyze")
            return
        
        total_videos = len(self.results)
        successful = [r for r in self.results if r['status'] == 'SUCCESS']
        failed = [r for r in self.results if r['status'] != 'SUCCESS']
        timeouts = [r for r in self.results if r['status'] == 'TIMEOUT']
        
        print("\n" + "=" * 80)
        print("📊 ANALYSIS RESULTS")
        print("=" * 80)
        
        print(f"Total Videos Tested: {total_videos}")
        print(f"Successful Downloads: {len(successful)} ({len(successful)/total_videos*100:.1f}%)")
        print(f"Failed Downloads: {len(failed)} ({len(failed)/total_videos*100:.1f}%)")
        print(f"Timeouts: {len(timeouts)} ({len(timeouts)/total_videos*100:.1f}%)")
        
        if successful:
            avg_size = sum(r['size_kb'] for r in successful) / len(successful)
            avg_speed = sum(r['speed_kbps'] for r in successful) / len(successful)
            avg_time = sum(r['download_time'] for r in successful) / len(successful)
            slowest = min(successful, key=lambda x: x['speed_kbps'])
            
            print(f"\nPerformance Metrics:")
            print(f"Average Thumbnail Size: {avg_size:.1f} KB")
            print(f"Average Download Speed: {avg_speed:.1f} KB/s")
            print(f"Average Download Time: {avg_time:.2f} seconds")
            print(f"Slowest Download: {slowest['title'][:40]} ({slowest['speed_kbps']:.1f} KB/s)")
        
        if failed:
            print(f"\n❌ Failed Downloads:")
            for result in failed[:5]:  # Show first 5 failures
                print(f"  • {result['title'][:40]} - {result.get('error', 'Unknown error')}")
        
        # Recommendations
        print(f"\n💡 RECOMMENDATIONS:")
        
        if len(timeouts) > total_videos * 0.2:  # More than 20% timeouts
            print("  • High timeout rate detected. Network connectivity may be poor.")
            print("  • Consider implementing retry logic with exponential backoff.")
        
        if successful and avg_speed < 50:  # Less than 50 KB/s average
            print("  • Slow download speeds detected. This can cause thumbnail loading delays.")
            print("  • Implement image caching to avoid re-downloading.")
            print("  • Consider using lower resolution thumbnails or image compression.")
        
        if len(failed) > total_videos * 0.1:  # More than 10% failures
            print("  • High failure rate detected. Some thumbnail URLs may be broken.")
            print("  • Implement fallback placeholder images.")
            print("  • Add retry logic for failed downloads.")
        
        success_rate = len(successful) / total_videos
        if success_rate < 0.8:  # Less than 80% success
            print("  • ⚠️  LOW SUCCESS RATE: This is likely the cause of missing thumbnails!")
            print("  • Immediate action required: Check network connectivity and URL validity.")
        elif success_rate < 0.95:  # Less than 95% success
            print("  • Moderate issues detected. Some users may experience missing thumbnails.")
        else:
            print("  • ✅ Good success rate. Missing thumbnails may be due to memory/caching issues.")
    
    def save_results(self, filename="thumbnail_test_results.json"):
        """Save results to JSON file"""
        with open(filename, 'w') as f:
            json.dump({
                'timestamp': time.time(),
                'total_tested': len(self.results),
                'results': self.results
            }, f, indent=2)
        print(f"\n💾 Results saved to {filename}")

def main():
    print("🔧 MTV App Thumbnail Loading Diagnostics")
    print("=" * 50)
    
    # Check if API key is set
    api_key = os.getenv('AIRTABLE_API_KEY', AIRTABLE_API_KEY)
    if api_key == "YOUR_AIRTABLE_API_KEY":
        print("❌ Please set your Airtable API key in the script or as environment variable")
        print("   export AIRTABLE_API_KEY='your_api_key_here'")
        return
    
    tester = ThumbnailTester(api_key)
    
    # Fetch videos
    videos = tester.fetch_80s_videos()
    if not videos:
        print("❌ No videos found. Check your API key and filter.")
        return
    
    # Run tests
    tester.run_concurrent_tests(videos, max_workers=8)
    
    # Analyze and save results
    tester.analyze_results()
    tester.save_results()

if __name__ == "__main__":
    main() 