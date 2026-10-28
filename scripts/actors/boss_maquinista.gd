extends CharacterBody2D

# O Maquinista — chefe final, luta coreografada em 3 fases.
#
# Cada fase tem um roteiro fixo de golpes (PHASE_SCRIPT) executados em sequência por um
# "cérebro" assíncrono (_brain). Cada golpe é uma corrotina com aviso visual (telegraph),
# animação própria e uma fala curta (bark) no balão ao lado do boss.
#   Fase 1 "Horário Rigoroso":  reposicionar · Apito de Partida · Bilhete Perfurado · Pêndulo
#   Fase 2 "Pressão Máxima":    Vazamento de Vapor · Investida da Locomotiva · Troca de Via (+ fase 1)
#   Fase 3 "Caldeira em Chamas": Roda Motriz · Chuva de Carvão · Anéis com brecha · Contagem Final (<12% HP)
# Tudo espera com timers pausáveis: cutscenes e diálogos congelam a luta no ponto exato.

const SHEETS: Array[String] = [
	"res://assets/sprites/boss/maquinista_p1.png",
	"res://assets/sprites/boss/maquinista_p2.png",
	"res://assets/sprites/boss/maquinista_p3.png",
]
const LAYOUT_PATH: String = "res://assets/sprites/boss/maquinista_layout.json"
const FX_WAVE: Texture2D = preload("res://assets/sprites/fx/steam_wave.png")
const FX_DASH_LINE: Texture2D = preload("res://assets/sprites/fx/telegraph_dash.png")
const FX_DOT: Texture2D = preload("res://assets/sprites/fx/telegraph_dot.png")
const FX_RING: Texture2D = preload("res://assets/sprites/fx/hurt_ring.png") # 4 quadros 48x48
const FX_PUFF: Texture2D = preload("res://assets/sprites/fx/steam_puff.png") # 8 estágios 32x32
const FX_VENT: Texture2D = preload("res://assets/sprites/fx/vent_warning.png")

const HOME_Y: float = 94.0
const STAGE_X: Array[float] = [96.0, 240.0, 384.0]
const ARENA := Rect2(40.0, 84.0, 400.0, 150.0) # onde o boss pode pisar (investida)
const FLOOR := Rect2(26.0, 74.0, 428.0, 166.0) # área jogável (avisos e chuva de carvão)

const PHASE_SCRIPT: Array = [
	["reposicionar", "apito", "bilhete", "reposicionar", "pendulo", "apito", "reposicionar", "bilhete"],
	["vapor", "investida", "trilhos", "reposicionar", "apito", "investida", "vapor", "pendulo", "bilhete", "trilhos"],
	["roda", "carvao", "investida", "anel", "reposicionar", "roda", "trilhos", "carvao", "anel", "investida"],
]
const REST: Array[float] = [0.9, 0.7, 0.5]

var max_hp: float = 2400.0
var hp: float = 2400.0
var phase: int = 1
var is_transitioning: bool = false
var _is_dead: bool = false
var _fight_started: bool = false

var _phase2_threshold: float = 0.60
var _phase3_threshold: float = 0.30
var _fire_rate_mult: float = 1.0

var _sprite: Sprite2D
var _layout: Dictionary = {}
var _anim_name: String = "idle"
var _anim_t: float = 0.0
var _anim_fps: float = 8.0
var _anim_loop: bool = true
var _hit_flash_t: float = 0.0
var _transition_wave_t: float = 0.0

var _seq_idx: int = 0
var _stage_idx: int = 1
var _desperation_done: bool = false
var _charging: bool = false
var _hp_barks_done: Dictionary = {}

var _tele_layer: Node2D
var _telegraphs: Array[Dictionary] = []
var _bubble: Panel
var _bubble_lbl: Label
var _bubble_t: float = 0.0
var _last_bark_ms: int = -100000


