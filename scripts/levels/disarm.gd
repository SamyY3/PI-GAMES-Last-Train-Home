extends Node2D

var hud: CanvasLayer
var dialogue_box: CanvasLayer
var step: int = 0
var _valve_count: int = 0
var _expect_right: bool = false
var _hold_timer: float = 0.0
var _correct_wire: int = 0
var _selected_wire: int = 0
var _anim_t: float = 0.0

var _bomb_canvas: Node2D
var _visor_timer_label: Label
var _status_label: Label
var _wire_target_label: Label
var _instruction_label: Label
var _panel_style: StyleBoxTexture
var _visor_style: StyleBoxTexture

const CABIN_TEX: Texture2D = preload("res://assets/sprites/backgrounds/wagon_5.png")
const VALVE_TEX: Texture2D = preload("res://assets/sprites/disarm/valve_wheel.png")
const LEVER_TRACK_TEX: Texture2D = preload("res://assets/sprites/disarm/lever_track.png")
const LEVER_HANDLE_TEX: Texture2D = preload("res://assets/sprites/disarm/lever_handle.png")
const WIRE_TEX: Texture2D = preload("res://assets/sprites/disarm/wire.png")
const CORE_TEX: Texture2D = preload("res://assets/sprites/disarm/core.png")


func _ready() -> void:
	GameState.current_wagon = 6
	TrainClock.apply_section_rubber_band("disarm")
	TrainClock.set_time(18.0)
	GameState.save_wagon_checkpoint()

	hud = preload("res://scenes/ui/HUD.tscn").instantiate()
	add_child(hud)
	dialogue_box = preload("res://scenes/ui/DialogueBox.tscn").instantiate()
	add_child(dialogue_box)
	add_child(preload("res://scenes/menus/Pause.tscn").instantiate())
	add_child(preload("res://scenes/menus/GameOver.tscn").instantiate())

	hud.set_wagon_title("DESARME DA BOMBA")
	_build_panel_ui()

	dialogue_box.start_dialogue("post_boss")
	await dialogue_box.dialogue_finished

	TrainClock.set_time(18.0)
	TrainClock.is_running = true
	step = 1
	_update_step_ui()


func _build_panel_ui() -> void:
	# Fundo: a cabine da locomotiva escurecida (pixel art)
	var bg := Sprite2D.new()
	bg.texture = CABIN_TEX
	bg.position = Vector2(240.0, 135.0)
	bg.modulate = Color(0.42, 0.38, 0.45)
	add_child(bg)
	_panel_style = Settings.make_ui_style("panel")
	_visor_style = Settings.make_ui_style("panel_small")

	_bomb_canvas = Node2D.new()
	_bomb_canvas.draw.connect(_draw_steampunk_bomb_device)
	add_child(_bomb_canvas)

	_visor_timer_label = Label.new()
	_visor_timer_label.text = "00:18"
	_visor_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_visor_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_visor_timer_label.position = Vector2(185.0, 74.0)
	_visor_timer_label.size = Vector2(110.0, 22.0)
	_visor_timer_label.add_theme_font_size_override("font_size", 20)
	if Settings.title_font != null:
		_visor_timer_label.add_theme_font_override("font", Settings.title_font)
	_visor_timer_label.add_theme_color_override("font_color", Color("#fff1c9"))
	add_child(_visor_timer_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position = Vector2(90.0, 32.0)
	_status_label.size = Vector2(300.0, 18.0)
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color("#f2c35b"))
	add_child(_status_label)

	_wire_target_label = Label.new()
	_wire_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wire_target_label.position = Vector2(90.0, 50.0)
	_wire_target_label.size = Vector2(300.0, 18.0)
	_wire_target_label.add_theme_font_size_override("font_size", 10)
	_wire_target_label.visible = false
	add_child(_wire_target_label)

	_instruction_label = Label.new()
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.position = Vector2(20.0, 204.0)
	_instruction_label.size = Vector2(440.0, 42.0)
	_instruction_label.add_theme_font_size_override("font_size", 10)
	_instruction_label.add_theme_color_override("font_color", Color("#fff1c9"))
	add_child(_instruction_label)


