# art_src — fontes de arte (não importadas pelo Godot)

Esta pasta tem um `.gdignore`: o Godot não importa nem exporta nada daqui. Os scripts de
`tools/` leem estas fontes e geram os assets finais em `assets/` (rodar da raiz do projeto).

| Pasta | Conteúdo | Montador |
|---|---|---|
| `teo/pixellab_export/` | zip do Teo extraído (estados `Idle` e `Aiming_Wrench_Gun`) — PixelLab `184d6a09-8284-4821-bb4f-4a52630e8d27` | `build_teo_sheet.py` |
| `teo/south_edit/` | 11 quadros do Teo de frente com a arma visível (PixelLab `edit_image`) | `build_teo_sheet.py` |
| `family/mae/` | Mãe — PixelLab `5b92dd3e-586e-4e00-802c-c652aacb5245` | `build_family_sheets.py` |
| `family/pai/` | Pai — PixelLab `da5759b8-62f4-4bad-a48c-76e6bc34ac3d` | `build_family_sheets.py` |
| `family/lia/` | Lia (criança 32px) — PixelLab `508315e1-fa94-4d84-b23e-a9c20dbe4630` | `build_family_sheets.py` |
| `boss/pixellab_export/` | Maquinista, 3 estados (fases) — PixelLab `067acb58-85fb-475e-8da4-45f9a8085b05` | `build_boss_sheets.py` |
| `train/locomotive_anim_original.png` | locomotiva original (9 quadros, com fumaça/facho embutidos) | `clean_locomotive.py` |
| `doors/` | esboço da geometria das portas laterais (`sketch_doors.py`) e o refinamento do PixelLab (`refined_0/1.png`, `edit_image` 31ada820-…); `assets/sprites/tiles/door_locked/open.png` = recorte do refinado | manual |
| `credits_capture/` | capturas de gameplay usadas nos créditos (`tools/capture/rec.tscn`) | `build_credits_media.py` |

Atualizar um personagem: baixe `https://api.pixellab.ai/mcp/characters/<id>/download`,
extraia por cima da pasta correspondente e rode o montador.