func _ready() -> void:
	add_to_group("enemies")
	var boss_cfg: Dictionary = GameState.balance_data.get("boss", {})
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	var hp_mult: float = float(diff_cfg.get("enemy_hp_mult", 1.0))
	_fire_rate_mult = maxf(0.1, float(diff_cfg.get("enemy_fire_rate_mult", 1.0)))
	max_hp = float(boss_cfg.get("hp", 2400.0)) * hp_mult
	hp = max_hp
	_phase2_threshold = float(boss_cfg.get("phase2_threshold", 0.60))
	_phase3_threshold = float(boss_cfg.get("phase3_threshold", 0.30))

	global_position = Vector2(240.0, HOME_Y)
	z_index = int(HOME_Y)

	var f := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_layout = parsed
	_sprite = $Sprite2D
	_apply_sheet()
	_play("idle")

	# Camada dos avisos no chão (fica embaixo de todos os atores)
	_tele_layer = Node2D.new()
	_tele_layer.top_level = true
	_tele_layer.z_index = 2
	_tele_layer.z_as_relative = false
	_tele_layer.draw.connect(_draw_telegraphs)
	add_child(_tele_layer)

	_build_bubble()
	Events.player_hit.connect(_on_player_hit)
	Events.boss_hp_changed.emit(hp, max_hp)


# Chamado pelo nível depois da cutscene de apresentação
func start_fight() -> void:
	if _fight_started:
		return
	_fight_started = true
	_bark("inicio", true)
	_brain()


# ==============================================================================
# Animação (folha por fase: linhas e quadros descritos em maquinista_layout.json)
# ==============================================================================
func _apply_sheet() -> void:
	var path: String = SHEETS[clampi(phase - 1, 0, 2)]
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	var cell: int = int(_layout.get("cell", 80))
	_sprite.hframes = maxi(1, floori(float(_sprite.texture.get_width()) / float(cell)))
	_sprite.vframes = maxi(1, floori(float(_sprite.texture.get_height()) / float(cell)))
	_sprite.offset = Vector2(0.0, float(_layout.get("offset_y", 0.0)))


func _play(anim: String, fps: float = 8.0, loop: bool = true) -> void:
	var rows: Dictionary = _layout.get("rows", {})
	if not rows.has(anim):
		anim = "idle"
	if _anim_name == anim and loop and _anim_loop:
		return
	_anim_name = anim
	_anim_t = 0.0
	_anim_fps = fps
	_anim_loop = loop


func _update_anim(delta: float) -> void:
	_anim_t += delta
	var rows: Dictionary = _layout.get("rows", {})
	var spec: Array = rows.get(_anim_name, [0, [1, 1, 1]])
	var n: int = maxi(1, int((spec[1] as Array)[clampi(phase - 1, 0, 2)]))
	var fi: int = int(_anim_t * _anim_fps)
	if _anim_loop:
		fi = fi % n
	else:
		fi = mini(fi, n - 1)
	_sprite.frame_coords = Vector2i(fi, int(spec[0]))


func _walk_anim_for(dir: Vector2, running: bool) -> String:
	if running:
		if absf(dir.x) > absf(dir.y) * 0.8:
			return "run_e" if dir.x > 0.0 else "run_w"
		return "run_s"
	return "walk_e" if dir.x >= 0.0 else "walk_w"


# ==============================================================================
# Loop principal
# ==============================================================================
func _physics_process(delta: float) -> void:
	_update_anim(delta)
	z_index = int(global_position.y)

	if _hit_flash_t > 0.0:
		_hit_flash_t -= delta
		_sprite.modulate = Color(2.6, 2.6, 2.6, 1.0)
	else:
		_sprite.modulate = Color.WHITE

	if _transition_wave_t > 0.0:
		_transition_wave_t -= delta
		queue_redraw()

	if _bubble_t > 0.0:
		_bubble_t -= delta
		_bubble.modulate.a = clampf(_bubble_t / 0.25, 0.0, 1.0)
		_bubble.visible = _bubble_t > 0.0
		_place_bubble()

	for tg in _telegraphs:
		tg["t"] = float(tg["t"]) + delta
	_tele_layer.queue_redraw()

	# investida: encostar no Maquinista em disparada machuca
	if _charging:
		var player: Node2D = _player()
		if player != null and player.global_position.distance_to(global_position) < 18.0 and player.has_method("take_damage"):
			player.take_damage(1, global_position)


