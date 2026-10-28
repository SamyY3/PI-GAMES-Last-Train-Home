# LAST TRAIN HOME

*— Rumo à Estação Zero —*

**Last Train Home** é um bullet hell / roguelite 2D steampunk em pixel art. Teo, um jovem mecânico, embarca no último trem da noite para voltar para casa e descobre que há uma bomba a bordo. Com o relógio correndo, ele precisa atravessar os vagões, enfrentar autômatos, coletar melhorias, derrotar **O Maquinista** e desarmar a bomba antes da chegada à Estação Zero.

<p align="center">
  <img src="assets/sprites/credits/photo_passengers.png" width="360" alt="Vagão 1 — os passageiros">
  <img src="assets/sprites/credits/photo_boss_card.png" width="360" alt="O Maquinista se apresenta">
</p>

| | |
|---|---|
| **Gênero** | Bullet hell / roguelite 2D |
| **Estilo** | Steampunk, pixel art (paleta TRAIN16), visão top-down 3/4 |
| **Plataforma** | PC |
| **Engine** | Godot 4 (GDScript, renderizador GL Compatibility) |
| **Resolução** | 480x270 nativa com upscale inteiro (janela 1440x810) |
| **Duração** | ~10–15 minutos por partida |
| **Modo** | Single-player |
| **Versão** | 1.6.0 |

## Como executar

1. Instale o **Godot 4.3 ou superior** (o projeto é testado no 4.7).
2. No Project Manager, clique em **Importar** e selecione o `project.godot` desta pasta.
3. Pressione **F5** para jogar. O jogo abre na tela de boot e depois no menu principal.

