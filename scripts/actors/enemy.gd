extends CharacterBody2D

const FX_SPARK: Texture2D = preload("res://assets/sprites/fx/hit_spark.png")
const FX_TELEGRAPH: Texture2D = preload("res://assets/sprites/fx/telegraph_dot.png")
const FX_DASH_LINE: Texture2D = preload("res://assets/sprites/fx/telegraph_dash.png")
const FX_HP_BACK: Texture2D = preload("res://assets/sprites/fx/hpbar_back.png")
const FX_HP_FILL: Texture2D = preload("res://assets/sprites/fx/hpbar_fill.png")

signal enemy_killed(pos: Vector2, is_elite: bool)

enum State { SPAWN, MOVE, TELEGRAPH, ATTACK, RECOVER, DEAD }

@export var enemy_type: String = "sentinel"
@export var affix: String = ""

var state: State = State.SPAWN
var hp: float = 30.0
var max_hp: float = 30.0
var _cfg: Dictionary = {}
var _fire_rate_mult: float = 1.0
var _state_timer: float = 0.5
var _spiral_angle: float = 0.0
var _shot_accum: float = 0.0
var _orbit_time: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
var _player_ref: Node2D
var _ring_step_index: int = 0
var _staggered_half_hp: bool = false
var _anim_t: float = 0.0
var _hit_flash_t: float = 0.0
var _strip: bool = false
var _attack_anim_t: float = -1.0
var _bombs: Array[Vector3] = []
var _facing: Vector2 = Vector2.LEFT
var _shield_down_t: float = 0.0
var _exploded: bool = false

const STRIP_TYPES: Array[String] = ["bomber", "shield", "spark", "flamer", "medic", "magnet"]
const FALLBACK_TEX: Dictionary = {"flamer": ["wrench", "#ff9a5a"], "medic": ["drone", "#7be08f"], "magnet": ["sentinel", "#b38cff"]}

