"""Folhas do Maquinista (PixelLab) — uma por fase — e o layout lido por boss_maquinista.gd.

Fonte: zip do grupo do personagem (download de qualquer estado de 067acb58-…) extraído em
art_src/boss/pixellab_export. Estados: Idle (fase 1), "Fase 2 - Pressao", "Fase 3 - Caldeira".
Saída:
  assets/sprites/boss/maquinista_p1.png / _p2.png / _p3.png
  assets/sprites/boss/maquinista_layout.json  {"cell": C, "rows": {nome: [linha, [quadros_f1, quadros_f2, quadros_f3]]}}
Todas as células têm o mesmo tamanho C (o maior quadro encontrado); cada quadro é colado
centralizado, porque o PixelLab mantém o pivô no centro do quadro em todas as animações.
"""
import json
import os
from PIL import Image

ROOT = "art_src/boss/pixellab_export/"
OUT = "assets/sprites/boss/"
STATE_IDS = {
    1: "067acb58-85fb-475e-8da4-45f9a8085b05",
    2: "44535eda-da90-4210-817c-525676e5bfe4",
    3: "3354a68f-6451-4526-834f-c38c7c5661f0",
}
# nome no jogo -> (animação no PixelLab, direção)
ROWS = [
    ("idle", "idle", "south"),
    ("walk_e", "walk", "east"),
    ("walk_w", "walk", "west"),
    ("cast", "cast", "south"),
    ("run_s", "run", "south"),
    ("run_e", "run", "east"),
    ("run_w", "run", "west"),
    ("hurt", "hurt", "south"),
    ("roar", "roar", "south"),
    ("slam", "slam", "south"),
    ("death", "death", "south"),
]

meta = json.load(open(ROOT + "metadata.json"))
states = {}
for st in meta["states"]:
    for ph, cid in STATE_IDS.items():
        if st["character"]["id"] == cid:
            states[ph] = st["frames"]


def frames_of(fr: dict, anim: str, direction: str) -> list:
    anims = fr.get("animations", {})
    if anim in anims and direction in anims[anim]:
        return anims[anim][direction]
    return []


# tamanho de célula: o maior quadro de todas as fases
cell = 0
max_frames = 1
for fr in states.values():
    cell = max(cell, Image.open(ROOT + fr["rotations"]["south"]).width)
    for _, anim, d in ROWS:
        fs = frames_of(fr, anim, d)
        max_frames = max(max_frames, len(fs))
        for p in fs[:1]:
            cell = max(cell, *Image.open(ROOT + p).size)

layout_rows = {name: [r, [1, 1, 1]] for r, (name, _a, _d) in enumerate(ROWS)}
for ph, fr in sorted(states.items()):
    sheet = Image.new("RGBA", (cell * max_frames, cell * len(ROWS)))
    for r, (name, anim, d) in enumerate(ROWS):
        fs = frames_of(fr, anim, d)
        if not fs:
            # sem essa animação nesta fase (ex.: morte só existe na 3): usa a pose parada
            fs = [fr["rotations"][d if d in fr["rotations"] else "south"]]
        for i, p in enumerate(fs):
            im = Image.open(ROOT + p).convert("RGBA")
            sheet.alpha_composite(im, (i * cell + (cell - im.width) // 2, r * cell + (cell - im.height) // 2))
        layout_rows[name][1][ph - 1] = len(fs)
    sheet.save(OUT + "maquinista_p%d.png" % ph)
    print("fase", ph, sheet.size)

json.dump({"cell": cell, "offset_y": 0, "rows": layout_rows}, open(OUT + "maquinista_layout.json", "w"), indent=1)
print("cell", cell, layout_rows)
