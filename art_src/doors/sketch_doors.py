"""Esboço da geometria das portas laterais (parede direita), na perspectiva 3/4 do jogo.

A parede lateral é vista quase de lado: a porta aparece estreita e alta, como uma folha de ferro
em escorço, com o chanfro voltado para o interior (esquerda) e o topo do batente visto de cima.
A porta esquerda é a mesma arte espelhada. O PixelLab (edit_image) refina o acabamento.
Saída: door_side_locked_sketch.png / door_side_open_sketch.png (24x60)
"""
from PIL import Image, ImageDraw

W, H = 24, 60
OUT = (13, 11, 18, 255)        # contorno
BRASS_D = (138, 90, 43, 255)
BRASS = (201, 138, 60, 255)
BRASS_L = (242, 195, 91, 255)
IRON_D = (40, 44, 56, 255)
IRON = (74, 82, 98, 255)
IRON_L = (120, 132, 148, 255)
DARK = (20, 18, 28, 255)
GLOW = (143, 184, 196, 255)


def base() -> Image.Image:
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # batente: topo visto de cima (lintel) + montantes, com espessura da parede para a direita
    d.rectangle((4, 4, 21, 9), fill=BRASS_D, outline=OUT)            # topo do batente (de cima)
    d.line((5, 5, 20, 5), fill=BRASS_L)
    d.rectangle((4, 9, 8, 57), fill=BRASS, outline=OUT)              # montante interno (voltado para o vagão)
    d.line((5, 10, 5, 56), fill=BRASS_L)
    d.rectangle((17, 9, 21, 57), fill=BRASS_D, outline=OUT)          # montante externo (na sombra)
    d.rectangle((4, 55, 21, 58), fill=BRASS_D, outline=OUT)          # soleira
    return im


def locked() -> Image.Image:
    im = base()
    d = ImageDraw.Draw(im)
    # folha de ferro em escorço: estreita, com o chanfro claro voltado para dentro
    d.rectangle((8, 10, 17, 55), fill=IRON, outline=OUT)
    d.line((9, 11, 9, 54), fill=IRON_L)                              # chanfro iluminado
    d.line((16, 11, 16, 54), fill=IRON_D)
    for y in range(14, 54, 6):                                       # rebites
        d.point((12, y), fill=IRON_L)
        d.point((13, y + 1), fill=IRON_D)
    for y in (24, 40):                                               # reforços horizontais
        d.line((9, y, 16, y), fill=IRON_D)
    d.rectangle((10, 30, 11, 34), fill=BRASS)                        # maçaneta/trava
    d.rectangle((9, 0, 14, 4), fill=(179, 52, 46, 255), outline=OUT)  # lâmpada vermelha
    d.point((11, 1), fill=(255, 140, 120, 255))
    return im


def opened() -> Image.Image:
    im = base()
    d = ImageDraw.Draw(im)
    # vão aberto: passagem escura com a luz do próximo vagão; a folha recolhida rente ao montante externo
    d.rectangle((8, 10, 16, 55), fill=DARK)
    d.line((12, 14, 12, 50), fill=(60, 70, 90, 255))
    d.line((13, 18, 13, 46), fill=GLOW)
    d.rectangle((15, 10, 17, 55), fill=IRON, outline=OUT)            # folha recolhida
    d.line((15, 11, 15, 54), fill=IRON_L)
    d.rectangle((9, 0, 14, 4), fill=(63, 122, 107, 255), outline=OUT)  # lâmpada verde
    d.point((11, 1), fill=(150, 230, 190, 255))
    return im


locked().save("art_src/doors/door_side_locked_sketch.png")
opened().save("art_src/doors/door_side_open_sketch.png")
print("ok")