func _draw_steampunk_bomb_device() -> void:
	var c: Node2D = _bomb_canvas
	# Carcaça da bomba (moldura de latão do kit) e visor do relógio
	c.draw_style_box(_panel_style, Rect2(86.0, 70.0, 308.0, 126.0))
	c.draw_style_box(_visor_style, Rect2(182.0, 72.0, 116.0, 26.0))

	# 1) Válvula: gira a cada meia-volta; brilha no passo ativo, esverdeia quando concluída
	var v_col: Color = Color(1.3, 1.2, 0.9) if step == 1 else (Color(0.6, 1.0, 0.85) if step > 1 else Color(0.6, 0.6, 0.7))
	c.draw_set_transform(Vector2(135.0, 144.0), float(_valve_count) * (PI / 3.0))
	c.draw_texture(VALVE_TEX, Vector2(-24.0, -24.0), v_col)
	c.draw_set_transform(Vector2.ZERO, 0.0)

	# 2) Alavanca: manopla desce enquanto o jogador segura
	c.draw_texture(LEVER_TRACK_TEX, Vector2(192.0, 112.0))
	var l_prog: float = 1.0 if step > 2 else (clampf(_hold_timer / 1.0, 0.0, 1.0) if step == 2 else 0.0)
	var handle_y: float = round(118.0 + l_prog * 48.0)
	var handle_col: Color = Color(1.2, 1.1, 0.8) if step == 2 else (Color(0.6, 1.0, 0.85) if step > 2 else Color.WHITE)
	c.draw_texture(LEVER_HANDLE_TEX, Vector2(184.0, handle_y - 6.0), handle_col)

	# 3) Fios: o selecionado ganha moldura; o correto aparece cortado
	var wire_colors: Array[Color] = [Color("#ff3d6e"), Color("#8fb8c4"), Color("#f2c35b")]
	for w in range(3):
		var wx: float = 254.0 + float(w) * 22.0
		if step == 3 and _selected_wire == w:
			c.draw_style_box(_visor_style, Rect2(wx - 8.0, 106.0, 16.0, 76.0))
		if step > 3 and w == _correct_wire:
			c.draw_texture_rect_region(WIRE_TEX, Rect2(wx - 4.0, 112.0, 8.0, 24.0), Rect2(0.0, 0.0, 8.0, 24.0), wire_colors[w])
			c.draw_texture_rect_region(WIRE_TEX, Rect2(wx - 4.0, 154.0, 8.0, 22.0), Rect2(0.0, 42.0, 8.0, 22.0), wire_colors[w])
		else:
			c.draw_texture_rect(WIRE_TEX, Rect2(wx - 4.0, 112.0, 8.0, 64.0), false, wire_colors[w])

	# 4) Núcleo: pulsa em brilho e apaga enquanto é drenado
	var core_active: float = 1.0 - (clampf(_hold_timer / 1.2, 0.0, 1.0) if step == 4 else (1.0 if step > 4 else 0.0))
	var glow: float = 0.35 + core_active * (0.85 + sin(_anim_t * 10.0) * 0.25)
	c.draw_texture(CORE_TEX, Vector2(326.0, 120.0), Color(glow, glow * (0.6 + 0.4 * core_active), glow * (0.5 + 0.5 * core_active)))


func _process(delta: float) -> void:
	_anim_t += delta
	_visor_timer_label.text = TrainClock.format_time()
	_bomb_canvas.queue_redraw()
	if not TrainClock.is_running or step == 0:
		return

	match step:
		1:
			if not _expect_right and Input.is_action_just_pressed("move_left"):
				_expect_right = true
				_valve_count += 1
				AudioManager.play_sfx("tick")
			elif _expect_right and Input.is_action_just_pressed("move_right"):
				_expect_right = false
				_valve_count += 1
				AudioManager.play_sfx("tick")
			_status_label.text = "PASSO 1/4 — VÁLVULA DE VAPOR: %d / 6" % _valve_count
			if _valve_count >= 6:
				step = 2
				_hold_timer = 0.0
				AudioManager.play_sfx("ui_confirm")
				_update_step_ui()
		2:
			if Input.is_action_pressed("move_down") or Input.is_action_pressed("interact"):
				_hold_timer += delta
			else:
				_hold_timer = maxf(0.0, _hold_timer - delta)
			_status_label.text = "PASSO 2/4 — ALAVANCA: %d%%" % int(clampf(_hold_timer / 1.0, 0.0, 1.0) * 100.0)
			if _hold_timer >= 1.0:
				step = 3
				_correct_wire = randi() % 3
				_selected_wire = 0
				AudioManager.play_sfx("ui_confirm")
				_update_step_ui()
		3:
			var wire_names: Array[String] = ["VERMELHO (1º)", "AZUL (2º)", "AMARELO (3º)"]
			var wire_hex: Array[String] = ["#ff6b3d", "#8fb8c4", "#f2c35b"]
			_wire_target_label.visible = true
			_wire_target_label.text = "⚠ CORTE O FIO: %s ⚠" % wire_names[_correct_wire]
			_wire_target_label.add_theme_color_override("font_color", Color(wire_hex[_correct_wire]))

			if Input.is_action_just_pressed("move_left"):
				_selected_wire = posmod(_selected_wire - 1, 3)
				AudioManager.play_sfx("ui_hover")
			elif Input.is_action_just_pressed("move_right"):
				_selected_wire = posmod(_selected_wire + 1, 3)
				AudioManager.play_sfx("ui_hover")
			_status_label.text = "PASSO 3/4 — SELECIONADO: < %s >" % wire_names[_selected_wire]

			if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("confirm"):
				if _selected_wire == _correct_wire:
					step = 4
					_hold_timer = 0.0
					_wire_target_label.visible = false
					AudioManager.play_sfx("ui_confirm")
					_update_step_ui()
				else:
					AudioManager.play_sfx("player_hurt")
					Events.request_screen_shake.emit(3.0, 0.2)
					TrainClock.set_time(TrainClock.time_left - 2.0)
		4:
			if Input.is_action_pressed("interact"):
				_hold_timer += delta
			else:
				_hold_timer = maxf(0.0, _hold_timer - delta)
			_status_label.text = "PASSO 4/4 — DESLIGANDO NÚCLEO: %d%%" % int(clampf(_hold_timer / 1.2, 0.0, 1.0) * 100.0)
			if _hold_timer >= 1.2:
				step = 5
				AudioManager.play_sfx("upgrade_get")
				SceneRouter.goto_scene("res://scenes/levels/Ending.tscn")


func _update_step_ui() -> void:
	match step:
		1:
			_instruction_label.text = "Alterne [A] e [D] (ou Setas Esq/Dir) 6 vezes para girar a válvula!"
		2:
			_instruction_label.text = "Segure [S] ou [F] por 1,0 segundo para baixar a alavanca!"
		3:
			_instruction_label.text = "Use [A/D] para escolher o fio indicado acima e pressione [F] para cortar!"
		4:
			_instruction_label.text = "Segure [F] por 1,2 segundos para apagar o núcleo da bomba!"
