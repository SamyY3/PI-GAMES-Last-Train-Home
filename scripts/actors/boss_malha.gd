extends CharacterBody2D

const FRAME: int = 96
const ROWS: Dictionary = {"idle": 0, "move": 1, "attack": 2, "special": 3, "death": 4}
const STAGE_POS: Array[Vector2] = [Vector2(120.0, 104.0), Vector2(240.0, 98.0), Vector2(360.0, 104.0)]
const LANES: int = 5
const LANE_TOP: float = 74.0
const LANE_H: float = 33.0
const REST: Array[float] = [0.85, 0.65, 0.45]
const TELE_COLOR := Color(1.0, 0.24, 0.43)
const ECHO_DELAY: float = 1.2

signal signal_light_changed(state: String)

var boss_id: String = "fortaleza"
var boss_name: String = ""
var max_hp: float = 2400.0
var hp: float = 2400.0
var phase: int = 1
var is_transitioning: bool = false
var _is_dead: bool = false
var _fight_started: bool = false
var _def: Dictionary = {}
var _phase2_threshold: float = 0.66
var _phase3_threshold: float = 0.33
var _fire_rate_mult: float = 1.0
var _seq_idx: int = 0
var _charging: bool = false
var _hit_flash_t: float = 0.0
var _home: Vector2 = Vector2(240.0, 110.0)
var _sprite: Sprite2D
var _tele_layer: Node2D
var _telegraphs: Array[Dictionary] = []
var _anim: String = "idle"
var _anim_t: float = 0.0
var _anim_loop: bool = true
var _armored: bool = true
var _stun_t: float = 0.0
var _light: String = "green"
var _red_moved: bool = false
var _recording: bool = false
var _record: Array = []
var _record_t0: float = 0.0
var _clock_t: float = 0.0


func setup(id: String) -> void:
	boss_id = id


func _ready() -> void:
	add_to_group("enemies")
	_def = Malha.get_boss_def(boss_id)
	boss_name = String(_def.get("name", boss_id.to_upper()))
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	_fire_rate_mult = maxf(0.1, float(diff_cfg.get("enemy_fire_rate_mult", 1.0)))
	max_hp = float(_def.get("hp", 2400.0)) * float(diff_cfg.get("enemy_hp_mult", 1.0)) * float(Malha.data.get("boss_hp_mult", 1.0))
	hp = max_hp
	_home = Vector2(240.0, 112.0) if boss_id == "fortaleza" else STAGE_POS[1]
	global_position = _home
	z_index = int(_home.y)

	_sprite = $Sprite2D
	var sheet: String = "res://assets/sprites/boss/boss_%s_sheet.png" % boss_id
	if ResourceLoader.exists(sheet):
		_sprite.texture = load(sheet)
		_sprite.hframes = 9
		_sprite.vframes = 5
		_sprite.offset = Vector2(0.0, -14.0)
	_play("idle")

	_tele_layer = Node2D.new()
	_tele_layer.top_level = true
	_tele_layer.z_index = 2
	_tele_layer.z_as_relative = false
	_tele_layer.draw.connect(_draw_telegraphs)
	add_child(_tele_layer)
	Events.boss_hp_changed.emit(hp, max_hp)


func get_texture() -> Texture2D:
	var img: Image = _sprite.texture.get_image()
	return ImageTexture.create_from_image(img.get_region(Rect2i(0, 0, FRAME, FRAME)))


func get_mechanic_tip() -> String:
	match boss_id:
		"fortaleza":
			return "Faça a Fortaleza bater na parede: a couraça abre!"
		"sinaleiro":
			return "SINAL VERMELHO: fique parado até o verde!"
		"relojoeiro":
			return "As balas rebobinam e voltam pelo mesmo caminho!"
	return ""


func start_fight() -> void:
	if _fight_started:
		return
	_fight_started = true
	_brain()


