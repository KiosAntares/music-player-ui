import os

def debug_println(text):
    if 'DEBUG' in os.environ:
        print("[DEBUG] " + text)

def error_println(text):
    print("[ERROR] " + text)
