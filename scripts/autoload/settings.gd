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

# Controle (layout Xbox; o SDL do Godot mapeia PlayStation/Switch para os mesmos botões)
signal input_device_changed(using_gamepad: bool)
const ALL_DEVICES: int = -1 # binds de controle valem para qualquer joypad conectado
const STICK_DEADZONE: float = 0.25
const NAV_STICK_PRESS: float = 0.5
const NAV_STICK_RELEASE: float = 0.35
const NAV_REPEAT_DELAY: float = 0.38
const NAV_REPEAT_RATE: float = 0.11
const MOUSE_SWITCH_GRACE_MSEC: int = 400
const MOUSE_SWITCH_TRAVEL: float = 24.0
const PAD_PROMPTS: Dictionary = {
	"move": "LS",
	"aim": "RS",
	"move_up": "▲",
	"move_down": "▼",
	"move_left": "◀",
	"move_right": "▶",
	"shoot": "RT",
	"dash": "B",
	"ability": "Y",
	"focus": "LT",
	"interact": "A",
	"confirm": "A",
	"cancel": "B",
	"pause": "START",
	"menu_alt": "X",
	"tab_prev": "LB",
	"tab_next": "RB"
}

# Botões remapeáveis do controle (aba CONTROLE das Opções). Gatilhos são guardados como
# PAD_TRIGGER_BASE + eixo, para caber no mesmo int dos botões.
const PAD_TRIGGER_BASE: int = 100
const PAD_LT: int = PAD_TRIGGER_BASE + JOY_AXIS_TRIGGER_LEFT
const PAD_RT: int = PAD_TRIGGER_BASE + JOY_AXIS_TRIGGER_RIGHT
const DEFAULT_PAD_BINDS: Dictionary = {
	"shoot": PAD_RT,
	"dash": JOY_BUTTON_B,
	"ability": JOY_BUTTON_Y,
	"focus": PAD_LT,
	"interact": JOY_BUTTON_A
}
# Start (pausa) e D-pad (movimento/menus) ficam de fora: são fixos
const PAD_BIND_NAMES: Dictionary = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_MISC1: "SHARE",
	JOY_BUTTON_PADDLE1: "P1",
	JOY_BUTTON_PADDLE2: "P2",
	JOY_BUTTON_PADDLE3: "P3",
	JOY_BUTTON_PADDLE4: "P4",
	PAD_LT: "LT",
	PAD_RT: "RT"
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
var custom_pad_binds: Dictionary = {}
var vibration_enabled: bool = true
var using_gamepad: bool = false
var joy_device: int = 0
var _nav_button: int = -1 # botão do D-pad emulado pelo analógico esquerdo
var _nav_repeat_t: float = 0.0
var _device_switch_msec: int = 0
var _mouse_travel: float = 0.0
var _prompt_bindings: Array = [] # [WeakRef do Control, modelo teclado, modelo controle]
var ui_font: Font
var title_font: Font # Jersey 10: nítida em 20px, usada nos títulos


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # analógico e troca de dispositivo também com o jogo pausado
	custom_keybinds = DEFAULT_KEYBINDS.duplicate()
	custom_pad_binds = DEFAULT_PAD_BINDS.duplicate()
	load_settings()
	_setup_input_map()
	_setup_global_theme()
	apply_settings()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var pads: Array[int] = Input.get_connected_joypads()
	if not pads.is_empty():
		joy_device = pads[0]


