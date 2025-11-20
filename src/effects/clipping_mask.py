import pygame

class ClippingMask():
    def __init__(self, size):
        self.size = size
        self._last_rendered_state = {}
        self._rendered_mask = None

    def render_mask(self):
        pass

    def should_rerender(self):
        return False 

    def apply(self, surface):
        surface.blit(self.render_mask(), (0,0), None, pygame.BLEND_RGBA_MIN)

