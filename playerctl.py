import re

from player import Player
from os_utils import run_cmd

class Playerctl(Player):
    @staticmethod
    def get_all_players():
        players, error = run_cmd('playerctl', '-l')
        if error == 'No players found':
            return {}
        statuses = {}
        for player in players.splitlines():
            status, error = run_cmd('playerctl', 'status', '-p', player)
            statuses[player] = status.strip()
        return statuses

    @staticmethod 
    def currently_playing() -> dict:
        metadata = Playerctl._get_metadata() or {}
        return {
            'status': 'Playing', # TODO: no
            'duration': metadata.get('mpris:length', 0),
            'position': metadata.get('mpris:position', 0),
            'title': metadata.get('xesam:title', ''),
            'album': metadata.get('xesam:album', ''),
            'artist': metadata.get('xesam:albumArtist', ''),
            'trackNumber': metadata.get('xesam:trackNumber', 0),
            'artUrl': metadata.get('mpris:artUrl')
        }

    @staticmethod
    def currently_playing_players():
        player_statuses = Playerctl.get_all_players()
        for player, status in player_statuses.items():
            if status == 'Playing':
                return player
        return None

    @staticmethod
    def _get_metadata() -> dict:
        current_player = Playerctl.currently_playing_players()
        if not current_player:
            return {}
        metadata, error = run_cmd('playerctl', 'metadata', '-p', current_player)
        metadata = [re.split(r'\s{1,}', line) for line in metadata.splitlines()]
        metadata = {key: ' '.join(value) for [_,key,*value] in metadata}
        return metadata

