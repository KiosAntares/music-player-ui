import pygame
from windows.window import Window
from utils.colors import Colors


# The specialization of App is particularly intense
class App(Window):
    def __init__(self, size):
        self._running = True
        self._surface = None
        self.size = self.width, self.height = size
        self.framerate = 1
        self._children = []
        self._clock = None
        self.margin = (0, 0, 0, 0)
        self.clipping_masks = []
        self._rerender = True
        self._parent = self
        self.DEBUG_whoasked = []

    def init(self):
        pygame.init()
        self._clock = pygame.time.Clock()
        self._surface = pygame.display.set_mode(self.size, pygame.HWSURFACE)
        self._running = True

    # App is the only window to receive events and pass to the business logic
    def on_event(self, event):
        if event.type == pygame.QUIT:
            self._running = False

    def on_loop(self):
        super().on_loop()
        pass

    # We can't defer render anymore, so we render all children and then execute the buffer flip
    def on_render(self):
        if not self.should_rerender():
            return
        self._surface.fill(Colors.background)
        super().on_render()
        self._rerender = False
        pygame.display.flip()
        pass

    # Close the app
    def on_cleanup(self):
        pygame.quit()

    # Core loop
    def run(self):
        self.init()

        # print(f"Children: {self._children}")
        while self._running:
            for event in pygame.event.get():
                self.on_event(event)
            self.on_loop()
            self.on_render()
            # We set a framerate to avoid running too fast
            # TODO: consider vsync?
            self._clock.tick(self.framerate)

        self.on_cleanup()
