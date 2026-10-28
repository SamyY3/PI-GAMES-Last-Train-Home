extends CanvasLayer

signal dialogue_finished

const CHARS_PER_SEC: float = 40.0
const MAX_LINES: int = 2
const PORTRAITS: Dictionary = {
	"teo": "portrait_teo",
	"passageiro nervoso": "portrait_nervous",
	"passageiro suspeito": "portrait_suspicious",
	"passageiro curioso": "portrait_curious",
	"funcionário": "portrait_worker",
	"mulher misteriosa": "portrait_woman",
	"mãe": "portrait_mother",
	"pai": "portrait_father",
	"lia": "portrait_lia",
	"maquinista": "portrait_boss",
	"fiscal": "portrait_fiscal",
}
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
var _opened_frame: int = -1

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
	return "res://assets/sprites/portraits/%s.png" % String(PORTRAITS.get(speaker.to_lower(), "portrait_system"))


func start_dialogue(dialogue_key: String) -> void:
	var raw_lines: Variant = GameState.dialogue_db.get(dialogue_key, [])
	if not (raw_lines is Array) or (raw_lines as Array).is_empty():
		push_warning("DialogueBox: chave de diálogo ausente: %s" % dialogue_key)
		dialogue_finished.emit.call_deferred()
		return
	start_custom_lines(raw_lines as Array)


func start_custom_lines(custom_lines: Array) -> void:
	if custom_lines.is_empty():
		dialogue_finished.emit.call_deferred()
		return
	_lines = custom_lines.duplicate()
	_current_index = 0
	_is_active = true
	_opened_frame = Engine.get_process_frames()
	Modals.push(self)
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
	_split_overflow(idx, entry)
	_text_label.visible_characters = 0
	_visible_chars = 0.0
	_last_blip_char = 0
	_next_indicator.visible = false

	if speaker == "Sistema":
		AudioManager.play_sfx("ui_confirm", 0.02)


func _count_lines(text: String) -> int:
	var para := TextParagraph.new()
	para.width = _text_label.size.x
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.add_string(text, _text_label.get_theme_font("font"), _text_label.get_theme_font_size("font_size"))
	return para.get_line_count()


func _split_overflow(idx: int, entry: Dictionary) -> void:
	var full: String = _text_label.text
	if _count_lines(full) <= MAX_LINES:
		return
	var words: PackedStringArray = full.split(" ")
	var cut: int = words.size() - 1
	while cut > 1 and _count_lines(" ".join(words.slice(0, cut))) > MAX_LINES:
		cut -= 1
	var best: int = cut
	for j in range(cut, maxi(1, cut - 8), -1):
		var w: String = words[j - 1]
		if w.ends_with(".") or w.ends_with("!") or w.ends_with("?") or w.ends_with(":") or w.ends_with(","):
			best = j
			break
	_text_label.text = " ".join(words.slice(0, best))
	var rest: Dictionary = entry.duplicate()
	rest["text"] = " ".join(words.slice(best))
	_lines.insert(idx + 1, rest)


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

	if Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed("skip_dialogue") or Input.is_action_just_pressed("confirm") or TouchControls.consume_tap():
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
	Modals.pop(self)
	dialogue_finished.emit()
