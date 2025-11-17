import subprocess
import re

class PlayerStatus:
    #TODO: consider extracting
    @staticmethod
    def run_cmd(*cmd):
        res = subprocess.run(cmd, capture_output=True, text=True)
        out = res.stdout
        err = res.stderr
        # code = res.returncode

        if err: 
            print(f"[ERROR] Command {cmd} failed with error {err}")
            exit(1)

        return out

    @staticmethod
    def get_all_players():
        players = PlayerStatus.run_cmd('playerctl', '-l').splitlines()
        statuses = {}
        for player in players:
            status = PlayerStatus.run_cmd('playerctl', 'status', '-p', player).strip()
            statuses[player] = status
        return statuses

    @staticmethod
    def currently_playing():
        player_statuses = PlayerStatus.get_all_players()
        for player, status in player_statuses.items():
            if status == 'Playing':
                return player
        return None

    @staticmethod
    def get_full_status():
        current_player = PlayerStatus.currently_playing()
        if not current_player:
            return None
        metadata = PlayerStatus.run_cmd('playerctl', 'metadata', '-p', current_player)
        metadata = [re.split(r'\s{1,}', line) for line in metadata.splitlines()]
        metadata = {key: value for [_,key,value,*_] in metadata}
        return metadata

    @staticmethod
    def get_art_url(metadata):
        if not metadata:
            return None
        return metadata['mpris:artUrl']
    
    @staticmethod
    def get_song_title(metadata):
        if not metadata:
            return None
        return metadata['xesam:title']

    