func _play(anim: String, loop: bool = true) -> void:
	if _anim == anim and loop and _anim_loop:
		return
	_anim = anim
	_anim_t = 0.0
	_anim_loop = loop


func _physics_process(delta: float) -> void:
	z_index = int(global_position.y)
	_anim_t += delta
	var f: int = int(_anim_t * 12.0)
	if _anim_loop:
		f = 1 + f % 8
	else:
		f = mini(8, f)
		if f >= 8 and _anim != "death" and _anim != "special":
			_play("idle")
	_sprite.frame_coords = Vector2i(f, int(ROWS.get(_anim, 0)))
	if _hit_flash_t > 0.0:
		_hit_flash_t -= delta
		_sprite.modulate = Color(2.6, 2.6, 2.6, _sprite.modulate.a)
	elif _stun_t > 0.0:
		_sprite.modulate = Color(1.3, 1.0, 0.7, _sprite.modulate.a)
	elif phase == 3:
		_sprite.modulate = Color(1.0, 0.82 + 0.12 * sin(_anim_t * 8.0), 0.78, _sprite.modulate.a)
	else:
		_sprite.modulate = Color(1.0, 1.0, 1.0, _sprite.modulate.a)
	if _stun_t > 0.0:
		_stun_t -= delta
		if _stun_t <= 0.0 and phase < 3:
			_armored = true
	_clock_t += delta
	for tg in _telegraphs:
		tg["t"] = float(tg["t"]) + delta
	_tele_layer.queue_redraw()
	var player: Node2D = _player()
	if player == null:
		return
	if _charging and player.global_position.distance_to(global_position) < 22.0 and player.has_method("take_damage"):
		player.take_damage(1, global_position)
	if _light == "red" and not _red_moved and player.velocity.length() > 25.0:
		_red_moved = true
		if player.has_method("take_damage"):
			player.take_damage(1, global_position)


func _brain() -> void:
	while not _is_dead and is_inside_tree():
		if is_transitioning or get_tree().paused or _stun_t > 0.0:
			await get_tree().physics_frame
			continue
		var p: int = phase
		var moves: Array = (_def.get("phases", [["salva"]]) as Array)[p - 1]
		var move: String = String(moves[_seq_idx % moves.size()])
		_seq_idx += 1
		await _run_move(move)
		if _is_dead or not is_inside_tree():
			return
		if phase != p:
			_seq_idx = 0
			continue
		if _anim != "death":
			_play("idle")
		await _wait(REST[p - 1])


func _run_move(move: String) -> void:
	match move:
		"salva": await _move_salva()
		"investida": await _move_investida()
		"drones": await _move_minions("drone")
		"muralha": await _move_muralha()
		"fornalha": await _move_fornalha()
		"espiral": await _move_espiral()
		"sinal": await _move_sinal()
		"trilhos": await _move_trilhos()
		"lanterna": await _move_lanterna()
		"torretas": await _move_minions("turret")
		"vermelho": await _move_vermelho()
		"teleporte": await _teleport(STAGE_POS[randi_range(0, STAGE_POS.size() - 1)])
		"ponteiros": await _recorded(_move_ponteiros)
		"tique": await _recorded(_move_tique)
		"badalada": await _recorded(_move_badalada)
		"rebobinar": await _move_rebobinar()
		"eco": await _move_eco()


func _ok(p: int) -> bool:
	return is_inside_tree() and not _is_dead and not is_transitioning and phase == p and _stun_t <= 0.0


func _wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds / _fire_rate_mult, false).timeout


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
	var player: Node2D = _player()
	if player == null:
		return Vector2.LEFT
	return (player.global_position - global_position).normalized()


func _fire(pos: Vector2, dir: Vector2, speed: float) -> void:
	BulletManager.spawn_bullet(pos, dir, speed, false, 1.0)
	if _recording:
		_record.append([_clock_t - _record_t0, pos, dir, speed])


