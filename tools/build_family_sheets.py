"""Spritesheets da família do Teo (PixelLab) para o final e os créditos.

Fontes extraídas em art_src/family/{mae,pai,lia} (zip de download dos personagens):
  Mãe 5b92dd3e-…, Pai da5759b8-…, Lia (criança, 32px) 508315e1-…
Saída em assets/sprites/family/:
  mae.png / pai.png (células 48): linha 0 rotações S,SE,E,NE,N,NW,W,SW; 1 idle leste (4); 2 andar leste (6); 3 andar oeste (6)
  lia.png (células 48, pés em y=40): linha 0 rotações; 1 pulando e acenando p/ oeste (6); 2 correndo p/ oeste (6); 3 andar leste (6)
  (a Lia é gerada em 32px, mas o aceno saiu num quadro de 48 e ela pula: nada é recortado,
   os quadros de 32 entram centralizados com os pés na mesma linha dos de 48)
"""
import json
from PIL import Image

DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]


def cell(path: str, size: int) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    if im.width < size:
        # quadro menor (Lia 32px num quadro de 48): centraliza na horizontal, pés em y=40
        out = Image.new("RGBA", (size, size))
        out.paste(im, ((size - im.width) // 2, 40 - (im.height - 1)))
        return out
    if im.size != (size, size):
        l, t = (im.width - size) // 2, (im.height - size) // 2
        im = im.crop((l, t, l + size, t + size))
    return im


def build(src: str, out: str, size: int, rows: list) -> None:
    root = "art_src/family/%s/" % src
    fr = json.load(open(root + "metadata.json"))["states"][0]["frames"]
    sheet = Image.new("RGBA", (8 * size, 4 * size))
    for d, name in enumerate(DIRS):
        sheet.alpha_composite(cell(root + fr["rotations"][name], size), (d * size, 0))
    for r, (anim, direction) in enumerate(rows, start=1):
        for i, p in enumerate(fr["animations"][anim][direction][:8]):
            sheet.alpha_composite(cell(root + p, size), (i * size, r * size))
    sheet.save("assets/sprites/family/%s.png" % out)


ADULT = [("idle", "east"), ("walk", "east"), ("walk", "west")]
build("mae", "mae", 48, ADULT)
build("pai", "pai", 48, ADULT)
build("lia", "lia", 48, [("wave", "west"), ("run", "west"), ("walk", "east")])
print("ok")
