class GraphicSurface():
    def __init__(self, size):
        self._size = size
        self._last_rendered_state = None
        self._surface = None

    def should_rerender(self):
        return False

    def get_surface(self):
        if self.should_rerender():
            self.render()
        return self._surface
    
    def render(self):
        pass
