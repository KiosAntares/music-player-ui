import subprocess
import re

class PlayerStatus:
    #TODO: consider extracting
    @staticmethod
    def run_cmd(*cmd):
        res = subprocess.run(cmd, capture_output=True, text=True)
        out = res.stdout
        err = res.stderr
        code = res.returncode

        # if err: 
        #     print(f"[ERROR] Command {cmd} failed with error {err}: code {code}")
        #     exit(1)

        return out, err

    @staticmethod
    def get_all_players():
        players, error = PlayerStatus.run_cmd('playerctl', '-l')
        if error == 'No players found':
            return {}
        statuses = {}
        for player in players.splitlines():
            status, error = PlayerStatus.run_cmd('playerctl', 'status', '-p', player)
            statuses[player] = status.strip()
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
        metadata, error = PlayerStatus.run_cmd('playerctl', 'metadata', '-p', current_player)
        metadata = [re.split(r'\s{1,}', line) for line in metadata.splitlines()]
        metadata = {key: ' '.join(value) for [_,key,*value] in metadata}
        return metadata

    @staticmethod
    def get_art_url(metadata):
        if not metadata or 'mpris:artUrl' not in metadata:
            return None
        return metadata['mpris:artUrl'] 
    
    @staticmethod
    def get_song_title(metadata):
        if not metadata:
            return None
        return metadata['xesam:title']

    