func _ring(pos: Vector2, count: int, speed: float, offset_deg: float = 0.0) -> void:
	var step: float = TAU / float(count)
	for i in range(count):
		_fire(pos, Vector2.RIGHT.rotated(deg_to_rad(offset_deg) + step * float(i)), speed)


func _add_tele(kind: String, data: Dictionary) -> Dictionary:
	var tg: Dictionary = data.duplicate()
	tg["kind"] = kind
	tg["t"] = 0.0
	_telegraphs.append(tg)
	return tg


func _clear_tele(tg: Dictionary) -> void:
	_telegraphs.erase(tg)


func _move_to(target: Vector2, speed: float) -> void:
	var p: int = phase
	target = Arena.clamp_point(target, Arena.BOSS_STEP)
	_play("move")
	while _ok(p) and global_position.distance_to(target) > 2.0:
		var dt: float = await _tick()
		global_position = global_position.move_toward(target, speed * dt)


func _move_salva() -> void:
	var p: int = phase
	var tg: Dictionary = _add_tele("circle", {"pos": global_position, "r": 30.0})
	await _wait(0.45)
	_clear_tele(tg)
	_play("attack", false)
	for r in range([3, 4, 5][p - 1]):
		if not _ok(p):
			return
		_ring(global_position, 14 + 2 * p, 70.0 + 10.0 * float(p), 0.0 if r % 2 == 0 else 180.0 / float(14 + 2 * p))
		AudioManager.play_sfx("blip", 0.05)
		await _wait(0.42)


func _move_investida() -> void:
	var p: int = phase
	for k in range([1, 2, 3][p - 1]):
		if not _ok(p):
			return
		var dir: Vector2 = _to_player()
		var tg: Dictionary = _add_tele("line", {"from": global_position, "to": global_position + dir * 460.0})
		AudioManager.play_sfx("whistle", 0.05)
		await _wait(0.75 if p == 1 else 0.55)
		_clear_tele(tg)
		if not _ok(p):
			return
		_charging = true
		_play("move")
		var speed: float = 250.0 + 30.0 * float(p)
		var hit_wall: bool = false
		while _ok(p):
			var dt: float = await _tick()
			var nxt: Vector2 = global_position + dir * speed * dt
			if not Arena.BOSS_FLOOR.has_point(nxt):
				global_position = Arena.clamp_point(nxt, Arena.BOSS_FLOOR)
				hit_wall = true
				break
			global_position = nxt
		_charging = false
		if not hit_wall:
			return
		Events.request_screen_shake.emit(4.0, 0.35)
		AudioManager.play_sfx("clang")
		_ring(global_position, 10 + 2 * p, 75.0, randf() * 30.0)
		if p < 3:
			_armored = false
			_stun_t = 2.4
			_play("special", false)
			Events.item_obtained.emit("COURAÇA ABERTA — ATAQUE AGORA!")
			while _stun_t > 0.0 and is_inside_tree() and not _is_dead:
				await get_tree().physics_frame
			if not _ok(p):
				return
		else:
			await _wait(0.3)
	await _move_to(_home, 130.0)


func _move_muralha() -> void:
	var p: int = phase
	for w in range([2, 3, 4][p - 1]):
		if not _ok(p):
			return
		var vertical: bool = p >= 2 and w % 2 == 1
		var slots: int = 12 if not vertical else 16
		var gap: int = randi_range(1, slots - 4)
		var gap_size: int = 3 if p < 3 else 2
		var tg: Dictionary
		if vertical:
			tg = _add_tele("vgap", {"x": 40.0 + float(gap) * 25.0, "w": float(gap_size) * 25.0})
		else:
			tg = _add_tele("gap", {"y": 84.0 + float(gap) * 14.0, "h": float(gap_size) * 14.0})
		_play("attack", false)
		await _wait(0.55)
		_clear_tele(tg)
		for k in range(slots):
			if k >= gap and k < gap + gap_size:
				continue
			if vertical:
				_fire(Vector2(40.0 + float(k) * 25.0 + 12.0, 70.0), Vector2.DOWN, 80.0 + 8.0 * float(p))
			else:
				_fire(Vector2(456.0, 84.0 + float(k) * 14.0 + 7.0), Vector2.LEFT, 85.0 + 10.0 * float(p))
		AudioManager.play_sfx("blip", 0.05)
		await _wait(1.0)


