#!/usr/bin/env python3
"""
Populate SpotifyChartVideos table with current Top 50
Searches YouTube for official music videos and adds to Airtable
"""

import urllib.request
import urllib.parse
import json
import time
import ssl

# Configuration
YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
BASE_ID = "appxCBIOkiJEZiph7"
TABLE_ID = "tblY46dNwduOlOuLG"

# SSL context for HTTPS
ssl_context = ssl.create_default_context()

# Spotify Top 50 - January 30, 2026
SONGS = [
    (1, "End of Beginning", "Djo"),
    (2, "The Fate of Ophelia", "Taylor Swift"),
    (3, "I Just Might", "Bruno Mars"),
    (4, "back to friends", "sombr"),
    (5, "Golden", "HUNTR/X"),
    (6, "Man I Need", "Olivia Dean"),
    (7, "Lush Life", "Zara Larsson"),
    (8, "WHERE IS MY HUSBAND!", "RAYE"),
    (9, "Die On This Hill", "SIENNA SPIRO"),
    (10, "So Easy (To Fall In Love)", "Olivia Dean"),
    (11, "Raindance", "Dave"),
    (12, "Die With A Smile", "Lady Gaga, Bruno Mars"),
    (13, "Ordinary", "Alex Warren"),
    (14, "Every Breath You Take", "The Police"),
    (15, "I Thought I Saw Your Face Today", "She & Him"),
    (16, "Iris", "The Goo Goo Dolls"),
    (17, "BIRDS OF A FEATHER", "Billie Eilish"),
    (18, "Locked out of Heaven", "Bruno Mars"),
    (19, "Sailor Song", "Gigi Perez"),
    (20, "That's What I Like", "Bruno Mars"),
    (21, "dopamina", "Peso Pluma, Tito Double P"),
    (22, "CHANEL", "Tyla"),
    (23, "Sweater Weather", "The Neighbourhood"),
    (24, "Gabriela", "KATSEYE"),
    (25, "BAILE INoLVIDABLE", "Bad Bunny"),
    (26, "No Broke Boys", "Disco Lines, Tinashe"),
    (27, "Love Me Not", "Ravyn Lenae"),
    (28, "Cuandoante", "El Bogueto, Yung Beef"),
    (29, "Opalite", "Taylor Swift"),
    (30, "Cuando No Era Cantante - Remix", "El Bogueto, Anuel AA, Fuerza Regida"),
    (31, "DtMF", "Bad Bunny"),
    (32, "4 Raws", "EsDeeKid"),
    (33, "Stateside", "PinkPantheress, Zara Larsson"),
    (34, "Let Me Love You", "DJ Snake, Justin Bieber"),
    (35, "12 to 12", "sombr"),
    (36, "Creep", "Radiohead"),
    (37, "One Of The Girls", "The Weeknd, JENNIE, Lily-Rose Depp"),
    (38, "One Dance", "Drake, Wizkid, Kyla"),
    (39, "Who", "Jimin"),
    (40, "The Night We Met", "Lord Huron"),
    (41, "WILDFLOWER", "Billie Eilish"),
    (42, "7-3", "Peso Pluma, Tito Double P"),
    (43, "Sedia Aku Sebelum Hujan", "Idgitaf"),
    (44, "What You Saying", "Lil Uzi Vert"),
    (45, "Don't Say You Love Me", "Jin"),
    (46, "Posso Até Não Te Dar Flores", "DJ Japa NK, MC Meno K"),
    (47, "Yellow", "Coldplay"),
    (48, "daño", "Peso Pluma, Tito Double P"),
    (49, "HELICOPTER", "A$AP Rocky"),
    (50, "I Wanna Be Yours", "Arctic Monkeys"),
]


def search_youtube(title, artist):
    """Search YouTube for official music video"""
    # Clean artist name - take first artist for search
    primary_artist = artist.split(",")[0].strip()

    # Try official music video search first
    queries = [
        f"{title} {primary_artist} official music video",
        f"{title} {primary_artist} official video",
        f"{title} {primary_artist}",
    ]

    for query in queries:
        params = urllib.parse.urlencode({
            "part": "snippet",
            "q": query,
            "type": "video",
            "videoCategoryId": "10",  # Music category
            "maxResults": 5,
            "key": YOUTUBE_API_KEY
        })

        url = f"https://www.googleapis.com/youtube/v3/search?{params}"

        try:
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, context=ssl_context) as response:
                data = json.loads(response.read().decode())

                if "items" in data and len(data["items"]) > 0:
                    # Look for official/VEVO channels first
                    for item in data["items"]:
                        channel = item["snippet"]["channelTitle"].lower()
                        video_title = item["snippet"]["title"].lower()

                        # Prioritize official channels
                        if "vevo" in channel or "official" in channel or primary_artist.lower() in channel:
                            video_id = item["id"]["videoId"]
                            return f"https://www.youtube.com/watch?v={video_id}"

                    # If no official channel found, use first result
                    video_id = data["items"][0]["id"]["videoId"]
                    return f"https://www.youtube.com/watch?v={video_id}"

        except Exception as e:
            print(f"  YouTube search error: {e}")
            continue

        time.sleep(0.5)  # Rate limiting between query attempts

    return None


def add_to_airtable(rank, title, artist, url):
    """Add record to SpotifyChartVideos table"""
    airtable_url = f"https://api.airtable.com/v0/{BASE_ID}/{TABLE_ID}"

    record = {
        "fields": {
            "title": title,
            "url": url,
            "Rank": rank,
            "artistName": artist
        }
    }

    data = json.dumps(record).encode("utf-8")

    req = urllib.request.Request(
        airtable_url,
        data=data,
        headers={
            "Authorization": f"Bearer {AIRTABLE_API_KEY}",
            "Content-Type": "application/json"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, context=ssl_context) as response:
            result = json.loads(response.read().decode())
            return result.get("id")
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"  Airtable error: {e.code} - {error_body}")
        return None


def main():
    print("=" * 60)
    print("Populating SpotifyChartVideos - Top 50")
    print("=" * 60)

    success_count = 0
    failed = []

    for rank, title, artist in SONGS:
        print(f"\n{rank}. {title} - {artist}")

        # Search YouTube
        print("  Searching YouTube...")
        video_url = search_youtube(title, artist)

        if not video_url:
            print("  ❌ No video found")
            failed.append((rank, title, artist))
            continue

        print(f"  Found: {video_url}")

        # Add to Airtable
        print("  Adding to Airtable...")
        record_id = add_to_airtable(rank, title, artist, video_url)

        if record_id:
            print(f"  ✅ Added (ID: {record_id})")
            success_count += 1
        else:
            print("  ❌ Failed to add")
            failed.append((rank, title, artist))

        # Rate limiting
        time.sleep(1.5)

    print("\n" + "=" * 60)
    print(f"COMPLETE: {success_count}/{len(SONGS)} songs added")
    print("=" * 60)

    if failed:
        print("\nFailed songs:")
        for rank, title, artist in failed:
            print(f"  {rank}. {title} - {artist}")


if __name__ == "__main__":
    main()
