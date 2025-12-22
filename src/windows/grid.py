from utils.vec2 import add_2vec, divide_2vec_quant, multiply_2vec, sub_2vec
from windows.window import Window
from utils.debug import debug_println


class Grid(Window):
    def __init__(
        self, parent, position, size, gridsize, margin=(0, 0, 0, 0), gap=(0, 0), background=None
    ):
        super().__init__(parent, position, size, background=background)
        self.margin = margin
        self.gap = gap
        self._cols, self._rows = gridsize
        self.gridsize = gridsize
        

        # setup a 2D array of null children
        for _ in range(self._cols):
            col = [None for _ in range(self._rows)]
            self._children.append(col)

    def register_child(self, child, slot=None):
        # This is for interface-compatibility with the components that expect
        # To register themselves instead of delegating. We don't register and wait.
        # We don't register and wait
        if not slot:
            return
        col, row = slot
        self._children[col][row] = child

    def get_slot_size(self):
        # calculate the size of the slot. The slot ignores gaps, and delegates
        # caring about slots to other functions
        return divide_2vec_quant(self.get_available_size(), self.gridsize) 

    def get_usable_slot_size(self):
        # Here we take gaps into consideration to inform the children
        # Gap TOP, BOTTOM, LEFT, RIGHT
        gt, gb, gl, gr = self.gap
        return sub_2vec(self.get_slot_size(), (gl + gr, gt + gb))

    def on_loop(self):
        if not self._enabled:
            return
        # Step all existing children
        for i, col in enumerate(self._children):
            for j, child in enumerate(col):
                if not child:
                    continue
                child.on_loop()
        if self.should_rerender():
            self._parent._rerender = True
            self._parent.DEBUG_whoasked.add(self)

    def on_render(self):
        if not self._enabled:
            self._rerender = False
            return 
        super().pre_render()
        if not self.should_rerender():
            return
        self._parent._rerender = True
        debug_println(f"I'm rerendering! ({type(self)}) because of {self.DEBUG_whoasked}")
        # We only need "origin" gaps for calculations now
        # We allow children to overlap and don't bind them here!
        gt, _, gl, _ = self.gap
        for i, col in enumerate(self._children):
            for j, child in enumerate(col):
                if not child:
                    continue
                # We get position relative to in-window (accounting for margins)
                child_position = self.rel_position(
                    multiply_2vec(self.get_slot_size(), (i,j))
                )
                # We now include the gaps
                child.on_render()
                # We render the child on top
                self._surface.blit(child._surface, 
                                   add_2vec(child_position, (gt, gl))
                                   # (c_pos_h, c_pos_w)
                                  )
        self._rerender = False
