"""Limpa a locomotiva PixelLab: remove fumaça e facho do farol embutidos
(o jogo desenha esses efeitos separadamente) e trava a carroceria em um único
quadro, animando apenas rodas e bielas.

Entrada: art_src/train/locomotive_anim_original.png (9 quadros 112x64)
Saída:   assets/sprites/train/locomotive_anim.png e locomotive.png
"""
from PIL import Image
import numpy as np

SRC = "art_src/train/locomotive_anim_original.png"
W, H, N = 112, 64, 9
SMOKE = (143, 184, 196)
OUTLINE = (13, 11, 18, 255)

src = np.array(Image.open(SRC).convert("RGBA"))
frames = [src[:, i * W:(i + 1) * W].copy() for i in range(N)]

body = frames[0].copy()
# fumaça: tudo com a cor de vapor acima da borda da chaminé
for y in range(0, 8):
    for x in range(W):
        if body[y, x, 3] and tuple(body[y, x, :3]) == SMOKE:
            body[y, x] = (0, 0, 0, 0)
# restos de baforadas soltas acima da chaminé
body[0:6, :] = 0
# boca da chaminé (entre os rebites do aro) fica escura
for x in range(77, 81):
    body[6, x] = OUTLINE
# facho do farol: tudo à frente da lanterna
body[12:27, 92:] = 0
# fecha a lente do farol com contorno
for y in range(17, 24):
    if body[y, 91, 3]:
        body[y, 92] = OUTLINE

# rodas motrizes + bielas: única região que anima (fora dela, carroceria fixa)
WHEEL_Y0, WHEEL_X1 = 43, 72
out = []
for f in frames:
    g = body.copy()
    g[WHEEL_Y0:, :WHEEL_X1] = f[WHEEL_Y0:, :WHEEL_X1]
    out.append(g)

Image.fromarray(np.concatenate(out, axis=1)).save("assets/sprites/train/locomotive_anim.png")
Image.fromarray(out[0]).save("assets/sprites/train/locomotive.png")
print("ok")
