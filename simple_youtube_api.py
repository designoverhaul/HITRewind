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
            'no_warnings': True,
            'extract_flat': 'discard_in_playlist', # Don't extract playlist items if a playlist URL is passed
            'dump_single_json': True # Dump info as a single JSON line
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            
            video_url = None
            hls_url = None

            if info.get('manifest_url') and info['manifest_url'].endswith('.m3u8'):
                hls_url = info['manifest_url']
                video_url = hls_url
            
            if not video_url and info.get('url'):
                video_url = info['url']

            if not hls_url and 'formats' in info:
                for fmt in reversed(info['formats']):
                    if fmt.get('url') and fmt.get('vcodec') != 'none' and fmt.get('acodec') != 'none':
                        if fmt.get('protocol') == 'm3u8_native' or fmt.get('url', '').endswith('.m3u8'):
                            hls_url = fmt['url']
                            if not video_url:
                                video_url = hls_url
                            break 
                        elif not video_url:
                             video_url = fmt['url']
            
            if not video_url and hls_url:
                 video_url = hls_url

            response = {
                'success': True,
                'video_id': video_id,
                'title': info.get('title', 'Unknown'),
                'duration': info.get('duration', 0),
                'uploader': info.get('uploader', 'Unknown'),
                'video_url': video_url,
                'hls_url': hls_url,
                'width': info.get('width'),
                'height': info.get('height')
            }
            
            print(f"✅ Successfully extracted: {info.get('title', 'Unknown')}")
            return jsonify(response)
            
    except yt_dlp.utils.DownloadError as e:
        error_msg = str(e)
        print(f"❌ DownloadError for {video_id}: {error_msg}")
        if "video is unavailable" in error_msg.lower() or \
           "private video" in error_msg.lower() or \
           "video is not available in your country" in error_msg.lower() or \
           "This video has been removed" in error_msg.lower():
            return jsonify({
                'success': False, 
                'error': 'Video is unavailable or private.', 
                'video_id': video_id, 
                'original_error': error_msg
            }), 404
        else:
            return jsonify({
                'success': False, 
                'error': 'Failed to process video.', 
                'video_id': video_id, 
                'original_error': error_msg
            }), 500
            
    except Exception as e:
        error_msg = str(e)
        print(f"❌ Generic error extracting {video_id}: {error_msg}")
        return jsonify({
            'success': False,
            'error': 'An unexpected error occurred.',
            'video_id': video_id,
            'original_error': error_msg
        }), 500

@app.route('/test')
def test():
    """Simple test endpoint"""
    return jsonify({
        'status': 'OK',
        'message': 'YouTube extraction API is running',
        'version': '1.0.1'
    })

@app.route('/')
def home():
    """API documentation"""
    return """
    <h1>Simple YouTube Extraction API (yt-dlp)</h1>
    <p>Endpoints:</p>
    <ul>
        <li><code>/test</code> - Test if API is running</li>
        <li><code>/extract/&lt;video_id&gt;</code> - Extract video URL for YouTube video ID</li>
    </ul>
    <p>Example: <a href="/extract/dQw4w9WgXcQ">/extract/dQw4w9WgXcQ</a></p>
    <p><em>Note: This is a simple server for a specific application need.</em></p>
    """

if __name__ == '__main__':
    print("🚀 Starting YouTube extraction API (yt-dlp based)...")
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5001
    print(f"📱 Your Apple TV app can now call: http://localhost:{port}/extract/VIDEO_ID")
    print(f"🧪 Test in browser: http://localhost:{port}/extract/dQw4w9WgXcQ")
    app.run(host='0.0.0.0', port=port, debug=True) 