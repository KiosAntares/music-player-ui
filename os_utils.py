import subprocess


def run_cmd(*cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    out = res.stdout
    err = res.stderr
    code = res.returncode
    return out, err


def format_time(seconds: float) -> str:
    seconds = int(seconds)
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60

    if h > 0:
        return f"{h:d}:{m:02d}:{s:02d}"  # e.g. 1:05:12
    else:
        return f"{m:02d}:{s:02d}"  # e.g. 03:45


def pretty_print_dict_aligned(d):
    # Get longest key for alignment
    width = max(len(k) for k in d.keys())
    for key, value in d.items():
        print(f"{key:<{width}} : {value}")
