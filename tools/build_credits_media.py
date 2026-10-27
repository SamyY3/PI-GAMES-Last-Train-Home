"""Fotos e vídeos dos créditos a partir de capturas reais do jogo.

Capturas (480x270) gravadas com tools/capture/rec.tscn (só as escolhidas ficam em art_src/credits_capture/).
Saída em assets/sprites/credits/:
  photo_<nome>.png  240x135 (redução 2:1 com média, aspecto de foto)
  video_<nome>.png  spritesheet 6x4 de quadros 240x135 (24 quadros)
O clipe do menu é recortado em resolução nativa (só o trem, sem os botões).
"""
import os
from PIL import Image

SRC = "art_src/credits_capture"
OUT = "assets/sprites/credits"
os.makedirs(OUT, exist_ok=True)
W, H = 240, 135

PHOTOS = {
    "boarding": "p_intro/f_000.png",
    "passengers": "p_w1/f_000.png",
    "wagon3": "p_w3/f_002.png",
    "wagon4": "p_w4/f_000.png",
    "boss_card": "p_bossintro/f_000.png",
    "disarm": "p_disarm/f_001.png",
}
VIDEOS = {"wagon2": ("v_w2", None), "boss": ("v_boss", None), "menu_train": ("v_menu", (236, 110))}


def half(img: Image.Image) -> Image.Image:
    return img.convert("RGB").resize((W, H), Image.BOX)


for name, rel in PHOTOS.items():
    half(Image.open(os.path.join(SRC, rel))).save(os.path.join(OUT, "photo_%s.png" % name))

for name, (folder, crop) in VIDEOS.items():
    sheet = Image.new("RGB", (W * 6, H * 4))
    for i in range(24):
        im = Image.open(os.path.join(SRC, folder, "f_%03d.png" % i)).convert("RGB")
        im = im.crop((crop[0], crop[1], crop[0] + W, crop[1] + H)) if crop else half(im)
        sheet.paste(im, ((i % 6) * W, (i // 6) * H))
    sheet.save(os.path.join(OUT, "video_%s.png" % name))
print("ok")