var _base_tint: Color = Color.WHITE
var _speed_mult: float = 1.0
var _spray_t: float = 0.0
var _pull_t: float = 0.0
var _heal_beam: Array = []


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED # linha de mira e barra de vida usam texturas repetidas
	add_to_group("enemies")
	var all_enemies: Dictionary = GameState.balance_data.get("enemies", {})
	_cfg = all_enemies.get(enemy_type, {})
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	var hp_mult: float = float(diff_cfg.get("enemy_hp_mult", 1.0))
	_fire_rate_mult = maxf(0.1, float(diff_cfg.get("enemy_fire_rate_mult", 1.0)))

	max_hp = float(_cfg.get("hp", 30.0)) * hp_mult * Malha.enemy_hp_scale()
	var affix_cfg: Dictionary = Malha.get_affix(affix) if affix != "" else {}
	max_hp *= float(affix_cfg.get("hp_mult", 1.0))
	_speed_mult = float(affix_cfg.get("speed_mult", 1.0))
	_fire_rate_mult *= float(affix_cfg.get("fire_mult", 1.0))
	hp = max_hp
	_state_timer = 0.5
	var tex_path: String = "res://assets/sprites/enemies/%s.png" % enemy_type
	if not ResourceLoader.exists(tex_path) and FALLBACK_TEX.has(enemy_type) and has_node("Sprite2D"):
		($Sprite2D as Sprite2D).texture = load("res://assets/sprites/enemies/%s.png" % String(FALLBACK_TEX[enemy_type][0]))
		_base_tint = Color(String(FALLBACK_TEX[enemy_type][1]))
	elif ResourceLoader.exists(tex_path) and has_node("Sprite2D"):
		($Sprite2D as Sprite2D).texture = load(tex_path)
		if enemy_type in STRIP_TYPES:
			_strip = true
			($Sprite2D as Sprite2D).hframes = 9
			($Sprite2D as Sprite2D).vframes = 2
			($Sprite2D as Sprite2D).offset = Vector2(0.0, -4.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_anim_t += delta
	if _hit_flash_t > 0.0:
		_hit_flash_t -= delta

	_state_timer -= delta
	var player: Node2D = _get_player()
	if player == null:
		return

	if has_node("Sprite2D"):
		var spr: Sprite2D = $Sprite2D
		spr.flip_h = player.global_position.x < global_position.x
		if _strip:
			if _attack_anim_t >= 0.0:
				_attack_anim_t += delta
				spr.frame_coords = Vector2i(mini(8, int(_attack_anim_t * 14.0)), 1)
				if _attack_anim_t * 14.0 >= 9.0:
					_attack_anim_t = -1.0
			else:
				spr.frame_coords = Vector2i(1 + int(_anim_t * 10.0) % 8, 0)
			spr.modulate = Color(3.0, 3.0, 3.0, 1.0) if _hit_flash_t > 0.0 else _base_tint
		elif _hit_flash_t > 0.0:
			spr.frame_coords = Vector2i(0, 3)
			spr.modulate = Color(3.0, 3.0, 3.0, 1.0)
		else:
			spr.modulate = _base_tint
			spr.frame_coords = Vector2i(int(_anim_t * 8.0) % 4, 0)

	_update_bombs(delta)
	if enemy_type == "shield":
		if _shield_down_t > 0.0:
			_shield_down_t -= delta
		else:
			_facing = _facing.slerp((player.global_position - global_position).normalized(), minf(1.0, delta * 3.0))

	match state:
		State.SPAWN:
			if _state_timer <= 0.0:
				state = State.MOVE
		State.MOVE:
			_process_move(delta, player)
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_enter_attack(player)
		State.ATTACK:
			_process_attack(delta, player)
		State.RECOVER:
			if _state_timer <= 0.0:
				state = State.MOVE

	_update_special(delta, player)
	velocity *= _speed_mult
	move_and_slide()
	global_position = Arena.clamp_point(global_position, Arena.ENEMY)
	z_index = int(global_position.y)
	queue_redraw()


func _process_move(delta: float, player: Node2D) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var spd: float = float(_cfg.get("speed", 40.0))

	match enemy_type:
		"sentinel":
			if dist > float(_cfg.get("stop_dist", 110.0)):
				velocity = to_player.normalized() * spd
			else:
				_charge_dir = to_player.normalized()
				state = State.TELEGRAPH
				_state_timer = float(_cfg.get("telegraph", 0.5))
		"drone":
			_orbit_time += delta
			var orbit_min: float = float(_cfg.get("orbit_min", 120.0))
			var orbit_max: float = float(_cfg.get("orbit_max", 160.0))
			var sine_amp: float = float(_cfg.get("sine_amp", 24.0))
			var sine_freq: float = float(_cfg.get("sine_freq", 1.5))
			var desired_dist: float = (orbit_min + orbit_max) * 0.5 + sin(_orbit_time * TAU * sine_freq) * sine_amp
			var radial: Vector2 = to_player.normalized() * ((dist - desired_dist) * 2.0)
			var tangent: Vector2 = to_player.normalized().orthogonal() * spd
			velocity = (radial + tangent).limit_length(spd)
			if _state_timer <= 0.0:
				var b_spd: float = float(_cfg.get("bullet_speed", 110.0))
				BulletManager.spawn_bullet(global_position, to_player.normalized(), b_spd, false)
				_state_timer = float(_cfg.get("cooldown", 1.8)) / _fire_rate_mult
		"wrench":
			velocity = to_player.normalized() * spd
			if dist <= float(_cfg.get("trigger_dist", 180.0)):
				_charge_dir = to_player.normalized()
				state = State.TELEGRAPH
				_state_timer = float(_cfg.get("telegraph", 0.6))
		"turret":
			velocity = Vector2.ZERO
			state = State.ATTACK
			_shot_accum = 0.0
			_state_timer = float(_cfg.get("fire_duration", 2.0))
		"sniper":
			var min_d: float = float(_cfg.get("min_dist", 180.0))
			var max_d: float = float(_cfg.get("max_dist", 220.0))
			if dist < min_d:
				velocity = -to_player.normalized() * spd
			elif dist > max_d:
				velocity = to_player.normalized() * spd
			else:
				_charge_dir = to_player.normalized()
				state = State.TELEGRAPH
				_state_timer = float(_cfg.get("aim_time", 0.8))
		"freighter":
			velocity = to_player.normalized() * spd
			if _state_timer <= 0.0:
				_charge_dir = to_player.normalized()
				state = State.TELEGRAPH
				_state_timer = float(_cfg.get("ring_telegraph", 0.8))
		"bomber":
			var hover: Vector2 = player.global_position + Vector2(sin(_anim_t * 1.3) * 70.0, -60.0)
			velocity = (hover - global_position).limit_length(spd)
			if _state_timer <= 0.0:
				_state_timer = float(_cfg.get("cooldown", 2.4)) / _fire_rate_mult
				_attack_anim_t = 0.0
				_bombs.append(Vector3(global_position.x, global_position.y + 10.0, float(_cfg.get("fuse", 1.0))))
		"shield":
			velocity = to_player.normalized() * spd if dist > 70.0 else Vector2.ZERO
			if _state_timer <= 0.0:
				_charge_dir = to_player.normalized()
				state = State.TELEGRAPH
				_state_timer = float(_cfg.get("telegraph", 0.5))
				_shield_down_t = float(_cfg.get("open_time", 1.4))
				_attack_anim_t = 0.0
		"flamer":
			velocity = to_player.normalized() * spd if dist > float(_cfg.get("range", 70.0)) else Vector2.ZERO
			if dist <= float(_cfg.get("range", 70.0)) + 10.0 and _state_timer <= 0.0:
				_charge_dir = to_player.normalized()
				state = State.TELEGRAPH
				_state_timer = float(_cfg.get("telegraph", 0.45))
				_attack_anim_t = 0.0
		"medic":
			var keep: float = float(_cfg.get("keep_dist", 150.0))
			velocity = (-to_player.normalized() if dist < keep else to_player.normalized().orthogonal()) * spd
			if _state_timer <= 0.0:
				_state_timer = float(_cfg.get("cooldown", 3.2)) / _fire_rate_mult
				_medic_heal()
				BulletManager.spawn_bullet(global_position, to_player.normalized(), float(_cfg.get("bullet_speed", 90.0)), false)
		"magnet":
			velocity = to_player.normalized() * spd
			if _state_timer <= 0.0:
				state = State.TELEGRAPH
				_state_timer = float(_cfg.get("charge", 1.0))
				_attack_anim_t = 0.0
		"spark":
			velocity = to_player.normalized() * spd
			if dist <= float(_cfg.get("trigger_dist", 34.0)):
				state = State.TELEGRAPH
				_state_timer = float(_cfg.get("telegraph", 0.5))
				_attack_anim_t = 0.0


func _enter_attack(player: Node2D) -> void:
	state = State.ATTACK
	var to_player: Vector2 = (player.global_position - global_position).normalized()

	match enemy_type:
		"sentinel":
			var b_cnt: int = int(_cfg.get("bullet_count", 3))
			var spread: float = float(_cfg.get("spread_deg", 18.0)) * 2.0
			var b_spd: float = float(_cfg.get("bullet_speed", 90.0))
			BulletManager.spawn_fan(global_position, to_player, b_cnt, spread, b_spd, false)
			state = State.RECOVER
			_state_timer = float(_cfg.get("cooldown", 2.2)) / _fire_rate_mult
		"wrench":
			_state_timer = float(_cfg.get("charge_duration", 0.5))
		"sniper":
			var b_spd: float = float(_cfg.get("bullet_speed", 220.0))
			BulletManager.spawn_bullet(global_position, _charge_dir, b_spd, false)
			state = State.RECOVER
			_state_timer = float(_cfg.get("cooldown", 2.8)) / _fire_rate_mult
		"freighter":
			_ring_step_index = 0
			_state_timer = 1.2
		"shield":
			var b_spd: float = float(_cfg.get("bullet_speed", 130.0))
			BulletManager.spawn_fan(global_position, to_player, 3, 24.0, b_spd, false)
			state = State.RECOVER
			_state_timer = float(_cfg.get("cooldown", 2.6)) / _fire_rate_mult
		"flamer":
			_spray_t = float(_cfg.get("spray_time", 1.2))
			state = State.RECOVER
			_state_timer = float(_cfg.get("cooldown", 2.4)) / _fire_rate_mult
		"magnet":
			_pull_t = float(_cfg.get("pull_time", 1.6))
			BulletManager.spawn_ring(global_position, int(_cfg.get("ring_bullets", 10)), float(_cfg.get("ring_speed", 70.0)))
			AudioManager.play_sfx("steam_pulse", 0.05)
			state = State.RECOVER
			_state_timer = float(_cfg.get("cooldown", 4.0)) / _fire_rate_mult
		"spark":
			_explode_spark(int(_cfg.get("ring_bullets", 12)))
			state = State.DEAD
			Events.enemy_died.emit(global_position, false)
			queue_free()


func _update_special(delta: float, player: Node2D) -> void:
	if _spray_t > 0.0:
		_spray_t -= delta
		_shot_accum += delta
		var dir: Vector2 = (player.global_position - global_position).normalized()
		while _shot_accum >= 0.09:
			_shot_accum -= 0.09
			for k in range(2):
				BulletManager.spawn_bullet(global_position + dir * 8.0, dir.rotated(randf_range(-0.35, 0.35)), float(_cfg.get("bullet_speed", 120.0)) * randf_range(0.85, 1.1), false, 1.0, float(_cfg.get("bullet_life", 0.75)))
	if _pull_t > 0.0:
		_pull_t -= delta
		if "extra_push" in player:
			player.set("extra_push", (global_position - player.global_position).normalized() * float(_cfg.get("pull_speed", 70.0)))
	for i in range(_heal_beam.size() - 1, -1, -1):
		_heal_beam[i][1] = float(_heal_beam[i][1]) - delta
		if float(_heal_beam[i][1]) <= 0.0:
			_heal_beam.remove_at(i)


func _medic_heal() -> void:
	var best: Node = null
	var best_ratio: float = 0.95
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node2D) or node.get("enemy_type") == null or node.get("max_hp") == null:
			continue
		if (node as Node2D).global_position.distance_to(global_position) > float(_cfg.get("heal_range", 170.0)):
			continue
		var ratio: float = float(node.get("hp")) / maxf(1.0, float(node.get("max_hp")))
		if ratio < best_ratio:
			best_ratio = ratio
			best = node
	if best == null:
		return
	best.set("hp", minf(float(best.get("max_hp")), float(best.get("hp")) + float(best.get("max_hp")) * float(_cfg.get("heal_ratio", 0.4))))
	_heal_beam.append([best, 0.35])
	AudioManager.play_sfx("heal", 0.1)


