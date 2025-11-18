import requests
import dotenv

from player import Player
from os_utils import format_time

class Jellyfin(Player):
    def __init__(self, url, apikey, devicename):
        self.url = url
        self.apikey = apikey
        self.devicename = devicename
        self.header = {
            'X-Emby-Token': self.apikey
        }

    def make_request(self, endpoint):
        url = f"{self.url}/{endpoint}"
        response = requests.get(url, headers = self.header)
        response.raise_for_status()
        return response.json()

    def _get_sessions(self):
        sessions = self.make_request('Sessions')
        out = []
        for session in sessions:
            item = session.get('NowPlayingItem')
            if not item or item.get('MediaType') != 'Audio':
                continue
            out.append(session)
        return out


    def _get_metadata(self):
        sessions = []
        for session in self._get_sessions():
            play_state = session.get('PlayState', {})
            item = session.get('NowPlayingItem', {})

            device_name = session.get('DeviceName')
            status = 'Paused' if play_state.get('IsPaused') else 'Playing'
            # Uses .NET ticks (100 nanoseconds)
            elapsed = play_state.get('PositionTicks', 0) / 10_000_000
            length = item.get('RunTimeTicks', 0) / 10_000_000
            
            title = item.get('Name')
            artist = item.get('AlbumArtist')
            album = item.get('Album')

            album_id = item.get('AlbumId')
            album_tag = item.get('AlbumPrimaryImageTag')
            track_id = item.get('Id')
            track_tag = item.get('ImageTags',{}).get('Primary')

            if track_id and track_tag:
                cover_url = f"{self.url}/Items/{track_id}/Images/Primary"
            elif album_id and album_tag:
                cover_url = f"{self.url}/Items/{album_id}/Images/Primary"
            else:
                cover_url = None

            track_number = item.get('IndexNumber')
            media_streams = item.get('MediaStreams')
            audio_stream = next(stream for stream in media_streams if stream['Type'] == 'Audio')
            sessions.append({
            'status': status,
            'device': device_name,
            'duration': length,
            'position': elapsed,
            'title': title,
            'artist': artist,
            'album': album,
            'trackNumber': track_number,
            'artUrl': cover_url,
            'codec': audio_stream['DisplayTitle'],
            'sampleRate': audio_stream['SampleRate'],
            'bitDepth': audio_stream['BitDepth'],
            })
        return sessions


    def currently_playing(self) -> dict:
        if self._get_metadata(): 
            return self._get_metadata()[0] 
        else: {}
