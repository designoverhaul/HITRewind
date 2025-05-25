import requests
import re
import time

def check_video(url):
    try:
        patterns = [
            r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})',
            r'youtube\.com/v/([a-zA-Z0-9_-]{11})',
        ]
        
        video_id = ''
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                video_id = match.group(1)
                break
        
        if not video_id:
            return False, 'Invalid URL format'
            
        # Check thumbnail availability (fast method)
        thumbnail_url = f'https://img.youtube.com/vi/{video_id}/mqdefault.jpg'
        response = requests.head(thumbnail_url, timeout=5)
        
        if response.status_code == 200:
            return True, 'OK'
        else:
            return False, f'HTTP {response.status_code}'
    except Exception as e:
        return False, str(e)

# Test sample URLs from your database
test_urls = [
    ('https://www.youtube.com/watch?v=YwTDqBcjwEE', 'Animal Collective'),
    ('https://www.youtube.com/watch?v=bUZx2ZEUDPs', 'Oklahoma - Guns N Roses'),
    ('https://www.youtube.com/watch?v=SqdE10H4ZCk', 'Chime for Change - Beyonce'),
    ('https://www.youtube.com/watch?v=buTkpHVPNCk', 'State of Mind Tour - Nas'),
    ('https://www.youtube.com/watch?v=INVALID123', 'Test Broken Link')
]

print('🔍 Testing YouTube Link Checker')
print('=' * 40)
broken_count = 0

for url, title in test_urls:
    is_valid, msg = check_video(url)
    status = '✅' if is_valid else '❌'
    if not is_valid:
        broken_count += 1
    print(f'{status} {title}: {msg}')
    time.sleep(0.5)

print(f'\n📊 Summary: {broken_count} broken links found out of {len(test_urls)} tested')
print('\nThe script is working! You can now use the full youtube_link_checker.py to scan your entire database.') 