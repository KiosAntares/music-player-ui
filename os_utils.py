import subprocess

def run_cmd(*cmd):
        res = subprocess.run(cmd, capture_output=True, text=True)
        out = res.stdout
        err = res.stderr
        code = res.returncode
        return out, err
