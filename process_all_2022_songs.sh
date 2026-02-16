#!/bin/bash

# Configuration
YOUTUBE_API_KEY="AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
AIRTABLE_API_KEY="pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID="appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID="tblNwqwVyflL8hNDy"
YEAR=2022

# Counters
SUCCESSFUL=0
NO_VIDEO=0
ERRORS=0

# Function to search YouTube
search_youtube() {
    local title="$1"
    local artist="$2"
    local query="${title} ${artist} official video"

    # URL encode the query
    local encoded_query=$(echo "$query" | jq -sRr @uri)

    # Search YouTube
    local response=$(curl -s "https://www.googleapis.com/youtube/v3/search?part=snippet&q=${encoded_query}&type=video&maxResults=1&videoCategoryId=10&key=${YOUTUBE_API_KEY}")

    # Extract video ID
    local video_id=$(echo "$response" | jq -r '.items[0].id.videoId // empty')

    if [ -z "$video_id" ] || [ "$video_id" = "null" ]; then
        echo ""
    else
        echo "$video_id"
    fi
}

# Function to extract main artist
extract_main_artist() {
    local artist="$1"

    # Remove everything after common separators
    artist=$(echo "$artist" | sed -E 's/ featuring .*//' | sed -E 's/ feat\.? .*//' | sed -E 's/ ft\.? .*//')

    # Handle "and" but only if it's not at the beginning (band names)
    if echo "$artist" | grep -q " and "; then
        local first_part=$(echo "$artist" | sed -E 's/ and .*//')
        if [ ${#first_part} -gt 5 ]; then
            artist="$first_part"
        fi
    fi

    # Remove " &" and everything after
    artist=$(echo "$artist" | sed -E 's/ & .*//' | sed -E 's/ with .*//' | sed -E 's/,.*//')

    echo "$artist"
}

# Function to add to Airtable
add_to_airtable() {
    local rank=$1
    local title="$2"
    local artist="$3"
    local video_url="$4"

    local main_artist=$(extract_main_artist "$artist")

    # Create JSON payload
    local json=$(jq -n \
        --arg title "$title" \
        --arg url "$video_url" \
        --argjson rank $rank \
        --arg artistName "$main_artist" \
        --arg year "$YEAR" \
        '{
            fields: {
                title: $title,
                url: $url,
                Rank: $rank,
                artistName: $artistName,
                Year: $year
            }
        }')

    # Send to Airtable
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST "https://api.airtable.com/v0/${AIRTABLE_BASE_ID}/${AIRTABLE_TABLE_ID}" \
        -H "Authorization: Bearer ${AIRTABLE_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$json")

    local http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# Process a single song
process_song() {
    local rank=$1
    local title="$2"
    local artist="$3"

    echo ""
    echo "[$rank/75] $title - $artist"

    # Search YouTube
    local video_id=$(search_youtube "$title" "$artist")

    if [ -z "$video_id" ]; then
        echo "  ⚠️  No YouTube video found"
        ((NO_VIDEO++))
        return 1
    fi

    local video_url="https://www.youtube.com/watch?v=${video_id}"
    echo "  ✅ Found video: $video_id"

    # Add to Airtable
    if add_to_airtable $rank "$title" "$artist" "$video_url"; then
        echo "  ✅ Added to Airtable"
        ((SUCCESSFUL++))
        return 0
    else
        echo "  ❌ Failed to add to Airtable"
        ((ERRORS++))
        return 2
    fi
}

# Main execution
echo "🎵 2022 SONGS AIRTABLE IMPORTER"
echo "======================================================================"
echo "Processing all 75 songs from 2022..."
echo ""

# All 75 songs
process_song 1 "Heat Waves" "Glass Animals"; sleep 2
process_song 2 "As It Was" "Harry Styles"; sleep 2
process_song 3 "Stay" "The Kid Laroi and Justin Bieber"; sleep 2
process_song 4 "Easy on Me" "Adele"; sleep 2
process_song 5 "Shivers" "Ed Sheeran"; sleep 2
process_song 6 "First Class" "Jack Harlow"; sleep 2
process_song 7 "Big Energy" "Latto"; sleep 2
process_song 8 "Ghost" "Justin Bieber"; sleep 2
process_song 9 "Super Gremlin" "Kodak Black"; sleep 2
process_song 10 "Cold Heart (Pnau Remix)" "Elton John and Dua Lipa"; sleep 2

process_song 11 "Wait for U" "Future featuring Drake and Tems"; sleep 2
process_song 12 "About Damn Time" "Lizzo"; sleep 2
process_song 13 "Bad Habits" "Ed Sheeran"; sleep 2
process_song 14 "Thats What I Want" "Lil Nas X"; sleep 2
process_song 15 "Enemy" "Imagine Dragons and JID"; sleep 2
process_song 16 "Industry Baby" "Lil Nas X and Jack Harlow"; sleep 2
process_song 17 "ABCDEFU" "Gayle"; sleep 2
process_song 18 "Need to Know" "Doja Cat"; sleep 2
process_song 19 "Wasted on You" "Morgan Wallen"; sleep 2
process_song 20 "Me Porto Bonito" "Bad Bunny and Chencho Corleone"; sleep 2

process_song 21 "Woman" "Doja Cat"; sleep 2
process_song 22 "Tití Me Preguntó" "Bad Bunny"; sleep 2
process_song 23 "Running Up That Hill (A Deal with God)" "Kate Bush"; sleep 2
process_song 24 "We Don't Talk About Bruno" "Carolina Gaitán, Mauro Castillo, Adassa, Rhenzy Feliz, Diane Guerrero, Stephanie Beatriz and the Encanto cast"; sleep 2
process_song 25 "Late Night Talking" "Harry Styles"; sleep 2
process_song 26 "I Like You (A Happier Song)" "Post Malone featuring Doja Cat"; sleep 2
process_song 27 "You Proof" "Morgan Wallen"; sleep 2
process_song 28 "Bad Habit" "Steve Lacy"; sleep 2
process_song 29 "Sunroof" "Nicky Youre and Dazy"; sleep 2
process_song 30 "One Right Now" "Post Malone and the Weeknd"; sleep 2

process_song 31 "Good 4 U" "Olivia Rodrigo"; sleep 2
process_song 32 "Numb Little Bug" "Em Beihold"; sleep 2
process_song 33 "Jimmy Cooks" "Drake featuring 21 Savage"; sleep 2
process_song 34 "'Til You Can't" "Cody Johnson"; sleep 2
process_song 35 "Fancy Like" "Walker Hayes"; sleep 2
process_song 36 "The Kind of Love We Make" "Luke Combs"; sleep 2
process_song 37 "I Ain't Worried" "OneRepublic"; sleep 2
process_song 38 "Break My Soul" "Beyoncé"; sleep 2
process_song 39 "Something in the Orange" "Zach Bryan"; sleep 2
process_song 40 "Save Your Tears" "The Weeknd and Ariana Grande"; sleep 2

process_song 41 "Smokin out the Window" "Silk Sonic (Bruno Mars and Anderson .Paak)"; sleep 2
process_song 42 "Levitating" "Dua Lipa"; sleep 2
process_song 43 "In a Minute" "Lil Baby"; sleep 2
process_song 44 "Moscow Mule" "Bad Bunny"; sleep 2
process_song 45 "You Right" "Doja Cat and the Weeknd"; sleep 2
process_song 46 "She Had Me at Heads Carolina" "Cole Swindell"; sleep 2
process_song 47 "Vegas" "Doja Cat"; sleep 2
process_song 48 "Pushin P" "Gunna and Future featuring Young Thug"; sleep 2
process_song 49 "Buy Dirt" "Jordan Davis and Luke Bryan"; sleep 2
process_song 50 "I Hate U" "SZA"; sleep 2

process_song 51 "Boyfriend" "Dove Cameron"; sleep 2
process_song 52 "Glimpse of Us" "Joji"; sleep 2
process_song 53 "Surface Pressure" "Jessica Darrow"; sleep 2
process_song 54 "Fall in Love" "Bailey Zimmerman"; sleep 2
process_song 55 "Love Nwantiti (Ah Ah Ah)" "CKay"; sleep 2
process_song 56 "Super Freaky Girl" "Nicki Minaj"; sleep 2
process_song 57 "Hrs and Hrs" "Muni Long"; sleep 2
process_song 58 "Sand in My Boots" "Morgan Wallen"; sleep 2
process_song 59 "Mamiii" "Becky G and Karol G"; sleep 2
process_song 60 "Knife Talk" "Drake featuring 21 Savage and Project Pat"; sleep 2

process_song 61 "AA" "Walker Hayes"; sleep 2
process_song 62 "Sweetest Pie" "Megan Thee Stallion and Dua Lipa"; sleep 2
process_song 63 "Provenza" "Karol G"; sleep 2
process_song 64 "Essence" "Wizkid featuring Justin Bieber and Tems"; sleep 2
process_song 65 "All I Want for Christmas Is You" "Mariah Carey"; sleep 2
process_song 66 "Bam Bam" "Camila Cabello featuring Ed Sheeran"; sleep 2
process_song 67 "5 Foot 9" "Tyler Hubbard"; sleep 2
process_song 68 "Get Into It (Yuh)" "Doja Cat"; sleep 2
process_song 69 "Efecto" "Bad Bunny"; sleep 2
process_song 70 "Rock and a Hard Place" "Bailey Zimmerman"; sleep 2

process_song 71 "Doin' This" "Luke Combs"; sleep 2
process_song 72 "Oh My God" "Adele"; sleep 2
process_song 73 "Better Days" "Neiked, Mae Muller and Polo G"; sleep 2
process_song 74 "Meet Me at Our Spot" "The Anxiety: Willow and Tyler Cole"; sleep 2
process_song 75 "Fingers Crossed" "Lauren Spencer-Smith"

echo ""
echo "======================================================================"
echo "📊 FINAL SUMMARY"
echo "======================================================================"
echo "✅ Successfully added: $SUCCESSFUL"
echo "⚠️  No video found: $NO_VIDEO"
echo "❌ Errors: $ERRORS"
echo "======================================================================"
