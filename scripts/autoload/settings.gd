extends Node

const SAVE_PATH: String = "user://settings.cfg"

const DEFAULT_KEYBINDS: Dictionary = {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"shoot": KEY_J,
	"dash": KEY_SPACE,
	"ability": KEY_Q,
	"focus": KEY_SHIFT,
	"interact": KEY_F
}

var master_volume: int = 100
var music_volume: int = 80
var sfx_volume: int = 100
var fullscreen: bool = false
var screen_shake_mode: int = 2
var reduce_flashes: bool = false
var auto_aim: bool = false
var always_show_hitbox: bool = false
var show_damage_numbers: bool = true
var high_contrast_bullets: bool = false
var last_difficulty: String = "medium"
var custom_keybinds: Dictionary = {}
var ui_font: Font
var title_font: Font # Jersey 10: nítida em 20px, usada nos títulos


func _ready() -> void:
	custom_keybinds = DEFAULT_KEYBINDS.duplicate()
	load_settings()
	_setup_input_map()
	_setup_global_theme()
	apply_settings()


func _setup_global_theme() -> void:
	var font_path: String = "res://assets/fonts/DotGothic16.ttf" # mais legível em 10px (números e acentos claros)
	if FileAccess.file_exists(font_path):
		var ffile := FontFile.new()
		if ffile.load_dynamic_font(font_path) == OK:
			ffile.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ffile.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			ui_font = ffile
	var title_path: String = "res://assets/fonts/Jersey10.ttf"
	if FileAccess.file_exists(title_path):
		var tfile := FontFile.new()
		if tfile.load_dynamic_font(title_path) == OK:
			tfile.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			tfile.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			title_font = tfile
	if ui_font == null:
		var sysf := SystemFont.new()
		sysf.font_names = PackedStringArray(["Consolas", "Lucida Console", "Monospace"])
		sysf.font_weight = 700
		ui_font = sysf

	var def_theme: Theme = ThemeDB.get_default_theme()
	if def_theme != null:
		def_theme.default_font = ui_font
		def_theme.default_font_size = 10

		def_theme.set_font("font", "Label", ui_font)
		def_theme.set_font_size("font_size", "Label", 10)
		def_theme.set_color("font_outline_color", "Label", Color("#0d0b12"))
		def_theme.set_constant("outline_size", "Label", 2)

		def_theme.set_font("font", "Button", ui_font)
		def_theme.set_font_size("font_size", "Button", 10)
		def_theme.set_stylebox("normal", "Button", make_ui_style("button_normal"))
		def_theme.set_stylebox("hover", "Button", make_ui_style("button_hover"))
		def_theme.set_stylebox("focus", "Button", make_ui_style("button_hover"))
		def_theme.set_stylebox("pressed", "Button", make_ui_style("button_pressed"))
		def_theme.set_stylebox("disabled", "Button", make_ui_style("button_pressed"))
		def_theme.set_stylebox("panel", "Panel", make_ui_style("panel"))
		def_theme.set_stylebox("panel", "PanelContainer", make_ui_style("panel"))
		def_theme.set_color("font_color", "Button", Color("#fff1c9"))
		def_theme.set_color("font_focus_color", "Button", Color("#f2c35b"))
		def_theme.set_color("font_hover_color", "Button", Color("#f2c35b"))
		def_theme.set_color("font_outline_color", "Button", Color("#0d0b12"))
		def_theme.set_constant("outline_size", "Button", 2)

		get_tree().root.theme = def_theme


# Kit de UI em pixel art (assets/sprites/ui/kit): molduras 9-slice de latão rebitado
func make_ui_style(kind: String) -> StyleBoxTexture:
	var st := StyleBoxTexture.new()
	st.texture = load("res://assets/sprites/ui/kit/%s.png" % kind)
	var is_button: bool = kind.begins_with("button")
	var is_small: bool = kind == "panel_small"
	var m: float = 4.0 if is_button else (3.0 if is_small else 6.0)
	st.texture_margin_left = m
	st.texture_margin_right = m
	st.texture_margin_top = m
	st.texture_margin_bottom = m
	# panel_small (selos de upgrade, tooltips) tem borda fina: margens menores para caber na base da tela
	st.content_margin_left = 4.0 if is_small else 8.0
	st.content_margin_right = 4.0 if is_small else 8.0
	st.content_margin_top = 3.0 if (is_button or is_small) else 6.0
	st.content_margin_bottom = 3.0 if (is_button or is_small) else 6.0
	return st


