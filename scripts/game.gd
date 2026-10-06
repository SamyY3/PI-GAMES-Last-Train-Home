extends Node
## Autoload "Game": guarda o estado global, os números de balanceamento, o sistema de melhorias e o mapa de teclas.

# ---- Balanceamento base (pode mexer à vontade) ----
const ARENA := Rect2(80, 110, 1120, 540)
const BOSS_HP := 1400.0            # vida MÍNIMA do boss; a de verdade escala com o DPS do jogador (olha o boss_hp())
const BASE_FIRE_INTERVAL := 0.16   # intervalo de tiro do jogador sem nenhuma melhoria (entra na conta do DPS)
const SETTINGS_PATH := "user://settings.cfg"

## Níveis de dificuldade. Tudo que muda de um pro outro tá aqui.
##  start_hp / heal / invuln / rerolls / reroll_cap ... o lado do jogador
##  enemy_hp / hp_wave / adapt ......................... vida dos inimigos (adapt = o quanto ela acompanha o DPS da sua build)
##  fire / bspeed ...................................... cadência (menor = mais rápido) e velocidade das balas inimigas
##  extra / extra_ratio ................................ inimigos extras por onda (um valor fixo + o que vem do poder da build)
##  elite ............................................. chance de nascer um "elite" (só a partir da 3ª onda)
##  boss_time / boss_density ........................... quanto a luta do boss deve durar (s) e o quanto ele enche a tela de bala
##  time / accel ....................................... relógio total e o teto do relógio quando entra na Caldeira (s)
const DIFFICULTIES := [
	{"name": "FÁCIL", "tag": "Para curtir a história", "color": Color(0.5, 1.0, 0.55),
		"start_hp": 7, "heal": 3, "invuln": 1.5, "rerolls": 2, "reroll_cap": 3,
		"enemy_hp": 0.8, "hp_wave": 0.03, "adapt": 0.35, "fire": 1.25, "bspeed": 0.9,
		"extra": 0.0, "extra_ratio": 0.0, "elite": 0.0,
		"boss_time": 45.0, "boss_density": 0.8, "time": 1080.0, "accel": 480.0},
	{"name": "NORMAL", "tag": "A experiência pretendida", "color": Color(1.0, 0.85, 0.4),
		"start_hp": 5, "heal": 2, "invuln": 1.2, "rerolls": 1, "reroll_cap": 2,
		"enemy_hp": 1.0, "hp_wave": 0.06, "adapt": 0.7, "fire": 1.0, "bspeed": 1.0,
		"extra": 0.0, "extra_ratio": 0.15, "elite": 0.0,
		"boss_time": 70.0, "boss_density": 1.0, "time": 900.0, "accel": 420.0},
	{"name": "DIFÍCIL", "tag": "Para quem busca desafio", "color": Color(1.0, 0.55, 0.25),
		"start_hp": 4, "heal": 1, "invuln": 1.0, "rerolls": 1, "reroll_cap": 2,
		"enemy_hp": 1.15, "hp_wave": 0.07, "adapt": 0.9, "fire": 0.8, "bspeed": 1.12,
		"extra": 1.0, "extra_ratio": 0.25, "elite": 0.15,
		"boss_time": 95.0, "boss_density": 1.2, "time": 870.0, "accel": 390.0},
	{"name": "PESADELO", "tag": "Sem piedade. Boa sorte.", "color": Color(1.0, 0.3, 0.3),
		"start_hp": 3, "heal": 0, "invuln": 0.8, "rerolls": 0, "reroll_cap": 1,
		"enemy_hp": 1.3, "hp_wave": 0.08, "adapt": 1.0, "fire": 0.65, "bspeed": 1.25,
		"extra": 2.0, "extra_ratio": 0.35, "elite": 0.3,
		"boss_time": 120.0, "boss_density": 1.4, "time": 840.0, "accel": 360.0},
]

