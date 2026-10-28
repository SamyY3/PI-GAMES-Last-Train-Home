extends LevelBase

const CRATE_POSITIONS: Array[Vector2] = [
	Vector2(110.0, 105.0),
	Vector2(240.0, 95.0),
	Vector2(370.0, 105.0),
	Vector2(160.0, 210.0),
	Vector2(330.0, 210.0)
]

const STAGES: Array = [
	[
		[["sentinel", Vector2(390.0, 100.0)], ["sentinel", Vector2(410.0, 157.0)], ["sentinel", Vector2(390.0, 215.0)], ["sniper", Vector2(430.0, 157.0)]],
		[["turret", Vector2(180.0, 150.0)], ["turret", Vector2(300.0, 150.0)], ["drone", Vector2(400.0, 100.0)], ["drone", Vector2(400.0, 215.0)], ["sniper", Vector2(80.0, 157.0)]],
	],
	[
		[["drone", Vector2(400.0, 100.0)], ["drone", Vector2(400.0, 215.0)], ["wrench", Vector2(420.0, 157.0)], ["sniper", Vector2(60.0, 110.0)]],
		[["turret", Vector2(240.0, 157.0)], ["sentinel", Vector2(400.0, 110.0)], ["sentinel", Vector2(400.0, 205.0)], ["sniper", Vector2(430.0, 157.0)]],
	],
]

var _crate_types: Array[String] = ["bomb", "heal", "trap", "empty", "empty"]
var _crate_sprites: Array[Sprite2D] = []
var _opened_crates: Array[bool] = [false, false, false, false, false]
var _bomb_crate_pos: Vector2 = Vector2.ZERO
var _hold_f_timer: float = 0.0
var _active_crate_idx: int = -1
var _radar_tick_timer: float = 0.0
var _stage_delay: float = 0.0
var _wave_stage: int = 0
var _bomb_found: bool = false
var _freighter_dead: bool = false
var _reinforce_timer: float = 0.0
var _progress_drawer: Node2D
var _bomb_visor_label: Label


func _ready() -> void:
	wagon_number = 3
	next_scene_path = "res://scenes/levels/Level_Wagon4.tscn"
	super._ready()
	GameState.has_cargo_key = false
	TrainClock.apply_section_rubber_band("wagon_3")
	AudioManager.play_music("wagon_3")
	hud.set_wagon_title("VAGÃO 3/4")
	hud.set_wave_info(0, 3)
	hud.set_contextual_tip("Aproxime-se das caixas e segure {interact} (0,6s)! Siga o RADAR.")

	_setup_crates()
	_progress_drawer = Node2D.new()
	_progress_drawer.z_index = 265
	_progress_drawer.draw.connect(_draw_crate_progress)
	add_child(_progress_drawer)

	dialogue_box.start_dialogue("wagon3_unlock")
	await dialogue_box.dialogue_finished
	TrainClock.is_running = true
	_spawn_stage_1()


func _setup_crates() -> void:
	seed(GameState.run_seed)
	_crate_types.shuffle()
	var tex_closed: Texture2D = load("res://assets/sprites/tiles/crate_closed.png")
	for i in range(5):
		var static_body := StaticBody2D.new()
		static_body.global_position = CRATE_POSITIONS[i]
		static_body.z_index = int(CRATE_POSITIONS[i].y)
		static_body.collision_layer = 1
		static_body.collision_mask = 0

		var col := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(26.0, 10.0)
		col.position = Vector2(0.0, 5.0)
		col.shape = rect_shape
		static_body.add_child(col)

		var spr := Sprite2D.new()
		spr.texture = tex_closed
		static_body.add_child(spr)
		add_child(static_body)
		_crate_sprites.append(spr)

		if _crate_types[i] == "bomb":
			_bomb_crate_pos = CRATE_POSITIONS[i]


func _process(delta: float) -> void:
	super._process(delta)
	_update_radar(delta)
	_handle_crate_interaction(delta)
	_progress_drawer.queue_redraw()
	if _bomb_visor_label != null:
		_bomb_visor_label.text = TrainClock.format_time()

	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	if alive <= 1:
		_stage_delay += delta
	else:
		_stage_delay = 0.0

	if _wave_stage == 1 and (alive == 0 or _stage_delay >= 3.0):
		_spawn_stage_2()
	elif _wave_stage == 2 and (alive == 0 or _stage_delay >= 3.0):
		_spawn_freighter()

	if _freighter_dead and not _bomb_found:
		_reinforce_timer += delta
		if _reinforce_timer >= 6.0 and alive < 4:
			_reinforce_timer = 0.0
			spawn_enemy("drone", Vector2(420.0, 110.0))
			spawn_enemy("drone", Vector2(420.0, 200.0))


