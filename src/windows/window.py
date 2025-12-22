import pygame
from utils.colors import Colors
from utils.vec2 import add_2vec, sub_2vec
from utils.debug import debug_println

class Window:
    def __init__(self, parent, position, size, margin=(0, 0, 0, 0), 
                 background = None):
        self._parent = parent
        self.position = position
        self.size = size
        self.margin = margin
        self.background = background
        self.clipping_masks = []

        self._enabled = True
        self._surface = pygame.Surface(self.size, pygame.SRCALPHA | pygame.HWSURFACE)
        self._children = []
        # Usually, children register themselves for a better experience
        # This excludes grids.
        self._parent.register_child(self)
        self._rerender = False
        self.DEBUG_whoasked = set()


    def register_child(self, child):
        self._children.append(child)

    # We get the net size, accounting for margins
    def get_available_size(self):
        mt, mb, ml, mr = self.margin
        return sub_2vec(self.size, (ml + mr, mt + mb))

    # Position relative to effective space (accounting for margins)
    def rel_position(self, position):
        (*origin, _, _) = self.margin
        return add_2vec(position, origin)

    def disable(self):
        self._enabled = False
        self.pre_render()
        self._parent._rerender = True

    def enable(self):
        self._enabled = True

    def on_event(self, event):
        if not self._enabled:
            return
        pass

    def toggle_enabled(self):
        print("Toggling enabled status")
        self._enabled = not self._enabled
        self.pre_render()
        self._parent._rerender = True

    # By default, windows forward update events to their children
    def on_loop(self):
        if not self._enabled:
            return
        for child in self._children:
            child.on_loop()
        if self.should_rerender():
            self._parent._rerender = True
            self._rerender = True
            self._parent.DEBUG_whoasked.add(self)

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
        if not self._enabled:
            self._rerender = False
            return
        if not self.should_rerender():
            return
        debug_println(f"I'm rerendering! ({type(self)}) because of {self.DEBUG_whoasked}")
        for child in self._children:
            if not child.should_rerender():
                continue
            child.on_render()
            self._surface.blit(child._surface, self.rel_position(child.position))

        for mask in self.clipping_masks:
            mask.apply(self._surface)
        self._rerender = False
        self.DEBUG_whoasked = set()