func _brain() -> void:
	while not _is_dead and is_inside_tree():
		if is_transitioning or get_tree().paused:
			await get_tree().physics_frame
			continue
		var p: int = phase
		var move: String
		if p == 3 and not _desperation_done and hp / max_hp <= 0.12:
			_desperation_done = true
			move = "contagem"
		else:
			var script_list: Array = PHASE_SCRIPT[p - 1]
			move = String(script_list[_seq_idx % script_list.size()])
			_seq_idx += 1
		await _run_move(move)
		if _is_dead or not is_inside_tree():
			return
		if phase != p:
			_seq_idx = 0
			continue
		_play("idle")
		await _wait(REST[p - 1])


func _run_move(move: String) -> void:
	match move:
		"reposicionar": await _move_reposicionar()
		"apito": await _move_apito()
		"bilhete": await _move_bilhete()
		"pendulo": await _move_pendulo()
		"vapor": await _move_vapor()
		"investida": await _move_investida()
		"trilhos": await _move_trilhos()
		"roda": await _move_roda()
		"carvao": await _move_carvao()
		"anel": await _move_anel()
		"contagem": await _move_contagem()


# ------------------------------------------------------------------------------
# Utilitários de corrotina (pausáveis e interrompíveis por troca de fase/morte)
# ------------------------------------------------------------------------------
func _ok(p: int) -> bool:
	return is_inside_tree() and not _is_dead and not is_transitioning and phase == p


func _wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds / _fire_rate_mult, false).timeout


# um passo de física; devolve o delta (0 se a árvore estiver pausada)
func _tick() -> float:
	var tree: SceneTree = get_tree()
	await tree.physics_frame
	if not is_inside_tree() or tree.paused:
		return 0.0
	return get_physics_process_delta_time()


func _player() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node2D


func _to_player() -> Vector2:
	var pl: Node2D = _player()
	if pl == null:
		return Vector2.DOWN
	return (pl.global_position - global_position).normalized()


func _walk_to(target: Vector2, speed: float, running: bool = false) -> void:
	var p: int = phase
	var dir: Vector2 = (target - global_position).normalized()
	_play(_walk_anim_for(dir, running), 14.0 if running else 9.0)
	while global_position.distance_to(target) > 2.0 and _ok(p):
		var dt: float = await _tick()
		global_position = global_position.move_toward(target, speed * dt)
	_play("idle")


func _cast() -> void:
	_play("cast", 12.0, false)


func _fire(pos: Vector2, dir: Vector2, speed: float) -> void:
	BulletManager.spawn_bullet(pos, dir, speed, false)


func _add_tele(kind: String, data: Dictionary) -> Dictionary:
	var tg: Dictionary = data.duplicate()
	tg["kind"] = kind
	tg["t"] = 0.0
	_telegraphs.append(tg)
	return tg


func _clear_tele(tg: Dictionary) -> void:
	_telegraphs.erase(tg)


func _clear_bursts() -> void:
	_telegraphs = _telegraphs.filter(func(tg: Dictionary) -> bool: return tg["kind"] != "burst")


# ==============================================================================
# FASE 1 — Horário Rigoroso
# ==============================================================================
func _move_reposicionar() -> void:
	# caminha entre três marcas no palco (esquerda, centro, direita), sempre trocando de lugar
	var options: Array[int] = [0, 1, 2]
	options.erase(_stage_idx)
	_stage_idx = options[randi() % options.size()]
	var speed: float = [70.0, 95.0, 120.0][phase - 1]
	await _walk_to(Vector2(STAGE_X[_stage_idx], HOME_Y), speed)


# Apito de Partida: três leques mirados, girando um pouco a cada apito
func _move_apito() -> void:
	var p: int = phase
	_bark("apito")
	_cast()
	var tg := _add_tele("dot", {"pos": global_position + Vector2(0.0, 6.0), "dur": 0.45})
	AudioManager.play_sfx("whistle", 0.05)
	await _wait(0.45)
	_clear_tele(tg)
	var volleys: int = 3 if p == 1 else 4
	var count: int = 5 if p == 1 else 7
	for v in range(volleys):
		if not _ok(p):
			return
		var base: Vector2 = _to_player().rotated(deg_to_rad(-8.0 + 8.0 * float(v % 3)))
		BulletManager.spawn_fan(global_position + Vector2(0.0, 8.0), base, count, 44.0, 130.0 + 10.0 * float(p), false)
		AudioManager.play_sfx("player_shoot", 0.1)
		await _wait(0.32)


