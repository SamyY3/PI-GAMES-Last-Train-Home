extends Node2D
class_name LevelBase

const UI_KEY_F: Texture2D = preload("res://assets/sprites/ui/kit/key_f.png")
const UI_SPEECH: Texture2D = preload("res://assets/sprites/ui/kit/speech_bubble.png")
const FX_HP_FILL: Texture2D = preload("res://assets/sprites/fx/hpbar_fill.png")
const FISCAL_POS: Vector2 = Vector2(408.0, 214.0)
const FISCAL_TALK_DIST: float = 36.0

@export var wagon_number: int = 1
@export var next_scene_path: String = ""

var hud: CanvasLayer
var dialogue_box: CanvasLayer
var upgrade_screen: CanvasLayer
var player: CharacterBody2D
var door_unlocked: bool = false
var _transitioning_out: bool = false
var _sway_time: float = 0.0
var _shake_strength: float = 0.0
var _shake_timer: float = 0.0
var _left_door_sprite: Sprite2D
var _right_door_sprite: Sprite2D
var _exit_label: Label
var _steam_cells: Array[Node2D] = []
var _music_calm_t: float = 0.0
var _fiscal_spr: Sprite2D
var _fiscal_drawer: Node2D
var _fiscal_done: bool = false
var _fiscal_busy: bool = false
var _fiscal_anim_t: float = 0.0

var enemy_scene: PackedScene = preload("res://scenes/actors/Enemy_Base.tscn")


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Mira de latão como cursor (3x, no tamanho dos pixels do jogo na janela padrão)
	Input.set_custom_mouse_cursor(load("res://assets/sprites/ui/crosshair_cursor.png"), Input.CURSOR_ARROW, Vector2(22.0, 22.0))
	GameState.current_wagon = wagon_number
	GameState.save_wagon_checkpoint()
	GameState.graze_time_this_level = 0.0

	_setup_doors()

	hud = preload("res://scenes/ui/HUD.tscn").instantiate()
	add_child(hud)
	dialogue_box = preload("res://scenes/ui/DialogueBox.tscn").instantiate()
	add_child(dialogue_box)
	upgrade_screen = preload("res://scenes/ui/UpgradeScreen.tscn").instantiate()
	add_child(upgrade_screen)
	add_child(preload("res://scenes/ui/DebugOverlay.tscn").instantiate())
	add_child(preload("res://scenes/menus/Pause.tscn").instantiate())
	add_child(preload("res://scenes/menus/GameOver.tscn").instantiate())

	player = preload("res://scenes/actors/Player.tscn").instantiate()
	player.global_position = Vector2(44.0, 157.0)
	add_child(player)

	Events.enemy_died.connect(_on_enemy_died)
	Events.request_screen_shake.connect(_on_request_shake)
	AudioManager.set_music_calm(true)


func _setup_doors() -> void:
	var tex_locked: Texture2D = load("res://assets/sprites/tiles/door_locked.png")
	_left_door_sprite = Sprite2D.new()
	_left_door_sprite.texture = tex_locked
	# a arte tem a lateral do batente à esquerda (porta da parede esquerda, de frente para o vagão);
	# na parede direita ela é espelhada
	_left_door_sprite.position = Vector2(10.0, 157.0)
	_left_door_sprite.z_index = 157
	add_child(_left_door_sprite)

	_right_door_sprite = Sprite2D.new()
	_right_door_sprite.texture = tex_locked
	_right_door_sprite.flip_h = true
	_right_door_sprite.position = Vector2(470.0, 157.0)
	_right_door_sprite.z_index = 157
	add_child(_right_door_sprite)

	_exit_label = Label.new()
	_exit_label.text = "SAÍDA ➔"
	_exit_label.position = Vector2(412.0, 118.0)
	_exit_label.add_theme_font_size_override("font_size", 10)
	_exit_label.add_theme_color_override("font_color", Color("#f2c35b"))
	_exit_label.visible = false
	_exit_label.z_index = 240
	add_child(_exit_label)


func _process(delta: float) -> void:
	_update_camera_offset(delta)
	_update_music_layer(delta)
	_check_steam_cell_pickups()
	_update_fiscal(delta)
	if door_unlocked and _exit_label != null:
		_exit_label.visible = int(float(Time.get_ticks_msec()) * 0.004) % 2 == 0
	if door_unlocked and not _transitioning_out and player != null:
		if player.global_position.x >= 448.0:
			_trigger_door_transition()


func _update_music_layer(delta: float) -> void:
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_music_calm_t += delta
		if _music_calm_t >= 2.5:
			AudioManager.set_music_calm(true)
	else:
		_music_calm_t = 0.0
		AudioManager.set_music_calm(false)