func blocks_bullet(bullet_vel: Vector2) -> bool:
	if enemy_type != "shield" or _shield_down_t > 0.0 or state == State.SPAWN:
		return false
	return _facing.dot(-bullet_vel.normalized()) > 0.45


func _explode_spark(count: int) -> void:
	if _exploded:
		return
	_exploded = true
	BulletManager.spawn_ring(global_position, count, float(_cfg.get("ring_speed", 85.0)), randf() * 30.0)
	AudioManager.play_sfx("clang", 0.08)
	Events.request_screen_shake.emit(1.5, 0.12)


func _update_bombs(delta: float) -> void:
	for i in range(_bombs.size() - 1, -1, -1):
		_bombs[i].z -= delta
		if _bombs[i].z <= 0.0:
			BulletManager.spawn_ring(Vector2(_bombs[i].x, _bombs[i].y), int(_cfg.get("ring_bullets", 10)), float(_cfg.get("ring_speed", 80.0)), randf() * 36.0)
			AudioManager.play_sfx("clang", 0.08)
			_bombs.remove_at(i)


func _process_attack(delta: float, player: Node2D) -> void:
	match enemy_type:
		"wrench":
			velocity = _charge_dir * float(_cfg.get("charge_speed", 200.0))
			if global_position.distance_to(player.global_position) < 14.0 and player.has_method("take_damage"):
				player.take_damage(1, global_position)
			if _state_timer <= 0.0:
				velocity = Vector2.ZERO
				var r_bullets: int = int(_cfg.get("ring_bullets", 8))
				var r_spd: float = float(_cfg.get("ring_bullet_speed", 80.0))
				BulletManager.spawn_ring(global_position, r_bullets, r_spd)
				state = State.RECOVER
				_state_timer = float(_cfg.get("cooldown", 3.0)) / _fire_rate_mult
		"turret":
			var rot_spd: float = float(_cfg.get("rot_speed_deg", 140.0))
			var shot_int: float = float(_cfg.get("shot_interval", 0.15)) / _fire_rate_mult
			var arms: int = int(_cfg.get("arms", 2))
			var b_spd: float = float(_cfg.get("bullet_speed", 85.0))
			_spiral_angle += rot_spd * delta
			_shot_accum += delta
			while _shot_accum >= shot_int:
				_shot_accum -= shot_int
				BulletManager.spawn_ring(global_position, arms, b_spd, _spiral_angle)
			if _state_timer <= 0.0:
				state = State.RECOVER
				_state_timer = float(_cfg.get("rest_duration", 2.0)) / _fire_rate_mult
		"freighter":
			var r_int: float = float(_cfg.get("ring_interval", 0.4))
			var r_cnt: int = int(_cfg.get("ring_count", 3))
			var r_bullets: int = int(_cfg.get("ring_bullets", 14))
			var r_spd: float = float(_cfg.get("ring_speed", 75.0))
			var r_step: float = float(_cfg.get("ring_rot_step", 12.0))
			var expected_ring: int = int((1.2 - _state_timer) / r_int)
			if expected_ring > _ring_step_index and _ring_step_index < r_cnt:
				BulletManager.spawn_ring(global_position, r_bullets, r_spd, float(_ring_step_index) * r_step)
				_ring_step_index += 1
			if _state_timer <= 0.0:
				state = State.RECOVER
				_state_timer = 2.5 / _fire_rate_mult


