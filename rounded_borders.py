from clipping_mask import ClippingMask
from colors import Colors
import pygame

class CMRoundedBorders(ClippingMask):
    def __init__(self, size, border_radius):
        super().__init__(size)
        self.border_radius = border_radius
        self._rendered_mask = pygame.Surface(size, pygame.SRCALPHA | pygame.HWACCEL)
        

    def render_mask(self):
        if self.should_rerender():
            print("DEBUG: Rendering rounded CM")
            self._rendered_mask.fill(Colors.empty)
            self._last_rendered_state['border_radius'] = self.border_radius
            pygame.draw.rect(self._rendered_mask,
                        (255,255,255),
                        (0,0,*self.size),
                        border_radius=self.border_radius)
        return self._rendered_mask

    def should_rerender(self):
        if not self._last_rendered_state:
            return True
        if self.border_radius != self._last_rendered_state.get('border_radius'):
            return True
        return False 


