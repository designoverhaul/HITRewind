#!/usr/bin/env python3
"""
Script to add 2001 songs to Airtable MTvVideosNEW table.
Searches YouTube for each song and adds the record to Airtable.
"""

import json
import time
import urllib.request
import urllib.parse
import urllib.error
from typing import Optional, Dict, List, Tuple

# YouTube API Configuration
YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"

# Song data from CSV
SONGS_2001 = [
    (1, "Hanging by a Moment", "Lifehouse"),
    (2, "Fallin'", "Alicia Keys"),
    (3, "All for You", "Janet Jackson"),
    (4, "Drops of Jupiter (Tell Me)", "Train"),
    (5, "I'm Real (Murder Remix)", "Jennifer Lopez featuring Ja Rule"),
    (6, "If You're Gone", "Matchbox Twenty"),
    (7, "Let Me Blow Ya Mind", "Eve featuring Gwen Stefani"),
    (8, "Thank You", "Dido"),
    (9, "Again", "Lenny Kravitz"),
    (10, "Independent Women Part I", "Destiny's Child"),
    (11, "Hit 'Em Up Style (Oops!)", "Blu Cantrell"),
    (12, "It Wasn't Me", "Shaggy featuring Rikrok"),
    (13, "Stutter", "Joe featuring Mystikal"),
    (14, "It's Been Awhile", "Staind"),
    (15, "U Remind Me", "Usher"),
    (16, "Where the Party At", "Jagged Edge with Nelly"),
    (17, "Angel", "Shaggy featuring Rayvon"),
    (18, "Ride wit Me", "Nelly featuring City Spud"),
    (19, "Follow Me", "Uncle Kracker"),
    (20, "Peaches & Cream", "112"),
    (21, "Drive", "Incubus"),
    (22, "What Would You Do?", "City High"),
    (23, "Survivor", "Destiny's Child"),
    (24, "Lady Marmalade", "Christina Aguilera, Lil' Kim, Mýa and Pink"),
    (25, "Ms. Jackson", "Outkast"),
    (26, "Love Don't Cost a Thing", "Jennifer Lopez"),
    (27, "The Way You Love Me", "Faith Hill"),
    (28, "He Loves U Not", "Dream"),
    (29, "Butterfly", "Crazy Town"),
    (30, "Put It on Me", "Ja Rule featuring Lil' Mo and Vita"),
    (31, "Family Affair", "Mary J. Blige"),
    (32, "I Hope You Dance", "Lee Ann Womack"),
    (33, "South Side", "Moby featuring Gwen Stefani"),
    (34, "Don't Tell Me", "Madonna"),
    (35, "Get Ur Freak On", "Missy Elliott"),
    (36, "Crazy", "K-Ci & JoJo"),
    (37, "Fill Me In", "Craig David"),
    (38, "Someone to Call My Lover", "Janet Jackson"),
    (39, "With Arms Wide Open", "Creed"),
    (40, "Case of the Ex (Whatcha Gonna Do)", "Mýa"),
    (41, "All or Nothing", "O-Town"),
    (42, "Bootylicious", "Destiny's Child"),
    (43, "I'm Like a Bird", "Nelly Furtado"),
    (44, "Kryptonite", "3 Doors Down"),
    (45, "Fiesta", "R. Kelly featuring Jay-Z"),
    (46, "When It's Over", "Sugar Ray"),
    (47, "Jaded", "Aerosmith"),
    (48, "Promise", "Jagged Edge"),
    (49, "Missing You", "Case"),
    (50, "Differences", "Ginuwine"),
    (51, "This I Promise You", "'N Sync"),
    (52, "Izzo (H.O.V.A.)", "Jay-Z"),
    (53, "Superwoman Pt. II", "Lil' Mo featuring Fabolous"),
    (54, "Crazy for This Girl", "Evan and Jaron"),
    (55, "Nobody Wants to Be Lonely", "Ricky Martin and Christina Aguilera"),
    (56, "I Just Wanna Love U (Give It 2 Me)", "Jay-Z"),
    (57, "One Minute Man", "Missy Elliott featuring Ludacris"),
    (58, "Danger (Been So Long)", "Mystikal featuring Nivea"),
    (59, "Only Time", "Enya"),
    (60, "I Do!!", "Toya"),
    (61, "Never Had a Dream Come True", "S Club 7"),
    (62, "Stranger in My House", "Tamia"),
    (63, "Irresistible", "Jessica Simpson"),
    (64, "Heard It All Before", "Sunshine Anderson"),
    (65, "The Space Between", "Dave Matthews Band"),
    (66, "There You'll Be", "Faith Hill"),
    (67, "Love", "Musiq Soulchild"),
    (68, "It's Over Now", "112"),
    (69, "No More (Baby I'ma Do Right)", "3LW"),
    (70, "Turn Off the Light", "Nelly Furtado"),
    (71, "Ain't Nothing 'bout You", "Brooks & Dunn"),
    (72, "Play", "Jennifer Lopez"),
    (73, "I'm Already There", "Lonestar"),
    (74, "My Baby", "Lil' Romeo"),
    (75, "Beautiful Day", "U2"),
    (76, "Austin", "Blake Shelton"),
    (77, "Southern Hospitality", "Ludacris"),
    (78, "Grown Men Don't Cry", "Tim McGraw"),
    (79, "Livin' It Up", "Ja Rule featuring Case"),
    (80, "Loverboy", "Mariah Carey featuring Cameo"),
    (81, "Contagious", "The Isley Brothers featuring R. Kelly and Chanté Moore"),
    (82, "Who I Am", "Jessica Andrews"),
    (83, "Music", "Erick Sermon featuring Marvin Gaye"),
    (84, "I Wanna Be Bad", "Willa Ford"),
    (85, "Don't Happen Twice", "Kenny Chesney"),
    (86, "One More Day", "Diamond Rio"),
    (87, "I Wish", "R. Kelly"),
    (88, "It's a Great Day to Be Alive", "Travis Tritt"),
    (89, "I'm a Thug", "Trick Daddy"),
    (90, "Here's to the Night", "Eve 6"),
    (91, "You Shouldn't Kiss Me Like This", "Toby Keith"),
    (92, "Get Over Yourself", "Eden's Crush"),
    (93, "Dance with Me", "Debelah Morgan"),
    (94, "So Fresh, So Clean", "Outkast"),
    (95, "E.I.", "Nelly"),
    (96, "Be Like That", "3 Doors Down"),
    (97, "Most Girls", "Pink"),
    (98, "Oochie Wally", "QB Finest featuring Nas and Bravehearts"),
    (99, "Hero", "Enrique Iglesias"),
    (100, "Hemorrhage (In My Hands)", "Fuel"),
]


