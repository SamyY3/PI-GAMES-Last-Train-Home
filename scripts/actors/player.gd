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
const GRAZE_SPARK_TIME: float = 0.3
const FX_PUFF: Texture2D = preload("res://assets/sprites/fx/steam_puff.png")
const TRAIL_DROP_TIME: float = 0.03
const TRAIL_TICK_TIME: float = 0.25
const TRAIL_RADIUS: float = 11.0
const FX_GEAR: Texture2D = preload("res://assets/sprites/ui/golden_gear.png")
const FX_MORTEIRO: Texture2D = preload("res://assets/sprites/fx/skill_morteiro.png")
const FX_EXPRESSO: Texture2D = preload("res://assets/sprites/fx/skill_expresso.png")
const GEAR_ORBIT: float = 26.0
const SCRIPTED_WALK_SPEED: float = 75.0

signal scripted_walk_finished

var _cfg: Dictionary = {}
var _shoot_timer: float = 0.0
var _invuln_timer: float = 0.0
var _hurt_flash_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_buffer_timer: float = 0.0
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
var _graze_sparks: Array[Vector3] = []
var _graze_sfx_cd: float = 0.0
var _trail: Array[Vector3] = []
var _trail_drop_t: float = 0.0
var _trail_tick_t: float = 0.0
var _trail_drawer: Node2D
var _embalo_t: float = 0.0
var _couraca_t: float = 0.0
var _dash_charges: int = 1
var _expresso_t: float = 0.0
var _expresso_dir: Vector2 = Vector2.RIGHT
var _expresso_speed: float = 500.0
var _expresso_dmg: float = 60.0
var _expresso_ring: bool = false
var _expresso_hit: Array = []
var _expresso_fx_t: float = 0.0
var _gear_angle: float = 0.0
var _gear_tick: float = 0.0
var _gear_shot: float = 0.0
var _reator_t: float = 0.0
var _fornalha_busy: bool = false
var external_push: Vector2 = Vector2.ZERO
var _walk_path: Array[Vector2] = []
var extra_push: Vector2 = Vector2.ZERO

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
	_fx_front.draw.connect(func() -> void:
		_draw_q_clip(_fx_front, Q_FRONT)
		_draw_graze_sparks(_fx_front)
		_draw_gears(_fx_front)
	)
	add_child(_fx_front)

	_trail_drawer = Node2D.new()
	_trail_drawer.top_level = true
	_trail_drawer.z_as_relative = false
	_trail_drawer.z_index = 2
	_trail_drawer.draw.connect(_draw_trail)
	add_child(_trail_drawer)
	Events.enemy_died.connect(_on_enemy_died)


func get_dash_cooldown_ratio() -> float:
	var cd_mult: float = 1.0 - GameState.get_upgrade_value("valvula")
	var max_cd: float = maxf(0.01, float(_cfg.get("dash_cooldown", 1.0)) * cd_mult)
	return clampf(1.0 - (_dash_cooldown_timer / max_cd), 0.0, 1.0)


func get_pulse_cooldown_ratio() -> float:
	if Malha.apito_tier() > 0:
		return Malha.skill_ratio()
	var cd_mult: float = (1.0 - GameState.get_upgrade_value("pressao")) * Malha.pulse_cooldown_mult()
	var max_cd: float = maxf(0.01, float(_cfg.get("pulse_cooldown", 14.0)) * cd_mult)
	return clampf(1.0 - (_pulse_cooldown_timer / max_cd), 0.0, 1.0)


func get_pulse_seconds_left() -> float:
	if Malha.apito_tier() > 0:
		return maxf(0.0, Malha.skill_cd)
	return maxf(0.0, _pulse_cooldown_timer)


func max_dash_charges() -> int:
	return 1 + GameState.get_upgrade_level("asas")