func _setup_input_map() -> void:
	# Teclas secundárias fixas de apoio (setas, Enter, Esc)
	var secondary_keys: Dictionary = {
		"move_left": [KEY_LEFT],
		"move_right": [KEY_RIGHT],
		"move_up": [KEY_UP],
		"move_down": [KEY_DOWN],
		"shoot": [KEY_Z],
		"dash": [],
		"ability": [KEY_E],
		"focus": [],
		"interact": [],
		"confirm": [KEY_ENTER, KEY_KP_ENTER],
		"cancel": [KEY_ESCAPE, KEY_BACKSPACE],
		"pause": [KEY_ESCAPE],
		"skip_dialogue": [KEY_ENTER, KEY_KP_ENTER, int(custom_keybinds.get("interact", KEY_F))]
	}

	for action in secondary_keys.keys():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)

		# Adiciona a tecla principal customizada pelo jogador (se existir para esta ação)
		if custom_keybinds.has(action):
			var primary_ev := InputEventKey.new()
			primary_ev.keycode = int(custom_keybinds[action]) as Key
			InputMap.action_add_event(action, primary_ev)

		# Adiciona teclas secundárias sem duplicar
		for k in secondary_keys[action]:
			if not custom_keybinds.has(action) or int(custom_keybinds[action]) != int(k):
				var ev := InputEventKey.new()
				ev.keycode = int(k) as Key
				InputMap.action_add_event(action, ev)

	# Clique esquerdo é exclusivo para atirar (shoot)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mb)

	var pad_bindings: Dictionary = {
		"shoot": [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER],
		"dash": [JOY_BUTTON_B],
		"ability": [JOY_BUTTON_Y],
		"focus": [JOY_BUTTON_LEFT_SHOULDER],
		"interact": [JOY_BUTTON_A],
		"confirm": [JOY_BUTTON_A],
		"cancel": [JOY_BUTTON_B],
		"pause": [JOY_BUTTON_START],
		"skip_dialogue": [JOY_BUTTON_A]
	}
	for action in pad_bindings.keys():
		for btn in pad_bindings[action]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = btn
			InputMap.action_add_event(action, jb)


func remap_action_key(action: String, new_key: int) -> void:
	if not custom_keybinds.has(action):
		return
	var old_key: int = int(custom_keybinds[action])
	# Prevenção de conflitos: se outra ação já usa new_key, troca as teclas entre elas!
	for other_act in custom_keybinds.keys():
		if other_act != action and int(custom_keybinds[other_act]) == new_key:
			custom_keybinds[other_act] = old_key
			break
	custom_keybinds[action] = new_key
	_setup_input_map()
	save_settings()


func reset_keybinds_to_default() -> void:
	custom_keybinds = DEFAULT_KEYBINDS.duplicate()
	_setup_input_map()
	save_settings()


func get_action_key_name(action: String) -> String:
	var k: int = int(custom_keybinds.get(action, DEFAULT_KEYBINDS.get(action, KEY_NONE)))
	var s: String = OS.get_keycode_string(k as Key)
	if s == "Space":
		return "ESPAÇO"
	elif s == "Shift":
		return "SHIFT"
	elif s == "Escape":
		return "ESC"
	return s.to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		fullscreen = not fullscreen
		apply_settings()
		save_settings()


func apply_settings() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume, -6.0)
	_set_bus_volume("SFX", sfx_volume)


func _set_bus_volume(bus_name: String, percent: int, offset_db: float = 0.0) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if percent <= 0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		var linear: float = float(percent) / 100.0
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear) + offset_db)


func get_shake_multiplier() -> float:
	if screen_shake_mode == 0:
		return 0.0
	elif screen_shake_mode == 1:
		return 0.5
	return 1.0


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "screen_shake_mode", screen_shake_mode)
	cfg.set_value("video", "reduce_flashes", reduce_flashes)
	cfg.set_value("gameplay", "auto_aim", auto_aim)
	cfg.set_value("gameplay", "always_show_hitbox", always_show_hitbox)
	cfg.set_value("gameplay", "show_damage_numbers", show_damage_numbers)
	cfg.set_value("gameplay", "high_contrast_bullets", high_contrast_bullets)
	cfg.set_value("gameplay", "last_difficulty", last_difficulty)
	for act in custom_keybinds.keys():
		cfg.set_value("keybinds", String(act), int(custom_keybinds[act]))
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master_volume = int(cfg.get_value("audio", "master_volume", 100))
	music_volume = int(cfg.get_value("audio", "music_volume", 80))
	sfx_volume = int(cfg.get_value("audio", "sfx_volume", 100))
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	screen_shake_mode = int(cfg.get_value("video", "screen_shake_mode", 2))
	reduce_flashes = bool(cfg.get_value("video", "reduce_flashes", false))
	auto_aim = bool(cfg.get_value("gameplay", "auto_aim", false))
	always_show_hitbox = bool(cfg.get_value("gameplay", "always_show_hitbox", false))
	show_damage_numbers = bool(cfg.get_value("gameplay", "show_damage_numbers", true))
	high_contrast_bullets = bool(cfg.get_value("gameplay", "high_contrast_bullets", false))
	last_difficulty = String(cfg.get_value("gameplay", "last_difficulty", "medium"))
	for act in DEFAULT_KEYBINDS.keys():
		custom_keybinds[act] = int(cfg.get_value("keybinds", String(act), DEFAULT_KEYBINDS[act]))
