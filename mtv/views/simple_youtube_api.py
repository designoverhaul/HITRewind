#!/usr/bin/env python3
"""
Simple YouTube URL extraction API using yt-dlp
Test server for Apple TV app
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import yt_dlp
import sys
import json

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests from iOS app

@app.route('/extract/<video_id>')
def extract_video(video_id):
    """Extract video info and stream URLs for a YouTube video ID"""
    try:
        url = f'https://www.youtube.com/watch?v={video_id}'
        
        # Configure yt-dlp options
        ydl_opts = {
            'format': 'best',  # Get best quality
            'quiet': True,     # Reduce output
            'no_warnings': True
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Extract info without downloading
            info = ydl.extract_info(url, download=False)
            
            # Find best video URL for Apple TV
            video_url = None
            hls_url = None
            
            # Look for HLS manifest (best for Apple TV)
            if 'manifest_url' in info and info['manifest_url']:
                hls_url = info['manifest_url']
                video_url = hls_url
            
            # Fallback to direct video URL
            if not video_url and 'url' in info:
                video_url = info['url']
            
            # Try formats array as backup
            if not video_url and 'formats' in info:
                for fmt in info['formats']:
                    if fmt.get('url') and 'video' in fmt.get('vcodec', ''):
                        video_url = fmt['url']
                        break
            
            response = {
                'success': True,
                'video_id': video_id,
                'title': info.get('title', 'Unknown'),
                'duration': info.get('duration', 0),
                'uploader': info.get('uploader', 'Unknown'),
                'video_url': video_url,
                'hls_url': hls_url,
                'format_note': info.get('format_note', ''),
                'width': info.get('width'),
                'height': info.get('height')
            }
            
            print(f"✅ Successfully extracted: {info.get('title', 'Unknown')}")
            return jsonify(response)
            
    except Exception as e:
        error_msg = str(e)
        print(f"❌ Error extracting {video_id}: {error_msg}")
        
        return jsonify({
            'success': False,
            'error': error_msg,
            'video_id': video_id
        }), 500

@app.route('/test')
def test():
    """Simple test endpoint"""
    return jsonify({
        'status': 'OK',
        'message': 'YouTube extraction API is running',
        'version': 'test-v1'
    })

@app.route('/')
def home():
    """API documentation"""
    return """
    <h1>Simple YouTube Extraction API</h1>
    <p>Endpoints:</p>
    <ul>
        <li><code>/test</code> - Test if API is running</li>
        <li><code>/extract/&lt;video_id&gt;</code> - Extract video URL for YouTube video ID</li>
    </ul>
    <p>Example: <a href="/extract/dQw4w9WgXcQ">/extract/dQw4w9WgXcQ</a></p>
    """

if __name__ == '__main__':
    print("🚀 Starting YouTube extraction API...")
    print("📱 Your Apple TV app can now call: http://localhost:5001/extract/VIDEO_ID")
    print("🧪 Test in browser: http://localhost:5001/extract/dQw4w9WgXcQ")
    
    app.run(host='0.0.0.0', port=5001, debug=True) 