#!/usr/bin/env python3
"""Add Front Row Music concerts to Videos table in Airtable (linked to Artists)."""

import urllib.request
import urllib.parse
import json
import ssl
import time

AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
ARTISTS_TABLE_ID = "tblu9a6MnrdzECJFJ"
VIDEOS_TABLE = "Videos"

ssl_context = ssl.create_default_context()

# Front Row Music concerts to add
CONCERTS = [
    ("Bruce Springsteen", "London Calling: Live In Hyde Park", 2009, "a_8ciWn4ki0"),
    ("Bruce Springsteen", "Live in New York City", 2001, "1USJSz-oJzY"),
    ("Bruce Springsteen", "Live in Barcelona", 2002, "7ivNA0DijNw"),
    ("Bruce Springsteen", "Hammersmith Odeon, London '75", 1975, "vOgxo1O1Mwg"),
    ("Bruce Springsteen", "Live in Dublin", 2006, "0oygb1ih6tw"),
    ("Billy Joel", "Live at Shea Stadium", 2008, "DgQi9B0trqI"),
    ("Billy Joel", "Live at Yankee Stadium", 1990, "9xWoB0KcWB0"),
    ("Queen", "A Night At The Odeon", 1975, "uMYN6cTHyQ4"),
    ("Queen", "Live in Rio", 1985, "fxwiCiNRRTA"),
    ("Queen", "Live at Wembley Stadium", 1986, "poiwqYcFqYY"),
    ("Queen", "On Fire: Live at the Bowl", 1982, "lV9omVrZAmk"),
    ("Queen", "Live at the Rainbow '74", 1974, "vjVe6txk-6I"),
    ("Foo Fighters", "Live At Wembley Stadium", 2008, "xATJlGTZwMI"),
    ("Carrie Underwood", "The Blown Away Tour LIVE", 2013, "r9yTsaAQOXU"),
    ("Johnny Cash", "Man in Black: Live in Denmark", 1971, "-qXjZZHLFM4"),
    ("Johnny Cash", "A Night To Remember", 1973, "ck_kvesGstM"),
    ("Nas", "Made You Look - God's Son Live", 2003, "ePl_uQ5tquo"),
    ("James Taylor", "Live at the Beacon Theatre", 1998, "IcqMdnBdR4E"),
    ("James Taylor", "Pull Over", 2001, "LPejveRUcvA"),
    ("James Taylor", "Squibnocket Live", 2008, "EVMeDNDrugw"),
    ("Cyndi Lauper", "Live...At Last", 2004, "puSS2KsnQ-k"),
    ("Gloria Estefan", "Live & Unwrapped", 2003, "msUyeqGZVPM"),
    ("Gloria Estefan", "Evolution Tour Live in Miami", 1996, "1G1gy5tiEW4"),
    ("Gloria Estefan", "Homecoming Concert", 1988, "Gujg5vKocIc"),
    ("Shakira", "El Dorado World Tour", 2018, "uyAREe7CQDc"),
    ("Shakira", "Live From Paris", 2011, "IHqUiOvjlC0"),
    ("Shakira", "Oral Fixation Tour", 2007, "v3dcd_UD560"),
    ("Christina Aguilera", "Stripped... Live in the U.K.", 2004, "meY9CtFSa8I"),
    ("Jamiroquai", "Live in Verona", 2002, "cjTZF-T1NFY"),
    ("Kings of Leon", "Live at the O2 London", 2009, "Brv_dh8Qt5U"),
]


def make_request(url: str, headers: dict = None, data: bytes = None, method: str = None) -> dict:
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(req, context=ssl_context, timeout=30) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        return {'error': {'code': e.code, 'message': error_body}}
    except Exception as e:
        return {'error': {'code': 0, 'message': str(e)}}


