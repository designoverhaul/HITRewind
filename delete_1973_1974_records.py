#!/usr/bin/env python3
"""
Delete all records from MTvVideosNEW where year is 1973 or 1974
"""

import requests
import time
import json

# Configuration
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"  # MTvVideosNEW


def get_records_by_year(year):
    """Get all records for a specific year"""
    all_records = []
    offset = None

    while True:
        url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"
        headers = {
            'Authorization': f'Bearer {AIRTABLE_API_KEY}',
        }
        params = {
            'filterByFormula': f'{{year}}={year}',
            'pageSize': 100
        }
        if offset:
            params['offset'] = offset

        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            response.raise_for_status()
            data = response.json()

            records = data.get('records', [])
            all_records.extend(records)

            offset = data.get('offset')
            if not offset:
                break

            time.sleep(0.3)  # Small delay between pagination requests

        except Exception as e:
            print(f"Error fetching records for year {year}: {e}")
            break

    return all_records


def delete_records_batch(record_ids):
    """Delete a batch of records (max 10)"""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"
    headers = {
        'Authorization': f'Bearer {AIRTABLE_API_KEY}',
    }

    # Build query params for batch delete
    params = {}
    for i, record_id in enumerate(record_ids):
        params[f'records[{i}]'] = record_id

    try:
        response = requests.delete(url, headers=headers, params=params, timeout=30)
        response.raise_for_status()
        return True, response.json()
    except Exception as e:
        return False, str(e)


def main():
    print("=" * 70)
    print("Deleting 1973 and 1974 records from MTvVideosNEW")
    print("=" * 70)

    # Step 1: Get all records for 1973
    print("\nStep 1: Fetching 1973 records...")
    records_1973 = get_records_by_year(1973)
    print(f"  Found {len(records_1973)} records for year 1973")

    # Step 2: Get all records for 1974
    print("\nStep 2: Fetching 1974 records...")
    records_1974 = get_records_by_year(1974)
    print(f"  Found {len(records_1974)} records for year 1974")

    # Combine all records
    all_records = records_1973 + records_1974
    total_records = len(all_records)

    print(f"\nTotal records to delete: {total_records}")

    if total_records == 0:
        print("No records found to delete.")
        return

    # Show sample records before deletion
    print("\nSample records found:")
    for record in all_records[:5]:
        fields = record.get('fields', {})
        print(f"  - [{fields.get('year')}] {fields.get('title', 'No title')} by {fields.get('artistName', 'Unknown')}")

    if len(all_records) > 5:
        print(f"  ... and {len(all_records) - 5} more records")

    # Step 3: Delete records in batches of 10
    print("\n" + "-" * 70)
    print("Step 3: Deleting records in batches of 10...")
    print("-" * 70)

    record_ids = [r['id'] for r in all_records]
    deleted_count = 0
    failed_count = 0

    # Process in batches of 10
    for i in range(0, len(record_ids), 10):
        batch = record_ids[i:i+10]
        batch_num = (i // 10) + 1
        total_batches = (len(record_ids) + 9) // 10

        print(f"\nBatch {batch_num}/{total_batches}: Deleting {len(batch)} records...")

        success, result = delete_records_batch(batch)

        if success:
            deleted_count += len(batch)
            print(f"  Successfully deleted {len(batch)} records")
        else:
            failed_count += len(batch)
            print(f"  FAILED: {result}")

        # Rate limiting
        time.sleep(0.5)

    # Final summary
    print("\n" + "=" * 70)
    print("DELETION SUMMARY")
    print("=" * 70)
    print(f"1973 records found: {len(records_1973)}")
    print(f"1974 records found: {len(records_1974)}")
    print(f"Total records targeted: {total_records}")
    print(f"Successfully deleted: {deleted_count}")
    print(f"Failed to delete: {failed_count}")
    print("=" * 70)


if __name__ == "__main__":
    main()
