#!/usr/bin/env python3
"""Bulk extract official channel videos and upload to Airtable OfficialVideos table."""

import subprocess, json, re, time, urllib.request, urllib.parse, sys

YOUTUBE_API_KEY = "AIzaSyBiNw2RoGEbxTMGNiApi3TBZ-EH8oQXy24"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE = "tblSq6zqj4c6aXDhB"
# Field IDs
FLD_TITLE = "fldO1e3nYAVfMVy60"
FLD_ARTIST = "fldJ1DiGlTjd9tuqn"
FLD_VIDEO_ID = "fldmWemcnY3I1JJvV"
FLD_DATE = "fldpbanMc1tNvI6xQ"
FLD_DURATION = "fldInoLuZjSZBBQ2J"

ARTISTS = {
    "Radiohead": "https://www.youtube.com/channel/UCq19-LqvG35A-30oyAiPiqA",
    "Rage Against The Machine": "https://www.youtube.com/channel/UCFcytuxeGAHyM67L_nHDTIA",
    "Red Hot Chili Peppers": "https://www.youtube.com/channel/UCEuOwB9vSL1oPKGNdONB4ig",
    "The Flaming Lips": "https://www.youtube.com/@flaminglips",
    "Coldplay": "https://www.youtube.com/channel/UCDPM_n1atn2ijUwHd0NNRQw",
    "Metallica": "https://www.youtube.com/channel/UCbulh9WdLtEXiooRcYK7SWw",
    "Dave Matthews Band": "https://www.youtube.com/channel/UCQv0bxIpI_K0zmmCBTOttAQ",
    "Nirvana": "https://www.youtube.com/channel/UCFMZHIQMgBXTSxsr86Caazw",
    "Foo Fighters": "https://www.youtube.com/channel/UCi2KNss4Yx73NG0JARSFe0A",
    "Smashing Pumpkins": "https://www.youtube.com/channel/UCnGcjQlLO8x7jsfw3r6U9ww",
    "Beck": "https://www.youtube.com/@beck",
    "Oasis": "https://www.youtube.com/channel/UCUDVBtnOQi4c7E8jebpjc9Q",
    "REM": "https://www.youtube.com/channel/UC2mK990tp7umnN6Y-DEGpDg",
    "Guns N Roses": "https://www.youtube.com/channel/UCIak6JLVOjqhStxrL1Lcytw",
    "Soundgarden": "https://www.youtube.com/@Soundgarden",
    "Alice in Chains": "https://www.youtube.com/channel/UCK9X9JACEsonjbqaewUtICA",
    "My Chemical Romance": "https://www.youtube.com/channel/UCCZGYab5SpD0I7Z5JqJZgww",
    "Panic! at the Disco": "https://www.youtube.com/channel/UColJTBTSGqaaZr5NOk5r3Pg",
    "Muse": "https://www.youtube.com/channel/UCGGhM6XCSJFQ6DTRffnKRIw",
    "Nine Inch Nails": "https://www.youtube.com/channel/UC4a5d57ZAWl999-YXw0C1Vg",
    "blink-182": "https://www.youtube.com/channel/UCdvlHk5SZWwr9HjUcwtu8ng",
    "Green Day": "https://www.youtube.com/channel/UCqC_GY2ZiENFz2pwL0cSfAw",
    "sombr": "https://www.youtube.com/channel/UCXlqFQmZZOb78teSnAqhuwA",
    "Arctic Monkeys": "https://www.youtube.com/channel/UC-KTRBl9_6AX10-Y7IKwKdw",
    "Linkin Park": "https://www.youtube.com/channel/UCZU9T1ceaOgwfLRq7OKFU4Q",
    "Queens of the Stone Age": "https://www.youtube.com/channel/UCAqa6dDmCH4XwipdfxoMo4Q",
    "System of a Down": "https://www.youtube.com/channel/UC7-YMmnc0ppcWmio8t1WdcA",
    "Weezer": "https://www.youtube.com/channel/UC7JDBUzkcwRGtQGia3_mMgQ",
    "The Black Keys": "https://www.youtube.com/channel/UCJL3h2-wEOB6EigQOBZ3ryg",
}