const CATEGORIES := {
	"atk":  {"name": "ATAQUE",     "color": Color(1.0, 0.5, 0.3)},
	"mob":  {"name": "MOBILIDADE", "color": Color(0.5, 1.0, 0.55)},
	"def":  {"name": "DEFESA",     "color": Color(0.45, 0.7, 1.0)},
	"util": {"name": "UTILIDADE",  "color": Color(1.0, 0.85, 0.4)},
}

## Todas as melhorias do jogo. "max" é o nível máximo de cada uma.
const UPGRADES := {
	"shots":     {"cat": "atk",  "name": "Tiro múltiplo",      "desc": "+1 projétil por disparo.", "max": 3},
	"damage":    {"cat": "atk",  "name": "Munição reforçada",  "desc": "+50% de dano por nível.", "max": 4},
	"rate":      {"cat": "atk",  "name": "Gatilho rápido",     "desc": "Atira mais rápido.", "max": 4},
	"crit":      {"cat": "atk",  "name": "Tiro crítico",       "desc": "+12% de chance de causar dano dobrado.", "max": 3},
	"pierce":    {"cat": "atk",  "name": "Munição perfurante", "desc": "Os tiros atravessam inimigos.", "max": 1},
	"homing":    {"cat": "atk",  "name": "Mira assistida",     "desc": "Os tiros curvam em direção aos inimigos.", "max": 2},
	"explosive": {"cat": "atk",  "name": "Munição explosiva",  "desc": "Tiros explodem e ferem inimigos próximos.", "max": 2},
	"rear":      {"cat": "atk",  "name": "Tiro traseiro",      "desc": "Também atira para trás (Nv2: e para os lados).", "max": 2},
	"slow":      {"cat": "util", "name": "Vapor gélido",       "desc": "Inimigos atingidos ficam mais lentos.", "max": 2},
	"ricochet":  {"cat": "util", "name": "Ricochete",          "desc": "Os tiros quicam nas paredes do vagão.", "max": 2},
	"scrap":     {"cat": "util", "name": "Reciclagem",         "desc": "Cura 1 HP a cada ~10 inimigos derrotados (menos com o nível).", "max": 2},
	"speed":     {"cat": "mob",  "name": "Pistões turbinados", "desc": "+15% de velocidade de movimento.", "max": 3},
	"dash":      {"cat": "mob",  "name": "Esquiva afiada",     "desc": "A esquiva recarrega mais rápido.", "max": 3},
	"ghost":     {"cat": "mob",  "name": "Esquiva fantasma",   "desc": "A invulnerabilidade da esquiva dura mais.", "max": 2},
	"hp":        {"cat": "def",  "name": "Blindagem",          "desc": "+1 HP máximo (e cura 1).", "max": 3},
	"shield":    {"cat": "def",  "name": "Escudo de vapor",    "desc": "Absorve golpes. Recarrega a cada vagão.", "max": 2},
	"compact":   {"cat": "def",  "name": "Casco compacto",     "desc": "Seu ponto de colisão fica menor.", "max": 2},
	"repair":    {"cat": "def",  "name": "Kit de reparo",      "desc": "Recupera 3 HP agora.", "max": 99},
}

# ---- Referências (quem preenche é o main) ----
var bullets_root: Node2D
var enemies_root: Node2D
var player: Node2D

# ---- Estado da partida ----
var difficulty := 1               # índice em DIFFICULTIES (fica salvo em user://settings.cfg)
var time_left := 900.0
var clock_on := false
var paused := false
var over := false
var won := false
var god_mode := false
var waves_cleared := 0
var kills := 0
var rerolls := 1

# ---- Melhorias (tudo calculado a partir de `levels`) ----
var levels := {}
var damage := 1.0
var speed_mult := 1.0
var extra_shots := 0
var rate_mult := 1.0
var homing := 0
var pierce := false
var dash_mult := 1.0
var ghost_extra := 0.0
var crit_chance := 0.0
var explosive := 0
var rear := 0
var bounces := 0
var slow_time := 0.0
var hit_radius := 5.0
var shield := 0
var has_key := false
var found_bomb := false


