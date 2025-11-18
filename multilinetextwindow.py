from textwindow import TextWindow
import pygame

class MultiLineTextWindow(TextWindow):
    def _render_text(self):
        self._rendered_text = pygame.Surface(self.size, pygame.SRCALPHA | pygame.HWSURFACE)
        lines = self.text.splitlines()
        _, height = self.font.size("I")
        line_space = height * 0.2 # self.interline
        for i, line in enumerate(lines):
            linepos = (0, height * i + line_space * i)
            rendered_line = self.font.render(line, True, self.fontColor)
            self._rendered_text.blit(rendered_line, linepos)
        self._last_rendered_text = self.text