func _move_fornalha() -> void:
	var p: int = phase
	_play("special", false)
	var spots: Array[Vector2] = []
	var player: Node2D = _player()
	var center: Vector2 = player.global_position if player != null else Vector2(240.0, 160.0)
	for i in range(3 if p < 3 else 4):
		spots.append(Arena.clamp_point(center + Vector2(randf_range(-80.0, 80.0), randf_range(-50.0, 50.0)), Arena.BOSS_FLOOR))
	var tgs: Array[Dictionary] = []
	for sp in spots:
		tgs.append(_add_tele("fire", {"pos": sp, "r": 16.0}))
	AudioManager.play_sfx("steam_pulse", 0.05)
	await _wait(1.1)
	for tg in tgs:
		_clear_tele(tg)
	if not _ok(p):
		return
	for sp in spots:
		_ring(sp, 8 + 2 * p, 90.0, randf() * 40.0)
	Events.request_screen_shake.emit(2.5, 0.2)
	AudioManager.play_sfx("bomb_explode", 0.05)
	_play("idle")


func _move_espiral() -> void:
	var p: int = phase
	_play("attack", false)
	var a: float = 0.0
	var t: float = 0.0
	var shot_t: float = 0.0
	while _ok(p) and t < 3.2:
		var dt: float = await _tick()
		t += dt
		shot_t -= dt
		if shot_t <= 0.0:
			shot_t = 0.09
			for i in range(3):
				_fire(global_position, Vector2.RIGHT.rotated(a + TAU * float(i) / 3.0), 85.0)
			a += 0.33


func _move_minions(type: String) -> void:
	var p: int = phase
	var level: Node = get_parent()
	if level == null or not level.has_method("spawn_enemy"):
		return
	var alive: int = get_tree().get_nodes_in_group("enemies").size() - 1
	if alive >= 4:
		if boss_id == "fortaleza":
			await _move_salva()
		else:
			await _move_sinal()
		return
	_play("special", false)
	AudioManager.play_sfx("boss_phase", 0.05)
	var spots: Array[Vector2] = [Vector2(100.0, 110.0), Vector2(100.0, 205.0), Vector2(380.0, 205.0)]
	if type == "turret":
		spots = [Vector2(150.0, 120.0), Vector2(330.0, 200.0), Vector2(150.0, 200.0)]
	for i in range([2, 2, 3][p - 1]):
		var tg: Dictionary = _add_tele("circle", {"pos": spots[i], "r": 14.0})
		await _wait(0.25)
		_clear_tele(tg)
		if not _ok(p):
			return
		level.spawn_enemy(type, spots[i])
	await _wait(0.5)


func _move_sinal() -> void:
	var p: int = phase
	await _teleport(STAGE_POS[randi_range(0, STAGE_POS.size() - 1)])
	for k in range(3):
		if not _ok(p):
			return
		var dir: Vector2 = _to_player()
		var tg: Dictionary = _add_tele("line", {"from": global_position, "to": global_position + dir * 400.0})
		_play("attack", false)
		await _wait(0.45 if k == 0 else 0.25)
		_clear_tele(tg)
		if not _ok(p):
			return
		var dir2: Vector2 = _to_player()
		var n: int = 5 if p < 3 else 7
		for i in range(n):
			_fire(global_position, dir2.rotated(deg_to_rad(-20.0 + 40.0 * float(i) / float(n - 1))), 140.0)
		AudioManager.play_sfx("blip", 0.05)
		await _wait(0.35)


