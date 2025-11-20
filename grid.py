from window import Window


class Grid(Window):
    def __init__(
        self, parent, position, size, gridsize, margin=(0, 0, 0, 0), gap=(0, 0), background=None
    ):
        super().__init__(parent, position, size, background=background)
        self.margin = margin
        self.gap = gap
        self._cols, self._rows = gridsize

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
        width, height = self.get_available_size()
        slot_width_col = width // self._cols
        slot_height_row = height // self._rows
        return slot_width_col, slot_height_row

    def get_usable_slot_size(self):
        # Here we take gaps into consideration to inform the children
        slot_width_col, slot_height_row = self.get_slot_size()
        # Gap TOP, BOTTOM, LEFT, RIGHT
        gt, gb, gl, gr = self.gap
        effective_col = slot_width_col - gl - gr
        effective_row = slot_height_row - gt - gb
        return (effective_col, effective_row)

    def on_loop(self):
        # Step all existing children
        for i, col in enumerate(self._children):
            for j, child in enumerate(col):
                if not child:
                    continue
                child.on_loop()
        if self.should_rerender():
            self._parent._rerender = True
            self._parent.DEBUG_whoasked.append(self)

    def on_render(self):
        super().pre_render()
        if not self.should_rerender():
            return
        self._parent._rerender = True
        print(f"[DEBUG] I'm rerendering! ({type(self)}) because of {self.DEBUG_whoasked}")
        # We only need "origin" gaps for calculations now
        # We allow children to overlap and don't bind them here!
        gt, _, gl, _ = self.gap
        slot_width_col, slot_height_row = self.get_slot_size()
        for i, col in enumerate(self._children):
            for j, child in enumerate(col):
                if not child:
                    continue
                # We get position relative to in-window (accounting for margins)
                slot_h, slot_w = self.rel_position(
                    (slot_width_col * i, slot_height_row * j)
                )
                # We now include the gaps
                c_pos_h = slot_h + gt
                c_pos_w = slot_w + gl
                child.on_render()
                # We render the child on top
                self._surface.blit(child._surface, (c_pos_h, c_pos_w))
        self._rerender = False
