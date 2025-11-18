import requests
import os
from dotenv import load_dotenv

load_dotenv()

JELLYFIN_URL = os.getenv("JELLYFIN_URL")
JELLYFIN_API_KEY = os.getenv("JELLYFIN_API_KEY")

headers = {
    "X-Emby-Token": JELLYFIN_API_KEY
}

def get_sessions():
    url = f"{JELLYFIN_URL}/Sessions"
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()

def extract_song_metadata(now_playing, base_url):
    """Return a dictionary with common music metadata + album art URL."""
    
    # Basic metadata
    title = now_playing.get("Name")
    artists = now_playing.get("Artists", [])
    album = now_playing.get("Album")
    album_artist = now_playing.get("AlbumArtist")
    
    album_id = now_playing.get("AlbumId")
    album_tag = now_playing.get("AlbumPrimaryImageTag")
    
    # Track-specific image (rare)
    track_image_tag = now_playing.get("ImageTags", {}).get("Primary")
    track_id = now_playing.get("Id")
    
    # Prefer album art → fall back to track art
    if album_id and album_tag:
        cover_url = f"{base_url}/Items/{album_id}/Images/Primary?tag={album_tag}"
    elif track_id and track_image_tag:
        cover_url = f"{base_url}/Items/{track_id}/Images/Primary?tag={track_image_tag}"
    else:
        cover_url = None
    
    # Optional metadata fields
    track_number = now_playing.get("IndexNumber")
    disc_number = now_playing.get("ParentIndexNumber")
    duration_ms = now_playing.get("RunTimeTicks", 0) / 10000  # ticks → ms
    
    media_streams = now_playing.get("MediaStreams")
    audio_stream = [stream for stream in media_streams if stream["Type"] == 'Audio'][0]

    return {
        "title": title,
        "artists": artists,
        "album": album,
        "album_artist": album_artist,
        "album_id": album_id,
        "track_id": track_id,
        "track_number": track_number,
        "disc_number": disc_number,
        "duration_ms": duration_ms,
        "cover_url": cover_url,
        "codec": audio_stream['DisplayTitle'],
        "sample_rate": audio_stream['SampleRate'],
        "bit_depth": audio_stream['BitDepth'],
    }

def pretty_print_dict_aligned(d):
    # Get longest key for alignment
    width = max(len(k) for k in d.keys())
    for key, value in d.items():
        print(f"{key:<{width}} : {value}")

sessions = get_sessions()

for s in sessions:
    item = s.get("NowPlayingItem")
    if not item or item.get("MediaType") != "Audio":
        continue

    print(s.get('DeviceName'))
    metadata = extract_song_metadata(item, JELLYFIN_URL)
    pretty_print_dict_aligned(metadata)