func _load_pixel_font(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var f := load(path) as FontFile
	if f == null:
		return null
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_LIGHT
	return f


func _setup_global_theme() -> void:
	ui_font = _load_pixel_font("res://assets/fonts/DotGothic16.ttf") # mais legível em 10px (números e acentos claros)
	title_font = _load_pixel_font("res://assets/fonts/Jersey10.ttf")
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
		"skip_dialogue": [KEY_ENTER, KEY_KP_ENTER, int(custom_keybinds.get("interact", KEY_F))],
		"menu_alt": [KEY_R],
		"tab_prev": [],
		"tab_next": []
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

	# O analógico esquerdo NÃO entra nas ações: o Teo lê o eixo direto (get_left_stick) e,
	# nos menus, _update_stick_nav o converte em toques de D-pad com repetição controlada
	# (eventos de eixo disparam "pressed" a cada variação e pulariam vários itens de uma vez).
	# Botões fixos: movimento pelo D-pad e navegação de menus
	var pad_bindings: Dictionary = {
		"move_up": [JOY_BUTTON_DPAD_UP],
		"move_down": [JOY_BUTTON_DPAD_DOWN],
		"move_left": [JOY_BUTTON_DPAD_LEFT],
		"move_right": [JOY_BUTTON_DPAD_RIGHT],
		"confirm": [JOY_BUTTON_A],
		"cancel": [JOY_BUTTON_B],
		"pause": [JOY_BUTTON_START],
		"skip_dialogue": [JOY_BUTTON_A],
		"menu_alt": [JOY_BUTTON_X],
		"tab_prev": [JOY_BUTTON_LEFT_SHOULDER],
		"tab_next": [JOY_BUTTON_RIGHT_SHOULDER],
		# no Godot 4 o ui_accept padrão não tem botão de controle: sem isso o A não aperta botões
		"ui_accept": [JOY_BUTTON_A]
	}
	for action in pad_bindings.keys():
		for btn in pad_bindings[action]:
			_add_pad_event(action, btn)

	# Botões escolhidos pelo jogador (o de interagir também avança diálogos)
	for action in custom_pad_binds.keys():
		_add_pad_event(action, int(custom_pad_binds[action]))
	_add_pad_event("skip_dialogue", int(custom_pad_binds.get("interact", JOY_BUTTON_A)))

	# As ações ui_* padrão do Godot incluem o eixo do analógico; ficam só com o D-pad (ver acima)
	for ui_act in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		for ev in InputMap.action_get_events(ui_act):
			if ev is InputEventJoypadMotion:
				InputMap.action_erase_event(ui_act, ev)


# code: índice do botão, ou PAD_TRIGGER_BASE + eixo para os gatilhos
func _add_pad_event(action: String, code: int) -> void:
	var ev: InputEvent
	if code >= PAD_TRIGGER_BASE:
		var jm := InputEventJoypadMotion.new()
		jm.axis = (code - PAD_TRIGGER_BASE) as JoyAxis
		jm.axis_value = 1.0
		ev = jm
	else:
		var jb := InputEventJoypadButton.new()
		jb.button_index = code as JoyButton
		ev = jb
	ev.device = ALL_DEVICES
	InputMap.action_add_event(action, ev) # ignora duplicatas ao remontar o mapa


# Converte um evento do controle no código de bind; -1 se não pode ser usado (Start, D-pad, analógicos)
func pad_code_from_event(event: InputEvent) -> int:
	var code: int = -1
	if event is InputEventJoypadButton and event.pressed:
		code = (event as InputEventJoypadButton).button_index
	elif event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis_value > 0.6:
		code = PAD_TRIGGER_BASE + (event as InputEventJoypadMotion).axis
	return code if PAD_BIND_NAMES.has(code) else -1


func get_pad_bind_name(action: String) -> String:
	return String(PAD_BIND_NAMES.get(int(custom_pad_binds.get(action, -1)), "?"))


func remap_action_pad(action: String, new_code: int) -> void:
	if not custom_pad_binds.has(action) or not PAD_BIND_NAMES.has(new_code):
		return
	var old_code: int = int(custom_pad_binds[action])
	# mesmo esquema do teclado: se outra ação já usa o botão, as duas trocam
	for other_act in custom_pad_binds.keys():
		if other_act != action and int(custom_pad_binds[other_act]) == new_code:
			custom_pad_binds[other_act] = old_code
			break
	custom_pad_binds[action] = new_code
	_setup_input_map()
	_refresh_prompt_bindings()
	save_settings()


func reset_pad_binds_to_default() -> void:
	custom_pad_binds = DEFAULT_PAD_BINDS.duplicate()
	_setup_input_map()
	_refresh_prompt_bindings()
	save_settings()


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


# Nome curto da tecla/botão de uma ação no dispositivo em uso (ex.: "F" no teclado, "A" no controle)
func get_prompt(action: String) -> String:
	if using_gamepad:
		if custom_pad_binds.has(action):
			return get_pad_bind_name(action)
		return String(PAD_PROMPTS.get(action, "?"))
	match action:
		"move":
			var parts := PackedStringArray()
			for a in ["move_up", "move_left", "move_down", "move_right"]:
				parts.append(get_action_key_name(a))
			var joined: String = "".join(parts)
			return joined if joined.length() == 4 else "/".join(parts)
		"aim":
			return "MOUSE"
		"shoot":
			return "MOUSE/" + get_action_key_name("shoot")
		"confirm":
			return "ENTER"
		"cancel", "pause":
			return "ESC"
		"menu_alt":
			return "R"
	var key_name: String = get_action_key_name(action)
	return "ESP" if key_name == "ESPAÇO" else key_name


# Troca cada {acao} do texto por [TECLA] ou [BOTÃO]: "Pressione {interact}" -> "Pressione [F]" ou "[A]"
func format_prompts(template: String) -> String:
	var out: String = template
	for action in PAD_PROMPTS.keys():
		var token: String = "{%s}" % action
		if out.contains(token):
			out = out.replace(token, "[%s]" % get_prompt(action))
	return out


# Mantém o texto de um Label/Button em dia quando o jogador alterna entre teclado e controle.
# pad_template (opcional) substitui o texto inteiro enquanto o controle está em uso.
func bind_prompt_text(ctrl: Control, template: String, pad_template: String = "") -> void:
	# um vínculo por Control: chamar de novo (ex.: dica contextual nova) substitui o modelo anterior
	_prompt_bindings = _prompt_bindings.filter(func(b: Array) -> bool: return (b[0] as WeakRef).get_ref() != ctrl)
	_prompt_bindings.append([weakref(ctrl), template, pad_template])
	_apply_prompt_binding(ctrl, template, pad_template)


func _apply_prompt_binding(ctrl: Control, template: String, pad_template: String) -> void:
	var txt: String = format_prompts(pad_template if (using_gamepad and pad_template != "") else template)
	if ctrl.has_meta("base_text"):
		# botões estilizados do menu mostram "▶ texto ◀" quando focados
		ctrl.set_meta("base_text", txt)
		ctrl.set("text", ("▶ " + txt + " ◀") if ctrl.has_focus() else txt)
	else:
		ctrl.set("text", txt)


func _refresh_prompt_bindings() -> void:
	var alive: Array = []
	for b in _prompt_bindings:
		var ctrl: Control = (b[0] as WeakRef).get_ref()
		if ctrl == null:
			continue
		_apply_prompt_binding(ctrl, String(b[1]), String(b[2]))
		alive.append(b)
	_prompt_bindings = alive


func get_left_stick() -> Vector2:
	return _read_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)


