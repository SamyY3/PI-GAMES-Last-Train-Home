"""Monta assets/sprites/player/teo_sheet_8dir.png a partir do zip do PixelLab
(grupo do Teo; baixar de 184d6a09-8284-4821-bb4f-4a52630e8d27, que inclui os estados
'Idle' e 'Aiming_Wrench_Gun') extraído em art_src/teo/pixellab_export.

Grade 8x66 de células 48x48. dir: 0 S, 1 SE, 2 E, 3 NE, 4 N, 5 NW, 6 W, 7 SW.
  Sem arma (cutscenes/dash): rotações 0; hurt 1+dir; idle 9+dir; walk 17+dir; dash 25+dir.
  Segurando a arma (gameplay): rotações 33; idle 34+dir; walk 42+dir; hurt 50+dir.
  Pulso de vapor [Q]: 58+dir (6 quadros; crava a arma no chão e solta o vapor).
"""
import json
from PIL import Image

ROOT = "art_src/teo/pixellab_export/"
DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
CELL = 48
LAYOUT = [  # (estado, animação ou None p/ rotações, linha inicial, quadros)
    ("Idle", None, 0, 1),
    ("Idle", "hurt", 1, 6),
    ("Idle", "idle", 9, 4),
    ("Idle", "walk", 17, 6),
    ("Idle", "dash", 25, 6),
    ("Aiming_Wrench_Gun", None, 33, 1),
    ("Aiming_Wrench_Gun", "aim_idle", 34, 4),
    ("Aiming_Wrench_Gun", "aim_walk", 42, 6),
]
# o template breathing-idle apagou a arma nestas direções: usa a animação v3 refeita
AIM_IDLE_OVERRIDE = {"north-east", "north"}
# leste/oeste: o template muda o comprimento da arma entre quadros (pisca) e o v3 do oeste
# veio com clarão embutido; nelas o idle é a pose fixa com o tronco descendo 1px (respiração)
AIM_IDLE_STATIC = {"east", "west"}
BREATH = [0, 0, 1, 1]
WAIST_Y = 29
# hurt mirando: os templates de golpe soltam a arma, então o quadro é a pose segurando a
# arma com um recuo de pixels contra a direção encarada (o jogo ainda pinta de vermelho)
HURT_ROW = 50
HURT_KNOCK = [1, 2, 2, 1, 1, 0]
DIR_VEC = [(0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1)]


# direção sul (frente): na arte gerada a arma aponta para a câmera e some atrás das mãos;
# estes quadros foram editados no PixelLab (edit_image 39cff54b-…) com a arma visível.
# ordem: rotação, idle 0-3, walk 0-5
SOUTH_EDIT = "art_src/teo/south_edit/out_%02d.png"
SOUTH_CELLS = [(0, 33)] + [(i, 34) for i in range(4)] + [(i, 42) for i in range(6)]


def cell(path: str) -> Image.Image:
    im = Image.open(ROOT + path).convert("RGBA")
    if im.size != (CELL, CELL):  # canvas maior (animações v3): recorta centralizado
        l, t = (im.width - CELL) // 2, (im.height - CELL) // 2
        im = im.crop((l, t, l + CELL, t + CELL))
    return im


states = {s["folder"]: s["frames"] for s in json.load(open(ROOT + "metadata.json"))["states"]}
sheet = Image.new("RGBA", (8 * CELL, 66 * CELL))
for state, anim, row0, n in LAYOUT:
    fr = states[state]
    for d, name in enumerate(DIRS):
        if anim is None:
            sheet.alpha_composite(cell(fr["rotations"][name]), (d * CELL, row0 * CELL))
            continue
        key = anim
        if anim == "aim_idle" and name in AIM_IDLE_OVERRIDE:
            key = "aim_idle_v3"
        if anim == "aim_idle" and name in AIM_IDLE_STATIC:
            base = cell(fr["rotations"][name])
            for i, b in enumerate(BREATH):
                im = base.copy()
                if b:
                    upper = base.crop((0, 0, CELL, WAIST_Y))
                    im.paste((0, 0, 0, 0), (0, 0, CELL, b))
                    im.paste(upper, (0, b))
                sheet.alpha_composite(im, (i * CELL, (row0 + d) * CELL))
            continue
        frames = fr["animations"][key][name]
        assert len(frames) >= n, (anim, name, len(frames))
        for i in range(n):
            sheet.alpha_composite(cell(frames[i]), (i * CELL, (row0 + d) * CELL))
for k, (c, r) in enumerate(SOUTH_CELLS):
    sheet.paste((0, 0, 0, 0), (c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))
    sheet.alpha_composite(Image.open(SOUTH_EDIT % k).convert("RGBA"), (c * CELL, r * CELL))

aim_rot = states["Aiming_Wrench_Gun"]["rotations"]
for d, name in enumerate(DIRS):
    base = Image.open(SOUTH_EDIT % 0).convert("RGBA") if d == 0 else cell(aim_rot[name])
    for i, k in enumerate(HURT_KNOCK):
        shifted = Image.new("RGBA", (CELL, CELL))
        shifted.paste(base, (-DIR_VEC[d][0] * k, -DIR_VEC[d][1] * k))
        sheet.alpha_composite(shifted, (i * CELL, (HURT_ROW + d) * CELL))
# Pulso [Q]: animação "pulse" do estado mirando; direção sem animação usa a pose parada
PULSE_ROW = 58
aim_anims = states["Aiming_Wrench_Gun"].get("animations", {}).get("pulse", {})
for d, name in enumerate(DIRS):
    frames = aim_anims.get(name, [])
    for i in range(6):
        if frames:
            im = cell(frames[min(i, len(frames) - 1)])
        else:
            im = Image.open(SOUTH_EDIT % 0).convert("RGBA") if d == 0 else cell(aim_rot[name])
        sheet.paste((0, 0, 0, 0), (i * CELL, (PULSE_ROW + d) * CELL, (i + 1) * CELL, (PULSE_ROW + d + 1) * CELL))
        sheet.alpha_composite(im, (i * CELL, (PULSE_ROW + d) * CELL))
sheet.save("assets/sprites/player/teo_sheet_8dir.png")
print("ok", sheet.size)