func _check_steam_cell_pickups() -> void:
	if player == null:
		return
	for i in range(_steam_cells.size() - 1, -1, -1):
		var cell: Node2D = _steam_cells[i]
		if not is_instance_valid(cell):
			_steam_cells.remove_at(i)
			continue
		if player.global_position.distance_to(cell.global_position) <= 18.0:
			_collect_steam_cell(cell)
			_steam_cells.remove_at(i)


func _collect_steam_cell(cell: Node2D) -> void:
	var cpos: Vector2 = cell.global_position
	GameState.heal_player(1)
	AudioManager.play_sfx("heal")

	var pop := Label.new()
	pop.text = "+1 ♥ VIDA!"
	pop.global_position = cpos + Vector2(-24.0, -20.0)
	pop.z_index = 265
	pop.add_theme_font_size_override("font_size", 10)
	pop.add_theme_color_override("font_color", Color("#8fb8c4"))
	add_child(pop)
	var tw := pop.create_tween()
	tw.tween_property(pop, "global_position:y", pop.global_position.y - 18.0, 0.5)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pop.queue_free)

	cell.queue_free()


func _update_camera_offset(delta: float) -> void:
	var mult: float = Settings.get_shake_multiplier()
	if mult <= 0.0:
		position = Vector2.ZERO
		return

	_sway_time += delta
	var sway_y: float = sin(_sway_time * TAU * 0.8) * 1.0 * mult
	var shake_offset := Vector2.ZERO
	if _shake_timer > 0.0:
		_shake_timer -= delta
		shake_offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		) * mult
	position = Vector2(shake_offset.x, sway_y + shake_offset.y)


func _on_request_shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_timer = maxf(_shake_timer, duration)


func spawn_enemy(type_name: String, pos: Vector2) -> Node2D:
	var e: CharacterBody2D = enemy_scene.instantiate()
	e.set("enemy_type", type_name)
	var spawn_pos: Vector2 = pos
	if player != null and spawn_pos.distance_to(player.global_position) < 100.0:
		spawn_pos.x = 415.0 if player.global_position.x < 240.0 else 65.0
	e.global_position = spawn_pos
	add_child(e)
	return e


func unlock_exit_door() -> void:
	door_unlocked = true
	if ResourceLoader.exists("res://assets/sprites/tiles/door_open.png"):
		_right_door_sprite.texture = load("res://assets/sprites/tiles/door_open.png")
	AudioManager.play_sfx("ui_confirm")
	if hud.has_method("set_contextual_tip"):
		hud.set_contextual_tip("PORTA ABERTA — SIGA PARA A DIREITA ➔")
	if wagon_number <= 4:
		_spawn_fiscal()


func _spawn_fiscal() -> void:
	_fiscal_spr = Sprite2D.new()
	_fiscal_spr.texture = load("res://assets/sprites/npcs/npc_fiscal.png")
	_fiscal_spr.hframes = 4
	_fiscal_spr.position = FISCAL_POS
	_fiscal_spr.z_index = int(FISCAL_POS.y)
	_fiscal_spr.modulate.a = 0.0
	add_child(_fiscal_spr)
	_fiscal_spr.create_tween().tween_property(_fiscal_spr, "modulate:a", 1.0, 0.4)

	_fiscal_drawer = Node2D.new()
	_fiscal_drawer.z_index = 255
	_fiscal_drawer.draw.connect(_draw_fiscal_prompt)
	add_child(_fiscal_drawer)
	hud.set_contextual_tip("PORTA ABERTA ➔  |  {interact} O Fiscal troca tempo por melhorias")


func _fiscal_in_range() -> bool:
	return player != null and player.global_position.distance_to(FISCAL_POS) <= FISCAL_TALK_DIST


func _update_fiscal(delta: float) -> void:
	if _fiscal_spr == null:
		return
	_fiscal_anim_t += delta
	_fiscal_spr.frame = int(_fiscal_anim_t * 5.0) % 4
	if player != null:
		_fiscal_spr.flip_h = player.global_position.x < _fiscal_spr.global_position.x
	_fiscal_drawer.queue_redraw()
	if not _fiscal_done and not _fiscal_busy and not _transitioning_out and _fiscal_in_range():
		if Input.is_action_just_pressed("interact"):
			_talk_to_fiscal()


func _draw_fiscal_prompt() -> void:
	if _fiscal_done or _fiscal_busy:
		return
	if _fiscal_in_range():
		draw_centered_f_prompt(_fiscal_drawer, FISCAL_POS + Vector2(0.0, -22.0), 0.0)
	else:
		draw_speech_bubble_hint(_fiscal_drawer, FISCAL_POS + Vector2(0.0, -20.0))