func start_expresso(damage: float, ring: bool) -> void:
	var cfg: Dictionary = Malha.get_skill_cfg("vapor")
	var duration: float = float(cfg.get("duration", 0.38)) * (1.0 + GameState.get_upgrade_value("desvio"))
	var distance: float = float(cfg.get("distance", 190.0)) * (1.0 + 0.2 * float(GameState.get_upgrade_level("pistao")))
	_expresso_t = duration
	_expresso_speed = distance / float(cfg.get("duration", 0.38))
	_embalo_t = duration + GameState.get_upgrade_value("embalo", 0.3)
	_expresso_dir = _aim_dir if _aim_dir != Vector2.ZERO else Vector2.RIGHT
	_expresso_dmg = damage
	_expresso_ring = ring
	_expresso_hit.clear()
	_expresso_fx_t = 0.0
	AudioManager.play_sfx("dash")
	Events.request_screen_shake.emit(2.0, 0.3)


func _on_upgrade_picked(upg_id: String, _lvl: int) -> void:
	if upg_id == "casaco":
		_update_hurtbox_size()
	elif upg_id == "escudo":
		_shield_ready = true


func _update_hurtbox_size() -> void:
	var radius: float = GameState.get_upgrade_value("casaco", float(_cfg.get("hurtbox_radius", 3.0)))
	var col: CollisionShape2D = hurtbox_area.get_node_or_null("CollisionShape2D")
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = radius


func reset_pulse_cooldown() -> void:
	_pulse_cooldown_timer = 0.0


func reset_dash_cooldown() -> void:
	_dash_cooldown_timer = 0.0
	_dash_charges = max_dash_charges()


func grant_couraca(seconds: float) -> void:
	_couraca_t = maxf(_couraca_t, seconds)


func _physics_process(delta: float) -> void:
	_anim_time += delta
	if not _walk_path.is_empty():
		_step_scripted_walk(delta)
		_update_sprite_animation()
		z_index = int(global_position.y)
		queue_redraw()
		_fx_front.queue_redraw()
		return
	_update_timers(delta)
	_update_aim()
	_handle_movement(delta)
	_handle_combat()
	_update_trail(delta)
	_update_sprite_animation()
	z_index = int(global_position.y)
	queue_redraw()
	_fx_front.queue_redraw()


func scripted_walk(points: Array, ignore_pause: bool = false) -> void:
	_walk_path.assign(points)
	_dash_timer = 0.0
	_expresso_t = 0.0
	_pulse_anim_t = -1.0
	velocity = Vector2.ZERO
	process_mode = Node.PROCESS_MODE_ALWAYS if ignore_pause else Node.PROCESS_MODE_INHERIT
	_update_door_tint()


func is_scripted() -> bool:
	return not _walk_path.is_empty()


func _step_scripted_walk(delta: float) -> void:
	var to: Vector2 = _walk_path[0] - global_position
	var step: float = SCRIPTED_WALK_SPEED * delta
	if to.length() > 0.01:
		_aim_dir = to.normalized()
	velocity = _aim_dir * SCRIPTED_WALK_SPEED
	if to.length() <= step:
		global_position = _walk_path.pop_front()
	else:
		global_position += _aim_dir * step
	_update_door_tint()
	if _walk_path.is_empty():
		velocity = Vector2.ZERO
		process_mode = Node.PROCESS_MODE_INHERIT
		scripted_walk_finished.emit()


