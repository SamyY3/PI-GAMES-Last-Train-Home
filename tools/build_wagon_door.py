from PIL import Image

SRC = "assets/sprites/train/wagon.png"
OUT = "assets/sprites/train/wagon_door_anim.png"
W, H = 96, 48
LEAF_X0, LEAF_X1 = 8, 12
LEAF_Y0, LEAF_Y1 = 21, 37
FRAMES = LEAF_X1 - LEAF_X0 + 2

DARK = (43, 29, 20, 255)
WARM_DARK = (90, 58, 34, 255)
WARM = (138, 90, 43, 255)
LIGHT = (242, 195, 91, 255)


def interior(x: int, y: int) -> tuple:
    if y == LEAF_Y0:
        return DARK
    if x == LEAF_X1:
        return DARK
    if y >= LEAF_Y1 - 1:
        return LIGHT if x in (LEAF_X0 + 1, LEAF_X0 + 2) and y == LEAF_Y1 else WARM
    if y in (LEAF_Y0 + 2, LEAF_Y0 + 3) and x == LEAF_X0 + 2:
        return LIGHT
    return WARM_DARK


base = Image.open(SRC).convert("RGBA")
sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
leaf = {(x, y): base.getpixel((x, y)) for x in range(LEAF_X0, LEAF_X1 + 1) for y in range(LEAF_Y0, LEAF_Y1 + 1)}

for f in range(FRAMES):
    frame = base.copy()
    for x in range(LEAF_X0, LEAF_X1 + 1):
        for y in range(LEAF_Y0, LEAF_Y1 + 1):
            frame.putpixel((x, y), interior(x, y))
    for (x, y), px in leaf.items():
        nx = x - f
        if nx >= LEAF_X0:
            frame.putpixel((nx, y), px)
    sheet.paste(frame, (f * W, 0))

sheet.save(OUT)
print("salvo", OUT, sheet.size)
