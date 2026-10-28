extends CharacterBody2D

const FX_MUZZLE: Texture2D = preload("res://assets/sprites/fx/muzzle_flash.png")
const FX_HURT: Texture2D = preload("res://assets/sprites/fx/hurt_ring.png")
# Pulso de vapor [Q] (PixelLab VFX "Pulso de Vapor (Q)", 16 fps): camada atrás e na frente do Teo,
# ancoradas nos pés. Cada clipe: textura, quadro (l x a), colunas, 1º quadro do efeito, nº de quadros, deslocamento.
const Q_FPS: float = 16.0
const Q_TOTAL_FRAMES: int = 10
const Q_BEHIND: Array = [preload("res://assets/sprites/fx/q_pulse_behind.png"), Vector2(160, 61), 3, 1, 8, Vector2(-80, -48)]
const Q_FRONT: Array = [preload("res://assets/sprites/fx/q_pulse_front.png"), Vector2(123, 86), 3, 0, 6, Vector2(-62, -57)]
const FEET_OFFSET := Vector2(0.0, 18.0)
const FX_DASH_CD: Texture2D = preload("res://assets/sprites/fx/dash_cooldown.png")
const FX_SHIELD: Texture2D = preload("res://assets/sprites/fx/shield_ring.png")
const FX_HITBOX: Texture2D = preload("res://assets/sprites/fx/hitbox_dot.png")

var _cfg: Dictionary = {}
var _shoot_timer: float = 0.0
var _invuln_timer: float = 0.0
var _hurt_flash_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_buffer_timer: float = 0.0
var _dash_coyote_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _pulse_cooldown_timer: float = 0.0
var _pulse_visual_timer: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _shield_cooldown_timer: float = 0.0
var _shield_ready: bool = false
var _is_focusing: bool = false
var _aim_dir: Vector2 = Vector2.RIGHT
var _anim_time: float = 0.0
var _face_idx: int = 0
var _pulse_anim_t: float = -1.0 # >= 0 enquanto o Teo faz o gesto do pulso
var _fx_front: Node2D