func _update_door_tint() -> void:
	var x: float = global_position.x
	var depth: float = maxf(clampf((x - Arena.PLAYER.end.x) / 12.0, 0.0, 1.0), clampf((Arena.PLAYER.position.x - x) / 12.0, 0.0, 1.0))
	var c: float = lerpf(1.0, 0.1, depth)
	modulate = Color(c, c, c, clampf((x - 2.0) / 8.0, 0.0, 1.0) * (1.0 - clampf((x - 476.0) / 10.0, 0.0, 1.0)))


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
		if _dash_cooldown_timer <= 0.0:
			_dash_charges = mini(max_dash_charges(), _dash_charges + 1)
			if _dash_charges < max_dash_charges():
				_dash_cooldown_timer = _dash_cd_full()
	elif _dash_charges < max_dash_charges():
		_dash_charges = max_dash_charges()
	if _dash_buffer_timer > 0.0:
		_dash_buffer_timer -= delta
	if _pulse_cooldown_timer > 0.0:
		_pulse_cooldown_timer -= delta
	if _pulse_visual_timer > 0.0:
		_pulse_visual_timer -= delta
	if _embalo_t > 0.0:
		_embalo_t -= delta
	if _couraca_t > 0.0:
		_couraca_t -= delta
	if GameState.get_upgrade_level("reator") > 0 and not _shield_ready:
		_reator_t += delta
		if _reator_t >= GameState.get_upgrade_value("reator", 12.0):
			_reator_t = 0.0
			_shield_ready = true
			AudioManager.play_sfx("clang", 0.05)
	if _graze_sfx_cd > 0.0:
		_graze_sfx_cd -= delta
	for i in range(_graze_sparks.size() - 1, -1, -1):
		_graze_sparks[i].z -= delta
		if _graze_sparks[i].z <= 0.0:
			_graze_sparks.remove_at(i)
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
			_aim_dir = _assisted_aim(joy_aim.normalized()) if Settings.aim_assist else joy_aim.normalized()
		elif not Input.is_action_pressed("shoot"):
			var move_dir: Vector2 = _get_move_input()
			if move_dir != Vector2.ZERO:
				_aim_dir = move_dir.normalized()
		return

	_aim_dir = (get_global_mouse_position() - global_position).normalized()


func _assisted_aim(dir: Vector2) -> Vector2:
	var best: Node2D = null
	var best_score: float = INF
	var max_angle: float = deg_to_rad(28.0)
	var aim_range: float = float(_cfg.get("auto_aim_range", 220.0)) + 60.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node2D):
			continue
		var to: Vector2 = (node as Node2D).global_position - global_position
		var dist: float = to.length()
		if dist > aim_range or dist < 1.0:
			continue
		var ang: float = absf(dir.angle_to(to))
		if ang > max_angle:
			continue
		var score: float = rad_to_deg(ang) + dist * 0.05
		if score < best_score:
			best_score = score
			best = node
	if best == null:
		return dir
	return (best.global_position - global_position).normalized()


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

	if _dash_buffer_timer > 0.0 and _dash_charges > 0 and _dash_timer <= 0.0 and _expresso_t <= 0.0:
		_start_dash(input_dir)

	if _expresso_t > 0.0:
		_update_expresso(delta)
	elif _dash_timer > 0.0:
		_dash_timer -= delta
		var dash_spd: float = float(_cfg.get("dash_distance", 56.0)) / float(_cfg.get("dash_duration", 0.18))
		velocity = _dash_dir * dash_spd
		if _dash_timer <= 0.0:
			_invuln_timer = maxf(_invuln_timer, float(_cfg.get("dash_post_invuln", 0.06)))
	else:
		var spd_mult: float = 1.0 + GameState.get_upgrade_value("velocidade")
		var base_spd: float = float(_cfg.get("focus_speed", 55.0)) if _is_focusing else float(_cfg.get("move_speed", 110.0))
		if _is_focusing and GameState.get_upgrade_level("casaco") > 0:
			base_spd *= 1.20
		var target_vel: Vector2 = input_dir * base_spd * spd_mult
		var rate: float = float(_cfg.get("accel", 900.0)) if input_dir != Vector2.ZERO else float(_cfg.get("friction", 1200.0))
		velocity = velocity.move_toward(target_vel, rate * delta)

	var own_velocity: Vector2 = velocity
	velocity += external_push + extra_push
	extra_push = Vector2.ZERO
	move_and_slide()
	velocity = own_velocity
	global_position = Arena.clamp_point(global_position, Arena.PLAYER)