# Bilhete Perfurado: trava a mira numa linha (aviso tracejado) e dispara uma fila rápida por ela
func _move_bilhete() -> void:
	var p: int = phase
	_bark("bilhete")
	var shots: int = 3 if p == 1 else 4
	for s in range(shots):
		if not _ok(p):
			return
		_cast()
		var dir: Vector2 = _to_player()
		var tg := _add_tele("line", {"pos": global_position, "dir": dir, "len": 300.0, "dur": 0.55})
		AudioManager.play_sfx("tick", 0.0)
		await _wait(0.55)
		_clear_tele(tg)
		for i in range(7):
			if not _ok(p):
				return
			_fire(global_position + dir * 10.0, dir, 230.0)
			await _wait(0.045)
		await _wait(0.25)


# Pêndulo: arco de balas que varre o vagão de um lado ao outro (na fase 2, dois pêndulos espelhados)
func _move_pendulo() -> void:
	var p: int = phase
	await _walk_to(Vector2(240.0, HOME_Y), 110.0)
	if not _ok(p):
		return
	_stage_idx = 1
	_bark("pendulo")
	_play("cast", 6.0, true)
	var t: float = 0.0
	var shot: float = 0.0
	while t < 2.6 and _ok(p):
		var dt: float = await _tick()
		t += dt
		shot -= dt * _fire_rate_mult
		if shot <= 0.0:
			shot = 0.07
			var swing: float = deg_to_rad(65.0) * sin(t * 2.4)
			_fire(global_position, Vector2.DOWN.rotated(swing), 110.0)
			if p >= 2:
				_fire(global_position, Vector2.DOWN.rotated(-swing), 110.0)


# ==============================================================================
# FASE 2 — Pressão Máxima
# ==============================================================================
# Vazamento de Vapor: golpeia o chão, marca pontos (um em cima do Teo) que explodem em anéis
func _move_vapor() -> void:
	var p: int = phase
	_bark("vapor")
	_play("slam", 10.0, false)
	await _wait(0.35)
	if not _ok(p):
		return
	Events.request_screen_shake.emit(2.5, 0.25)
	AudioManager.play_sfx("clang", 0.05)
	var pl: Node2D = _player()
	var center: Vector2 = pl.global_position if pl != null else Vector2(240.0, 170.0)
	var spots: Array[Vector2] = [center]
	for i in range(3 if p == 2 else 4):
		spots.append(_clamp_floor(center + Vector2(randf_range(-110.0, 110.0), randf_range(-50.0, 50.0))))
	var tgs: Array[Dictionary] = []
	for s in spots:
		tgs.append(_add_tele("vent", {"pos": s, "dur": 0.9}))
	AudioManager.play_sfx("steam_pulse", 0.1)
	await _wait(0.9)
	for tg in tgs:
		_clear_tele(tg)
	if not _ok(p):
		return
	for s in spots:
		_add_tele("burst", {"pos": s, "dur": 0.5})
		BulletManager.spawn_ring(s, 10, 85.0, randf() * 36.0)
	Events.request_screen_shake.emit(2.0, 0.2)
	await _wait(0.5)
	_clear_bursts()