def fetch_all_artists() -> list:
    """Fetch all artists from the Artists table."""
    headers = {'Authorization': f'Bearer {AIRTABLE_API_KEY}'}
    all_records = []
    offset = None

    while True:
        url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{ARTISTS_TABLE_ID}?pageSize=100"
        if offset:
            url += f"&offset={offset}"

        data = make_request(url, headers=headers)

        if 'error' in data:
            print(f"Error fetching artists: {data['error']}")
            break

        all_records.extend(data.get('records', []))
        offset = data.get('offset')
        if not offset:
            break
        time.sleep(0.2)

    return all_records


def check_video_exists(video_url: str) -> bool:
    """Check if a video URL already exists in Videos table."""
    headers = {'Authorization': f'Bearer {AIRTABLE_API_KEY}'}
    filter_formula = f'{{URL}}="{video_url}"'
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{VIDEOS_TABLE}?filterByFormula={urllib.parse.quote(filter_formula)}&maxRecords=1"

    data = make_request(url, headers=headers)
    if 'error' in data:
        return False
    return len(data.get('records', [])) > 0


def create_video_record(title: str, url: str, year: int, video_id: str, artist_record_id: str) -> dict:
    """Create a new video record in Videos table."""
    api_url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{VIDEOS_TABLE}"
    headers = {
        'Authorization': f'Bearer {AIRTABLE_API_KEY}',
        'Content-Type': 'application/json'
    }

    fields = {
        'Title': title,
        'URL': url,
        'Year': str(year),  # Year must be string
        'Artist Number': [artist_record_id],  # Link to Artist
    }

    payload = json.dumps({'fields': fields}).encode('utf-8')
    return make_request(api_url, headers=headers, data=payload, method='POST')


def create_artist_record(artist_name: str) -> dict:
    """Create a new artist record."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{ARTISTS_TABLE_ID}"
    headers = {
        'Authorization': f'Bearer {AIRTABLE_API_KEY}',
        'Content-Type': 'application/json'
    }
    fields = {'artistName': artist_name}
    payload = json.dumps({'fields': fields}).encode('utf-8')
    return make_request(url, headers=headers, data=payload, method='POST')


if __name__ == "__main__":
    print("=" * 60)
    print("ADDING FRONT ROW MUSIC CONCERTS TO VIDEOS TABLE")
    print("=" * 60)

    # Fetch all existing artists
    print("\n1. Fetching existing artists...")
    all_artists = fetch_all_artists()
    print(f"   Found {len(all_artists)} artists")

    # Build lookup by artist name (normalized)
    artist_lookup = {}
    for rec in all_artists:
        fields = rec.get('fields', {})
        name = fields.get('artistName', '').lower().strip()
        # Also handle variants like "Queen - Live Aid"
        base_name = name.split(' - ')[0].strip()
        if base_name and base_name not in artist_lookup:
            artist_lookup[base_name] = rec
        if name and name not in artist_lookup:
            artist_lookup[name] = rec

    print(f"\n2. Processing {len(CONCERTS)} concerts...")
    print("-" * 60)

    stats = {'added': 0, 'skipped': 0, 'artist_created': 0, 'errors': 0}

    for artist_name, title, year, video_id in CONCERTS:
        video_url = f"https://www.youtube.com/watch?v={video_id}"
        print(f"\n{artist_name} - {title} ({year})")

        # Check if video already exists
        if check_video_exists(video_url):
            print(f"  SKIPPED: Already exists")
            stats['skipped'] += 1
            continue

        # Find or create artist
        lookup_key = artist_name.lower().strip()
        artist_rec = artist_lookup.get(lookup_key)

        if not artist_rec:
            print(f"  SKIPPED: Artist '{artist_name}' not found in Artists table")
            stats['errors'] += 1
            continue

        artist_record_id = artist_rec.get('id')

        # Create video record
        result = create_video_record(title, video_url, year, video_id, artist_record_id)

        if 'error' in result:
            print(f"  ERROR: {result['error']}")
            stats['errors'] += 1
        else:
            print(f"  ADDED: {result.get('id')}")
            stats['added'] += 1

        time.sleep(0.3)

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Videos added: {stats['added']}")
    print(f"Videos skipped (already exist): {stats['skipped']}")
    print(f"New artists created: {stats['artist_created']}")
    print(f"Errors: {stats['errors']}")
