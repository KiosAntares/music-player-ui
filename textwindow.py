from window import Window
from colors import Colors
import pygame


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
    ):
        super().__init__(parent, position, size, margin=margin)
        self.text = text
        self.font = font
        self.justify = justify
        self.fontColor = fontColor

        self.text_update_fn = None
        self._last_rendered_text = None

    def _render_text(self):
        # first render of the text. If it never changes, we never need to render it again!
        self._rendered_text = self.font.render(
            self.text, True, self.fontColor, wraplength=self.size[0]
        )
        self._last_rendered_text = self.text

    def on_loop(self):
        super().on_loop()
        # if we have a text update function, we run it
        if self.text_update_fn:
            self.text = self.text_update_fn()

    def on_render(self):
        if self.text != self._last_rendered_text:
            super().pre_render()
            # Only render the text if it has changed
            self._render_text()
            adj_position = self.rel_position((0, 0))
            self._surface.blit(self._rendered_text, adj_position)
