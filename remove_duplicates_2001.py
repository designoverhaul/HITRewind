#!/usr/bin/env python3
"""
Remove duplicate 2001 records from Airtable MTvVideosNEW table.
Keeps the most recently created record for each rank.
"""

import urllib.request
import json
from collections import defaultdict
from datetime import datetime
import time

# Airtable Configuration
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
BASE_ID = "appxCBIOkiJEZiph7"
TABLE_ID = "tblNwqwVyflL8hNDy"
AIRTABLE_URL = f"https://api.airtable.com/v0/{BASE_ID}/{TABLE_ID}"


def fetch_all_2001_records():
    """Fetch all records with Year=2001"""
    url = f'{AIRTABLE_URL}?filterByFormula=%7BYear%7D%3D%222001%22'

    all_records = []
    offset = None

    print("Fetching all 2001 records from Airtable...")

    while True:
        fetch_url = url + (f'&offset={offset}' if offset else '')
        req = urllib.request.Request(fetch_url)
        req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')

        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            all_records.extend(data.get('records', []))

            offset = data.get('offset')
            if not offset:
                break

    print(f"Found {len(all_records)} total records with Year=2001\n")
    return all_records


def identify_duplicates(records):
    """Group records by rank and identify duplicates"""
    by_rank = defaultdict(list)

    for record in records:
        rank = record['fields'].get('Rank')
        if rank is not None:
            by_rank[rank].append(record)

    # Find duplicates (ranks with more than one record)
    duplicates = {rank: recs for rank, recs in by_rank.items() if len(recs) > 1}

    return duplicates


def delete_duplicate_records(duplicates, dry_run=True):
    """
    Delete duplicate records, keeping the first one for each rank.

    Args:
        duplicates: Dict of {rank: [records]}
        dry_run: If True, only show what would be deleted
    """
    to_delete = []

    for rank, records in sorted(duplicates.items()):
        # Keep the first record, delete the rest
        keep = records[0]
        delete_list = records[1:]

        print(f"\nRank {rank}: {len(records)} records")
        print(f"  KEEP: {keep['fields'].get('title')} (ID: {keep['id'][:8]}...)")

        for rec in delete_list:
            print(f"  DELETE: {rec['fields'].get('title')} (ID: {rec['id'][:8]}...)")
            to_delete.append(rec['id'])

    print(f"\n{'[DRY RUN] ' if dry_run else ''}Total records to delete: {len(to_delete)}")

    if not dry_run and to_delete:
        print("\nDeleting records in batches of 10...")

        # Delete in batches of 10 (Airtable limit)
        batch_size = 10
        for i in range(0, len(to_delete), batch_size):
            batch = to_delete[i:i+batch_size]

            # Build URL with record IDs
            delete_url = AIRTABLE_URL + "?" + "&".join([f"records[]={rid}" for rid in batch])

            req = urllib.request.Request(delete_url, method='DELETE')
            req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')

            try:
                with urllib.request.urlopen(req) as response:
                    result = json.loads(response.read().decode())
                    deleted_count = len(result.get('records', []))
                    print(f"  Deleted batch {i//batch_size + 1}: {deleted_count} records")

                time.sleep(1)  # Rate limiting

            except Exception as e:
                print(f"  Error deleting batch: {e}")

    return len(to_delete)


if __name__ == "__main__":
    print("2001 Records - Duplicate Removal Tool")
    print("=" * 70 + "\n")

    # Fetch all 2001 records
    records = fetch_all_2001_records()

    # Identify duplicates
    duplicates = identify_duplicates(records)

    if not duplicates:
        print("✓ No duplicates found!")
    else:
        print(f"Found duplicates for {len(duplicates)} ranks\n")
        print("=" * 70)

        # First, do a dry run
        print("\nDRY RUN - Showing what would be deleted:")
        print("=" * 70)
        count = delete_duplicate_records(duplicates, dry_run=True)

        # Ask for confirmation
        print("\n" + "=" * 70)
        response = input(f"\nDelete {count} duplicate records? (yes/no): ")

        if response.lower() == 'yes':
            print("\nProceeding with deletion...")
            print("=" * 70)
            deleted = delete_duplicate_records(duplicates, dry_run=False)
            print(f"\n✓ Successfully deleted {deleted} duplicate records")
        else:
            print("\nCancelled. No records were deleted.")
