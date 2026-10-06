# Last Train Home — MVP (Godot 4.3+)

Abra a pasta no Godot (Import → project.godot) e aperte F5. O jogo abre no **menu inicial**.

## Controles
- WASD/setas: mover • Mouse: mirar • Clique ou J: atirar
- Shift: esquiva (invulnerável por instantes) • Ctrl: movimento lento (precisão)
- E / Enter / Espaço: interagir e avançar diálogo
- Desarme final: Q → E → R → F
- Game Over / Final: R joga de novo • M volta ao menu

## Progressão (estilo roguelike)
- 5 vagões + boss, 15 ondas (V1: 3, V2: 3, V3: 2, V4 Caldeira: 4, V5 Locomotiva: 3).
- Após cada onda: escolha 1 de 3 cartas de melhoria (teclas 1/2/3 ou clique). [R] troca as opções (1 troca no início, +1 a cada vagão, máx. 2).
- 18 melhorias com nível, em 4 categorias coloridas: ATAQUE (laranja), MOBILIDADE (verde), DEFESA (azul), UTILIDADE (amarelo).
  Ataque: tiro múltiplo, dano, cadência, crítico, perfurante, mira assistida, explosivo, tiro traseiro.
  Utilidade: vapor gélido (lentidão), ricochete, reciclagem (cura por abates).
  Mobilidade: velocidade, esquiva afiada, esquiva fantasma.  Defesa: blindagem, escudo, casco compacto, kit de reparo.
- Vagão 3: caixas com 1 bomba, 2 armadilhas e 3 peças mecânicas (melhoria extra).
- HUD: faixa de chips fixa embaixo com suas melhorias; banner colorido ao obter; diálogo da história na caixa dourada.
- Balanceamento: tabela `DIFFICULTIES` e `UPGRADES` em `scripts/game.gd`.

## Dificuldade (escolha no menu; é salva em `user://settings.cfg`)
| | Fácil | Normal | Difícil | Pesadelo |
|---|---|---|---|---|
| Vida inicial / cura por vagão | 7 / +3 | 5 / +2 | 4 / +1 | 3 / 0 |
| Vida inimiga (base) | x0.8 | x1.0 | x1.15 | x1.3 |
| Cadência / velocidade das balas inimigas | -20% / -10% | normal | +25% / +12% | +54% / +25% |
| Inimigos acompanham sua build | 35% | 70% | 90% | 100% |
| Elites (mais vida e mais tiros) | não | não | 15% | 30% |
| Boss (duração-alvo) | ~45s | ~70s | ~95s | ~120s |
| Relógio / limite na Caldeira | 18:00 / 8:00 | 15:00 / 7:00 | 14:30 / 6:30 | 14:00 / 6:00 |

**Como o jogo deixa de ficar fácil com a build forte:** a vida dos inimigos comuns cresce com as ondas vencidas **e com o DPS estimado da sua build**
(`Game.enemy_hp_factor()`); ondas ganham inimigos extras conforme você fica mais forte (`Game.extra_enemies()`); a vida do boss é calculada para uma luta de
`boss_time` segundos com o DPS que você tem ao chegar nele (`Game.boss_hp()`, mínimo 1400); e os inimigos atiram um pouco mais rápido a cada onda.

## HUD
- Painel de status: vida em segmentos (rastro branco ao perder, flash verde ao curar, pulsa com vida baixa), escudo em losangos azuis, barra de esquiva (PRONTA / recarregando), objetivo e vagão.
- Painel do tempo: relógio grande (laranja < 2:00, vermelho pulsando < 1:00) com barra de tempo restante, e ONDA n/m com bolinhas de progresso.
- Selo da dificuldade no topo; barra do boss com nome, fase (1/3–3/3), vida numérica, marcadores de fase e rastro de dano.
- Feedback de dano: vinheta vermelha ao ser atingido (azul ao perder escudo), borda pulsando com vida baixa e leve tremor de tela.

## Debug (só no editor / builds de debug)
- F1: mata todos os inimigos • F2: +60s no relógio • F3: god mode

## Estrutura
- scripts/menu.gd   — menu inicial (jogar, dificuldade, controles) com fundo animado
- scripts/main.gd   — fluxo do jogo (cada vagão é uma coroutine linear)
- scripts/game.gd   — autoload: dificuldades, balanceamento, upgrades, input
- scripts/enemy.gd  — autômato, robô e boss (3 fases)
- scripts/player.gd, bullet.gd, hazard.gd (vapor), prop.gd (NPCs/caixas), hud.gd

Tudo é desenhado por código (placeholders): os `_draw()` precisam ser trocados por Sprite2D/AnimatedSprite2D quando tiver arte.