# Investida da Locomotiva: mira, dispara em linha reta até o ponto marcado deixando brasas, e volta
func _move_investida() -> void:
	var p: int = phase
	_bark("investida")
	var pl: Node2D = _player()
	var target: Vector2 = _clamp_arena(pl.global_position if pl != null else Vector2(240.0, 200.0))
	var dir: Vector2 = (target - global_position).normalized()
	_play(_walk_anim_for(dir, true), 4.0)
	var tg := _add_tele("line", {"pos": global_position, "dir": dir, "len": global_position.distance_to(target), "dur": 0.75, "wide": true})
	AudioManager.play_sfx("whistle", 0.0)
	await _wait(0.75)
	_clear_tele(tg)
	if not _ok(p):
		return
	_charging = true
	_play(_walk_anim_for(dir, true), 16.0)
	var drop: float = 0.0
	while global_position.distance_to(target) > 3.0 and _ok(p):
		var dt: float = await _tick()
		global_position = global_position.move_toward(target, 360.0 * dt)
		drop -= dt
		if drop <= 0.0:
			drop = 0.06
			# brasas que escapam para os lados do trilho da investida
			var side: Vector2 = dir.orthogonal()
			_fire(global_position, side, 38.0)
			_fire(global_position, -side, 38.0)
	_charging = false
	if not _ok(p):
		return
	Events.request_screen_shake.emit(3.0, 0.3)
	AudioManager.play_sfx("clang", 0.0)
	BulletManager.spawn_ring(global_position, 12 if p == 2 else 16, 95.0)
	_play("idle")
	await _wait(0.45)
	await _walk_to(Vector2(STAGE_X[_stage_idx], HOME_Y), 140.0)


# Troca de Via: faixas horizontais de balas entram pelas laterais, com uma brecha perto do Teo
func _move_trilhos() -> void:
	var p: int = phase
	_bark("trilhos")
	_cast()
	var lanes: Array[float] = []
	var y: float = 84.0
	while y <= 236.0:
		lanes.append(y)
		y += 19.0
	for w in range(2 if p == 2 else 3):
		if not _ok(p):
			return
		var from_left: bool = w % 2 == 0
		var pl: Node2D = _player()
		var py: float = pl.global_position.y if pl != null else 160.0
		# brecha de duas faixas perto (mas não necessariamente em cima) do Teo
		var gap_i: int = clampi(int(round((py - 84.0) / 19.0)) + (randi() % 3 - 1), 0, lanes.size() - 2)
		var tgs: Array[Dictionary] = []
		for i in range(lanes.size()):
			if i != gap_i and i != gap_i + 1:
				tgs.append(_add_tele("lane", {"y": lanes[i], "left": from_left, "dur": 0.7}))
		AudioManager.play_sfx("tick", 0.0)
		await _wait(0.7)
		for tg in tgs:
			_clear_tele(tg)
		for k in range(4):
			if not _ok(p):
				return
			for i in range(lanes.size()):
				if i != gap_i and i != gap_i + 1:
					_fire(Vector2(24.0 if from_left else 456.0, lanes[i]), Vector2.RIGHT if from_left else Vector2.LEFT, 150.0)
			await _wait(0.16)
		await _wait(0.5)


# ==============================================================================
# FASE 3 — Caldeira em Chamas
# ==============================================================================
# Roda Motriz: duas espirais girando em sentidos opostos, como as rodas da locomotiva
func _move_roda() -> void:
	var p: int = phase
	await _walk_to(Vector2(240.0, HOME_Y + 8.0), 120.0)
	if not _ok(p):
		return
	_stage_idx = 1
	_bark("roda")
	_play("roar", 8.0, true)
	var t: float = 0.0
	var shot: float = 0.0
	var spin: float = randf() * TAU
	while t < 3.0 and _ok(p):
		var dt: float = await _tick()
		t += dt
		shot -= dt * _fire_rate_mult
		if shot <= 0.0:
			shot = 0.12
			var a: float = spin + t * deg_to_rad(110.0)
			for k in range(3):
				_fire(global_position, Vector2.RIGHT.rotated(a + TAU / 3.0 * k), 95.0)
				_fire(global_position, Vector2.RIGHT.rotated(-a * 1.3 + TAU / 3.0 * k + 0.5), 80.0)


