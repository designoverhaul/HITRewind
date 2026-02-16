#!/usr/bin/env python3
"""
Upload the 2001 songs to Airtable MTvVideosNEW table using the REST API.
Processes records in batches of 10 (Airtable's limit).
"""

import json
import time
import urllib.request
import urllib.parse
import urllib.error
from typing import List, Dict, Tuple

# Airtable Configuration
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
BASE_ID = "appxCBIOkiJEZiph7"
TABLE_ID = "tblNwqwVyflL8hNDy"
AIRTABLE_URL = f"https://api.airtable.com/v0/{BASE_ID}/{TABLE_ID}"


def upload_batch(records: List[Dict]) -> Tuple[bool, str, int]:
    """
    Upload a batch of records to Airtable.

    Args:
        records: List of record dicts (max 10)

    Returns:
        Tuple of (success, message, records_created)
    """
    if len(records) > 10:
        return False, "Batch size exceeds 10 records", 0

    # Prepare the request
    data = json.dumps({"records": records}).encode('utf-8')

    req = urllib.request.Request(AIRTABLE_URL, data=data, method='POST')
    req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')
    req.add_header('Content-Type', 'application/json')

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode())
            created_count = len(result.get('records', []))
            return True, f"Successfully created {created_count} records", created_count

    except urllib.error.HTTPError as e:
        error_body = e.read().decode() if e.fp else "No error details"
        return False, f"HTTP {e.code}: {error_body}", 0
    except Exception as e:
        return False, f"Error: {str(e)}", 0


def upload_all_records(json_file: str, delay: float = 1.5) -> Dict:
    """
    Upload all records from JSON file in batches.

    Args:
        json_file: Path to JSON file with records
        delay: Delay between batches in seconds

    Returns:
        Dict with summary statistics
    """
    # Load records
    with open(json_file, 'r') as f:
        records = json.load(f)

    print(f"Loaded {len(records)} records from {json_file}\n")

    # Split into batches of 10
    batch_size = 10
    batches = [records[i:i+batch_size] for i in range(0, len(records), batch_size)]

    print(f"Processing {len(batches)} batches of up to {batch_size} records each\n")
    print("=" * 70)

    # Track results
    total_created = 0
    total_failed = 0
    failed_batches = []

    # Upload each batch
    for batch_num, batch in enumerate(batches, 1):
        print(f"\n[Batch {batch_num}/{len(batches)}] Uploading {len(batch)} records...")

        # Show which songs are in this batch
        for record in batch:
            fields = record['fields']
            print(f"  {fields['Rank']}. {fields['title']} - {fields['artistName']}")

        # Upload the batch
        success, message, created = upload_batch(batch)

        if success:
            print(f"  ✓ {message}")
            total_created += created
        else:
            print(f"  ✗ {message}")
            total_failed += len(batch)
            failed_batches.append({
                'batch_num': batch_num,
                'records': batch,
                'error': message
            })

        # Rate limiting - pause between batches
        if batch_num < len(batches):
            print(f"  ⏸️  Pausing {delay}s before next batch...")
            time.sleep(delay)

    # Print summary
    print("\n" + "=" * 70)
    print("UPLOAD SUMMARY")
    print("=" * 70)
    print(f"\n✓ Successfully created: {total_created} records")
    print(f"✗ Failed to create: {total_failed} records")
    print(f"📊 Success rate: {(total_created / len(records) * 100):.1f}%")

    if failed_batches:
        print(f"\n⚠️  {len(failed_batches)} batch(es) failed:")
        for fb in failed_batches:
            print(f"  - Batch {fb['batch_num']}: {fb['error']}")
            # Save failed batch for retry
            filename = f"failed_batch_{fb['batch_num']}.json"
            with open(filename, 'w') as f:
                json.dump(fb['records'], f, indent=2)
            print(f"    Saved to {filename} for retry")

    print("\n" + "=" * 70)

    return {
        'total_records': len(records),
        'created': total_created,
        'failed': total_failed,
        'failed_batches': failed_batches
    }


if __name__ == "__main__":
    print("2001 Songs - Airtable Upload")
    print("=" * 70 + "\n")

    # Upload the records
    result = upload_all_records('2001_songs_records.json', delay=1.5)

    # Exit with appropriate code
    if result['failed'] > 0:
        print("\n⚠️  Upload completed with errors")
        exit(1)
    else:
        print("\n✅ Upload completed successfully!")
        exit(0)
