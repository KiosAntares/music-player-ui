# music-player-ui
All new rewrite in vala/gtk to save resources and (my) development time.

## Building

### Debian

Install dependencies:

    sudo apt install $(cat packages.txt)

Then build:

    meson setup build
    ninja -C build

### NixOS

    nix-shell
    meson setup build
    ninja -C build