func _talk_to_fiscal() -> void:
	_fiscal_busy = true
	var price: float = GameState.get_fiscal_price()
	var min_left: float = float(GameState.get_fiscal_config().get("min_clock_after", 30.0))
	var lines: Array = []
	if not GameState.fiscal_met:
		GameState.fiscal_met = true
		lines.append_array(GameState.dialogue_db.get("fiscal_intro", []))

	if not TrainClock.can_afford(price, min_left):
		lines.append_array(GameState.dialogue_db.get("fiscal_broke", []))
		dialogue_box.start_custom_lines(lines)
		await dialogue_box.dialogue_finished
		_fiscal_busy = false
		return

	for entry in GameState.dialogue_db.get("fiscal_offer", []):
		var line: Dictionary = (entry as Dictionary).duplicate()
		line["text"] = String(line.get("text", "")).replace("{price}", TrainClock.format_seconds(price))
		lines.append(line)
	dialogue_box.start_custom_lines(lines)
	await dialogue_box.dialogue_finished

	upgrade_screen.open_shop(price)
	var bought: bool = await upgrade_screen.shop_closed
	if bought:
		_fiscal_done = true
		hud.set_contextual_tip("PORTA ABERTA — SIGA PARA A DIREITA ➔")
	_fiscal_busy = false


func _trigger_door_transition() -> void:
	_transitioning_out = true
	TrainClock.is_running = false
	BulletManager.clear_all_bullets()
	AudioManager.play_sfx("steam_pulse")
	await get_tree().create_timer(0.35).timeout
	SceneRouter.goto_scene(next_scene_path, 0.35)


func _on_enemy_died(pos: Vector2, is_elite: bool) -> void:
	if is_elite:
		_spawn_steam_cell(pos)
		return
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	if bool(diff_cfg.get("allow_random_drops", true)) and GameState.random_drops_spawned < 3:
		if randf() < 0.06:
			GameState.random_drops_spawned += 1
			_spawn_steam_cell(pos)


func _spawn_steam_cell(pos: Vector2) -> void:
	var node := Node2D.new()
	node.global_position = pos
	node.z_index = int(pos.y)

	var spr := Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/ui/steam_cell.png"):
		spr.texture = load("res://assets/sprites/ui/steam_cell.png")
	node.add_child(spr)

	var lbl := Label.new()
	lbl.text = "+1 ♥"
	lbl.position = Vector2(-12.0, -20.0)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color("#8fb8c4"))
	node.add_child(lbl)

	add_child(node)
	_steam_cells.append(node)

	# Tween vinculado ao próprio node: se o node for coletado antes dos 8s, o Tween é cancelado sem erro de lambda!
	var tw := node.create_tween()
	tw.tween_interval(8.0)
	tw.tween_callback(node.queue_free)


func draw_centered_f_prompt(canvas: CanvasItem, center: Vector2, progress_ratio: float = 0.0) -> void:
	var tl: Vector2 = (center - Vector2(10.0, 10.0)).round()
	if Settings.using_gamepad:
		# botão A do controle: disco escuro com aro de latão e a letra no centro
		var c: Vector2 = tl + Vector2(10.5, 8.5)
		canvas.draw_circle(c, 7.5, Color("#0d0b12"))
		canvas.draw_arc(c, 7.0, 0.0, TAU, 20, Color("#f2c35b"), 1.0)
		var fs: int = 10
		var baseline: float = c.y + (Settings.ui_font.get_ascent(fs) - Settings.ui_font.get_descent(fs)) * 0.5
		canvas.draw_string(Settings.ui_font, Vector2(c.x - 10.0, round(baseline)), Settings.get_prompt("interact"), HORIZONTAL_ALIGNMENT_CENTER, 20.0, fs, Color("#fff1c9"))
	elif Settings.touch_mode:
		var pill := Rect2(tl + Vector2(-5.0, 1.0), Vector2(30.0, 15.0))
		canvas.draw_rect(pill, Color("#0d0b12"))
		canvas.draw_rect(pill, Color("#f2c35b"), false, 1.0)
		var tfs: int = 10
		var tbase: float = pill.get_center().y + (Settings.ui_font.get_ascent(tfs) - Settings.ui_font.get_descent(tfs)) * 0.5
		canvas.draw_string(Settings.ui_font, Vector2(pill.position.x, round(tbase)), Settings.get_prompt("interact"), HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, tfs, Color("#fff1c9"))
	else:
		canvas.draw_texture(UI_KEY_F, tl)
	if progress_ratio > 0.0:
		canvas.draw_texture_rect(FX_HP_FILL, Rect2(tl.x + 3.0, tl.y + 16.0, round(15.0 * clampf(progress_ratio, 0.0, 1.0)), 3.0), true, Color("#f2c35b"))


func draw_speech_bubble_hint(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_texture(UI_SPEECH, (center - Vector2(7.0, 6.0)).round())
