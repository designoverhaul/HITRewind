#!/bin/bash

AIRTABLE_API_KEY="pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID="appxCBIOkiJEZiph7"
AIRTABLE_TABLE_NAME="MTvVideosNEW"
AIRTABLE_URL="https://api.airtable.com/v0/${AIRTABLE_BASE_ID}/${AIRTABLE_TABLE_NAME}"

# Function to add a batch of records (max 10)
add_batch() {
    local json_data="$1"
    
    curl -s -X POST "$AIRTABLE_URL" \
        -H "Authorization: Bearer ${AIRTABLE_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$json_data"
}

# Parse results.txt and create batches
batch_count=0
record_count=0
batch_records=""

while IFS='|' read -r status rank title artist url; do
    if [[ "$status" == "FOUND" ]]; then
        # Escape quotes in title and artist for JSON
        title=$(echo "$title" | sed 's/"/\\"/g')
        artist=$(echo "$artist" | sed 's/"/\\"/g')
        
        if [ $record_count -eq 0 ]; then
            batch_records="{"
            batch_records+="\"fields\": {"
            batch_records+="\"title\": \"$title\","
            batch_records+="\"url\": \"$url\","
            batch_records+="\"Rank\": $rank,"
            batch_records+="\"artistName\": \"$artist\","
            batch_records+="\"Year\": \"2023\""
            batch_records+="}}"
        else
            batch_records+=",{"
            batch_records+="\"fields\": {"
            batch_records+="\"title\": \"$title\","
            batch_records+="\"url\": \"$url\","
            batch_records+="\"Rank\": $rank,"
            batch_records+="\"artistName\": \"$artist\","
            batch_records+="\"Year\": \"2023\""
            batch_records+="}}"
        fi
        
        record_count=$((record_count + 1))
        
        # Send batch when we hit 10 records
        if [ $record_count -eq 10 ]; then
            batch_count=$((batch_count + 1))
            json_payload="{\"records\": [$batch_records]}"
            echo "Sending batch $batch_count (records $(($batch_count * 10 - 9))-$(($batch_count * 10)))..."
            response=$(add_batch "$json_payload")
            
            # Check for errors
            if echo "$response" | grep -q "error"; then
                echo "Error in batch $batch_count:"
                echo "$response" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin), indent=2))"
            else
                echo "✅ Batch $batch_count added successfully"
            fi
            
            # Reset for next batch
            record_count=0
            batch_records=""
            sleep 0.5
        fi
    fi
done < results.txt

# Send remaining records if any
if [ $record_count -gt 0 ]; then
    batch_count=$((batch_count + 1))
    json_payload="{\"records\": [$batch_records]}"
    echo "Sending final batch $batch_count (records $(($batch_count * 10 - 9 - (10 - record_count)))-$(($batch_count * 10 - (10 - record_count))))..."
    response=$(add_batch "$json_payload")
    
    if echo "$response" | grep -q "error"; then
        echo "Error in batch $batch_count:"
        echo "$response" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin), indent=2))"
    else
        echo "✅ Batch $batch_count added successfully"
    fi
fi

echo ""
echo "Done! Added records from $batch_count batches to Airtable."
