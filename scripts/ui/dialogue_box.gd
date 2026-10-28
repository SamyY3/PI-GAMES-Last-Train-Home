extends CanvasLayer

signal dialogue_finished

const CHARS_PER_SEC: float = 40.0
const PALETTE_HEX: Dictionary = {
	8: "#c98a3c",
	9: "#f2c35b",
	10: "#fff1c9",
	11: "#8fb8c4",
	13: "#3f7a6b",
	14: "#b3342e"
}

var _lines: Array = []
var _current_index: int = 0
var _visible_chars: float = 0.0
var _last_blip_char: int = 0
var _is_active: bool = false
var _esc_hold_time: float = 0.0
var _was_clock_running: bool = false

var _root_ctrl: Control
var _panel: Panel
var _portrait_tex: TextureRect
var _speaker_label: Label
var _text_label: Label
var _next_indicator: Label


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root_ctrl.visible = false


func _build_ui() -> void:
	_root_ctrl = Control.new()
	_root_ctrl.position = Vector2.ZERO
	_root_ctrl.size = Vector2(480.0, 270.0)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_ctrl)

	_panel = Panel.new()
	_panel.position = Vector2(16.0, 186.0)
	_panel.size = Vector2(448.0, 60.0)

	_panel.add_theme_stylebox_override("panel", Settings.make_ui_style("panel"))
	_root_ctrl.add_child(_panel)

	_portrait_tex = TextureRect.new()
	# Retratos PixelLab 64x64 em escala 1:1 (sem reamostragem), saindo um pouco acima do painel
	_portrait_tex.position = Vector2(4.0, -6.0)
	_portrait_tex.size = Vector2(64.0, 64.0)
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_panel.add_child(_portrait_tex)

	_speaker_label = Label.new()
	_speaker_label.position = Vector2(74.0, 6.0)
	_speaker_label.size = Vector2(300.0, 14.0)
	_speaker_label.add_theme_font_size_override("font_size", 10)
	_panel.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.position = Vector2(74.0, 22.0)
	_text_label.size = Vector2(364.0, 32.0)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 10)
	_text_label.add_theme_color_override("font_color", Color("#fff1c9"))
	_panel.add_child(_text_label)

	_next_indicator = Label.new()
	Settings.bind_prompt_text(_next_indicator, "▼ {confirm}/{interact}", "▼ {confirm}")
	_next_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next_indicator.position = Vector2(335.0, 44.0)
	_next_indicator.size = Vector2(105.0, 12.0)
	_next_indicator.add_theme_font_size_override("font_size", 10)
	_next_indicator.add_theme_color_override("font_color", Color("#f2c35b"))
	_panel.add_child(_next_indicator)


func _get_portrait_path(speaker: String) -> String:
	var s_low: String = speaker.to_lower()
	if s_low.contains("teo"):
		return "res://assets/sprites/portraits/portrait_teo.png"
	elif s_low.contains("nervos"):
		return "res://assets/sprites/portraits/portrait_nervous.png"
	elif s_low.contains("suspeit"):
		return "res://assets/sprites/portraits/portrait_suspicious.png"
	elif s_low.contains("curios"):
		return "res://assets/sprites/portraits/portrait_curious.png"
	elif s_low.contains("funcion"):
		return "res://assets/sprites/portraits/portrait_worker.png"
	elif s_low.contains("mulher"):
		return "res://assets/sprites/portraits/portrait_woman.png"
	elif s_low.contains("mãe") or s_low.contains("mae"):
		return "res://assets/sprites/portraits/portrait_mother.png"
	elif s_low.contains("pai"):
		return "res://assets/sprites/portraits/portrait_father.png"
	elif s_low.contains("lia"):
		return "res://assets/sprites/portraits/portrait_lia.png"
	elif s_low.contains("maquinista"):
		return "res://assets/sprites/portraits/portrait_boss.png"
	return "res://assets/sprites/portraits/portrait_system.png"


func start_dialogue(dialogue_key: String) -> void:
	var raw_lines: Variant = GameState.dialogue_db.get(dialogue_key, [])
	if not (raw_lines is Array) or (raw_lines as Array).is_empty():
		dialogue_finished.emit()
		return
	start_custom_lines(raw_lines as Array)


func start_custom_lines(custom_lines: Array) -> void:
	if custom_lines.is_empty():
		dialogue_finished.emit()
		return
	_lines = custom_lines
	_current_index = 0
	_is_active = true
	_was_clock_running = TrainClock.is_running
	TrainClock.is_running = false
	get_tree().paused = true
	AudioManager.set_dialogue_ducking(true)
	_root_ctrl.visible = true
	_show_line(0)


func _show_line(idx: int) -> void:
	var entry: Dictionary = _lines[idx]
	var speaker: String = String(entry.get("speaker", ""))
	var color_idx: int = int(entry.get("color", 10))
	var hex: String = String(PALETTE_HEX.get(color_idx, "#fff1c9"))

	_speaker_label.text = speaker.to_upper() if speaker == "Sistema" else speaker
	_speaker_label.add_theme_color_override("font_color", Color(hex))

	var p_path: String = _get_portrait_path(speaker)
	if ResourceLoader.exists(p_path):
		_portrait_tex.texture = load(p_path)

	var text_str: String = String(entry.get("text", ""))
	_text_label.text = text_str.to_upper() if speaker == "Sistema" else text_str
	_text_label.visible_characters = 0
	_visible_chars = 0.0
	_last_blip_char = 0
	_next_indicator.visible = false

	if speaker == "Sistema":
		AudioManager.play_sfx("ui_confirm", 0.02)


func _process(delta: float) -> void:
	if not _is_active:
		return

	if Settings.is_skip_held():
		_esc_hold_time += delta
		if _esc_hold_time >= 1.0:
			_finish_dialogue()
			return
	else:
		_esc_hold_time = 0.0

	var total_chars: int = _text_label.text.length()
	if _text_label.visible_characters < total_chars:
		_visible_chars += CHARS_PER_SEC * delta
		var current_c: int = mini(total_chars, int(_visible_chars))
		_text_label.visible_characters = current_c
		if current_c - _last_blip_char >= 2:
			_last_blip_char = current_c
			AudioManager.play_sfx("blip", 0.04)
	else:
		_next_indicator.visible = int(float(Time.get_ticks_msec()) * 0.004) % 2 == 0

	if Input.is_action_just_pressed("skip_dialogue") or Input.is_action_just_pressed("confirm"):
		if _text_label.visible_characters < total_chars:
			_text_label.visible_characters = total_chars
		else:
			_current_index += 1
			if _current_index >= _lines.size():
				_finish_dialogue()
			else:
				_show_line(_current_index)


func _finish_dialogue() -> void:
	_is_active = false
	_root_ctrl.visible = false
	AudioManager.set_dialogue_ducking(false)
	get_tree().paused = false
	TrainClock.is_running = _was_clock_running
	dialogue_finished.emit()
