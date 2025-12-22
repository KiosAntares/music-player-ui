from enum import nonmember
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
from utils.os_utils import run_cmd

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



class MainDisplay(Window):
    def __init__(self, parent, position, size):
       super().__init__(parent, position, size)
       self.grid = FlexiGrid(
           self, 
           (20,20),       # Position 
           (1880,440),    # Size
           (0.4,0.4,0.2), # Grid proportion (width)
           (1,),          # Grid proportions (height)
           gap=(5,5,5,5)
       )

       self.grid_textinfo = FlexiGrid(
           self.grid,
           None,
           self.grid.get_usable_slot_size((1,0)),
           (1,),
           (0.25, 0.12, 0.12, 0.25, 0.06, 0.1),
           gap = (2,2,2,2)
       )

       self.artwork = ImageWindow(
           self.grid,
           None,
           self.grid.get_usable_slot_size((0,0)),
           None,
           FitModes.CENTERED_FILL)
       self.artwork.img_update_fn = lambda: self.player.currently_playing().get("artUrl")
       self.clipping_masks.append(CMRoundedBorders(self.artwork.size, 20))

       self.progressbar = ProgressBar(
           self.grid_textinfo,
           None,
           self.grid_textinfo.get_usable_slot_size((0,4)),
           0,
           test_gradient,
           bar_size_prop=(0.9,0.4),
        )

       self.progressbar.progress_update_fn = lambda: float(self.player.currently_playing().get("position"))/float(self.player.currently_playing().get("duration"))
       
       self.text_codecInfo = TextWindow(
           self.grid_textinfo,
           None,
           self.grid_textinfo.get_usable_slot_size((0,5)),
           "TEST",
           mainfont,
           Colors.fg,
           margin=(5,5,5,5)
       )

       self.test_title = TextWindow(
            self.grid_textinfo,
            None,
            self.grid_textinfo.get_usable_slot_size((0,0)),
            "",
            mainfont,
            Colors.fg,
            margin=(5,5,5,5)
        )

       self.test_album = TextWindow(
            self.grid_textinfo,
            None,
            self.grid_textinfo.get_usable_slot_size((0,2)),
            "",
            mainfont,
            Colors.fg,
            margin=(5,5,5,5)
        )

       self.test_artist = TextWindow(
            self.grid_textinfo,
            None,
            self.grid_textinfo.get_usable_slot_size((0,1)),
            "",
            mainfont,
            Colors.fg,
            margin=(5,5,5,5)
        )

       self.test_playpause = TextWindow(
            self.grid_textinfo,
            None,
            self.grid_textinfo.get_usable_slot_size((0,3)),
            "♛",
            mainfont,
            Colors.fg,
            margin=(5,5,5,5)
        )


       self.test_title.text_update_fn = lambda: (lambda: f"{self.player.currently_playing().get('title')}")()
       self.test_artist.text_update_fn = lambda: (lambda: f"{self.player.currently_playing().get('artist')}")()
       self.test_album.text_update_fn = lambda: (lambda: f"{self.player.currently_playing().get('album')}")()

       self.s2 = Square(self.grid,None,self.grid.get_usable_slot_size((1,0)))
       self.s3 = Square(self.grid,None,self.grid.get_usable_slot_size((2,0)))

       self.grid.register_child(self.artwork, (0,0))
       self.grid.register_child(self.grid_textinfo, (1,0))
       self.grid.register_child(self.s3, (2,0))
       self.grid_textinfo.register_child(self.progressbar, (0,4))
       self.grid_textinfo.register_child(self.text_codecInfo, (0,5))
       self.grid_textinfo.register_child(self.test_title, (0,0))
       self.grid_textinfo.register_child(self.test_artist, (0,1))
       self.grid_textinfo.register_child(self.test_album, (0,2))
       self.grid_textinfo.register_child(self.test_playpause, (0,3))

       # app.register_keypress(pygame.K_f, (lambda: grid.toggle_enabled()))


class Menu(Window):
    def __init__(self, parent, position, size):
       super().__init__(parent, position, size)
       self.grid = Grid(
           self,    # parent
           (20,20), # Position
           (1880, 440), # size
           (1, 5), # Grid size col, row
           gap=(5,5,5,5)
       )
       self._enabled = False

       self.poweroff = TextWindow(
           self.grid,
           None,
           self.grid.get_usable_slot_size(),
           "POWER OFF",
           mainfont,
           Colors.fg,
           margin=(5,5,5,5)
       )
       self.grid.register_child(self.poweroff, (0,1))

    def toggle_enabled(self):
        self.grid._rerender = True
        return super().toggle_enabled()

    def on_event(self, event):
        super().on_event(event)
        if event.type == pygame.KEYDOWN:
            match event.key:
                case pygame.K_e:
                    print("Running shutdown!")
                    run_cmd("sudo", "poweroff")


class Square(Window):
    bg = (100, 100, 100)
    rerender = True
    
    def should_rerender(self):
        return self._rerender

    def on_render(self):
        self._surface.fill(self.bg)
        self._rerender = False
        super().on_render()


test_gradient = LinearGradient((600,400), (10,10,10), (100,40,40))
if __name__ == "__main__":
    debug_println("Init...")
    dotenv.load_dotenv()
    pygame.font.init()
    mainfont = pygame.font.SysFont("CaskaydiaCove Nerd Font", 24)
    # mainfont = pygame.font.Font("Cyberbit.ttf", 24)
    print(hasattr(mainfont,"UCS4"))

    app = App((1920, 480))
    player = Jellyfin(os.getenv('JELLYFIN_URL'), os.getenv('JELLYFIN_API_KEY'), '')

    main_display = MainDisplay(app, (0,0), (1920, 480))
    main_display.player = player

   
    menu = Menu(app, (0,0), (192,480))

    def toggle_display_menu():
        main_display.toggle_enabled()
        menu.toggle_enabled()
        

    app.register_keypress(pygame.K_f, (lambda _: toggle_display_menu()))
    app.register_keypress(pygame.K_e, menu.on_event)
    # grid._enabled = False
    app.run()
