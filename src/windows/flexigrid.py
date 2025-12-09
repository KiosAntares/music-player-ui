from utils.vec2 import add_2vec, divide_2vec_quant, multiply_2vec, sub_2vec
from windows.window import Window
from utils.debug import debug_println, error_println


class FlexiGrid(Window):
    def __init__(
        self, parent, position, size, grid_dimensions_w, grid_dimensions_h, margin=(0, 0, 0, 0), gap=(0, 0), background=None
    ):
        super().__init__(parent, position, size, background=background)
        self.margin = margin
        self.gap = gap
        if sum(grid_dimensions_h) > 1 or sum(grid_dimensions_w) > 1:
            error_println("Total scales should not sum to a number larger than 1")
            exit()
        self.grid_dimensions_w = grid_dimensions_w
        self.grid_dimensions_h = grid_dimensions_h

        self.gridsize = (len(self.grid_dimensions_w), len(self.grid_dimensions_h))
        self._rerender = True

        # setup a 2D array of null children
        for _ in self.grid_dimensions_w:
            col = [None for _ in self.grid_dimensions_h]
            self._children.append(col)

    def register_child(self, child, slot=None):
        # This is for interface-compatibility with the components that expect
        # To register themselves instead of delegating. We don't register and wait.
        # We don't register and wait
        if not slot:
            return
        col, row = slot
        self._children[col][row] = child

    def get_slot_size(self, slot):
        c, r = slot
        return multiply_2vec(self.get_available_size(), (self.grid_dimensions_w[c], self.grid_dimensions_h[r]))

    def get_usable_slot_size(self, slot):
        # Here we take gaps into consideration to inform the children
        # Gap TOP, BOTTOM, LEFT, RIGHT
        gt, gb, gl, gr = self.gap
        return sub_2vec(self.get_slot_size(slot), (gl + gr, gt + gb))

    def on_loop(self):
        # Step all existing children
        for i, col in enumerate(self._children):
            for j, child in enumerate(col):
                if not child:
                    continue
                child.on_loop()
                # debug_println(f"Running loop for child {child}")
        if self.should_rerender():
            self._parent._rerender = True
            self._parent.DEBUG_whoasked.add(self)

    def on_render(self):
        super().pre_render()
        if not self.should_rerender():
            return
        self._parent._rerender = True
        debug_println(f"I'm rerendering! ({type(self)}) because of {self.DEBUG_whoasked}")
        # We only need "origin" gaps for calculations now
        # We allow children to overlap and don't bind them here!
        gt, _, gl, _ = self.gap

        w_so_far = 0
        for i, col in enumerate(self._children):
            h_so_far = 0
            lastw = 0
            for j, child in enumerate(col):
                # We get position relative to in-window (accounting for margins)
                child_position = self.rel_position((w_so_far, h_so_far))
                lastw, childh = self.get_slot_size((i,j))
                h_so_far += childh
                # We now include the gaps
                if not child:
                    continue
                child.on_render()
                # We render the child on top
                self._surface.blit(child._surface, 
                                   add_2vec(child_position, (gt, gl))
                                   # (c_pos_h, c_pos_w)
                                  )
            w_so_far += lastw
        self._rerender = False
