#!/usr/bin/env python3
"""Bulk extract Classic Rock official channel videos and upload to Airtable."""

import subprocess, json, re, time, urllib.request, urllib.parse, sys

YOUTUBE_API_KEY = "AIzaSyBiNw2RoGEbxTMGNiApi3TBZ-EH8oQXy24"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE = "tblSq6zqj4c6aXDhB"
FLD_TITLE = "fldO1e3nYAVfMVy60"
FLD_ARTIST = "fldJ1DiGlTjd9tuqn"
FLD_VIDEO_ID = "fldmWemcnY3I1JJvV"
FLD_DATE = "fldpbanMc1tNvI6xQ"
FLD_DURATION = "fldInoLuZjSZBBQ2J"

ARTISTS = {
    "Led Zeppelin": "https://www.youtube.com/channel/UCaKZA66vM_TUpetUNohmR0A",
    "Pink Floyd": "https://www.youtube.com/channel/UCY2qt3dw2TQJxvBrDiYGHdQ",
    "Rolling Stones": "https://www.youtube.com/channel/UCB_Z6rBg3WW3NL4-QimhC2A",
    "David Bowie": "https://www.youtube.com/channel/UC8YgWcDKi1rLbQ1OtrOHeDw",
    "Grateful Dead": "https://www.youtube.com/channel/UCPuuuhmMW7jh6roOrIV9yRw",
    "Beatles": "https://www.youtube.com/channel/UCc4K7bAqpdBP8jh1j9XZAww",
    "The Doors": "https://www.youtube.com/channel/UCYgJ2M1mq8Ae0QOm_VQU4VQ",
    "Elton John": "https://www.youtube.com/channel/UCcd0tBtip8YzdTCUw3OVv_Q",
    "AC/DC": "https://www.youtube.com/channel/UCB0JSO6d5ysH2Mmqz5I9rIw",
    "Bob Dylan": "https://www.youtube.com/@BobDylan",
    "Fleetwood Mac": "https://www.youtube.com/channel/UCAb60rVrvVQVfSgrX1UWb0g",
    "Eric Clapton": "https://www.youtube.com/channel/UCtCOFqqGGGunX71nfZgPQOQ",
    "The Allman Brothers": "https://www.youtube.com/channel/UCiIe7qOxLXxRpLSEuGHp5rw",
    "Black Sabbath": "https://www.youtube.com/channel/UCrx-X329UKv0Y06VhfpFVvw",
    "Tom Petty": "https://www.youtube.com/channel/UCvYomLPMwUr1FAXRMGhVfCQ",
    "Queen": "https://www.youtube.com/channel/UCiMhD4jzUqG-IgPzUmmytRQ",
    "Jimi Hendrix": "https://www.youtube.com/channel/UCEqrtYLjy1o4hvaUI0J530w",
    "The Who": "https://www.youtube.com/channel/UCUtwj-3S97bj3lYDVxDKtlQ",
    "Eagles": "https://www.youtube.com/channel/UCPTypnDNlOZVnD7MY30_YBw",
    "Aerosmith": "https://www.youtube.com/channel/UCBxdHQVOaZhUOIj_3gt2FYw",
    "Stevie Ray Vaughan": "https://www.youtube.com/channel/UCxPlXqVP-0GvvGG-WrE_6Iw",
    "ZZ Top": "https://www.youtube.com/channel/UCXdqh7TtuMuqasECfTItzXA",
}

def yt_dlp_extract(channel_url, max_videos=40):
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
        time.sleep(0.25)
    return total

def process_artist(name, channel_url):
    print(f"\n{'='*60}")
    print(f"Processing: {name}")
    print(f"{'='*60}")
    print(f"  [1/3] Extracting videos from channel...")
    videos = yt_dlp_extract(channel_url)
    if not videos:
        print(f"  SKIP: No videos found")
        return 0
    print(f"  Found {len(videos)} videos")
    print(f"  [2/3] Fetching publish dates...")
    video_ids = [v["id"] for v in videos]
    dates = youtube_api_dates(video_ids)
    print(f"  Got dates for {len(dates)}/{len(videos)} videos")
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
    print(f"DONE! Uploaded {total_uploaded} total records for {total_artists} Classic Rock artists")
    print(f"{'='*60}")
