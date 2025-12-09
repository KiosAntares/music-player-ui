import pygame
# from pygame.locals import *

from windows.app import App
from windows.window import Window   
from windows.grid import Grid
from windows.textwindow import TextWindow
from windows.imagewindow import ImageWindow, FitModes
from windows.progressbar import ProgressBar
from windows.flexigrid import FlexiGrid

from utils.colors import Colors
from utils.debug import debug_println

from effects.rounded_borders import CMRoundedBorders
from effects.linear_gradient import LinearGradient

from players.playerctl import Playerctl
from players.jellyfin_player import Jellyfin

import datetime
import dotenv
import os# MARGINS and GAPS:
# TOP, BOTTOM, LEFT, RIGHT

# SIZE/COORDINATE order:
# Width (x), Height (y)

# Grid slots:
# Column, Row








class Square(Window):
    bg = (100, 100, 100)
    rerender = True
    
    def should_rerender(self):
        return self._rerender

    def on_render(self):
        self._surface.fill(self.bg)
        self._rerender = False
        super().on_render()


if __name__ == "__main__":
    debug_println("Init...")
    dotenv.load_dotenv()
    pygame.font.init()
    mainfont = pygame.font.SysFont("CaskaydiaCove Nerd Font", 24)
    # mainfont = pygame.font.Font("Cyberbit.ttf", 24)
    print(hasattr(mainfont,"UCS4"))

    app = App((1920, 480))
    player = Jellyfin(os.getenv('JELLYFIN_URL'), os.getenv('JELLYFIN_API_KEY'), '')

    test_gradient = LinearGradient((600,400), (10,10,10), (100,40,40))
    grid = FlexiGrid(
        app,
        (20,20),
        (1880,440),
        (0.4,0.4,0.2),
        (1,),
        gap=(5,5,5,5)
    )

    grid_textinfo = FlexiGrid(
        grid, 
        None, 
        grid.get_usable_slot_size((0,0)),
        (1,),
        (0.25, 0.12, 0.12, 0.25, 0.06, 0.10),
        gap = (2,2,2,2)
    )

    artwork = ImageWindow(grid, 
                          None,
                          grid.get_usable_slot_size((0,0)), 
                          None, 
                          FitModes.CENTERED_FILL)
    artwork.img_update_fn = lambda: player.currently_playing().get("artUrl")
    artwork.clipping_masks.append(
        CMRoundedBorders(artwork.size, 20)
    )

    progressbar = ProgressBar(
        grid_textinfo,
        None,
        grid_textinfo.get_usable_slot_size((0,4)),
        0,
        test_gradient,
        bar_size_prop=(0.9,0.4),
    )

    progressbar.progress_update_fn = lambda: float(player.currently_playing().get("position"))/float(player.currently_playing().get("duration"))


    test_codecinfo = TextWindow(
        grid_textinfo,
        None,
        grid_textinfo.get_usable_slot_size((0,5)),
        "TEST",
        mainfont,
        Colors.fg,
        margin=(5,5,5,5)
    )

    test_title = TextWindow(
        grid_textinfo,
        None,
        grid_textinfo.get_usable_slot_size((0,0)),
        "",
        mainfont,
        Colors.fg,
        margin=(5,5,5,5)
    )

    test_album = TextWindow(
        grid_textinfo,
        None,
        grid_textinfo.get_usable_slot_size((0,2)),
        "",
        mainfont,
        Colors.fg,
        margin=(5,5,5,5)
    )

    test_artist = TextWindow(
        grid_textinfo,
        None,
        grid_textinfo.get_usable_slot_size((0,1)),
        "",
        mainfont,
        Colors.fg,
        margin=(5,5,5,5)
    )

    test_playpause = TextWindow(
        grid_textinfo,
        None,
        grid_textinfo.get_usable_slot_size((0,3)),
        "♛",
        mainfont,
        Colors.fg,
        margin=(5,5,5,5)
    )


    test_title.text_update_fn = lambda: (lambda: f"{player.currently_playing().get('title')}")()
    test_artist.text_update_fn = lambda: (lambda: f"{player.currently_playing().get('artist')}")()
    test_album.text_update_fn = lambda: (lambda: f"{player.currently_playing().get('album')}")()


    # s1 = Square(grid,None,grid.get_usable_slot_size((0,0)))
    s2 = Square(grid,None,grid.get_usable_slot_size((1,0)))
    s3 = Square(grid,None,grid.get_usable_slot_size((2,0)))
    # s4 = Square(grid,None,grid.get_usable_slot_size((3,0)))

    grid.register_child(artwork, (0,0))
    grid.register_child(grid_textinfo, (1,0))
    # grid.register_child(s2, (1,0))
    grid.register_child(s3, (2,0))
    # grid.register_child(s4, (3,0))
    # grid_coverprog.register_child(artwork, (0,0))
    grid_textinfo.register_child(progressbar, (0,4))
    grid_textinfo.register_child(test_codecinfo, (0,5))
    grid_textinfo.register_child(test_title, (0,0))
    grid_textinfo.register_child(test_artist, (0,1))
    grid_textinfo.register_child(test_album, (0,2))
    grid_textinfo.register_child(test_playpause, (0,3))

    
    app.run()