func _ready() -> void:
	_load_settings()
	_key_action("move_up", [KEY_W, KEY_UP])
	_key_action("move_down", [KEY_S, KEY_DOWN])
	_key_action("move_left", [KEY_A, KEY_LEFT])
	_key_action("move_right", [KEY_D, KEY_RIGHT])
	_key_action("dash", [KEY_SHIFT])
	_key_action("focus", [KEY_CTRL])
	_key_action("interact", [KEY_E, KEY_ENTER, KEY_SPACE])
	_key_action("shoot", [KEY_J])
	_mouse_action("shoot", MOUSE_BUTTON_LEFT)


func reset() -> void:
	time_left = time_total()
	clock_on = false
	paused = false
	over = false
	won = false
	waves_cleared = 0
	kills = 0
	rerolls = int(diff()["rerolls"])
	levels = {}
	shield = 0
	has_key = false
	found_bomb = false
	_recompute()


# ---------- dificuldade ----------

func diff() -> Dictionary:
	return DIFFICULTIES[difficulty]


func set_difficulty(i: int) -> void:
	difficulty = clampi(i, 0, DIFFICULTIES.size() - 1)
	_save_settings()


func start_hp() -> int:
	return int(diff()["start_hp"])


func time_total() -> float:
	return float(diff()["time"])


func accel_clamp() -> float:
	return float(diff()["accel"])


func transition_heal() -> int:
	return int(diff()["heal"])


func hit_invuln() -> float:
	return float(diff()["invuln"])


## DPS "de cabeça" do jogador com as melhorias de agora (sem melhoria nenhuma dá ~6.25 tiros/s).
func player_dps() -> float:
	var shots := 1.0 + extra_shots
	var rate := 1.0 / (BASE_FIRE_INTERVAL * rate_mult)
	var dps := rate * shots * damage * (1.0 + crit_chance)
	# melhorias que fazem o tiro render mais (acertar mais ou acertar vários)
	dps *= 1.0 + 0.12 * homing + (0.1 if pierce else 0.0) + 0.1 * explosive + 0.08 * rear
	return dps


## Quantas vezes você tá mais forte do que no começo (sempre >= 1).
func power_ratio() -> float:
	return maxf(1.0, player_dps() * BASE_FIRE_INTERVAL)


## Vida dos inimigos comuns: dificuldade x ondas vencidas x poder da build.
## (É isso aqui que impede o jogo de ficar mamão quando a build fica forte.)
func enemy_hp_factor() -> float:
	var d := diff()
	var power := clampf(pow(power_ratio(), 0.75), 1.0, 6.0)
	return float(d["enemy_hp"]) * (1.0 + float(d["hp_wave"]) * waves_cleared) * (1.0 + float(d["adapt"]) * (power - 1.0))


## Vida do boss: calculada pra luta durar ~boss_time segundos com o DPS que você tem agora.
func boss_hp() -> float:
	var d := diff()
	return clampf(float(d["boss_time"]) * player_dps() * 0.55, BOSS_HP, 14000.0)


## Multiplicador do intervalo entre tiros inimigos (menor = mais rápido). Vai caindo um pouquinho a cada onda.
func fire_cd_mult() -> float:
	return float(diff()["fire"]) * clampf(1.0 - 0.012 * waves_cleared, 0.65, 1.0)


func bullet_speed_mult() -> float:
	return float(diff()["bspeed"]) * (1.0 + 0.006 * waves_cleared)


func elite_chance() -> float:
	return float(diff()["elite"])


## Inimigos extras que entram em cada onda (aumenta com as ondas vencidas e com o poder da build).
func extra_enemies() -> int:
	var d := diff()
	var base := float(d["extra"]) * minf(1.0, waves_cleared / 3.0)
	return mini(6, int(base + float(d["extra_ratio"]) * (power_ratio() - 1.0)))


