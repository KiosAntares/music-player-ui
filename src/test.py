import pygame
# from pygame.locals import *

from windows.app import App
from windows.window import Window   
from windows.grid import Grid
from windows.textwindow import TextWindow
from windows.imagewindow import ImageWindow, FitModes

from utils.colors import Colors

from effects.rounded_borders import CMRoundedBorders
from effects.linear_gradient import LinearGradient

from players.playerctl import Playerctl
from players.jellyfin_player import Jellyfin

import datetime
import dotenv
import os


# MARGINS and GAPS:
# TOP, BOTTOM, LEFT, RIGHT

# SIZE/COORDINATE order:
# Width (x), Height (y)

# Grid slots:
# Column, Row









class Square(Window):
    bg = (100, 100, 100)

    def on_render(self):
        self._surface.fill(self.bg)
        super().on_render()


if __name__ == "__main__":
    dotenv.load_dotenv()
    pygame.font.init()
    mainfont = pygame.font.SysFont("CaskaydiaCove Nerd Font", 30)

    app = App((640, 480))

    # player = Playerctl()
    player = Jellyfin(os.getenv('JELLYFIN_URL'), os.getenv('JELLYFIN_API_KEY'), '')


    test_gradient = LinearGradient((600,400), (10,10,10), (100,40,40))

    grid = Grid(
        app, (20, 20), (600, 400), (2, 2), margin=(10, 10, 10, 10), gap=(5, 5, 5, 5)
    )
    slots = grid.get_usable_slot_size()

 #         art_source = self.player.currently_playing().get("artUrl")

    artwork = ImageWindow(grid, None, slots, None, FitModes.CENTERED_FILL)
    artwork.img_update_fn = lambda: player.currently_playing().get("artUrl")
    artwork.clipping_masks.append(
        CMRoundedBorders(slots, 20)
    )

    tw, th = slots
    subgrid = Grid(
        grid, None, (tw * 2, th), (1, 2), margin=(10, 10, 10, 10), gap=(5, 5, 5, 5)
    )

    sgBRCM = CMRoundedBorders(subgrid.get_usable_slot_size(), 10)

    text1 = TextWindow(
        subgrid,
        None,
        subgrid.get_usable_slot_size(),
        "Now playing:",
        mainfont,
        Colors.fg,
        margin=(20, 20, 5, 5),
        background = test_gradient
    )

    text2 = TextWindow(
        subgrid,
        None,
        subgrid.get_usable_slot_size(),
        "",
        mainfont,
        Colors.fg,
        margin=(20, 20, 5, 5),
        background=test_gradient
    )

    text1.clipping_masks.append(sgBRCM)
    text2.clipping_masks.append(sgBRCM)

    text2.text_update_fn = lambda: (lambda: f"{player.currently_playing().get('title')}")() #on {player.currently_playing().get('device')}")()

    # subq = Square(subgrid, None, subgrid.get_usable_slot_size())
    # subq.bg = (0,255,0)
    # subq2 = Square(subgrid, None, subgrid.get_usable_slot_size())
    # subq2.bg = (255,0,0)
    # sq3 = Square(grid, None, slots)

    textML = TextWindow(
        grid,
        (0, 0),
        slots,
        "This is \na multiline text",
        mainfont,
        Colors.fg,
        margin=(5, 5, 5, 5),
    )

    # textML.text_update_fn = lambda: str(datetime.datetime.now())

    grid.register_child(artwork, slot=(0, 0))
    grid.register_child(subgrid, slot=(0, 1))
    grid.register_child(textML, slot=(1, 0))
    subgrid.register_child(text1, slot=(0, 0))
    subgrid.register_child(text2, slot=(0, 1))
    app.run()
