#!/usr/bin/env python3
"""
Upload videos from results JSON files to Airtable.
Reads the failed records and uploads them with correct field names.
"""

import urllib.request
import urllib.parse
import urllib.error
import json
import re
import sys
import time
import ssl

# Create SSL context
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

# Configuration
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"  # MTvVideosNEW


def clean_artist_name(artist: str) -> str:
    """Extract the main artist name from collaboration strings."""
    patterns = [
        r'\s+featuring\s+.*',
        r'\s+feat\.\s+.*',
        r'\s+ft\.\s+.*',
        r'\s+and\s+.*',
        r'\s+with\s+.*',
        r'\s+&\s+.*',
        r'\s+\(.*\)',
    ]

    cleaned = artist
    for pattern in patterns:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE)

    return cleaned.strip()


def add_to_airtable(record_data):
    """Add a record to Airtable MTvVideosNEW table."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"

    payload = json.dumps({'fields': record_data}).encode('utf-8')

    try:
        req = urllib.request.Request(url, data=payload, method='POST')
        req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')
        req.add_header('Content-Type', 'application/json')

        with urllib.request.urlopen(req, timeout=10, context=ssl_context) as response:
            data = json.loads(response.read().decode())
            return True, data.get('id', 'success')
    except urllib.error.HTTPError as e:
        try:
            error_body = e.read().decode()
            error_detail = json.loads(error_body)
            return False, f"HTTP {e.code}: {error_detail}"
        except:
            return False, f"HTTP {e.code}: {str(e)}"
    except Exception as e:
        return False, str(e)


def upload_year(year: int, results_file: str):
    """Upload records for a specific year from results file."""
    print(f"\n🎵 Uploading {year} songs from {results_file}...")

    try:
        with open(results_file, 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"❌ File not found: {results_file}")
        return {'successful': [], 'failed': []}

    # Get records to upload (from "failed" list since they have video URLs)
    records_to_upload = data.get('failed', [])

    if not records_to_upload:
        print(f"⚠️  No records to upload in {results_file}")
        return {'successful': [], 'failed': []}

    print(f"📊 Found {len(records_to_upload)} records to upload\n")

    results = {
        'successful': [],
        'failed': []
    }

    for i, record in enumerate(records_to_upload, 1):
        rank = record.get('rank')
        title = record.get('title')
        artist = record.get('artist')
        video_url = record.get('video_url')

        if not video_url:
            print(f"[{i}/{len(records_to_upload)}] {rank}. {title} - {artist}")
            print(f"  ⚠️  No video URL, skipping")
            results['failed'].append({**record, 'error': 'No video URL'})
            continue

        print(f"[{i}/{len(records_to_upload)}] {rank}. {title} - {artist}")
        print(f"  🔗 {video_url}")

        # Clean artist name
        cleaned_artist = clean_artist_name(artist)

        # Prepare Airtable record with correct field name
        record_data = {
            'title': title,
            'url': video_url,
            'Rank': rank,
            'artistName': cleaned_artist,
            'Year': str(year)  # Capital Y, string value
        }

        # Add to Airtable
        success, response = add_to_airtable(record_data)

        if success:
            print(f"  ✅ Added to Airtable (ID: {response})")
            results['successful'].append({
                'rank': rank,
                'title': title,
                'artist': artist,
                'video_url': video_url,
                'airtable_id': response
            })
        else:
            print(f"  ❌ Airtable error: {response}")
            results['failed'].append({
                'rank': rank,
                'title': title,
                'artist': artist,
                'video_url': video_url,
                'error': response
            })

        print()

        # Rate limiting
        time.sleep(1.0)

    return results


def main():
    """Main entry point."""
    print("📤 Upload Results to Airtable")
    print("=" * 70)

    # Define years and their result files
    years_files = {
        1973: "/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/1973_processing_results.json",
        1974: "/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/1974_processing_results.json",
        1975: "/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/1975_processing_results.json",
        1976: "/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/1976_processing_results.json",
    }

    # Parse command line arguments for specific years
    if len(sys.argv) > 1:
        years_to_process = []
        for arg in sys.argv[1:]:
            try:
                year = int(arg)
                if year in years_files:
                    years_to_process.append(year)
            except ValueError:
                pass
    else:
        years_to_process = list(years_files.keys())

    print(f"📅 Years to upload: {years_to_process}")

    all_results = {}

    for year in years_to_process:
        results_file = years_files[year]
        results = upload_year(year, results_file)
        all_results[year] = results

        # Print year summary
        print(f"\n📅 {year} Summary:")
        print(f"   ✅ Successfully added: {len(results['successful'])}")
        print(f"   ❌ Failed: {len(results['failed'])}")

        # Save updated results
        output_file = f"/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/{year}_upload_results.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"   💾 Results saved to: {output_file}")

        # Pause between years
        if year != years_to_process[-1]:
            print(f"\n⏸️  Pausing 3 seconds before next year...")
            time.sleep(3)

    # Print final summary
    print("\n" + "=" * 70)
    print("📊 FINAL SUMMARY")
    print("=" * 70)

    total_successful = sum(len(r['successful']) for r in all_results.values())
    total_failed = sum(len(r['failed']) for r in all_results.values())

    print(f"\n✅ Total successfully added: {total_successful}")
    print(f"❌ Total failed: {total_failed}")
    print("=" * 70)


if __name__ == "__main__":
    main()
