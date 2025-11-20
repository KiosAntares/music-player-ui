from window import Window


class TextWindow(Window):
    def __init__(
        self,
        parent,
        position,
        size,
        text,
        font,
        fontColor,
        justify=None,
        margin=(0, 0, 0, 0),
        background=None
    ):
        super().__init__(parent, position, size, margin=margin, background=background)
        self.text = text
        self.font = font
        self.justify = justify
        self.fontColor = fontColor

        self.text_update_fn = None
        self._last_rendered_text = None

    def _render_text(self):
        self.DEBUG_whoasked = [self]
        # first render of the text. If it never changes, we never need to render it again!
        self._rendered_text = self.font.render(
            self.text, True, self.fontColor, wraplength=self.size[0]
        )
        self._last_rendered_text = self.text

    def should_rerender(self):
        return self._rerender or self.text != self._last_rendered_text

    def on_loop(self):
        # if we have a text update function, we run it
        if self.text_update_fn:
            try:
                self.text = self.text_update_fn()
            except Exception as e:
                print(f"DEBUG: failed to run text update function: {e}")
        super().on_loop()

    def on_render(self):
        if self.should_rerender():
            self._parent._rerender = True
            super().pre_render()
            # Only render the text if it has changed
            self._render_text()
            adj_position = self.rel_position((0, 0))
            self._surface.blit(self._rendered_text, adj_position)
            self._rerender = True
        super().on_render()
