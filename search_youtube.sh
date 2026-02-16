#!/bin/bash

# YouTube API configuration
YOUTUBE_API_KEY="AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
YOUTUBE_SEARCH_URL="https://www.googleapis.com/youtube/v3/search"

# Function to search for a video
search_video() {
    local title="$1"
    local artist="$2"
    local query="${title} ${artist} official video"

    # URL encode the query
    local encoded_query=$(echo "$query" | sed 's/ /%20/g' | sed 's/&/%26/g')

    # Make the API call
    local response=$(curl -s "${YOUTUBE_SEARCH_URL}?part=snippet&q=${encoded_query}&type=video&maxResults=1&videoCategoryId=10&key=${YOUTUBE_API_KEY}")

    # Extract video ID using grep and sed
    local video_id=$(echo "$response" | grep -o '"videoId"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')

    if [ -n "$video_id" ]; then
        echo "$video_id"
        return 0
    else
        echo ""
        return 1
    fi
}

# Test with one song
echo "Testing YouTube search..."
video_id=$(search_video "Last Night" "Morgan Wallen")
if [ -n "$video_id" ]; then
    echo "✅ Found video: https://www.youtube.com/watch?v=${video_id}"
else
    echo "❌ Video not found"
fi
