from windows.window import Window
from utils.vec2 import multiply_2vec, scale_2vec, sub_2vec
import pygame


class ProgressBar(Window):
    def __init__(
        self,
        parent,
        position,
        size,
        progress,
        bar_surface,
        bar_size_prop = (1,1),
        margin = (0, 0, 0, 0),
        background = None
    ):
        super().__init__(parent, position, size, margin=margin, background=background)
        self.progress = progress
        self.bar_surface = bar_surface
        self.progress_update_fn = None
        self._last_rendered_progress = None
        self.bar_clipping_masks = []
        self.bar_size_prop = bar_size_prop

    def get_bar_size(self):
        return multiply_2vec(self.get_available_size(),self.bar_size_prop)

    def should_rerender(self):
        return self._rerender or self.progress != self._last_rendered_progress

    def on_loop(self):
        # if we have a text update function, we run it
        if self.progress_update_fn:
            try:
                self.progress = self.progress_update_fn()
            except Exception as e:
                print(f"DEBUG: failed to run progress function: {e}")
        super().on_loop()

    def on_render(self):
        if self.should_rerender():
            self._parent._rerender = True
            super().pre_render()
            scaled_bar_pos = multiply_2vec(
                scale_2vec(sub_2vec((1,1), self.bar_size_prop), 0.5),
                self.get_available_size()
            )
            pos = self.rel_position(scaled_bar_pos)
            bar_size = multiply_2vec(self.get_bar_size(), (self.progress, 1))
            blitsurf = pygame.transform.smoothscale(self.bar_surface.get_surface(), bar_size)
            for clipping_mask in self.bar_clipping_masks:
                clipping_mask.apply(blitsurf)
            self._surface.blit(blitsurf, pos)
            self._last_rendered_progress = self.progress
            super().on_render()