func _get_player() -> Node2D:
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	return _player_ref


func take_damage(amount: float) -> void:
	if state == State.SPAWN or state == State.DEAD:
		return
	hp -= amount
	_hit_flash_t = 0.09
	AudioManager.play_sfx("enemy_hit")

	if has_node("Sprite2D"):
		var spr: Sprite2D = $Sprite2D
		spr.scale = Vector2(1.28, 0.75)
		var tw := create_tween()
		tw.tween_property(spr, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)

	var player: Node2D = _get_player()
	if player != null and enemy_type != "turret":
		var push_dir: Vector2 = (global_position - player.global_position).normalized()
		global_position += push_dir * 4.0

	if Settings.show_damage_numbers and get_parent() != null:
		_spawn_damage_number(int(round(amount)))

	if enemy_type == "freighter" and not _staggered_half_hp and hp <= max_hp * 0.5:
		_staggered_half_hp = true
		state = State.RECOVER
		_state_timer = 2.0

	if hp <= 0.0:
		if GameState.is_malha():
			Events.xp_dropped.emit(global_position, Malha.xp_value(enemy_type, affix))
		if affix == "explosivo":
			BulletManager.spawn_ring(global_position, int(Malha.get_affix("explosivo").get("death_ring", 8)), 75.0, randf() * 40.0)
		elif affix == "divisor" and get_parent() != null and get_parent().has_method("spawn_enemy"):
			for k in range(int(Malha.get_affix("divisor").get("split", 2))):
				get_parent().call_deferred("spawn_enemy", "spark", global_position + Vector2(-10.0 + 20.0 * float(k), 0.0))
		if enemy_type == "spark":
			_explode_spark(int(_cfg.get("death_ring", 6)))
		for bomb in _bombs:
			BulletManager.spawn_ring(Vector2(bomb.x, bomb.y), 6, 70.0)
		_bombs.clear()
		state = State.DEAD
		AudioManager.play_sfx("enemy_die")
		enemy_killed.emit(global_position, enemy_type == "freighter")
		Events.enemy_died.emit(global_position, enemy_type == "freighter")
		queue_free()


