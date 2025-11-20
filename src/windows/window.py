import pygame
from utils.colors import Colors


class Window:
    def __init__(self, parent, position, size, margin=(0, 0, 0, 0), 
                 background = None):
        self._parent = parent
        self.position = position
        self.size = size
        self.margin = margin
        self.background = background
        self.clipping_masks = []

        self._surface = pygame.Surface(self.size, pygame.SRCALPHA | pygame.HWSURFACE)
        self._children = []
        # Usually, children register themselves for a better experience
        # This excludes grids.
        self._parent.register_child(self)
        self._rerender = False
        self.DEBUG_whoasked = []

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
        if self.should_rerender():
            self._parent._rerender = True
            self._parent.DEBUG_whoasked.append(self)

    def should_rerender(self):
        return self._rerender

    def pre_render(self):
        if not self.should_rerender():
            return
        self._surface.fill(Colors.empty)
        if self.background:
            self._surface.blit(self.background.get_surface(), (0,0))

    # By default, windows delagate the rendering to the children, and then place
    # them at the requested position on their surface.
    def on_render(self):
        # print(f"Should I ({type(self)}) be rendering? {self._rerender}")
        if not self.should_rerender():
            return
        # self._surface.fill(Colors.empty)
        print(f"[DEBUG] I'm rerendering! ({type(self)}) because of {self.DEBUG_whoasked}")
        for child in self._children:
            if not child.should_rerender():
                continue
            child.on_render()
            self._surface.blit(child._surface, self.rel_position(child.position))

        for mask in self.clipping_masks:
            mask.apply(self._surface)
        self._rerender = False
        self.DEBUG_whoasked = []
