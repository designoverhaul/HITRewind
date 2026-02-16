#!/usr/bin/env python3
"""
Create SpotifyTop100 table in Airtable
"""

import requests
import json

# Airtable configuration
API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
BASE_ID = "appxCBIOkiJEZiph7"

# Airtable Meta API endpoint for creating tables
CREATE_TABLE_URL = f"https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# Table definition
table_definition = {
    "name": "SpotifyTop100",
    "description": "Current week's top songs based on Spotify Global streams. Updated weekly.",
    "fields": [
        {
            "name": "title",
            "type": "singleLineText",
            "description": "Song title"
        },
        {
            "name": "url",
            "type": "singleLineText",
            "description": "YouTube video URL"
        },
        {
            "name": "Rank",
            "type": "number",
            "description": "Spotify chart position (1-100)",
            "options": {
                "precision": 0
            }
        },
        {
            "name": "artistName",
            "type": "singleLineText",
            "description": "Primary artist name"
        }
    ]
}

def create_table():
    """Create the SpotifyTop100 table"""
    print("Creating SpotifyTop100 table...")
    print(f"URL: {CREATE_TABLE_URL}")

    response = requests.post(
        CREATE_TABLE_URL,
        headers=headers,
        json=table_definition
    )

    if response.status_code == 200:
        result = response.json()
        print(f"✅ Table created successfully!")
        print(f"   Table ID: {result.get('id')}")
        print(f"   Table Name: {result.get('name')}")
        print("\n⚠️  NOTE: You need to manually add the formula fields in Airtable UI:")
        print('   - videoImage: "https://img.youtube.com/vi/" & MID({url}, 33, 11) & "/mqdefault.jpg"')
        print('   - videoImage0: "https://img.youtube.com/vi/" & MID({url}, 33, 11) & "/0.jpg"')
        return result
    else:
        print(f"❌ Error creating table: {response.status_code}")
        print(f"   Response: {response.text}")
        return None

if __name__ == "__main__":
    create_table()
