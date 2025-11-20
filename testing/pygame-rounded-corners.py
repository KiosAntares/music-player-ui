import pygame

pygame.init()
window = pygame.display.set_mode((400,400))

def rounder_surface(original, corner_radius):
    size = original.get_size()
    masking_surface = pygame.Surface(size, pygame.SRCALPHA | pygame.HWACCEL)
    pygame.draw.rect(masking_surface, (255,255,255), (0,0,*size), border_radius=corner_radius)
    out = original.copy().convert_alpha()
    out.blit(masking_surface, (0,0), None, pygame.BLEND_RGBA_MIN)
    return out


img = pygame.image.load('test.png')
img = pygame.transform.scale_by(img, 0.5)
clock = pygame.time.Clock()
# window.fill((255,255,255))
while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            quit()
    rounded_img = rounder_surface(img, 20)
    window.blit(rounded_img, (50,50))
    #gradient = make_linear_gradient_surface((0,0,0),(255,255,255),(400,400))
    pygame.display.flip()
    clock.tick_busy_loop(60)