# teo_sheet_8dir.png: a arma é desenhada na própria arte (Teo segura com as duas mãos).
# Linhas sem arma (cutscenes/dash): rotações 0, hurt 1+dir, idle 9+dir, walk 17+dir, dash 25+dir.
# Linhas mirando: rotações 33, idle 34+dir, walk 42+dir, hurt 50+dir.
const ROW_AIM_IDLE: int = 34
const ROW_AIM_WALK: int = 42
const ROW_AIM_HURT: int = 50
# Gesto do pulso de vapor [Q]: crava a chave-pistola no chão e solta o vapor (6 quadros por direção)
const ROW_PULSE: int = 58
const PULSE_ANIM_TIME: float = 0.45
# Ponta do cano em cada direção (relativa ao centro do sprite), medida na arte do PixelLab
const MUZZLE_OFFSETS: Array[Vector2] = [
	Vector2(9, 8), Vector2(17, 5), Vector2(21, -7), Vector2(18, -18),
	Vector2(4, -23), Vector2(-16, -19), Vector2(-22, -6), Vector2(-17, 5),
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox_area: Area2D = $PlayerHurtbox


func _ready() -> void:
	add_to_group("player")
	_cfg = GameState.balance_data.get("player", {})
	_update_hurtbox_size()
	Events.upgrade_picked.connect(_on_upgrade_picked)

	# camada do pulso que passa NA FRENTE do sprite (o _draw do próprio Teo fica atrás dele)
	_fx_front = Node2D.new()
	_fx_front.draw.connect(func() -> void: _draw_q_clip(_fx_front, Q_FRONT))
	add_child(_fx_front)


func get_dash_cooldown_ratio() -> float:
	var cd_mult: float = 1.0 - 0.25 * float(GameState.get_upgrade_level("valvula"))
	var max_cd: float = maxf(0.01, float(_cfg.get("dash_cooldown", 1.0)) * cd_mult)
	return clampf(1.0 - (_dash_cooldown_timer / max_cd), 0.0, 1.0)


func get_pulse_cooldown_ratio() -> float:
	var cd_mult: float = 1.0 - 0.30 * float(GameState.get_upgrade_level("pressao"))
	var max_cd: float = maxf(0.01, float(_cfg.get("pulse_cooldown", 14.0)) * cd_mult)
	return clampf(1.0 - (_pulse_cooldown_timer / max_cd), 0.0, 1.0)


func get_pulse_seconds_left() -> float:
	return maxf(0.0, _pulse_cooldown_timer)


func _on_upgrade_picked(upg_id: String, _lvl: int) -> void:
	if upg_id == "casaco":
		_update_hurtbox_size()
	elif upg_id == "escudo":
		_shield_ready = true


func _update_hurtbox_size() -> void:
	var radius: float = 2.0 if GameState.get_upgrade_level("casaco") > 0 else 3.0
	var col: CollisionShape2D = hurtbox_area.get_node_or_null("CollisionShape2D")
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = radius


func reset_pulse_cooldown() -> void:
	_pulse_cooldown_timer = 0.0


func _physics_process(delta: float) -> void:
	_anim_time += delta
	_update_timers(delta)
	_update_aim()
	_handle_movement(delta)
	_handle_combat()
	_update_sprite_animation()
	z_index = int(global_position.y)
	queue_redraw()
	_fx_front.queue_redraw()


func _get_dir_index(dir: Vector2) -> int:
	if dir == Vector2.ZERO:
		return 0
	var angle: float = dir.angle()
	var oct: int = int(round(angle / (PI / 4.0)))
	match oct:
		2: return 0       # south
		1: return 1       # south-east
		0: return 2       # east
		-1, 7: return 3   # north-east
		-2, 6: return 4   # north
		-3, 5: return 5   # north-west
		4, -4: return 6   # west
		3: return 7       # south-west
	return 0


func _update_sprite_animation() -> void:
	var face_dir: Vector2 = _aim_dir if (_is_focusing or Input.is_action_pressed("shoot") or velocity.length() < 10.0) else velocity.normalized()
	var dir_idx: int = _get_dir_index(face_dir)
	_face_idx = dir_idx
	# coice: o corpo recua 1px contra a mira enquanto o clarão está ativo
	sprite.offset = (-_aim_dir).round() if _muzzle_flash_timer > 0.0 else Vector2.ZERO
	if _pulse_anim_t >= 0.0:
		sprite.modulate = Color.WHITE
		sprite.frame_coords = Vector2i(mini(int(_pulse_anim_t / PULSE_ANIM_TIME * 6.0), 5), ROW_PULSE + dir_idx)
		return
	if _hurt_flash_timer > 0.0:
		sprite.frame_coords = Vector2i(int(_anim_time * 12.0) % 6, ROW_AIM_HURT + dir_idx)
		sprite.modulate = Color(2.5, 0.5, 0.5, 1.0)
	else:
		sprite.modulate = Color.WHITE
		if _dash_timer > 0.0:
			# no dash a arma vai junto ao corpo (arte sem arma, braços livres para correr)
			sprite.frame_coords = Vector2i(int(_anim_time * 20.0) % 6, 25 + dir_idx)
		elif velocity.length() > 10.0:
			sprite.frame_coords = Vector2i(int(_anim_time * 12.0) % 6, ROW_AIM_WALK + dir_idx)
		else:
			sprite.frame_coords = Vector2i(int(_anim_time * 6.0) % 4, ROW_AIM_IDLE + dir_idx)


func _update_timers(delta: float) -> void:
	if _shoot_timer > 0.0:
		_shoot_timer -= delta
	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer -= delta
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		sprite.visible = int(_invuln_timer * 24.0) % 2 == 0
	else:
		sprite.visible = true

	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _dash_buffer_timer > 0.0:
		_dash_buffer_timer -= delta
	if _dash_coyote_timer > 0.0:
		_dash_coyote_timer -= delta
	if _pulse_cooldown_timer > 0.0:
		_pulse_cooldown_timer -= delta
	if _pulse_visual_timer > 0.0:
		_pulse_visual_timer -= delta
	if _pulse_anim_t >= 0.0:
		_pulse_anim_t += delta
		if _pulse_anim_t >= PULSE_ANIM_TIME:
			_pulse_anim_t = -1.0

	var shield_lvl: int = GameState.get_upgrade_level("escudo")
	if shield_lvl > 0 and not _shield_ready:
		_shield_cooldown_timer -= delta
		if _shield_cooldown_timer <= 0.0:
			_shield_ready = true


func _update_aim() -> void:
	if Settings.auto_aim:
		var nearest: Node2D = _get_auto_aim_target()
		if nearest != null:
			_aim_dir = (nearest.global_position - global_position).normalized()
			return

	if Settings.using_gamepad or Settings.touch_mode:
		# Analógico direito mira; solto, a mira segue o movimento — exceto atirando, quando fica
		# travada para o Teo poder recuar atirando para a frente
		var joy_aim: Vector2 = Settings.get_right_stick() if Settings.using_gamepad else TouchControls.aim_vector
		if joy_aim != Vector2.ZERO:
			_aim_dir = joy_aim.normalized()
		elif not Input.is_action_pressed("shoot"):
			var move_dir: Vector2 = _get_move_input()
			if move_dir != Vector2.ZERO:
				_aim_dir = move_dir.normalized()
		return

	_aim_dir = (get_global_mouse_position() - global_position).normalized()


# Analógico esquerdo (proporcional) ou teclas/D-pad
func _get_move_input() -> Vector2:
	var stick: Vector2 = Settings.get_left_stick()
	if stick != Vector2.ZERO:
		return stick
	if TouchControls.move_vector != Vector2.ZERO:
		return TouchControls.move_vector
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _handle_movement(delta: float) -> void:
	_is_focusing = Input.is_action_pressed("focus")
	var input_dir: Vector2 = _get_move_input()

	if Input.is_action_just_pressed("dash"):
		_dash_buffer_timer = float(_cfg.get("dash_buffer", 0.12))

	if _dash_buffer_timer > 0.0 and (_dash_cooldown_timer <= 0.0 or _dash_coyote_timer > 0.0):
		_start_dash(input_dir)

	if _dash_timer > 0.0:
		_dash_timer -= delta
		var dash_spd: float = float(_cfg.get("dash_distance", 56.0)) / float(_cfg.get("dash_duration", 0.18))
		velocity = _dash_dir * dash_spd
		if _dash_timer <= 0.0:
			_invuln_timer = maxf(_invuln_timer, float(_cfg.get("dash_post_invuln", 0.06)))
			_dash_coyote_timer = float(_cfg.get("dash_coyote", 0.06))
	else:
		var spd_mult: float = 1.0 + 0.12 * float(GameState.get_upgrade_level("velocidade"))
		var base_spd: float = float(_cfg.get("focus_speed", 55.0)) if _is_focusing else float(_cfg.get("move_speed", 110.0))
		if _is_focusing and GameState.get_upgrade_level("casaco") > 0:
			base_spd *= 1.20
		var target_vel: Vector2 = input_dir * base_spd * spd_mult
		var rate: float = float(_cfg.get("accel", 900.0)) if input_dir != Vector2.ZERO else float(_cfg.get("friction", 1200.0))
		velocity = velocity.move_toward(target_vel, rate * delta)

	move_and_slide()
	global_position.x = clampf(global_position.x, 22.0, 458.0)
	global_position.y = clampf(global_position.y, 68.0, 244.0)


func _start_dash(input_dir: Vector2) -> void:
	_dash_buffer_timer = 0.0
	_dash_coyote_timer = 0.0
	_dash_dir = input_dir.normalized() if input_dir != Vector2.ZERO else -_aim_dir
	_dash_timer = float(_cfg.get("dash_duration", 0.18))
	var cd_mult: float = 1.0 - 0.25 * float(GameState.get_upgrade_level("valvula"))
	_dash_cooldown_timer = float(_cfg.get("dash_cooldown", 1.0)) * cd_mult
	_invuln_timer = maxf(_invuln_timer, _dash_timer)
	AudioManager.play_sfx("dash")


func _handle_combat() -> void:
	if Input.is_action_pressed("shoot") and _shoot_timer <= 0.0:
		_fire_weapon()

	if Input.is_action_just_pressed("ability") and _pulse_cooldown_timer <= 0.0:
		_activate_steam_pulse()


func _fire_weapon() -> void:
	var rate_mult: float = 1.0 + 0.20 * float(GameState.get_upgrade_level("cadencia"))
	var fire_rate: float = float(_cfg.get("fire_rate", 5.0)) * rate_mult
	_shoot_timer = 1.0 / fire_rate
	_muzzle_flash_timer = 0.05

	var dmg_mult: float = 1.0 + 0.25 * float(GameState.get_upgrade_level("dano"))
	var dmg: float = float(_cfg.get("base_damage", 10.0)) * dmg_mult
	var b_speed: float = float(_cfg.get("bullet_speed", 320.0))
	var multi_lvl: int = GameState.get_upgrade_level("tiro_duplo")
	# ao atirar o Teo encara a mira, então o cano da arte aponta para o octante do disparo
	var muzzle_pos: Vector2 = global_position + MUZZLE_OFFSETS[_get_dir_index(_aim_dir)]

	if multi_lvl == 0:
		BulletManager.spawn_bullet(muzzle_pos, _aim_dir, b_speed, true, dmg, 1.2)
	elif multi_lvl == 1:
		var perp: Vector2 = _aim_dir.orthogonal() * 3.0
		BulletManager.spawn_bullet(muzzle_pos + perp, _aim_dir, b_speed, true, dmg * 0.7, 1.2)
		BulletManager.spawn_bullet(muzzle_pos - perp, _aim_dir, b_speed, true, dmg * 0.7, 1.2)
	else:
		BulletManager.spawn_fan(muzzle_pos, _aim_dir, 3, 20.0, b_speed, true, dmg * 0.6)

	AudioManager.play_sfx("player_shoot")


func _activate_steam_pulse() -> void:
	var cd_mult: float = 1.0 - 0.30 * float(GameState.get_upgrade_level("pressao"))
	_pulse_cooldown_timer = float(_cfg.get("pulse_cooldown", 14.0)) * cd_mult
	_pulse_visual_timer = float(Q_TOTAL_FRAMES) / Q_FPS
	_pulse_anim_t = 0.0
	var radius: float = float(_cfg.get("pulse_radius", 80.0))
	var dmg: float = float(_cfg.get("pulse_damage", 40.0))
	var push: float = float(_cfg.get("pulse_pushback", 32.0))

	BulletManager.clear_enemy_bullets_in_radius(global_position, radius)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and node.global_position.distance_to(global_position) <= radius:
			if node.has_method("take_damage"):
				node.take_damage(dmg)
			if node.has_method("apply_knockback"):
				var push_dir: Vector2 = (node.global_position - global_position).normalized()
				node.apply_knockback(push_dir * push)

	AudioManager.play_sfx("steam_pulse")
	Settings.rumble(0.6, 0.3, 0.3)
	Events.request_screen_shake.emit(2.0, 0.2)
	Events.request_screen_flash.emit(0.08)


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> void:
	if GameState.debug_invincible or _invuln_timer > 0.0 or _dash_timer > 0.0:
		return

	if _shield_ready:
		_shield_ready = false
		var shield_lvl: int = GameState.get_upgrade_level("escudo")
		_shield_cooldown_timer = 16.0 if shield_lvl >= 2 else 20.0
		_invuln_timer = 0.6
		AudioManager.play_sfx("clang")
		Settings.rumble(0.3, 0.0, 0.12)
		return

	GameState.current_hp = maxi(0, GameState.current_hp - amount)
	GameState.damage_taken_in_run += amount
	_invuln_timer = float(_cfg.get("invuln_time", 1.2))
	_hurt_flash_timer = 0.22

	# Squash & Stretch de impacto no Teo + partículas de dano
	sprite.scale = Vector2(1.35, 0.65)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK)

	_spawn_floating_hurt_text()

	if source_pos != Vector2.ZERO:
		var kb_dir: Vector2 = (global_position - source_pos).normalized()
		global_position += kb_dir * float(_cfg.get("knockback_dist", 24.0))

	AudioManager.play_sfx("player_hurt")
	Settings.rumble(0.5, 0.8, 0.25)
	Events.request_screen_shake.emit(3.5, 0.18)
	Events.request_screen_flash.emit(0.08)
	Events.player_hit.emit(GameState.current_hp, GameState.max_hp)

	if GameState.current_hp <= 0:
		TrainClock.is_running = false
		Events.player_died.emit("hp_zero")