func _spawn_damage_number(dmg_val: int) -> void:
	var lbl := Label.new()
	lbl.text = str(dmg_val)
	lbl.global_position = global_position + Vector2(randf_range(-8.0, 4.0), -18.0)
	lbl.z_index = 260
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color("#f2c35b"))
	get_parent().add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 12.0, 0.38)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.38)
	tw.tween_callback(lbl.queue_free)


func apply_knockback(force: Vector2) -> void:
	global_position += force


func _draw() -> void:
	if _hit_flash_t > 0.0:
		var sf: int = mini(int((1.0 - _hit_flash_t / 0.09) * 3.0), 2)
		draw_texture_rect_region(FX_SPARK, Rect2(-12.0, -12.0, 25.0, 25.0), Rect2(sf * 25.0, 0.0, 25.0, 25.0))

	if affix != "":
		var ac := Color(String(Malha.get_affix(affix).get("color", "#ffffff")))
		var top := Vector2(0.0, -26.0 if enemy_type != "freighter" else -36.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, -3), top + Vector2(3, 0), top + Vector2(0, 3), top + Vector2(-3, 0)]), ac)
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 16, Color(ac, 0.35 + 0.15 * sin(_anim_t * 6.0)), 1.0)
	for beam in _heal_beam:
		if is_instance_valid(beam[0]):
			draw_line(Vector2.ZERO, (beam[0] as Node2D).global_position - global_position, Color(0.5, 1.0, 0.6, 0.8), 2.0)
	if _spray_t > 0.0:
		var sdir: Vector2 = _charge_dir if _charge_dir != Vector2.ZERO else Vector2.LEFT
		draw_line(sdir * 8.0, sdir * 14.0, Color(1.0, 0.6, 0.2, 0.9), 3.0)
	if _pull_t > 0.0:
		draw_arc(Vector2.ZERO, 20.0 + 6.0 * sin(_anim_t * 20.0), 0.0, TAU, 20, Color(0.7, 0.55, 1.0, 0.6), 2.0)
	if state == State.TELEGRAPH and enemy_type == "magnet":
		draw_arc(Vector2.ZERO, 30.0 * clampf(_state_timer, 0.0, 1.0) + 10.0, 0.0, TAU, 20, Color(0.7, 0.55, 1.0, 0.5), 1.0)
	for bomb in _bombs:
		var bp: Vector2 = Vector2(bomb.x, bomb.y) - global_position
		var fuse: float = float(_cfg.get("fuse", 1.0))
		var k: float = 1.0 - clampf(bomb.z / fuse, 0.0, 1.0)
		draw_arc(bp, lerpf(22.0, 8.0, k), 0.0, TAU, 20, Color(1.0, 0.24, 0.43, 0.4 + 0.4 * k), 1.0)
		draw_circle(bp + Vector2(0.0, -lerpf(10.0, 0.0, k)), 3.0, Color("#0d0b12"))
		draw_circle(bp + Vector2(0.0, -lerpf(10.0, 0.0, k)), 2.0, Color("#b3342e"))
	if enemy_type == "shield" and _shield_down_t <= 0.0 and state != State.SPAWN:
		draw_arc(Vector2.ZERO, 15.0, _facing.angle() - 0.9, _facing.angle() + 0.9, 10, Color(0.86, 0.91, 0.93, 0.55), 2.0)
	if enemy_type == "spark" and state == State.TELEGRAPH:
		draw_circle(Vector2.ZERO, 30.0 * (1.0 - clampf(_state_timer / 0.5, 0.0, 1.0)), Color(1.0, 0.85, 0.3, 0.25))

	if state == State.TELEGRAPH and enemy_type == "freighter":
		var t: float = clampf(1.0 - _state_timer / maxf(0.01, float(_cfg.get("ring_telegraph", 0.8))), 0.0, 1.0)
		var dots: int = 16
		for i in range(dots):
			var p: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / float(dots)) * lerpf(34.0, 20.0, t)
			draw_texture(FX_TELEGRAPH, (p - Vector2(4.0, 4.0)).round())
	elif state == State.TELEGRAPH and not (enemy_type in ["spark", "shield", "magnet"]):
		# Linha de mira tracejada (textura repetida) rumo ao ponto da investida
		draw_set_transform(Vector2.ZERO, _charge_dir.angle())
		draw_texture_rect(FX_DASH_LINE, Rect2(0.0, -1.0, 120.0, 3.0), true)
		draw_set_transform(Vector2.ZERO, 0.0)
		draw_texture(FX_TELEGRAPH, Vector2(-4.0, -4.0))

	if enemy_type == "freighter" or hp < max_hp:
		var bw: float = 32.0 if enemy_type == "freighter" else 18.0
		var by: float = -30.0 if enemy_type == "freighter" else -20.0 # acima dos sprites PixelLab (32px; cargueiro 48px)
		var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
		draw_texture_rect(FX_HP_BACK, Rect2(-bw * 0.5 - 1.0, by - 1.0, bw + 2.0, 5.0), false)
		draw_texture_rect(FX_HP_FILL, Rect2(-bw * 0.5, by, round(bw * ratio), 3.0), true)