func _move_trilhos() -> void:
	var p: int = phase
	var lanes: Array[int] = [0, 1, 2, 3, 4]
	lanes.shuffle()
	var picked: Array[int] = lanes.slice(0, [2, 3, 3][p - 1])
	var tgs: Array[Dictionary] = []
	for lane in picked:
		tgs.append(_add_tele("lane", {"y": LANE_TOP + float(lane) * LANE_H, "h": LANE_H}))
	_play("attack", false)
	AudioManager.play_sfx("whistle", 0.05)
	await _wait(1.0)
	for tg in tgs:
		_clear_tele(tg)
	var t: float = 0.0
	var shot_t: float = 0.0
	while _ok(p) and t < 1.3:
		var dt: float = await _tick()
		t += dt
		shot_t -= dt
		if shot_t <= 0.0:
			shot_t = 0.07
			for lane in picked:
				_fire(Vector2(462.0, LANE_TOP + float(lane) * LANE_H + randf_range(5.0, LANE_H - 5.0)), Vector2.LEFT, 210.0)


func _move_lanterna() -> void:
	var p: int = phase
	await _teleport(STAGE_POS[1] + Vector2(0.0, 50.0))
	_play("special", false)
	var arms: int = 4 if p < 3 else 6
	var a: float = 0.0
	var spin: float = 0.11 * (-1.0 if p == 2 else 1.0)
	var t: float = 0.0
	var shot_t: float = 0.0
	while _ok(p) and t < 3.0:
		var dt: float = await _tick()
		t += dt
		shot_t -= dt
		if shot_t <= 0.0:
			shot_t = 0.1
			for i in range(arms):
				_fire(global_position, Vector2.RIGHT.rotated(a + TAU * float(i) / float(arms)), 90.0)
			a += spin
	_play("idle")
	await _teleport(STAGE_POS[1])


func _move_vermelho() -> void:
	var p: int = phase
	_set_light("yellow")
	_play("special", false)
	for i in range(2 + p):
		_ring(global_position, 12, 70.0, float(i) * 15.0)
		await _wait(0.3)
	await _wait(0.6)
	if not _ok(p):
		_set_light("green")
		return
	_set_light("red")
	_red_moved = false
	BulletManager.freeze_enemy_bullets(Color(1.6, 0.5, 0.5))
	await _wait(2.0 + 0.3 * float(p))
	_set_light("green")
	BulletManager.release_enemy_bullets(false, 1.0 + 0.15 * float(p - 1))


func _set_light(state: String) -> void:
	_light = state
	signal_light_changed.emit(state)
	if state == "red":
		AudioManager.play_sfx("whistle", 0.0)
		Events.item_obtained.emit("SINAL VERMELHO — NÃO SE MEXA!")
	elif state == "yellow":
		AudioManager.play_sfx("tick", 0.0)


func _teleport(target: Vector2) -> void:
	var p: int = phase
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.2)
	await tw.finished
	if not _ok(p):
		_sprite.modulate.a = 1.0
		return
	if boss_id == "sinaleiro" and p >= 2:
		_ring(global_position, 8, 60.0)
	global_position = target
	var tw2 := create_tween()
	tw2.tween_property(_sprite, "modulate:a", 1.0, 0.2)
	await tw2.finished


func _recorded(move: Callable) -> void:
	_recording = true
	_record.clear()
	_record_t0 = _clock_t
	await move.call()
	_recording = false


func _move_ponteiros() -> void:
	var p: int = phase
	_play("attack", false)
	var hour: float = randf() * TAU
	var minute: float = hour + PI
	var t: float = 0.0
	var shot_t: float = 0.0
	while _ok(p) and t < 2.6:
		var dt: float = await _tick()
		t += dt
		hour += dt * 0.9
		minute += dt * (2.6 + 0.4 * float(p))
		shot_t -= dt
		if shot_t <= 0.0:
			shot_t = 0.11
			_fire(global_position, Vector2.RIGHT.rotated(hour), 80.0)
			_fire(global_position, Vector2.RIGHT.rotated(minute), 110.0)
			if p >= 2:
				_fire(global_position, Vector2.RIGHT.rotated(minute + PI), 110.0)