def clean_artist_name(artist: str) -> str:
    """Extract the main artist name, removing featuring/with clauses."""
    # Common separators for featured artists
    separators = [' featuring ', ' feat. ', ' feat ', ' ft. ', ' ft ', ' with ', ' and ']

    artist_lower = artist.lower()
    for sep in separators:
        if sep in artist_lower:
            idx = artist_lower.index(sep)
            return artist[:idx].strip()

    return artist.strip()


def search_youtube_video(title: str, artist: str) -> Optional[str]:
    """
    Search YouTube for a music video and return the video ID.

    Args:
        title: Song title
        artist: Artist name

    Returns:
        Video ID if found, None otherwise
    """
    query = f"{title} {artist} official video"
    params = {
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': 1,
        'key': YOUTUBE_API_KEY,
        'videoCategoryId': '10',  # Music category
    }

    url = f"{YOUTUBE_SEARCH_URL}?{urllib.parse.urlencode(params)}"

    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())

            if 'items' in data and len(data['items']) > 0:
                video_id = data['items'][0]['id']['videoId']
                video_title = data['items'][0]['snippet']['title']
                print(f"  ✓ Found: {video_title} (ID: {video_id})")
                return video_id
            else:
                print(f"  ✗ No results found")
                return None

    except urllib.error.HTTPError as e:
        if e.code == 403:
            print(f"  ✗ API quota exceeded or access denied")
        else:
            print(f"  ✗ HTTP error {e.code}: {e.reason}")
        return None
    except Exception as e:
        print(f"  ✗ Error: {str(e)}")
        return None