## Linhas de resumo que aparecem nas cartas do menu.
func diff_lines(i: int) -> Array:
	var d: Dictionary = DIFFICULTIES[i]
	var t := int(d["time"])
	var cad := int(round((1.0 / float(d["fire"]) - 1.0) * 100.0))
	var spd := int(round((float(d["bspeed"]) - 1.0) * 100.0))
	var l: Array = []
	l.append("Vida inicial: %d" % int(d["start_hp"]))
	l.append("Cura por vagão: +%d" % int(d["heal"]))
	l.append("Vida inimiga: x%.1f" % float(d["enemy_hp"]))
	l.append("Cadência inimiga: %+d%%" % cad)
	l.append("Velocidade das balas: %+d%%" % spd)
	l.append("Inimigos acompanham\nsua build: %d%%" % int(round(float(d["adapt"]) * 100.0)))
	l.append("Elites: %d%%" % int(round(float(d["elite"]) * 100.0)) if float(d["elite"]) > 0.0 else "Sem elites")
	l.append("Boss: ~%ds de luta" % int(d["boss_time"]))
	l.append("Tempo: %02d:%02d" % [t / 60, t % 60])
	l.append("Trocas de opção: %d" % int(d["rerolls"]))
	return l


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		difficulty = clampi(int(cf.get_value("game", "difficulty", 1)), 0, DIFFICULTIES.size() - 1)


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "difficulty", difficulty)
	cf.save(SETTINGS_PATH)


func on_kill() -> void:
	kills += 1
	var s := lvl("scrap")
	if s > 0 and player and kills % (14 - 4 * s) == 0:
		player.heal(1)


# ---------- melhorias ----------

func lvl(id: String) -> int:
	return int(levels.get(id, 0))


func _recompute() -> void:
	damage = 1.0 + 0.5 * lvl("damage")
	speed_mult = 1.0 + 0.15 * lvl("speed")
	extra_shots = lvl("shots")
	rate_mult = pow(0.88, lvl("rate"))
	homing = lvl("homing")
	pierce = lvl("pierce") >= 1
	dash_mult = pow(0.75, lvl("dash"))
	ghost_extra = 0.12 * lvl("ghost")
	crit_chance = 0.12 * lvl("crit")
	explosive = lvl("explosive")
	rear = lvl("rear")
	bounces = lvl("ricochet")
	slow_time = [0.0, 1.2, 2.2][lvl("slow")]
	hit_radius = 5.0 - 1.2 * lvl("compact")


func apply_upgrade(id: String) -> void:
	if id == "repair":
		if player:
			player.heal(3)
		return
	levels[id] = lvl(id) + 1
	_recompute()
	if player == null:
		return
	match id:
		"hp":
			player.max_hp += 1
			player.heal(1)
		"shield":
			shield = lvl("shield")
			player.hp_changed.emit(player.hp, player.max_hp)


func restore_shield() -> void:
	shield = lvl("shield")
	if player:
		player.hp_changed.emit(player.hp, player.max_hp)


## Sorteia n melhorias diferentes entre as disponíveis ("repair" só aparece se você tiver tomado dano).
func roll_choices(n: int) -> Array:
	var pool: Array = []
	for id in UPGRADES:
		if id == "repair":
			if player == null or player.hp >= player.max_hp:
				continue
		elif lvl(id) >= int(UPGRADES[id]["max"]):
			continue
		pool.append(id)
	pool.shuffle()
	return pool.slice(0, n)


## Dados já mastigados pra interface (cartas, banner, chips).
func info(id: String) -> Dictionary:
	var u: Dictionary = UPGRADES[id]
	var c: Dictionary = CATEGORIES[u["cat"]]
	return {"id": id, "name": u["name"], "desc": u["desc"], "lvl": lvl(id), "max": int(u["max"]),
			"cat_name": c["name"], "color": c["color"]}


func build_entries() -> Array:
	var out: Array = []
	for id in UPGRADES:
		if id != "repair" and lvl(id) > 0:
			out.append(info(id))
	return out


# ---------- input ----------

func _key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		InputMap.action_add_event(action, ev)


func _mouse_action(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