func _move_tique() -> void:
	var p: int = phase
	for k in range(8 + 4 * p):
		if not _ok(p):
			return
		AudioManager.play_sfx("tick", 0.0)
		_fire(global_position, _to_player(), 150.0)
		if k % 4 == 3:
			_play("attack", false)
			_ring(global_position, 12, 75.0, float(k) * 7.0)
		await _wait(0.25)


func _move_badalada() -> void:
	var p: int = phase
	var player: Node2D = _player()
	if player == null:
		return
	var center: Vector2 = player.global_position
	var tgs: Array[Dictionary] = []
	var pts: Array[Vector2] = []
	for h in range(12):
		var pt: Vector2 = center + Vector2.UP.rotated(TAU * float(h) / 12.0) * 90.0
		pts.append(pt)
		tgs.append(_add_tele("dot", {"pos": pt}))
	_play("special", false)
	for h in range(12):
		AudioManager.play_sfx("tick", 0.0)
		await _wait(0.06 if p >= 2 else 0.09)
	await _wait(0.4)
	for tg in tgs:
		_clear_tele(tg)
	if not _ok(p):
		return
	AudioManager.play_sfx("whistle", 0.0)
	for pt in pts:
		_fire(pt, (center - pt).normalized(), 70.0 + 10.0 * float(p))
		if p == 3:
			_fire(pt, (center - pt).normalized().rotated(0.35), 60.0)
	_play("idle")


func _move_rebobinar() -> void:
	var p: int = phase
	_play("attack", false)
	_ring(global_position, 18 + 4 * p, 95.0, randf() * 20.0)
	await _wait(0.4)
	_ring(global_position, 18 + 4 * p, 75.0, randf() * 20.0)
	await _wait(0.6)
	if not _ok(p):
		return
	_play("special", false)
	var n: int = BulletManager.freeze_enemy_bullets()
	Events.item_obtained.emit("REBOBINANDO...")
	AudioManager.play_sfx("tick", 0.0)
	await _wait(0.6)
	BulletManager.release_enemy_bullets(true, 1.1)
	if n > 0:
		Events.request_screen_shake.emit(1.5, 0.2)


func _move_eco() -> void:
	var p: int = phase
	if _record.is_empty():
		await _move_tique()
		return
	var echo: Array = _record.duplicate()
	_play("special", false)
	await _wait(ECHO_DELAY * 0.5)
	var start: float = _clock_t
	var i: int = 0
	while _ok(p) and i < echo.size():
		var entry: Array = echo[i]
		if _clock_t - start >= float(entry[0]):
			BulletManager.spawn_echo(entry[1], entry[2], float(entry[3]) * 0.9)
			i += 1
		else:
			await _tick()


func take_damage(amount: float) -> void:
	if _is_dead:
		return
	if amount < 50000.0 and is_transitioning:
		return
	var mult: float = 1.0
	if boss_id == "fortaleza":
		mult = 1.6 if not _armored else 0.3
	hp = maxf(0.0, hp - amount * mult)
	_hit_flash_t = 0.06
	Events.boss_hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
		return
	var ratio: float = hp / max_hp
	if phase == 1 and ratio <= _phase2_threshold:
		_transition_to_phase(2)
	elif phase == 2 and ratio <= _phase3_threshold:
		_transition_to_phase(3)


func is_vulnerable() -> bool:
	return boss_id != "fortaleza" or not _armored


func _transition_to_phase(next_phase: int) -> void:
	is_transitioning = true
	_charging = false
	_stun_t = 0.0
	_telegraphs.clear()
	if _light != "green":
		_set_light("green")
		BulletManager.release_enemy_bullets(false)
	phase = next_phase
	_armored = not (boss_id == "fortaleza" and phase == 3)
	BulletManager.clear_all_bullets()
	_sprite.modulate.a = 1.0
	_play("special", false)
	AudioManager.play_sfx("boss_phase", 0.02)
	Events.request_screen_shake.emit(4.0, 0.6)
	Events.request_screen_flash.emit(0.15)
	Events.boss_phase_changed.emit(phase)
	await _wait(0.9)
	if _is_dead:
		return
	await _move_to_free(_home)
	is_transitioning = false


