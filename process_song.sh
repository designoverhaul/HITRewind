#!/bin/bash

YOUTUBE_API_KEY="AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
YOUTUBE_SEARCH_URL="https://www.googleapis.com/youtube/v3/search"

search_video() {
    local title="$1"
    local artist="$2"
    local query="${title} ${artist} official video"

    # Use printf to properly escape for Python
    local encoded_query=$(printf '%s' "$query" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))")

    local response=$(curl -s "${YOUTUBE_SEARCH_URL}?part=snippet&q=${encoded_query}&type=video&maxResults=1&videoCategoryId=10&key=${YOUTUBE_API_KEY}")

    local video_id=$(echo "$response" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['items'][0]['id']['videoId'] if data.get('items') else '')" 2>/dev/null)

    echo "$video_id"
}

rank="$1"
title="$2"
artist="$3"

echo "[$rank] Searching: $title - $artist"
video_id=$(search_video "$title" "$artist")

if [ -n "$video_id" ]; then
    # Extract main artist name (before "featuring", "and", etc.)
    main_artist=$(echo "$artist" | sed -E 's/ (featuring|and|,|with).*//')
    url="https://www.youtube.com/watch?v=${video_id}"
    echo "FOUND|$rank|$title|$main_artist|$url"
else
    echo "NOT_FOUND|$rank|$title|$artist|"
fi