func _spawn_floating_hurt_text() -> void:
	var lbl := Label.new()
	lbl.text = "-1 ♥"
	lbl.global_position = global_position + Vector2(-14.0, -24.0)
	lbl.z_index = 260
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color("#ff3d6e"))
	get_parent().add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 16.0, 0.45)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.45)
	tw.tween_callback(lbl.queue_free)


func _get_auto_aim_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = 220.0 * 220.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D:
			var d: float = global_position.distance_squared_to(node.global_position)
			if d <= best_d:
				best_d = d
				best = node
	return best


func _draw() -> void:
	# Todos os efeitos do Teo são sprites pixel art (assets/sprites/fx)
	if _muzzle_flash_timer > 0.0:
		var mpos: Vector2 = MUZZLE_OFFSETS[_face_idx] + sprite.offset
		draw_texture_rect_region(FX_MUZZLE, Rect2(mpos - Vector2(4.0, 4.0), Vector2(9.0, 9.0)), Rect2(float(int(_muzzle_flash_timer * 60.0) % 2) * 9.0, 0.0, 9.0, 9.0))

	if _hurt_flash_timer > 0.0:
		var hf: int = mini(int((1.0 - _hurt_flash_timer / 0.22) * 4.0), 3)
		draw_texture_rect_region(FX_HURT, Rect2(-24.0, -24.0, 48.0, 48.0), Rect2(hf * 48.0, 0.0, 48.0, 48.0))

	if _pulse_visual_timer > 0.0:
		_draw_q_clip(self, Q_BEHIND)

	if _dash_cooldown_timer > 0.0:
		var df: int = clampi(int(get_dash_cooldown_ratio() * 8.0), 0, 7)
		draw_texture_rect_region(FX_DASH_CD, Rect2(-6.0, 6.0, 13.0, 13.0), Rect2(df * 13.0, 0.0, 13.0, 13.0))

	if _shield_ready:
		draw_texture(FX_SHIELD, Vector2(-12.0, -12.0))
	if _is_focusing or Settings.always_show_hitbox:
		draw_texture(FX_HITBOX, Vector2(-3.0, -3.0))

	# Retícula de mira no controle (o cursor do mouse fica escondido)
	if Settings.using_gamepad or Settings.touch_mode:
		var rc: Vector2 = (_aim_dir * 34.0).round() + Vector2(0.5, 0.5)
		var col := Color("#f2c35b")
		draw_line(rc + Vector2(-4.0, 0.0), rc + Vector2(-2.0, 0.0), col)
		draw_line(rc + Vector2(2.0, 0.0), rc + Vector2(4.0, 0.0), col)
		draw_line(rc + Vector2(0.0, -4.0), rc + Vector2(0.0, -2.0), col)
		draw_line(rc + Vector2(0.0, 2.0), rc + Vector2(0.0, 4.0), col)


func _draw_q_clip(canvas: CanvasItem, clip: Array) -> void:
	if _pulse_visual_timer <= 0.0:
		return
	var f: int = int((float(Q_TOTAL_FRAMES) / Q_FPS - _pulse_visual_timer) * Q_FPS) - int(clip[3])
	if f < 0 or f >= int(clip[4]):
		return
	var fs: Vector2 = clip[1]
	var cols: int = int(clip[2])
	var src := Rect2(Vector2(float(f % cols) * fs.x, float(f / cols) * fs.y), fs)
	canvas.draw_texture_rect_region(clip[0], Rect2(FEET_OFFSET + Vector2(clip[5]), fs), src)