func _move_to_free(target: Vector2) -> void:
	_play("move")
	while is_inside_tree() and not _is_dead and global_position.distance_to(target) > 2.0:
		var dt: float = await _tick()
		global_position = global_position.move_toward(target, 140.0 * dt)
	_play("idle")


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	is_transitioning = true
	_charging = false
	_telegraphs.clear()
	if _light != "green":
		_set_light("green")
	TrainClock.is_running = false
	BulletManager.clear_all_bullets()
	_sprite.modulate.a = 1.0
	_play("death", false)
	AudioManager.play_sfx("bomb_explode")
	Events.request_screen_shake.emit(3.5, 1.5)
	Engine.time_scale = 0.4
	await get_tree().create_timer(1.6, true, false, true).timeout
	Engine.time_scale = GameState.debug_time_scale
	if not is_inside_tree():
		return
	Malha.complete_current()
	SceneRouter.goto_scene(Malha.MAP_SCENE)


func _exit_tree() -> void:
	Engine.time_scale = GameState.debug_time_scale


func _draw_telegraphs() -> void:
	for tg in _telegraphs:
		var blink: float = 0.35 + 0.25 * sin(float(tg["t"]) * 18.0)
		var col := Color(TELE_COLOR, blink)
		match String(tg["kind"]):
			"circle":
				_tele_layer.draw_arc(tg["pos"], float(tg["r"]), 0.0, TAU, 24, col, 2.0)
			"fire":
				_tele_layer.draw_circle(tg["pos"], float(tg["r"]) * (0.6 + 0.4 * minf(1.0, float(tg["t"]))), Color(1.0, 0.45, 0.15, blink * 0.6))
				_tele_layer.draw_arc(tg["pos"], float(tg["r"]), 0.0, TAU, 20, Color(1.0, 0.6, 0.2, blink + 0.2), 1.0)
			"dot":
				_tele_layer.draw_circle(tg["pos"], 3.0, Color(0.45, 0.95, 1.0, blink + 0.3))
				_tele_layer.draw_arc(tg["pos"], 6.0, 0.0, TAU, 12, Color(0.45, 0.95, 1.0, blink), 1.0)
			"line":
				_tele_layer.draw_line(tg["from"], tg["to"], col, 3.0)
			"lane":
				_tele_layer.draw_rect(Rect2(Arena.BOSS_FLOOR.position.x, float(tg["y"]), Arena.BOSS_FLOOR.size.x, float(tg["h"])), Color(TELE_COLOR, blink * 0.45))
			"gap":
				_tele_layer.draw_rect(Rect2(440.0, float(tg["y"]), 20.0, float(tg["h"])), Color(Color("#8fb8c4"), blink + 0.2))
			"vgap":
				_tele_layer.draw_rect(Rect2(float(tg["x"]), 66.0, float(tg["w"]), 14.0), Color(Color("#8fb8c4"), blink + 0.2))
	if _light != "green" and not _is_dead:
		var post := global_position + Vector2(30.0, -40.0)
		_tele_layer.draw_rect(Rect2(post + Vector2(-5.0, -4.0), Vector2(10.0, 22.0)), Color("#0d0b12"))
		_tele_layer.draw_circle(post + Vector2(0.0, 1.0), 3.5, Color("#f2c35b") if _light == "yellow" else Color("#3a2a1a"))
		_tele_layer.draw_circle(post + Vector2(0.0, 11.0), 3.5, Color("#ff3d3d") if _light == "red" else Color("#3a1a1a"))
		if _light == "red":
			_tele_layer.draw_rect(Arena.BOSS_FLOOR, Color(1.0, 0.1, 0.1, 0.08))