Para jogar sem o Godot, baixe o `.zip` para Windows na página de [Releases](https://github.com/SamyY3/PI-GAMES-Last-Train-Home/releases), extraia e abra o `LastTrainHome.exe`.

### Exportar para PC

A predefinição **Windows Desktop** já está em `export_presets.cfg`. Com os templates de exportação do Godot 4.7.2 instalados, use **Projeto → Exportar** no editor ou, pela linha de comando:

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/LastTrainHome.exe
```

O resultado é um único `.exe` (com os dados embutidos) em `build/windows/`, pasta que não vai para o git.

### Exportar para Android

A predefinição **Android** gera um APK para arm64 com o pacote `com.pigames.lasttrainhome`. Além dos templates do Godot 4.7.2, é preciso o JDK 17 e o Android SDK (platform-tools, build-tools 36.1.0 e a plataforma android-36), configurados em **Editor → Configurações do Editor → Exportar → Android**. Para gerar um APK de teste, assinado com a chave de debug do Godot:

```bash
godot --headless --path . --export-debug "Android" build/android/LastTrainHome.apk
```

Para testar os controles de toque no PC, rode o jogo com `-- --touch`.

## Controles

| Ação | Teclado / mouse | Controle |
|---|---|---|
| Mover | WASD ou setas | Analógico esquerdo ou D-pad |
| Mirar | Mouse (ou mira automática, nas Opções) | Analógico direito (solto, mira para onde anda) |
| Atirar | Clique esquerdo, J ou Z | RT |
| Dash (invulnerável por instantes) | Espaço | B |
| Pulso de vapor (limpa projéteis e empurra inimigos) | Q ou E | Y |
| Foco (movimento lento e preciso) | Shift | LT |
| Interagir / avançar diálogo | F ou Enter | A |
| Pular introdução / diálogo (segurar) | Esc | B |
| Sortear melhorias / tentar de novo | R | X |
| Trocar de aba (Opções e Pausa) | Mouse | LB / RB |
| Pausar | Esc | Start |
| Tela cheia | F11 | — |

No celular aparecem controles na tela: o analógico esquerdo move, o direito mira e atira enquanto estiver pressionado, e os botões **DASH**, **PULSO**, **FOCO** (liga e desliga) e **AÇÃO** ficam acima dele, com a pausa no canto superior direito (o botão também fecha o menu de pausa, em qualquer aba). O botão Voltar do Android pausa e despausa o jogo e volta nos menus. Os analógicos surgem onde o dedo toca em cada metade da tela. Nos diálogos, tocar avança e segurar pula; no desarme da bomba aparecem os botões ◀ ▶ ▼ e **AÇÃO**. Com um controle conectado, os botões da tela somem. No celular, as Opções mostram só as abas Áudio, Vídeo e Jogo: as abas Teclado e Controle e a opção de tela cheia ficam escondidas.

As teclas principais podem ser remapeadas em **Opções → Teclado**, e os botões do controle (atirar, dash, pulso, foco e interagir, incluindo gatilhos, L3/R3 e paddles traseiros) em **Opções → Controle**. Movimento, mira, Start e os botões de menu são fixos (layout Xbox; controles de PlayStation e Switch usam as posições equivalentes). O jogo detecta sozinho o último dispositivo usado: as dicas na tela trocam entre teclas e botões, o cursor do mouse some e o Teo ganha uma retícula de mira. A vibração pode ser desligada em **Opções → Jogo**.

## Fluxo do jogo

**Boot → Menu → Embarque → Vagões 1–4 → Cabine → Boss → Desarme da bomba → Final → Créditos → Resultados**

- **Vagões 1 a 4:** ondas de inimigos (Drone, Sentinela, Cargueiro, Torreta, Sniper) em cenários diferentes — passageiros, tubulações de vapor, cargueiro e velocidade máxima.
- **O Maquinista:** luta em 3 fases, cada uma com roteiro próprio de golpes, avisos no chão e cutscenes em estilo cartaz:
  1. *Horário Rigoroso* — Apito de Partida, Bilhete Perfurado, Pêndulo.
  2. *Pressão Máxima* — Vazamento de Vapor, Investida da Locomotiva, Troca de Via.
  3. *Caldeira em Chamas* — Roda Motriz, Chuva de Carvão, Anéis com brecha e a **Contagem Final**.
- **Desarme:** girar a válvula (alternar A/D), baixar a alavanca, cortar o fio certo e apagar o núcleo — tudo em poucos segundos.
- **Final:** a chegada à estação da colina ao amanhecer e o reencontro com a família (Mãe, Pai e Lia).

## Mecânicas

- **Relógio regressivo** com meta por vagão: ao entrar em cada seção, o tempo que sobrou é limitado a um teto, então a pressão nunca some. O que passa do teto ao entrar nos vagões vai para a **reserva**, mostrada ao lado do relógio.
- **O Fiscal:** quando a porta de saída de um vagão se abre, o Fiscal aparece perto dela e vende uma carta (com mais chance de rara e épica) em troca de tempo. Ele cobra primeiro da reserva e o resto do relógio. Custa 0:20 e cada compra encarece a próxima em 0:05. É uma compra por vagão, e ele não negocia se o relógio for ficar abaixo de 0:30.
- **Raspão:** passar perto de uma bala inimiga sem ser atingido (e sem estar no dash ou invulnerável) solta uma faísca, reduz a recarga do pulso de vapor em 0,35s e devolve 0,15s ao relógio (até 12s por vagão). A tela de resultados mostra os raspões e as compras do Fiscal.
- **Tiro contínuo com mira**, **dash** com invulnerabilidade e **pulso de vapor**.
- **19 cartas de melhoria** em 4 categorias (ataque, defesa, mobilidade, utilidade) com raridades comum, rara, épica e **maldição**. Exemplos: Tiro Duplo, Munição Perfurante, Balas Elásticas, Mira Giroscópica e Sucata Viva.
  - **Malditas** têm um custo junto com o bônus: Caldeira Sobrecarregada (+50% de dano, mas o relógio corre 10% mais rápido) e Freio de Emergência (o Pulso congela o relógio por 3s, mas tira 1 coração máximo).
  - **Cartas de dash e pulso:** Rastro de Vapor (o dash deixa vapor que fere), Pulso Refletor (o pulso rebate as balas) e Embalo (derrotar um inimigo durante o dash recarrega o dash).
  - **Combinações escondidas:** duas cartas certas juntas ganham um bônus extra e um aviso na tela. São elas: Bala Fantasma (Balas Elásticas + Munição Perfurante), Míssil de Latão (Mira Giroscópica + Pólvora Instável) e Locomotiva (Rastro de Vapor + Válvula de Escape). As combinações descobertas ficam salvas.
- **Partidas diferentes a cada vez:** os vagões 2, 3 e 4 sorteiam as ondas entre 2 ou 3 variações (o vagão 1, o tutorial, é fixo). Cada um desses vagões ainda pode receber um modificador:
  - **Túnel:** de tempos em tempos o vagão escurece e só a área em volta do Teo fica iluminada.
  - **Curva fechada:** um aviso e, logo depois, o trem empurra o Teo para um lado por alguns segundos.
  - **Passageiro em perigo:** um passageiro aguenta 3 balas. Se ele sobreviver até o vagão ser limpo, Teo ganha uma carta extra.
- **Recordes e desbloqueios:** a tela de dificuldade mostra o melhor tempo e a melhor nota de cada dificuldade, as vitórias e as combinações descobertas.
  - **Ferramentas iniciais** são liberadas vencendo e fazem a partida começar com uma carta de nível 1: Botas Velhas (vença uma vez), Chave Inglesa (vença na Média ou Difícil) e Luneta (vença na Difícil).
  - **Viagem do Dia:** uma partida na Média com a mesma semente para o dia inteiro (mesmas ondas, modificadores e sorteios de cartas), sem ferramenta inicial e com recorde próprio.
- **Três dificuldades:**

| | Fácil | Média | Difícil |
|---|---|---|---|
| Vida inicial | 6 | 5 | 4 |
| Tempo inicial | 08:00 | 06:30 | 05:30 |
| Vida dos inimigos | x0,8 | x1,0 | x1,25 |
| Velocidade das balas inimigas | x0,85 | x1,0 | x1,15 |
| Cadência inimiga | x0,8 | x1,0 | x1,2 |
| Drops aleatórios | sim | sim | não |

- **Trilha sonora por cena:** menu, embarque, cada um dos quatro vagões, cabine, as fases do Maquinista, desarme, final e créditos têm músicas próprias. Nos vagões, a música tem uma camada calma para a exploração e os diálogos e passa para a versão completa quando surgem inimigos.

## Estrutura do projeto

```
├── project.godot
├── assets/        # sprites, áudio (músicas e SFX) e fontes usados pelo jogo
├── data/          # balance.json, upgrades.json, dialogue_pt_br.json, credits.json
├── scenes/        # actors, boot, levels, menus, ui
├── scripts/
│   ├── autoload/  # Events, Settings, GameState, TrainClock, AudioManager, SceneRouter
│   ├── systems/   # BulletManager (pool de projéteis)
│   ├── actors/    # player, inimigos e boss
│   ├── levels/    # um script por nível + desarme e final
│   └── ui/        # HUD, diálogos, menus, cartas de melhoria, cutscenes, créditos
├── tools/         # geradores/montadores de assets em Python + tools/capture/ (capturas)
├── export_icons/  # ícones do jogo para exportar para PC e Android (ignorados pelo Godot)
└── art_src/       # fontes de arte do PixelLab (ignoradas pelo Godot)
```

Balanceamento, melhorias, diálogos e créditos ficam em JSON dentro de `data/` e podem ser ajustados sem mexer no código. Detalhes das folhas de sprite e do pipeline de arte estão em [`art_src/README.md`](art_src/README.md).

## Ícones de exportação

O ícone do jogo (`assets/sprites/ui/icon.png`, 64×64) é um relógio de bolso de latão com a locomotiva no mostrador e um pavio aceso. Em `export_icons/` estão as versões ampliadas sem borrar (vizinho mais próximo, em múltiplos inteiros) para usar nas predefinições de exportação do Godot:

| Arquivo | Onde usar |
|---|---|
| `icon.ico` (16 a 256 px) | Windows → `application/icon` |
| `icon_256.png` | cópia em PNG do ícone grande |
| `android_icon_192.png` | Android → `launcher_icons/main_192x192` |
| `android_adaptive_foreground_432.png` | Android → `launcher_icons/adaptive_foreground_432x432` |
| `android_adaptive_background_432.png` | Android → `launcher_icons/adaptive_background_432x432` |

## Regenerar assets (opcional)

Os assets prontos já estão em `assets/`. Para reconstruí-los a partir das fontes (rodar na raiz do projeto):

```bash
pip install pillow numpy scipy
python tools/build_teo_sheet.py          # Teo
python tools/build_family_sheets.py      # família (final/créditos)
python tools/build_boss_sheets.py        # O Maquinista
python tools/build_credits_media.py      # fotos/vídeos dos créditos
python tools/clean_locomotive.py         # locomotiva
python tools/generate_sfx.py             # efeitos sonoros
python tools/generate_music.py           # trilhas do jogo (menu, vagões, chefe, desarme, final)
python tools/generate_credits_music.py   # tema dos créditos
```

## Atalhos de debug (apenas no editor)

| Tecla | Efeito |
|---|---|
| F1 | Overlay de FPS, inimigos e relógio |
| F2 | Avançar para o próximo vagão |
| F3 | Alternar imortalidade |
| F4 | Eliminar todos os inimigos ativos |
| F5 | Reduzir a vida do boss para 31% |
| F6 | Conceder uma melhoria aleatória |

## Créditos

- Pixel art e ilustrações feitas com o auxílio do [PixelLab](https://www.pixellab.ai).
- Fontes **DotGothic16** e **Jersey 10** sob a SIL Open Font License (licenças em `assets/fonts/`).
- Músicas chiptune e efeitos sonoros sintetizados pela equipe.

## Equipe

1. **Clara Sobreira Vidal**
2. **Ingrid Sampaio Angelim do Nascimento**
3. **José Daniel Macêdo Fechine**
4. **Lia Costa Andrade**
5. **Maria Taliciane Pereira da Silva**
6. **Michel Gomes Pinheiro**
7. **Morya Samyak Arrais Benicio**
8. **Wesley Furtado Pessoa**
