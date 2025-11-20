import pygame
from effects.graphic_surface import GraphicSurface


class LinearGradient(GraphicSurface):
    def __init__(self, size, color1, color2, direction='V'):
        super().__init__(size)
        self.color1 = color1
        self.color2 = color2
        self.direction = direction
        self._last_rendered_state = {}

    def should_rerender(self):
        if not self._last_rendered_state:
            return True
        if self.color1 != self._last_rendered_state.get('color1') or\
           self.color2 != self._last_rendered_state.get('color2') or\
           self.direction != self._last_rendered_state.get('direction'):
            return True
        return False

    def render(self):
        print("[DEBUG] Rendering gradient")
        self._last_rendered_state['color1'] = self.color1
        self._last_rendered_state['color2'] = self.color2
        self._last_rendered_state['direction'] = self.direction
        base = pygame.Surface((2,2))
        if self.direction == 'V':
            pygame.draw.line(base, self.color1, (0,0), (1,0))
            pygame.draw.line(base, self.color2, (0,1), (1,1))
        else:
            pygame.draw.line(base, self.color1, (0,0), (0,1))
            pygame.draw.line(base, self.color2, (1,0), (1,1))
        self._surface = pygame.transform.smoothscale(base, self._size)