func _draw_crate_progress() -> void:
	if _active_crate_idx == -1:
		return
	var ring_pos: Vector2 = CRATE_POSITIONS[_active_crate_idx] + Vector2(0.0, -20.0)
	draw_centered_f_prompt(_progress_drawer, ring_pos, _hold_f_timer / 0.6)


func _spawn_stage_1() -> void:
	_wave_stage = 1
	_stage_delay = 0.0
	hud.set_wave_info(1, 3)
	spawn_wave(STAGES[GameState.get_wave_variant(3)][0])


func _spawn_stage_2() -> void:
	_wave_stage = 2
	_stage_delay = 0.0
	hud.set_wave_info(2, 3)
	spawn_wave(STAGES[GameState.get_wave_variant(3)][1])


func _spawn_freighter() -> void:
	_wave_stage = 3
	_stage_delay = 0.0
	hud.set_wave_info(3, 3)
	hud._show_banner("BLINDADO DE CARGA")
	var f: Node2D = spawn_enemy("freighter", Vector2(410.0, 157.0))
	if f.has_signal("enemy_killed"):
		f.connect("enemy_killed", _on_freighter_killed_signal)


func _on_freighter_killed_signal(_pos: Vector2, _elite: bool) -> void:
	if _freighter_dead:
		return
	_freighter_dead = true
	hud.set_wave_info(0, 0)
	upgrade_screen.open_upgrade_choices()
	await upgrade_screen.upgrade_selected
	_check_wagon3_completion()


func _update_radar(delta: float) -> void:
	if _bomb_found:
		Events.radar_distance_updated.emit(-1.0)
		return
	var dist: float = player.global_position.distance_to(_bomb_crate_pos)
	Events.radar_distance_updated.emit(dist)
	if dist <= 250.0:
		_radar_tick_timer += delta
		var interval: float = remap(clampf(dist, 30.0, 250.0), 250.0, 30.0, 0.9, 0.25)
		if _radar_tick_timer >= interval:
			_radar_tick_timer = 0.0
			AudioManager.play_sfx("tick", 0.08)


func _handle_crate_interaction(delta: float) -> void:
	_active_crate_idx = -1
	for i in range(5):
		if not _opened_crates[i] and player.global_position.distance_to(CRATE_POSITIONS[i]) <= 36.0:
			_active_crate_idx = i
			break

	if _active_crate_idx != -1:
		if Input.is_action_pressed("interact"):
			_hold_f_timer += delta
			if _hold_f_timer >= 0.6:
				_hold_f_timer = 0.0
				_open_crate(_active_crate_idx)
		else:
			_hold_f_timer = maxf(0.0, _hold_f_timer - delta * 2.0)
	else:
		_hold_f_timer = 0.0


func _open_crate(idx: int) -> void:
	_opened_crates[idx] = true
	_crate_sprites[idx].texture = load("res://assets/sprites/tiles/crate_open.png")
	AudioManager.play_sfx("clang")

	match _crate_types[idx]:
		"bomb":
			_bomb_found = true
			Events.radar_distance_updated.emit(-1.0)
			var bomb_spr := Sprite2D.new()
			if ResourceLoader.exists("res://assets/sprites/tiles/bomb_device.png"):
				bomb_spr.texture = load("res://assets/sprites/tiles/bomb_device.png")
			# Escala 0.42x (26x16px) para encaixar perfeitamente dentro da caixa aberta (32x24px)!
			bomb_spr.scale = Vector2(0.42, 0.42)
			bomb_spr.position = CRATE_POSITIONS[idx] + Vector2(0.0, 1.0)
			bomb_spr.z_index = int(CRATE_POSITIONS[idx].y) + 1
			add_child(bomb_spr)

			# Pequeno rótulo de tempo logo acima da caixa da bomba para leitura nítida
			_bomb_visor_label = Label.new()
			_bomb_visor_label.text = TrainClock.format_time()
			_bomb_visor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_bomb_visor_label.position = CRATE_POSITIONS[idx] + Vector2(-24.0, -24.0)
			_bomb_visor_label.size = Vector2(48.0, 14.0)
			_bomb_visor_label.z_index = 260
			_bomb_visor_label.add_theme_font_size_override("font_size", 10)
			_bomb_visor_label.add_theme_color_override("font_color", Color("#ff3d6e"))
			add_child(_bomb_visor_label)

			dialogue_box.start_dialogue("wagon3_bomb_found")
			await dialogue_box.dialogue_finished
			_check_wagon3_completion()
		"heal":
			_spawn_steam_cell(CRATE_POSITIONS[idx] + Vector2(0.0, 14.0))
		"trap":
			spawn_enemy("drone", CRATE_POSITIONS[idx] + Vector2(-24.0, -20.0))
			spawn_enemy("drone", CRATE_POSITIONS[idx] + Vector2(24.0, 20.0))


func _check_wagon3_completion() -> void:
	if _bomb_found and _freighter_dead and not door_unlocked:
		unlock_exit_door()
