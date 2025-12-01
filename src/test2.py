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

    app = App((1920, 480))
    player = Jellyfin(os.getenv('JELLYFIN_URL'), os.getenv('JELLYFIN_API_KEY'), '')

    test_gradient = LinearGradient((600,400), (10,10,10), (100,40,40))
    grid = FlexiGrid(
        app,
        (20,20),
        (1880,440),
        (0.35,0.15,0.35,0.15),
        (1,),
        gap=(5,5,5,5)
    )

    grid_coverprog = FlexiGrid(
        grid, 
        None, 
        grid.get_usable_slot_size((0,0)),
        (1,),
        (0.85, 0.15),
        gap = (5,5,5,5)
    )

    artwork = ImageWindow(grid, 
                          None,
                          grid_coverprog.get_usable_slot_size((0,0)), 
                          None, 
                          FitModes.CENTERED_FILL)
    artwork.img_update_fn = lambda: player.currently_playing().get("artUrl")
    artwork.clipping_masks.append(
        CMRoundedBorders(artwork.size, 20)
    )

    progressbar = ProgressBar(
        grid_coverprog,
        None,
        grid_coverprog.get_usable_slot_size((0,1)),
        0,
        test_gradient,
        bar_size_prop=(0.8,0.2),
    )

    progressbar.progress_update_fn = lambda: float(player.currently_playing().get("position"))/float(player.currently_playing().get("duration"))



    # s1 = Square(grid,None,grid.get_usable_slot_size((0,0)))
    s2 = Square(grid,None,grid.get_usable_slot_size((1,0)))
    s3 = Square(grid,None,grid.get_usable_slot_size((2,0)))
    s4 = Square(grid,None,grid.get_usable_slot_size((3,0)))

    grid.register_child(grid_coverprog, (0,0))
    grid.register_child(s2, (1,0))
    grid.register_child(s3, (2,0))
    grid.register_child(s4, (3,0))
    grid_coverprog.register_child(artwork, (0,0))
    grid_coverprog.register_child(progressbar, (0,1))

    
    app.run()