# Chuva de Carvão: brasas caem em pontos marcados pelo vagão e estouram em pequenos anéis
func _move_carvao() -> void:
	var p: int = phase
	_bark("carvao")
	_play("slam", 10.0, false)
	await _wait(0.35)
	if not _ok(p):
		return
	Events.request_screen_shake.emit(2.0, 0.2)
	var pl: Node2D = _player()
	var center: Vector2 = pl.global_position if pl != null else Vector2(240.0, 170.0)
	var spots: Array[Vector2] = []
	for i in range(16):
		var s: Vector2
		if i < 5:
			s = center + Vector2(randf_range(-45.0, 45.0), randf_range(-30.0, 30.0))
		else:
			s = Vector2(randf_range(FLOOR.position.x, FLOOR.end.x), randf_range(FLOOR.position.y + 30.0, FLOOR.end.y))
		spots.append(_clamp_floor(s))
	var tgs: Array[Dictionary] = []
	for i in range(spots.size()):
		tgs.append(_add_tele("coal", {"pos": spots[i], "dur": 0.85, "delay": float(i) * 0.03}))
	await _wait(0.85)
	for tg in tgs:
		_clear_tele(tg)
	for s in spots:
		if not _ok(p):
			return
		BulletManager.spawn_ring(s, 5, 70.0, randf() * 72.0)
		_add_tele("burst", {"pos": s, "dur": 0.35, "small": true})
		await _wait(0.03)
	AudioManager.play_sfx("enemy_die", 0.1)
	await _wait(0.4)
	_clear_bursts()


# Anéis com brecha: três anéis seguidos; a brecha persegue o Teo
func _move_anel() -> void:
	var p: int = phase
	_bark("anel")
	for r in range(3):
		if not _ok(p):
			return
		_cast()
		await _wait(0.2)
		var gap_angle: float = _to_player().angle() + deg_to_rad(randf_range(-25.0, 25.0))
		for i in range(30):
			var ang: float = TAU / 30.0 * float(i)
			if absf(wrapf(ang - gap_angle, -PI, PI)) > deg_to_rad(20.0):
				_fire(global_position, Vector2.RIGHT.rotated(ang), 92.0)
		AudioManager.play_sfx("player_shoot", 0.1)
		await _wait(0.55)


# Contagem Final (desespero, uma vez abaixo de 12%): ponteiros de relógio feitos de balas giram
# em volta dele enquanto o tique-taque solta anéis lentos
func _move_contagem() -> void:
	var p: int = phase
	await _walk_to(Vector2(240.0, 140.0), 140.0)
	if not _ok(p):
		return
	_bark("contagem", true)
	_play("roar", 8.0, true)
	Events.request_screen_shake.emit(3.0, 0.5)
	AudioManager.play_sfx("boss_phase", 0.0)
	await _wait(0.8)
	var t: float = 0.0
	var shot: float = 0.0
	var tick_t: float = 0.0
	while t < 6.0 and _ok(p):
		var dt: float = await _tick()
		t += dt
		shot -= dt * _fire_rate_mult
		tick_t -= dt
		if shot <= 0.0:
			shot = 0.09
			var a: float = t * deg_to_rad(42.0)
			for k in range(4):
				_fire(global_position, Vector2.RIGHT.rotated(a + PI * 0.5 * float(k)), 120.0)
		if tick_t <= 0.0:
			tick_t = 1.0
			AudioManager.play_sfx("tick", 0.0)
			BulletManager.spawn_ring(global_position, 14, 55.0, t * 25.0)
	await _walk_to(Vector2(240.0, HOME_Y), 120.0)


func _clamp_arena(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, ARENA.position.x, ARENA.end.x), clampf(pos.y, ARENA.position.y, ARENA.end.y))


func _clamp_floor(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, FLOOR.position.x + 10.0, FLOOR.end.x - 10.0), clampf(pos.y, FLOOR.position.y + 10.0, FLOOR.end.y - 6.0))


# ==============================================================================
# Dano, fases e morte
# ==============================================================================
func take_damage(amount: float) -> void:
	if _is_dead:
		return
	if amount < 50000.0 and is_transitioning:
		return

	hp = maxf(0.0, hp - amount)
	_hit_flash_t = 0.06
	_sprite.scale = Vector2(1.08, 0.94)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2.ONE, 0.10)
	Events.boss_hp_changed.emit(hp, max_hp)

	if hp <= 0.0:
		_die()
		return

	var ratio: float = hp / max_hp
	for mark in [0.8, 0.45, 0.15]:
		if ratio <= mark and not _hp_barks_done.has(mark):
			_hp_barks_done[mark] = true
			_bark("ferido_%d" % int(round(mark * 100.0)), true)
	if phase == 1 and ratio <= _phase2_threshold:
		_transition_to_phase(2)
	elif phase == 2 and ratio <= _phase3_threshold:
		_transition_to_phase(3)


