from utils.debug import error_println
from utils.vec2 import divide_2vec, quant_2vec, scale_2vec, sub_2vec
from windows.window import Window
from utils.os_utils import get_image
import pygame
from enum import Enum

class FitModes(Enum):
    STRETCH = 1
    FILL = 2
    CROP = 3
    CENTERED_FILL = 4


class ImageWindow(Window):
    def __init__(
        self,
        parent,
        position,
        size,
        img_source,
        fit_mode = FitModes.STRETCH,
        margin = (0, 0, 0, 0),
        background = None
    ):
        super().__init__(parent, position, size, margin=margin, background=background)
        self.img_source = img_source
        self.img_update_fn = None
        self._last_rendered_img = None
        self._rendered_img = None
        self.fit_mode = fit_mode

    def _render_img(self):
        self.DEBUG_whoasked = [self]
        if not self.img_source:
            return
        self._rendered_img = get_image(self.img_source)
        if self.fit_mode == FitModes.STRETCH:
            self._rendered_img = pygame.transform.smoothscale(self._rendered_img, self.get_available_size())
        elif self.fit_mode == FitModes.CROP:
            pass 
        elif self.fit_mode == FitModes.FILL or self.fit_mode == FitModes.CENTERED_FILL:
            ratios = divide_2vec(self.get_available_size(), self._rendered_img.size)
            self._rendered_img = pygame.transform.smoothscale_by(self._rendered_img,min(ratios))
        self._last_rendered_img = self.img_source

    def should_rerender(self):
        return self._rerender or not self._last_rendered_img or self.img_source != self._last_rendered_img

    def on_loop(self):
        # if we have a text update function, we run it
        if self.img_update_fn:
            try:
                self.img_source = self.img_update_fn()
            except Exception as e:
                error_println(f"Failed to run image update function: {e}")
        super().on_loop()

    def on_render(self):
        if self.should_rerender():
            self._parent._rerender = True
            super().pre_render()
            self._render_img()
            if not self._rendered_img:
                self._rerender = False
                return
            if self.fit_mode == FitModes.CENTERED_FILL:
                centered = scale_2vec(
                    sub_2vec(self.get_available_size(), self._rendered_img.size),
                    0.5
                )
                adj_position = self.rel_position(quant_2vec(centered))
            else:
                adj_position = self.rel_position((0, 0))
            self._surface.blit(self._rendered_img, adj_position)
            self._rerender = False
        super().on_render()