def yt_dlp_extract(channel_url, max_videos=40):
    """Extract video IDs, titles, durations from a YouTube channel."""
    cmd = [
        "yt-dlp", "--flat-playlist", f"--playlist-end={max_videos}",
        "--print", "%(id)s|||%(title)s|||%(duration)s",
        f"{channel_url}/videos"
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        videos = []
        for line in result.stdout.strip().split("\n"):
            if "|||" not in line:
                continue
            parts = line.split("|||")
            if len(parts) >= 3:
                vid_id, title, dur = parts[0], parts[1], parts[2]
                dur_secs = int(float(dur)) if dur and dur != "NA" else 0
                videos.append({"id": vid_id, "title": title, "duration": dur_secs})
        return videos
    except Exception as e:
        print(f"  yt-dlp error: {e}")
        return []

def youtube_api_dates(video_ids):
    """Batch fetch publish dates from YouTube API. Returns {videoId: date_str}."""
    dates = {}
    for i in range(0, len(video_ids), 50):
        batch = video_ids[i:i+50]
        ids_str = ",".join(batch)
        url = f"https://www.googleapis.com/youtube/v3/videos?part=snippet&id={ids_str}&key={YOUTUBE_API_KEY}&maxResults=50"
        try:
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
                for item in data.get("items", []):
                    dates[item["id"]] = item["snippet"]["publishedAt"][:10]
        except Exception as e:
            print(f"  YouTube API error: {e}")
    return dates

def airtable_upload(records):
    """Upload records to Airtable in batches of 10."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE}/{AIRTABLE_TABLE}"
    headers = {
        "Authorization": f"Bearer {AIRTABLE_API_KEY}",
        "Content-Type": "application/json"
    }
    total = 0
    for i in range(0, len(records), 10):
        batch = records[i:i+10]
        payload = json.dumps({"records": batch}).encode()
        req = urllib.request.Request(url, data=payload, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                result = json.loads(resp.read())
                total += len(result.get("records", []))
        except Exception as e:
            print(f"  Airtable upload error: {e}")
        time.sleep(0.25)  # Rate limit
    return total

def process_artist(name, channel_url):
    """Full pipeline for one artist."""
    print(f"\n{'='*60}")
    print(f"Processing: {name}")
    print(f"{'='*60}")

    # Step 1: yt-dlp
    print(f"  [1/3] Extracting videos from channel...")
    videos = yt_dlp_extract(channel_url)
    if not videos:
        print(f"  SKIP: No videos found")
        return 0
    print(f"  Found {len(videos)} videos")

    # Step 2: YouTube API for dates
    print(f"  [2/3] Fetching publish dates...")
    video_ids = [v["id"] for v in videos]
    dates = youtube_api_dates(video_ids)
    print(f"  Got dates for {len(dates)}/{len(videos)} videos")

    # Step 3: Build Airtable records
    records = []
    for v in videos:
        vid_id = v["id"]
        yt_url = f"https://www.youtube.com/watch?v={vid_id}"
        date = dates.get(vid_id, "")
        records.append({
            "fields": {
                FLD_TITLE: v["title"],
                FLD_ARTIST: name,
                FLD_VIDEO_ID: yt_url,
                FLD_DATE: date,
                FLD_DURATION: str(v["duration"]),
            }
        })

    # Step 4: Upload
    print(f"  [3/3] Uploading {len(records)} records to Airtable...")
    uploaded = airtable_upload(records)
    print(f"  Uploaded {uploaded} records")
    return uploaded

if __name__ == "__main__":
    total_uploaded = 0
    total_artists = len(ARTISTS)
    for idx, (name, url) in enumerate(ARTISTS.items(), 1):
        print(f"\n[{idx}/{total_artists}]", end="")
        count = process_artist(name, url)
        total_uploaded += count
        time.sleep(0.5)

    print(f"\n{'='*60}")
    print(f"DONE! Uploaded {total_uploaded} total records for {total_artists} artists")
    print(f"{'='*60}")