def format_airtable_record(rank: int, title: str, artist: str, video_id: str, year: int = 2001) -> Dict:
    """
    Format a record for Airtable MTvVideosNEW table.

    Args:
        rank: Song rank
        title: Song title
        artist: Full artist name
        video_id: YouTube video ID
        year: Year (default 2001)

    Returns:
        Record dict formatted for Airtable
    """
    cleaned_artist = clean_artist_name(artist)
    youtube_url = f"https://www.youtube.com/watch?v={video_id}"

    return {
        "fields": {
            "title": title,
            "url": youtube_url,
            "Rank": rank,
            "artistName": cleaned_artist,
            "Year": str(year)  # Note: "Year" with capital Y, and as string
        }
    }


def process_songs(batch_size: int = 10, delay: float = 1.0) -> Tuple[List[Dict], List[Dict], List[Dict]]:
    """
    Process all songs in batches to avoid API quota limits.

    Args:
        batch_size: Number of songs to process before pausing
        delay: Delay in seconds between API calls

    Returns:
        Tuple of (successful_records, not_found, errors)
    """
    successful = []
    not_found = []
    errors = []

    print(f"Processing {len(SONGS_2001)} songs from 2001...")
    print(f"Batch size: {batch_size}, Delay: {delay}s\n")

    for i, (rank, title, artist) in enumerate(SONGS_2001, 1):
        print(f"[{i}/{len(SONGS_2001)}] {rank}. {title} - {artist}")

        # Search for video
        video_id = search_youtube_video(title, artist)

        if video_id:
            record = format_airtable_record(rank, title, artist, video_id)
            successful.append(record)
        else:
            not_found.append({"rank": rank, "title": title, "artist": artist})

        # Rate limiting
        if i % batch_size == 0 and i < len(SONGS_2001):
            print(f"\n⏸️  Processed {i} songs, pausing for {delay}s...\n")
            time.sleep(delay)
        else:
            time.sleep(0.5)  # Small delay between requests

    return successful, not_found, errors


def save_records_json(records: List[Dict], filename: str):
    """Save records to JSON file for review or manual import."""
    with open(filename, 'w') as f:
        json.dump(records, f, indent=2)
    print(f"Saved {len(records)} records to {filename}")


def print_summary(successful: List[Dict], not_found: List[Dict], errors: List[Dict]):
    """Print a summary of the processing results."""
    print("\n" + "="*70)
    print("PROCESSING SUMMARY")
    print("="*70)
    print(f"\n✓ Successfully found: {len(successful)} videos")
    print(f"✗ Not found: {len(not_found)} videos")
    print(f"⚠ Errors: {len(errors)} videos")

    if not_found:
        print("\n--- Videos Not Found ---")
        for item in not_found:
            print(f"  {item['rank']}. {item['title']} - {item['artist']}")

    if errors:
        print("\n--- Errors ---")
        for item in errors:
            print(f"  {item['rank']}. {item['title']} - {item['artist']}: {item.get('error', 'Unknown error')}")

    print("\n" + "="*70)


if __name__ == "__main__":
    print("2001 Songs YouTube Video Search and Airtable Preparation")
    print("="*70 + "\n")

    # Process songs
    successful, not_found, errors = process_songs(batch_size=10, delay=2.0)

    # Save successful records to JSON
    if successful:
        save_records_json(successful, "2001_songs_records.json")

    # Print summary
    print_summary(successful, not_found, errors)

    print("\n📋 Next steps:")
    print("1. Review 2001_songs_records.json")
    print("2. Use Airtable MCP to batch create records:")
    print("   - Use batch_create_records tool")
    print("   - baseId: appxCBIOkiJEZiph7")
    print("   - tableId: tblNwqwVyflL8hNDy")
    print("   - Records are formatted and ready in the JSON file")