func _transition_to_phase(next_phase: int) -> void:
	is_transitioning = true
	_charging = false
	_telegraphs.clear()
	phase = next_phase
	BulletManager.clear_all_bullets()
	_play("hurt", 10.0, false)
	AudioManager.play_sfx("boss_phase", 0.02)
	Events.request_screen_shake.emit(4.0, 0.6)
	Events.request_screen_flash.emit(0.15)
	# a cutscene da fase (e o diálogo) pausam a árvore a partir daqui
	Events.boss_phase_changed.emit(phase)

	_apply_sheet()
	if phase == 2:
		AudioManager.play_music("boss_p1_p2", 1.05)
	elif phase == 3:
		TrainClock.apply_section_rubber_band("boss_phase_3")
		var player: Node = _player()
		if player and player.has_method("reset_pulse_cooldown"):
			player.reset_pulse_cooldown()
		AudioManager.play_music("boss_p3")

	# de volta ao jogo: rugido com a onda de vapor e volta ao centro do palco
	_play("roar", 9.0, false)
	_transition_wave_t = 2.0
	await _wait(1.1)
	if _is_dead:
		return
	var target := Vector2(240.0, HOME_Y)
	_play(_walk_anim_for(target - global_position, false), 10.0)
	while global_position.distance_to(target) > 2.0 and not _is_dead:
		var dt: float = await _tick()
		global_position = global_position.move_toward(target, 130.0 * dt)
	_play("idle")
	_stage_idx = 1
	is_transitioning = false


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	is_transitioning = true
	_charging = false
	_telegraphs.clear()
	get_tree().paused = false
	BulletManager.clear_all_bullets()
	_bark("derrota", true)
	_play("death", 7.0, false)
	AudioManager.play_sfx("bomb_explode")
	Events.request_screen_shake.emit(3.5, 1.5)
	Engine.time_scale = 0.4
	await get_tree().create_timer(1.4, true, false, true).timeout
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return
	var cs: Node = get_tree().get_first_node_in_group("boss_cutscene")
	if cs != null:
		await cs.play_defeat(get_parent(), self)
	SceneRouter.goto_scene("res://scenes/levels/Disarm.tscn")


# ==============================================================================
# Falas (balão ao lado do boss; textos em dialogue_pt_br.json → "boss_barks")
# ==============================================================================
func _build_bubble() -> void:
	_bubble = Panel.new()
	_bubble.add_theme_stylebox_override("panel", Settings.make_ui_style("panel"))
	_bubble.size = Vector2(196.0, 22.0)
	_bubble.visible = false
	_bubble.z_index = 300
	_bubble.z_as_relative = false
	_bubble.top_level = true
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	_bubble_lbl = Label.new()
	_bubble_lbl.position = Vector2(6.0, 3.0)
	_bubble_lbl.size = Vector2(184.0, 16.0)
	_bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_lbl.add_theme_font_size_override("font_size", 10)
	_bubble_lbl.add_theme_color_override("font_color", Color("#ff6b3d"))
	_bubble.add_child(_bubble_lbl)


func _place_bubble() -> void:
	# ao lado da cabeça (em cima fica a barra de vida do chefe); troca de lado perto da borda
	var right_side: bool = global_position.x < 300.0
	var x: float = global_position.x + (30.0 if right_side else -30.0 - _bubble.size.x)
	_bubble.global_position = Vector2(round(x), round(global_position.y - 38.0))


func _bark(key: String, force: bool = false) -> void:
	var barks: Dictionary = GameState.dialogue_db.get("boss_barks", {})
	var lines: Array = barks.get(key, [])
	if lines.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if not force and (now - _last_bark_ms < 2500 or randf() > 0.7):
		return
	_last_bark_ms = now
	_bubble_lbl.text = String(lines[randi() % lines.size()])
	# uma linha cabe ~36 caracteres; frases maiores ganham uma segunda linha
	var two_lines: bool = _bubble_lbl.text.length() > 36
	_bubble.size.y = 38.0 if two_lines else 22.0
	_bubble_lbl.size.y = _bubble.size.y - 6.0
	_bubble_t = 2.4
	_bubble.visible = true
	_place_bubble()


