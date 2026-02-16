#!/bin/bash

API_KEY="pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
BASE_ID="appxCBIOkiJEZiph7"
TABLE_ID="tblNwqwVyflL8hNDy"
ENDPOINT="https://api.airtable.com/v0/${BASE_ID}/${TABLE_ID}"

# Function to extract artist name (before featuring)
extract_artist_name() {
    local artist="$1"
    # Remove everything after "featuring", "feat.", "feat", "ft.", "ft", or "with"
    echo "$artist" | sed -E 's/ featuring.*//i; s/ feat\..*//i; s/ feat .*//i; s/ ft\..*//i; s/ ft .*//i; s/ with .*//i'
}

# Batch 1: Songs 1-10
echo "Adding Batch 1 (Songs 1-10)..."
curl -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "records": [
      {"fields": {"title": "How You Remind Me", "url": "https://www.youtube.com/watch?v=Aiay8I5IPB8", "Rank": 1, "artistName": "Nickelback", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Foolish", "url": "https://www.youtube.com/watch?v=gUPrnu3BEU8", "Rank": 2, "artistName": "Ashanti", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Hot in Herre", "url": "https://www.youtube.com/watch?v=GeZZr_p6vB8", "Rank": 3, "artistName": "Nelly", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Dilemma", "url": "https://www.youtube.com/watch?v=WwJm5hnWv6E", "Rank": 4, "artistName": "Nelly", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Wherever You Will Go", "url": "https://www.youtube.com/watch?v=iAP9AF6DCu4", "Rank": 5, "artistName": "The Calling", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "A Thousand Miles", "url": "https://www.youtube.com/watch?v=Cwkej79U3ek", "Rank": 6, "artistName": "Vanessa Carlton", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "In the End", "url": "https://www.youtube.com/watch?v=eVTXPUF4Oz4", "Rank": 7, "artistName": "Linkin Park", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "What'\''s Luv?", "url": "https://www.youtube.com/watch?v=VpvyG2NrS1Y", "Rank": 8, "artistName": "Fat Joe", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "U Got It Bad", "url": "https://www.youtube.com/watch?v=o3IWTfcks4k", "Rank": 9, "artistName": "Usher", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Blurry", "url": "https://www.youtube.com/watch?v=xJJsoquu70o", "Rank": 10, "artistName": "Puddle of Mudd", "Year": "2002", "artistID": ""}}
    ]
  }'
echo -e "\n\n"
sleep 1

# Batch 2: Songs 11-20
echo "Adding Batch 2 (Songs 11-20)..."
curl -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "records": [
      {"fields": {"title": "Complicated", "url": "https://www.youtube.com/watch?v=5NPBIwQyPWE", "Rank": 11, "artistName": "Avril Lavigne", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Always on Time", "url": "https://www.youtube.com/watch?v=0tcDXJfAFVw", "Rank": 12, "artistName": "Ja Rule", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Ain'\''t It Funny (Murder Remix)", "url": "https://www.youtube.com/watch?v=tr-H8dR0HLo", "Rank": 13, "artistName": "Jennifer Lopez", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "The Middle", "url": "https://www.youtube.com/watch?v=oKsxPW6i3pM", "Rank": 14, "artistName": "Jimmy Eat World", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "I Need a Girl (Part One)", "url": "https://www.youtube.com/watch?v=zXYb1OMhwBA", "Rank": 15, "artistName": "P. Diddy", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "U Don'\''t Have to Call", "url": "https://www.youtube.com/watch?v=3AszPTJXIgM", "Rank": 16, "artistName": "Usher", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Family Affair", "url": "https://www.youtube.com/watch?v=znlFu_lemsU", "Rank": 17, "artistName": "Mary J. Blige", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "I Need a Girl (Part Two)", "url": "https://www.youtube.com/watch?v=zGUttrXgzLI", "Rank": 18, "artistName": "P. Diddy", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Gangsta Lovin'\''", "url": "https://www.youtube.com/watch?v=aNI8XFEAyI0", "Rank": 19, "artistName": "Eve", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "My Sacrifice", "url": "https://www.youtube.com/watch?v=O-fyNgHdmLI", "Rank": 20, "artistName": "Creed", "Year": "2002", "artistID": ""}}
    ]
  }'
echo -e "\n\n"
sleep 1

# Batch 3: Songs 21-30
echo "Adding Batch 3 (Songs 21-30)..."
curl -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "records": [
      {"fields": {"title": "Without Me", "url": "https://www.youtube.com/watch?v=YVkUvmDQ3HY", "Rank": 21, "artistName": "Eminem", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Hero", "url": "https://www.youtube.com/watch?v=koJlIGDImiU", "Rank": 22, "artistName": "Enrique Iglesias", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "All You Wanted", "url": "https://www.youtube.com/watch?v=Cbo2n2MzxxE", "Rank": 23, "artistName": "Michelle Branch", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Get the Party Started", "url": "https://www.youtube.com/watch?v=mW1dbiD_zDk", "Rank": 24, "artistName": "Pink", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Hero", "url": "https://www.youtube.com/watch?v=Vuw8SRDNEDI", "Rank": 25, "artistName": "Chad Kroeger", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Wasting My Time", "url": "https://www.youtube.com/watch?v=UAocvKHUidg", "Rank": 26, "artistName": "Default", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "One Last Breath", "url": "https://www.youtube.com/watch?v=qnkuBUAwfe0", "Rank": 27, "artistName": "Creed", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Whenever, Wherever", "url": "https://www.youtube.com/watch?v=weRHyjj34ZE", "Rank": 28, "artistName": "Shakira", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "I'\''m Gonna Be Alright", "url": "https://www.youtube.com/watch?v=LzX23qVqyJg", "Rank": 29, "artistName": "Jennifer Lopez", "Year": "2002", "artistID": ""}},
      {"fields": {"title": "Oh Boy", "url": "https://www.youtube.com/watch?v=a6kwOYBVOgA", "Rank": 30, "artistName": "Cam'\''ron", "Year": "2002", "artistID": ""}}
    ]
  }'
echo -e "\n\n"
sleep 1

# Continue with remaining batches...
echo "Script completed first 3 batches. Run remaining batches separately to avoid rate limits."
