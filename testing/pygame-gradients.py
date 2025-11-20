import pygame

pygame.init()
window = pygame.display.set_mode((400,400))

def make_linear_gradient_surface(color1, color2, size):
    base = pygame.Surface((2,2))
    pygame.draw.line(base, color1, (0,0), (1,0))
    pygame.draw.line(base, color2, (0,1), (1,1))
    return pygame.transform.smoothscale(base, size)

def make_circular_gradient_surface(color1, color2, size):
    base = pygame.Surface((3,3))
    base.fill(color1)
    pygame.draw.line(base,color2,(1,1),(1,1))
    return pygame.transform.smoothscale(base,size)

clock = pygame.time.Clock()
while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            quit()
    gradient = make_linear_gradient_surface((0,0,0),(255,255,255),(400,400))
    # gradient = make_circular_gradient_surface((0,0,0),(255,255,255),(400,400))
    window.blit(gradient,(0,0))
    pygame.display.flip()
    clock.tick_busy_loop(60)