func _on_player_hit(_cur: int, _max_v: int) -> void:
	if _fight_started and not _is_dead:
		_bark("acertou")


# ==============================================================================
# Desenho: onda de vapor da troca de fase e avisos no chão
# ==============================================================================
func _draw() -> void:
	if _transition_wave_t > 0.0:
		var p: float = 1.0 - (_transition_wave_t / 2.0)
		for k in range(2):
			var wf: int = int(fmod(p * 12.0 + float(k) * 3.0, 6.0))
			draw_texture_rect_region(FX_WAVE, Rect2(-84.0, -84.0, 168.0, 168.0), Rect2(wf * 168.0, 0.0, 168.0, 168.0), Color("#ff6b3d") if k == 0 else Color("#f2c35b"))


func _draw_telegraphs() -> void:
	var d: Node2D = _tele_layer
	for tg in _telegraphs:
		var t: float = float(tg["t"])
		var dur: float = maxf(0.01, float(tg.get("dur", 1.0)))
		var k: float = clampf(t / dur, 0.0, 1.0)
		var blink: bool = k > 0.6 and int(t * 16.0) % 2 == 0
		match String(tg["kind"]):
			"line":
				# tracejado que "enche" do boss até o fim da linha; pisca perto do disparo
				var pos: Vector2 = tg["pos"]
				var dir: Vector2 = tg["dir"]
				var length: float = float(tg["len"]) * minf(1.0, k * 1.6)
				var h: float = 5.0 if tg.get("wide", false) else 3.0
				d.draw_set_transform(pos, dir.angle())
				d.draw_texture_rect(FX_DASH_LINE, Rect2(0.0, -h * 0.5, length, h), true, Color(1.0, 0.45, 0.35, 1.0) if blink else Color(1.0, 1.0, 1.0, 0.85))
				d.draw_set_transform(Vector2.ZERO, 0.0)
			"dot":
				d.draw_texture(FX_DOT, (Vector2(tg["pos"]) - Vector2(4.0, 4.0)).round(), Color(1.0, 0.6, 0.4) if blink else Color.WHITE)
			"vent", "coal":
				if t < float(tg.get("delay", 0.0)):
					continue
				var pos2: Vector2 = tg["pos"]
				var frame: int = int(t * 10.0) % 4
				var is_vent: bool = String(tg["kind"]) == "vent"
				var size: float = 48.0 if is_vent else 24.0
				var col: Color = Color("#ff6b3d") if blink else (Color("#8fb8c4") if is_vent else Color("#f2c35b"))
				d.draw_texture_rect_region(FX_RING, Rect2(pos2 - Vector2(size, size) * 0.5, Vector2(size, size)), Rect2(frame * 48.0, 0.0, 48.0, 48.0), col)
				d.draw_texture(FX_DOT, (pos2 - Vector2(4.0, 4.0)).round(), col)
			"burst":
				var pos3: Vector2 = tg["pos"]
				var st: int = mini(int(k * 8.0), 7)
				var small: bool = tg.get("small", false)
				var s: float = 24.0 if small else 40.0
				d.draw_texture_rect_region(FX_PUFF, Rect2(pos3 - Vector2(s, s) * 0.5, Vector2(s, s)), Rect2(st * 32.0, 0.0, 32.0, 32.0), Color(1.0, 0.85, 0.7, 1.0 - k) if small else Color(1.0, 1.0, 1.0, 1.0 - k))
			"lane":
				# aviso de via: faixa listrada na borda de onde as balas vão entrar
				var y: float = float(tg["y"])
				var w: float = 120.0 * minf(1.0, k * 2.0)
				var x0: float = 24.0 if tg["left"] else 456.0 - w
				d.draw_texture_rect(FX_VENT, Rect2(x0, y - 2.0, w, 4.0), true, Color(1.0, 0.5, 0.4) if blink else Color(1.0, 1.0, 1.0, 0.8))