func _start_dash(input_dir: Vector2) -> void:
	_dash_buffer_timer = 0.0
	_dash_dir = input_dir.normalized() if input_dir != Vector2.ZERO else -_aim_dir
	_dash_timer = float(_cfg.get("dash_duration", 0.18))
	_dash_charges -= 1
	if _dash_cooldown_timer <= 0.0:
		_dash_cooldown_timer = _dash_cd_full()
	_invuln_timer = maxf(_invuln_timer, _dash_timer)
	_embalo_t = _dash_timer + GameState.get_upgrade_value("embalo", 0.3)
	_trail_drop_t = 0.0
	AudioManager.play_sfx("dash")


func _dash_cd_full() -> float:
	return float(_cfg.get("dash_cooldown", 1.0)) * (1.0 - GameState.get_upgrade_value("valvula"))


func _update_expresso(delta: float) -> void:
	_expresso_t -= delta
	var nxt: Vector2 = global_position + _expresso_dir * _expresso_speed * delta
	if GameState.get_upgrade_level("desvio") > 0 and not Arena.PLAYER.has_point(nxt):
		if nxt.x < Arena.PLAYER.position.x or nxt.x > Arena.PLAYER.end.x:
			_expresso_dir.x = -_expresso_dir.x
		if nxt.y < Arena.PLAYER.position.y or nxt.y > Arena.PLAYER.end.y:
			_expresso_dir.y = -_expresso_dir.y
		_expresso_hit.clear()
		AudioManager.play_sfx("clang", 0.08)
	velocity = _expresso_dir * _expresso_speed
	BulletManager.clear_enemy_bullets_in_radius(global_position, 22.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and not _expresso_hit.has(node) and (node as Node2D).global_position.distance_to(global_position) <= 22.0:
			_expresso_hit.append(node)
			if node.has_method("take_damage"):
				node.take_damage(_expresso_dmg)
			if GameState.get_upgrade_level("fornalha_viva") > 0:
				Malha.skill_cd = maxf(0.0, Malha.skill_cd - GameState.get_upgrade_value("fornalha_viva", 0.8))
			if node.has_method("apply_knockback"):
				node.apply_knockback(_expresso_dir.orthogonal() * 18.0 * (1.0 if randf() < 0.5 else -1.0))
	_expresso_fx_t -= delta
	if _expresso_fx_t <= 0.0:
		_expresso_fx_t = 0.06
		SheetFx.spawn(get_parent(), FX_EXPRESSO, global_position + Vector2(0.0, 4.0), Vector2(87.0, 46.0), 4, 9, 18.0, Vector2(61.0, 27.0), 0.7, _expresso_dir.x < 0.0)
	if _expresso_t <= 0.0:
		velocity = _expresso_dir * 60.0
		_invuln_timer = maxf(_invuln_timer, 0.25)
		var wave: float = GameState.get_upgrade_value("onda_choque", 0.0)
		if wave > 0.0:
			var boost: float = 1.5 if GameState.has_combo("expresso_infernal") else 1.0
			LineSkills.shockwave(get_parent(), global_position, 50.0 * boost, wave * boost)


func _update_gears(delta: float) -> void:
	var count: int = int(GameState.get_upgrade_value("campo", 0.0))
	if count <= 0:
		return
	_gear_angle += delta * 3.2
	_gear_tick -= delta
	_gear_shot -= delta
	var tick: bool = _gear_tick <= 0.0
	if tick:
		_gear_tick = 0.25
	var shoot: bool = GameState.has_combo("engrenagem_viva") and _gear_shot <= 0.0
	if shoot:
		_gear_shot = 1.2
	for i in range(count):
		var gp: Vector2 = global_position + Vector2(GEAR_ORBIT, 0.0).rotated(_gear_angle + TAU * float(i) / float(count))
		BulletManager.hit_enemy_bullets_near(gp, 7.0)
		if tick:
			for node in get_tree().get_nodes_in_group("enemies"):
				if node is Node2D and (node as Node2D).global_position.distance_to(gp) <= 12.0 and node.has_method("take_damage"):
					node.take_damage(3.0 + 3.0 * float(GameState.get_upgrade_level("campo")))
		if shoot:
			var target: Node2D = _get_auto_aim_target()
			if target != null:
				BulletManager.spawn_bullet(gp, (target.global_position - gp).normalized(), 260.0, true, get_bullet_damage() * 0.6, 1.0)


func _handle_combat() -> void:
	var auto_fire: bool = Settings.auto_aim and Settings.touch_mode and not Settings.using_gamepad and _get_auto_aim_target() != null
	if (Input.is_action_pressed("shoot") or auto_fire) and _shoot_timer <= 0.0:
		_fire_weapon()

	if Input.is_action_just_pressed("ability"):
		if Malha.apito_tier() > 0:
			if Malha.use_skill(self):
				_pulse_anim_t = 0.0
		elif _pulse_cooldown_timer <= 0.0:
			_activate_steam_pulse()


func _fire_weapon() -> void:
	var rate_mult: float = 1.0 + GameState.get_upgrade_value("cadencia")
	var fire_rate: float = float(_cfg.get("fire_rate", 5.0)) * rate_mult
	_shoot_timer = 1.0 / fire_rate
	_muzzle_flash_timer = 0.05

	var dmg: float = get_bullet_damage()
	var b_speed: float = float(_cfg.get("bullet_speed", 320.0))
	var b_life: float = float(_cfg.get("bullet_lifetime", 1.2))
	var multi_lvl: int = GameState.get_upgrade_level("tiro_duplo")
	# ao atirar o Teo encara a mira, então o cano da arte aponta para o octante do disparo
	var muzzle_pos: Vector2 = global_position + MUZZLE_OFFSETS[_get_dir_index(_aim_dir)]
	if BulletManager.next_shot_is_lightning():
		var jumps: int = 1 + GameState.get_upgrade_level("corrente") + (2 if GameState.has_combo("tempestade") else 0)
		BulletManager.chain_lightning(muzzle_pos, dmg * 1.5, jumps)

	if multi_lvl == 0:
		BulletManager.spawn_bullet(muzzle_pos, _aim_dir, b_speed, true, dmg, b_life)
	elif multi_lvl == 1:
		var perp: Vector2 = _aim_dir.orthogonal() * 3.0
		BulletManager.spawn_bullet(muzzle_pos + perp, _aim_dir, b_speed, true, dmg * 0.7, b_life)
		BulletManager.spawn_bullet(muzzle_pos - perp, _aim_dir, b_speed, true, dmg * 0.7, b_life)
	else:
		BulletManager.spawn_fan(muzzle_pos, _aim_dir, 3, 20.0, b_speed, true, dmg * 0.6)

	AudioManager.play_sfx("player_shoot")


func _activate_steam_pulse() -> void:
	var cd_mult: float = (1.0 - GameState.get_upgrade_value("pressao")) * Malha.pulse_cooldown_mult()
	_pulse_cooldown_timer = float(_cfg.get("pulse_cooldown", 14.0)) * cd_mult
	_pulse_visual_timer = float(Q_TOTAL_FRAMES) / Q_FPS
	_pulse_anim_t = 0.0
	var radius: float = float(_cfg.get("pulse_radius", 80.0))
	var dmg: float = float(_cfg.get("pulse_damage", 40.0))
	var push: float = float(_cfg.get("pulse_pushback", 32.0))

	if GameState.get_upgrade_level("refletor") > 0:
		BulletManager.reflect_enemy_bullets_in_radius(global_position, radius, get_bullet_damage())
	else:
		BulletManager.clear_enemy_bullets_in_radius(global_position, radius)
	if GameState.get_upgrade_level("freio") > 0:
		TrainClock.freeze(GameState.get_upgrade_value("freio"))
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


func get_bullet_damage() -> float:
	var dmg_mult: float = 1.0 + GameState.get_upgrade_value("dano") + GameState.get_upgrade_value("sobrecarga")
	return float(_cfg.get("base_damage", 10.0)) * dmg_mult * Malha.damage_mult()


func _on_enemy_died(pos: Vector2, _is_elite: bool) -> void:
	var fornalha: float = GameState.get_upgrade_value("fornalha", 0.0)
	if fornalha > 0.0 and (not _fornalha_busy or GameState.has_combo("reacao_cadeia")):
		var was_busy: bool = _fornalha_busy
		_fornalha_busy = true
		var radius: float = 30.0 * (1.5 if GameState.has_combo("reacao_cadeia") else 1.0)
		SheetFx.spawn(get_parent(), FX_MORTEIRO, pos, Vector2(116.0, 82.0), 4, 8, 16.0, Vector2(58.0, 41.0), radius / 60.0)
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Node2D and (node as Node2D).global_position.distance_to(pos) <= radius and node.has_method("take_damage"):
				node.take_damage(fornalha)
		_fornalha_busy = was_busy
	if _embalo_t > 0.0 and GameState.get_upgrade_level("embalo") > 0 and _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = 0.0
		AudioManager.play_sfx("blip")


func _update_trail(delta: float) -> void:
	_update_gears(delta)
	if (_dash_timer > 0.0 or _expresso_t > 0.0) and GameState.get_upgrade_level("turbina") > 0:
		BulletManager.clear_enemy_bullets_in_radius(global_position, GameState.get_upgrade_value("turbina", 22.0))
	if GameState.has_combo("ciclone"):
		for point in _trail:
			BulletManager.clear_enemy_bullets_in_radius(Vector2(point.x, point.y), 9.0)
	var lvl: int = GameState.get_upgrade_level("rastro")
	if lvl > 0 and (_dash_timer > 0.0 or _expresso_t > 0.0):
		_trail_drop_t -= delta
		if _trail_drop_t <= 0.0:
			_trail_drop_t = TRAIL_DROP_TIME
			var life: float = 0.9 if lvl == 1 else 1.3
			if GameState.has_combo("locomotiva"):
				life *= 2.0
			_trail.append(Vector3(global_position.x, global_position.y + 4.0, life))

	for i in range(_trail.size() - 1, -1, -1):
		_trail[i].z -= delta
		if _trail[i].z <= 0.0:
			_trail.remove_at(i)

	if not _trail.is_empty():
		_trail_tick_t -= delta
		if _trail_tick_t <= 0.0:
			_trail_tick_t = TRAIL_TICK_TIME
			var dmg: float = GameState.get_upgrade_value("rastro")
			for node in get_tree().get_nodes_in_group("enemies"):
				if not (node is Node2D) or not node.has_method("take_damage"):
					continue
				for point in _trail:
					if (node as Node2D).global_position.distance_to(Vector2(point.x, point.y)) <= TRAIL_RADIUS:
						node.take_damage(dmg)
						break
	_trail_drawer.queue_redraw()


func _draw_trail() -> void:
	for point in _trail:
		var frame: int = clampi(int((1.0 - clampf(point.z, 0.0, 1.0)) * 5.0), 0, 5)
		var alpha: float = clampf(point.z * 2.0, 0.0, 0.85)
		_trail_drawer.draw_texture_rect_region(FX_PUFF, Rect2(Vector2(point.x, point.y).round() - Vector2(16.0, 16.0), Vector2(32.0, 32.0)), Rect2(frame * 32.0, 0.0, 32.0, 32.0), Color(1.0, 1.0, 1.0, alpha * 0.8))


func register_graze(at: Vector2) -> void:
	if _invuln_timer > 0.0 or _dash_timer > 0.0 or GameState.current_hp <= 0:
		return
	var gcfg: Dictionary = GameState.balance_data.get("graze", {})
	_pulse_cooldown_timer = maxf(0.0, _pulse_cooldown_timer - float(gcfg.get("pulse_cd_reduction", 0.35)))
	var bonus: float = minf(float(gcfg.get("time_bonus", 0.15)), float(gcfg.get("time_cap_per_level", 12.0)) - GameState.graze_time_this_level)
	if bonus > 0.0 and TrainClock.is_running:
		GameState.graze_time_this_level += bonus
		TrainClock.add_time(bonus)
	GameState.grazes += 1
	Events.player_grazed.emit(GameState.grazes)
	var edge: Vector2 = (at - global_position).normalized() * 7.0
	_graze_sparks.append(Vector3(edge.x, edge.y, GRAZE_SPARK_TIME))
	if _graze_sfx_cd <= 0.0:
		_graze_sfx_cd = 0.06
		AudioManager.play_sfx("graze", 0.12)


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> void:
	if GameState.debug_invincible or _invuln_timer > 0.0 or _dash_timer > 0.0 or _couraca_t > 0.0 or _expresso_t > 0.0 or is_scripted():
		return
	_reator_t = 0.0

	if _shield_ready:
		_shield_ready = false
		_shield_cooldown_timer = GameState.get_upgrade_value("escudo", 20.0)
		_invuln_timer = 0.6
		AudioManager.play_sfx("clang")
		Settings.rumble(0.3, 0.0, 0.12)
		return

	if Malha.consume_bilhete():
		_invuln_timer = 0.8
		AudioManager.play_sfx("clang")
		Events.item_obtained.emit("BILHETE RASGADO SALVOU O TEO")
		return

	GameState.current_hp = maxi(0, GameState.current_hp - amount)
	if GameState.current_hp <= 0 and Malha.consume_fotografia():
		GameState.current_hp = 1
		Events.item_obtained.emit("A FOTOGRAFIA DA FAMÍLIA DEU FORÇAS AO TEO")
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

	var rebites: int = int(GameState.get_upgrade_value("rebites"))
	if rebites > 0 and GameState.current_hp > 0:
		var rebite_dmg: float = get_bullet_damage() * (1.0 + 0.5 * float(GameState.get_upgrade_level("rebites") - 1))
		for i in range(rebites):
			BulletManager.spawn_bullet(global_position, Vector2.RIGHT.rotated(TAU * float(i) / float(rebites)), 240.0, true, rebite_dmg, 1.0)

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
	var aim_range: float = float(_cfg.get("auto_aim_range", 220.0))
	var best_d: float = aim_range * aim_range
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

	if _shield_ready or (_couraca_t > 0.0 and (_couraca_t > 1.0 or int(_couraca_t * 10.0) % 2 == 0)):
		draw_texture(FX_SHIELD, Vector2(-12.0, -12.0), Malha.get_line_color("engrenagem") if _couraca_t > 0.0 else Color.WHITE)
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
	var src := Rect2(Vector2(float(f % cols) * fs.x, float(floori(float(f) / float(cols))) * fs.y), fs)
	canvas.draw_texture_rect_region(clip[0], Rect2(FEET_OFFSET + Vector2(clip[5]), fs), src)


func _draw_graze_sparks(canvas: CanvasItem) -> void:
	for spark in _graze_sparks:
		var t: float = 1.0 - spark.z / GRAZE_SPARK_TIME
		var c: Vector2 = Vector2(spark.x, spark.y).round()
		var reach: float = round(2.0 + t * 4.0)
		var col: Color = Color("#fff1c9").lerp(Color("#f2c35b"), t)
		col.a = 1.0 if t < 0.5 else 2.0 - t * 2.0
		if t < 0.4:
			canvas.draw_rect(Rect2(c - Vector2.ONE, Vector2(2.0, 2.0)), col)
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			canvas.draw_rect(Rect2(c + d * reach, Vector2.ONE), col)
			canvas.draw_rect(Rect2(c + d * (reach - 1.0), Vector2.ONE), col)


func _draw_gears(canvas: CanvasItem) -> void:
	var count: int = int(GameState.get_upgrade_value("campo", 0.0))
	for i in range(count):
		var gp: Vector2 = Vector2(GEAR_ORBIT, 0.0).rotated(_gear_angle + TAU * float(i) / float(count))
		canvas.draw_set_transform(gp.round(), _gear_angle * 2.0, Vector2(0.6, 0.6))
		canvas.draw_texture(FX_GEAR, -FX_GEAR.get_size() * 0.5)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
