extends CharacterBody2D

const FX_SPARK: Texture2D = preload("res://assets/sprites/fx/hit_spark.png")
const FX_TELEGRAPH: Texture2D = preload("res://assets/sprites/fx/telegraph_dot.png")
const FX_DASH_LINE: Texture2D = preload("res://assets/sprites/fx/telegraph_dash.png")
const FX_HP_BACK: Texture2D = preload("res://assets/sprites/fx/hpbar_back.png")
const FX_HP_FILL: Texture2D = preload("res://assets/sprites/fx/hpbar_fill.png")

signal enemy_killed(pos: Vector2, is_elite: bool)

enum State { SPAWN, MOVE, TELEGRAPH, ATTACK, RECOVER, DEAD }

@export var enemy_type: String = "sentinel"

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
var _ring_step_index: int = 0
var _summoned_half_hp: bool = false
var _anim_t: float = 0.0
var _hit_flash_t: float = 0.0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED # linha de mira e barra de vida usam texturas repetidas
	add_to_group("enemies")
	var all_enemies: Dictionary = GameState.balance_data.get("enemies", {})
	_cfg = all_enemies.get(enemy_type, {})
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	var hp_mult: float = float(diff_cfg.get("enemy_hp_mult", 1.0))
	_fire_rate_mult = maxf(0.1, float(diff_cfg.get("enemy_fire_rate_mult", 1.0)))

	max_hp = float(_cfg.get("hp", 30.0)) * hp_mult
	hp = max_hp
	_state_timer = 0.5
	var tex_path: String = "res://assets/sprites/enemies/%s.png" % enemy_type
	if ResourceLoader.exists(tex_path) and has_node("Sprite2D"):
		($Sprite2D as Sprite2D).texture = load(tex_path)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_anim_t += delta
	if _hit_flash_t > 0.0:
		_hit_flash_t -= delta

	_state_timer -= delta
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	if has_node("Sprite2D"):
		var spr: Sprite2D = $Sprite2D
		spr.flip_h = player.global_position.x < global_position.x
		if _hit_flash_t > 0.0:
			spr.frame_coords = Vector2i(0, 3)
			spr.modulate = Color(3.0, 3.0, 3.0, 1.0)
		else:
			spr.modulate = Color.WHITE
			spr.frame_coords = Vector2i(int(_anim_t * 8.0) % 4, 0)

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

	move_and_slide()
	global_position.x = clampf(global_position.x, 20.0, 460.0)
	global_position.y = clampf(global_position.y, 68.0, 244.0)
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
				_state_timer = float(_cfg.get("charge_telegraph", 0.8))


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

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and enemy_type != "turret":
		var push_dir: Vector2 = (global_position - player.global_position).normalized()
		global_position += push_dir * 4.0

	if Settings.show_damage_numbers and get_parent() != null:
		_spawn_damage_number(int(round(amount)))

	if enemy_type == "freighter" and not _summoned_half_hp and hp <= max_hp * 0.5:
		_summoned_half_hp = true
		state = State.RECOVER
		_state_timer = 2.0

	if hp <= 0.0:
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

	if state == State.TELEGRAPH:
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