func get_right_stick() -> Vector2:
	return _read_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)


# Zona morta radial com reescala: o valor sai de 0 suavemente ao passar do limite
func _read_stick(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(joy_device, axis_x), Input.get_joy_axis(joy_device, axis_y))
	var l: float = v.length()
	if l < STICK_DEADZONE:
		return Vector2.ZERO
	return v / l * minf(1.0, (l - STICK_DEADZONE) / (1.0 - STICK_DEADZONE))


# Segurar para pular (introdução e diálogos): ESC no teclado, B no controle
func is_skip_held() -> bool:
	return Input.is_key_pressed(KEY_ESCAPE) or Input.is_joy_button_pressed(joy_device, JOY_BUTTON_B)


func rumble(weak: float, strong: float, duration: float) -> void:
	if vibration_enabled and using_gamepad:
		Input.start_joy_vibration(joy_device, weak, strong, duration)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4):
		joy_device = event.device
		_set_using_gamepad(true)
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_set_using_gamepad(false)
	elif event is InputEventMouseMotion and using_gamepad:
		# Só volta ao teclado/mouse com movimento real e acumulado. Esconder o cursor pode gerar
		# eventos de movimento (principalmente com o jogo embutido no editor); sem essa trava,
		# controle e mouse ficariam alternando a cada quadro.
		if Time.get_ticks_msec() - _device_switch_msec < MOUSE_SWITCH_GRACE_MSEC:
			return
		_mouse_travel += (event as InputEventMouseMotion).relative.length()
		if _mouse_travel > MOUSE_SWITCH_TRAVEL:
			_set_using_gamepad(false)


