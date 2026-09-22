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

## Audio visualizer

The audio display is native GTK4/Vala — no `cava`, no terminal emulator, no
child process. It records the default sink's monitor through pipewire-pulse, so
it shows whatever is actually coming out of the box: Jellyfin playback and a
phone streaming in over Bluetooth A2DP both work without special-casing.

Five styles, cycled with `g` (which also jumps to the page from anywhere) or
from *Display -> Visualizer Style* in the menu:

| Style  | What it draws                                        |
|--------|------------------------------------------------------|
| Bars   | Classic spectrum bars with falling peak markers      |
| Mirror | Bars grown symmetrically from the centre line        |
| Wave   | The spectrum as one smooth filled curve              |
| Scope  | Oscilloscope of the raw waveform                     |
| Radial | Bands radiating from a centre ring                   |

Bars and Mirror suit the 1920x480 panel best; Radial is a circle, so it leaves
the sides of a wide display empty by design.

Everything is tunable from `src/config.vala` (`VIS_*`): band count, frequency
range, colours, attack/decay, peak gravity and the frame cap. Analysis only runs
while the page is visible, since GtkStack unmaps the pages you cannot see.

If the wrong thing gets visualised — this box runs EasyEffects, so the default
sink may not be the one you mean — set `VIS_MONITOR_SOURCE` to a specific source
from `pactl list short sources`.
