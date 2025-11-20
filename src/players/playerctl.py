import re

from players.player import Player
from utils.os_utils import run_cmd


class Playerctl(Player):
    def get_all_players(self):
        players, error = run_cmd("playerctl", "-l")
        if error == "No players found":
            return {}
        statuses = {}
        for player in players.splitlines():
            status, error = run_cmd("playerctl", "status", "-p", player)
            statuses[player] = status.strip()
        return statuses

    def currently_playing(self) -> dict:
        metadata = self._get_metadata() or {}
        return {
            "status": "Playing",  # TODO: no
            "duration": metadata.get("mpris:length", 0),
            "position": metadata.get("mpris:position", 0),
            "title": metadata.get("xesam:title", ""),
            "album": metadata.get("xesam:album", ""),
            "artist": metadata.get("xesam:albumArtist", ""),
            "trackNumber": metadata.get("xesam:trackNumber", 0),
            "artUrl": metadata.get("mpris:artUrl"),
        }

    def currently_playing_players(self):
        player_statuses = self.get_all_players()
        for player, status in player_statuses.items():
            if status == "Playing":
                return player
        return None

    def _get_metadata(self) -> dict:
        current_player = self.currently_playing_players()
        if not current_player:
            return {}
        metadata, error = run_cmd("playerctl", "metadata", "-p", current_player)
        metadata = [re.split(r"\s{1,}", line) for line in metadata.splitlines()]
        metadata = {key: " ".join(value) for [_, key, *value] in metadata}
        return metadata
