import requests
import re

def check_video(url):
    try:
        pattern = r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})'
        match = re.search(pattern, url)
        if not match:
            return False, 'Invalid URL'
        video_id = match.group(1)
        thumbnail_url = f'https://img.youtube.com/vi/{video_id}/mqdefault.jpg'
        response = requests.head(thumbnail_url, timeout=5)
        return response.status_code == 200, f'HTTP {response.status_code}'
    except Exception as e:
        return False, str(e)

url = 'https://www.youtube.com/watch?v=oTAA4GlcY5s'
is_valid, msg = check_video(url)
status = '✅' if is_valid else '❌'
print(f'{status} NY State of Mind Tour - New Jersey: {msg}') 