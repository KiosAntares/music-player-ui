import pygame
from colors import Colors

class Window:
    def __init__(self, parent, position, size, margin = (0,0,0,0)):
        self._parent = parent
        self.position = position
        self.size = size
        self.margin = margin

        self._surface = pygame.Surface(self.size, pygame.SRCALPHA)
        self._children = []
        # Usually, children register themselves for a better experience
        # This excludes grids.
        self._parent.register_child(self)

    def register_child(self, child):
        self._children.append(child)

    # We get the net size, accounting for margins
    def get_available_size(self):
        width, height = self.size
        mt, mb, ml, mr = self.margin
        return (width - ml - mr, height - mt - mb)

    # Position relative to effective space (accounting for margins)
    def rel_position(self, position):
        mt, ml, _, _ = self.margin
        w, h = position
        return (w + ml, h + mt)

    # By default, windows forward update events to their children
    def on_loop(self):
        for child in self._children:
            child.on_loop()
        pass

    # By default, windows delagate the rendering to the children, and then place
    # them at the requested position on their surface.
    def on_render(self):
        for child in self._children:
            child.on_render()
            self._surface.blit(child._surface, self.rel_position(child.position))
        pass
