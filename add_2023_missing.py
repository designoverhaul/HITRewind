#!/usr/bin/env python3
"""Add 2023 Billboard Hot 100 ranks 76-100 to Airtable MTvVideosNEW."""

import urllib.request
import urllib.parse
import urllib.error
import time
import json
import re
import ssl

YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"

YOUTUBE_DELAY = 1.5
AIRTABLE_DELAY = 0.5

ssl_context = ssl.create_default_context()


def clean_artist_name(artist: str) -> str:
    patterns = [r'\s+featuring\s+.*$', r'\s+feat\.\s+.*$', r'\s+ft\.\s+.*$',
                r'\s+with\s+.*$', r'\s+and\s+.*$', r'\s+&\s+.*$', r'\s+x\s+.*$', r'\s+/\s+.*$']
    cleaned = artist
    for pattern in patterns:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'\s*\(.*\)$', '', cleaned)
    return cleaned.strip()


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


def search_youtube_video(title: str, artist: str) -> dict | None:
    cleaned_artist = clean_artist_name(artist)
    search_queries = [
        f'"{title}" "{cleaned_artist}" official music video',
        f'{title} {cleaned_artist} official video',
        f'{title} {cleaned_artist} music video',
        f'{title} {cleaned_artist}',
    ]

    for query in search_queries:
        try:
            params = urllib.parse.urlencode({
                'part': 'snippet', 'q': query, 'type': 'video',
                'videoCategoryId': '10', 'maxResults': 5, 'key': YOUTUBE_API_KEY,
            })
            url = f'https://www.googleapis.com/youtube/v3/search?{params}'
            data = make_request(url)

            if 'error' in data:
                continue

            items = data.get('items', [])
            if not items:
                continue

            best_result, best_score = None, -1
            for item in items:
                snippet = item.get('snippet', {})
                video_id = item.get('id', {}).get('videoId', '')
                channel_title = snippet.get('channelTitle', '').lower()
                video_title = snippet.get('title', '').lower()

                if not video_id:
                    continue

                score = 0
                if 'vevo' in channel_title: score += 100
                if cleaned_artist.lower() in channel_title: score += 80
                if 'official' in channel_title: score += 50
                if 'official' in video_title: score += 30
                if 'music video' in video_title: score += 20
                if 'official music video' in video_title: score += 35
                if 'cover' in video_title and cleaned_artist.lower() not in channel_title: score -= 100
                if 'karaoke' in video_title: score -= 100

                title_words = title.lower().split()
                title_match_count = sum(1 for word in title_words if len(word) > 2 and word in video_title)
                title_match_ratio = title_match_count / len(title_words) if title_words else 0
                if title.lower() in video_title: score += 100
                elif title_match_ratio >= 0.7: score += 60
                elif title_match_ratio >= 0.5: score += 30
                else: score -= 50

                if score > best_score:
                    best_score = score
                    best_result = {'videoId': video_id, 'title': snippet.get('title', ''),
                                   'channelTitle': snippet.get('channelTitle', ''), 'score': score}

            if best_result and best_score >= 0:
                return best_result
            time.sleep(YOUTUBE_DELAY)
        except:
            continue
    return None


def add_to_airtable(records: list) -> dict:
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"
    headers = {'Authorization': f'Bearer {AIRTABLE_API_KEY}', 'Content-Type': 'application/json'}
    results = {'success': 0, 'failed': 0, 'errors': []}

    for i in range(0, len(records), 10):
        batch = records[i:i + 10]
        payload = json.dumps({'records': [{'fields': record} for record in batch]}).encode('utf-8')
        try:
            data = make_request(url, headers=headers, data=payload, method='POST')
            if 'error' in data:
                results['failed'] += len(batch)
                results['errors'].append(f"Batch {i // 10 + 1}: {data['error']}")
                print(f"  Error: {data['error']}")
            else:
                results['success'] += len(batch)
                print(f"  Added batch {i // 10 + 1}: {len(batch)} records")
            time.sleep(AIRTABLE_DELAY)
        except Exception as e:
            results['failed'] += len(batch)
            results['errors'].append(str(e))
    return results


# 2023 Billboard Year-End Hot 100 (ranks 76-100)
SONGS_2023 = [
    (76, "What It Is (Block Boy)", "Doechii Featuring Kodak Black"),
    (77, "Nobody Gets Me", "SZA"),
    (78, "Rich Men North Of Richmond", "Oliver Anthony Music"),
    (79, "Super Freaky Girl", "Nicki Minaj"),
    (80, "Dial Drunk", "Noah Kahan With Post Malone"),
    (81, "What Was I Made For?", "Billie Eilish"),
    (82, "Seven", "Jung Kook Featuring Latto"),
    (83, "Wait For U", "Future Featuring Drake & Tems"),
    (84, "Last Christmas", "Wham!"),
    (85, "Handle On You", "Parker McCollum"),
    (86, "Por Las Noches", "Peso Pluma"),
    (87, "Memory Lane", "Old Dominion"),
    (88, "Area Codes", "Kaliii"),
    (89, "Bury Me In Georgia", "Kane Brown"),
    (90, "PRC", "Peso Pluma X Natanael Cano"),
    (91, "What My World Spins Around", "Jordan Davis"),
    (92, "Ain't That Some", "Morgan Wallen"),
    (93, "Wild As Her", "Corey Kent"),
    (94, "Peaches & Eggplants", "Young Nudy Featuring 21 Savage"),
    (95, "I Wrote The Book", "Morgan Wallen"),
    (96, "Bzrp Music Sessions, Vol. 53", "Bizarrap & Shakira"),
    (97, "Meltdown", "Travis Scott Featuring Drake"),
    (98, "Put It On Da Floor Again", "Latto Featuring Cardi B"),
    (99, "Bloody Mary", "Lady Gaga"),
    (100, "Watermelon Moonshine", "Lainey Wilson"),
]


if __name__ == "__main__":
    records_to_add = []
    not_found = []

    print(f"\nProcessing {len(SONGS_2023)} songs for 2023...")
    print("=" * 60)

    for rank, title, artist in SONGS_2023:
        print(f"\n[{rank}] {title} - {artist}")
        result = search_youtube_video(title, artist)

        if result:
            video_url = f"https://www.youtube.com/watch?v={result['videoId']}"
            cleaned_artist = clean_artist_name(artist)
            print(f"  ✓ Found: {result['title'][:50]}...")
            print(f"  Score: {result['score']}")

            record = {'title': title, 'url': video_url, 'Rank': rank,
                      'artistName': cleaned_artist, 'Year': '2023'}
            records_to_add.append(record)
        else:
            print(f"  ✗ NOT FOUND")
            not_found.append((rank, title, artist))

        time.sleep(YOUTUBE_DELAY)

    print("\n" + "=" * 60)
    print(f"Found: {len(records_to_add)}, Not found: {len(not_found)}")

    if records_to_add:
        print(f"\nAdding {len(records_to_add)} records to Airtable...")
        results = add_to_airtable(records_to_add)
        print(f"Results: {results['success']} success, {results['failed']} failed")

    with open('2023_missing_results.json', 'w') as f:
        json.dump({'found': len(records_to_add), 'not_found': not_found}, f, indent=2)