func _set_using_gamepad(value: bool) -> void:
	if using_gamepad == value:
		return
	using_gamepad = value
	_device_switch_msec = Time.get_ticks_msec()
	_mouse_travel = 0.0
	# com controle o cursor some (o Teo desenha a própria retícula de mira)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if value else Input.MOUSE_MODE_VISIBLE
	_refresh_prompt_bindings()
	input_device_changed.emit(value)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if not using_gamepad:
			joy_device = device
		return
	if device != joy_device:
		return
	_release_stick_nav()
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		_set_using_gamepad(false)
	else:
		joy_device = pads[0]


func _process(delta: float) -> void:
	_update_stick_nav(delta)


# Analógico esquerdo -> toques de D-pad (com repetição ao segurar) para menus e telas de escolha
func _update_stick_nav(delta: float) -> void:
	var v := Vector2(Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_X), Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_Y))
	var btn: int = _nav_button
	if v.length() >= NAV_STICK_PRESS:
		if absf(v.x) > absf(v.y):
			btn = JOY_BUTTON_DPAD_RIGHT if v.x > 0.0 else JOY_BUTTON_DPAD_LEFT
		else:
			btn = JOY_BUTTON_DPAD_DOWN if v.y > 0.0 else JOY_BUTTON_DPAD_UP
	elif v.length() < NAV_STICK_RELEASE:
		btn = -1

	if btn != _nav_button:
		_release_stick_nav()
		if btn != -1:
			_nav_button = btn
			_send_nav_button(btn, true)
			_nav_repeat_t = NAV_REPEAT_DELAY
	elif btn != -1:
		_nav_repeat_t -= delta
		if _nav_repeat_t <= 0.0:
			_send_nav_button(btn, false)
			_send_nav_button(btn, true)
			_nav_repeat_t = NAV_REPEAT_RATE


func _release_stick_nav() -> void:
	if _nav_button != -1:
		_send_nav_button(_nav_button, false)
	_nav_button = -1


func _send_nav_button(btn: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = joy_device
	ev.button_index = btn as JoyButton
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


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
	cfg.set_value("gameplay", "vibration_enabled", vibration_enabled)
	for act in custom_keybinds.keys():
		cfg.set_value("keybinds", String(act), int(custom_keybinds[act]))
	for act in custom_pad_binds.keys():
		cfg.set_value("padbinds", String(act), int(custom_pad_binds[act]))
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
	vibration_enabled = bool(cfg.get_value("gameplay", "vibration_enabled", true))
	for act in DEFAULT_KEYBINDS.keys():
		custom_keybinds[act] = int(cfg.get_value("keybinds", String(act), DEFAULT_KEYBINDS[act]))
	for act in DEFAULT_PAD_BINDS.keys():
		var code: int = int(cfg.get_value("padbinds", String(act), DEFAULT_PAD_BINDS[act]))
		custom_pad_binds[act] = code if PAD_BIND_NAMES.has(code) else int(DEFAULT_PAD_BINDS[act])
