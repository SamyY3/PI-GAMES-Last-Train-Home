extends CanvasLayer

const STICK_RADIUS: float = 26.0
const KNOB_RADIUS: float = 10.0
const MOVE_DEADZONE: float = 0.15
const AIM_DEADZONE: float = 0.3
const TAP_WINDOW_FRAMES: int = 1
const LEFT_REST: Vector2 = Vector2(58.0, 206.0)
const RIGHT_REST: Vector2 = Vector2(420.0, 206.0)
const COL_BRASS: Color = Color("#f2c35b")
const COL_DARK: Color = Color("#0d0b12")
const COL_TEXT: Color = Color("#fff1c9")

const PLAY_BUTTONS: Array[Dictionary] = [
	{"action": "dash", "label": "DASH", "pos": Vector2(454.0, 150.0), "r": 15.0},
	{"action": "ability", "label": "PULSO", "pos": Vector2(418.0, 136.0), "r": 15.0},
	{"action": "focus", "label": "FOCO", "pos": Vector2(382.0, 150.0), "r": 15.0, "toggle": true},
	{"action": "interact", "label": "AÇÃO", "pos": Vector2(358.0, 186.0), "r": 15.0},
	{"action": "pause", "label": "II", "pos": Vector2(464.0, 50.0), "r": 11.0},
]
const DPAD_BUTTONS: Array[Dictionary] = [
	{"action": "move_left", "label": "◀", "pos": Vector2(24.0, 128.0), "r": 15.0},
	{"action": "move_right", "label": "▶", "pos": Vector2(60.0, 128.0), "r": 15.0},
	{"action": "move_down", "label": "▼", "pos": Vector2(42.0, 162.0), "r": 15.0},
	{"action": "interact", "label": "AÇÃO", "pos": Vector2(437.0, 145.0), "r": 20.0},
	{"action": "pause", "label": "II", "pos": Vector2(464.0, 50.0), "r": 11.0},
]
const MENU_BUTTONS: Array[Dictionary] = [
	{"action": "pause", "label": "II", "pos": Vector2(464.0, 50.0), "r": 11.0},
]

var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.ZERO
var _mode: String = "off"
var _touches: Dictionary = {}
var _down: Dictionary = {}
var _held_actions: Dictionary = {}
var _focus_on: bool = false
var _tap_frame: int = -100
var _last_back_msec: int = -1000
var _canvas: Control


func _ready() -> void:
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(480.0, 270.0)
	_canvas.visible = false
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)


func is_screen_held() -> bool:
	return Settings.touch_mode and not _down.is_empty()


func consume_tap() -> bool:
	if Engine.get_process_frames() - _tap_frame > TAP_WINDOW_FRAMES:
		return false
	_tap_frame = -100
	return true


func _process(_delta: float) -> void:
	var m: String = _resolve_mode()
	if m != _mode:
		_release_all()
		_mode = m
		_canvas.visible = m != "off"
		Input.emulate_mouse_from_touch = m == "off" or m == "menu"
	if _mode != "off":
		_canvas.queue_redraw()


func _resolve_mode() -> String:
	if not Settings.touch_mode or Settings.using_gamepad:
		return "off"
	var tree: SceneTree = get_tree()
	if tree.paused:
		for overlay in tree.get_nodes_in_group("pause_overlay"):
			if overlay.is_open():
				return "menu"
		return "off"
	var scene: Node = tree.current_scene
	if scene != null and scene.is_in_group("touch_dpad"):
		return "dpad"
	if tree.get_first_node_in_group("player") != null:
		return "play"
	return "off"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var now: int = Time.get_ticks_msec()
		if now - _last_back_msec < 250:
			return
		_last_back_msec = now
		_tap_action("cancel" if _mode == "off" else "pause")


func _tap_action(action: String) -> void:
	_send_action(action, true)
	await get_tree().process_frame
	_send_action(action, false)


func _input(event: InputEvent) -> void:
	if not Settings.touch_mode:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_down[st.index] = true
			if _mode == "off":
				_tap_frame = Engine.get_process_frames()
			else:
				_begin_touch(st.index, st.position)
		else:
			_down.erase(st.index)
			_end_touch(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touches.has(sd.index):
			var t: Dictionary = _touches[sd.index]
			t["pos"] = sd.position
			if t["role"] != "button":
				var off: Vector2 = sd.position - Vector2(t["origin"])
				if off.length() > STICK_RADIUS:
					t["origin"] = sd.position - off.normalized() * STICK_RADIUS
			_update_sticks()


func _buttons() -> Array[Dictionary]:
	match _mode:
		"dpad":
			return DPAD_BUTTONS
		"menu":
			return MENU_BUTTONS
	return PLAY_BUTTONS


func _begin_touch(idx: int, pos: Vector2) -> void:
	for b in _buttons():
		if pos.distance_to(b["pos"]) <= float(b["r"]) + 4.0:
			_touches[idx] = {"role": "button", "action": b["action"], "pos": pos, "origin": pos}
			if b.get("toggle", false):
				_focus_on = not _focus_on
				_send_action(b["action"], _focus_on)
			else:
				_send_action(b["action"], true)
			return
	if _mode != "play":
		return
	var role: String = "move" if pos.x < 240.0 else "aim"
	for t in _touches.values():
		if t["role"] == role:
			return
	var origin := Vector2(clampf(pos.x, STICK_RADIUS + 4.0, 476.0 - STICK_RADIUS), clampf(pos.y, 40.0 + STICK_RADIUS, 268.0 - STICK_RADIUS))
	_touches[idx] = {"role": role, "pos": pos, "origin": origin}
	if role == "aim":
		_send_action("shoot", true)
	_update_sticks()


func _end_touch(idx: int) -> void:
	if not _touches.has(idx):
		return
	var t: Dictionary = _touches[idx]
	_touches.erase(idx)
	match t["role"]:
		"button":
			if t["action"] != "focus":
				_send_action(t["action"], false)
		"aim":
			_send_action("shoot", false)
	_update_sticks()


func _stick_value(t: Dictionary) -> Vector2:
	var v: Vector2 = (Vector2(t["pos"]) - Vector2(t["origin"])) / STICK_RADIUS
	return v.normalized() if v.length() > 1.0 else v


func _update_sticks() -> void:
	move_vector = Vector2.ZERO
	aim_vector = Vector2.ZERO
	for t in _touches.values():
		if t["role"] == "button":
			continue
		var v: Vector2 = _stick_value(t)
		if t["role"] == "move" and v.length() >= MOVE_DEADZONE:
			move_vector = v
		elif t["role"] == "aim" and v.length() >= AIM_DEADZONE:
			aim_vector = v.normalized()


func _send_action(action: String, pressed: bool) -> void:
	if pressed:
		_held_actions[action] = true
	else:
		_held_actions.erase(action)
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for action in _held_actions.keys():
		_send_action(action, false)
	_touches.clear()
	_focus_on = false
	move_vector = Vector2.ZERO
	aim_vector = Vector2.ZERO


func _draw_controls() -> void:
	if _mode == "play":
		_draw_stick("move", LEFT_REST)
		_draw_stick("aim", RIGHT_REST)
	var player: Node = get_tree().get_first_node_in_group("player")
	for b in _buttons():
		var pressed: bool = (b["action"] == "focus" and _focus_on)
		for t in _touches.values():
			if t["role"] == "button" and t["action"] == b["action"]:
				pressed = true
		var ready_ratio: float = 1.0
		if player != null and b["action"] == "dash":
			ready_ratio = player.get_dash_cooldown_ratio()
		elif player != null and b["action"] == "ability":
			ready_ratio = player.get_pulse_cooldown_ratio()
		_draw_button(b, pressed, ready_ratio)


func _draw_stick(role: String, rest: Vector2) -> void:
	var active: Dictionary = {}
	for t in _touches.values():
		if t["role"] == role:
			active = t
	var base: Vector2 = (Vector2(active["origin"]) if not active.is_empty() else rest).round()
	var alpha: float = 0.85 if not active.is_empty() else 0.4
	var knob: Vector2 = base + (_stick_value(active) * STICK_RADIUS if not active.is_empty() else Vector2.ZERO)
	_canvas.draw_circle(base, STICK_RADIUS, Color(COL_DARK, 0.35 * alpha))
	_canvas.draw_arc(base, STICK_RADIUS, 0.0, TAU, 40, Color(COL_BRASS, alpha), 1.0)
	_canvas.draw_circle(knob.round(), KNOB_RADIUS, Color(COL_BRASS, 0.7 * alpha))
	_canvas.draw_arc(knob.round(), KNOB_RADIUS, 0.0, TAU, 24, Color(COL_DARK, alpha), 1.0)


func _draw_button(b: Dictionary, pressed: bool, ready_ratio: float) -> void:
	var pos: Vector2 = b["pos"]
	var r: float = b["r"]
	var fill: Color = Color(COL_BRASS, 0.8) if pressed else Color(COL_DARK, 0.55)
	_canvas.draw_circle(pos, r, fill)
	if ready_ratio < 1.0:
		_canvas.draw_arc(pos, r - 2.0, -PI / 2.0, -PI / 2.0 + TAU * ready_ratio, 32, Color(COL_BRASS, 0.5), 2.0)
		_canvas.draw_arc(pos, r, 0.0, TAU, 32, Color(COL_BRASS, 0.35), 1.0)
	else:
		_canvas.draw_arc(pos, r, 0.0, TAU, 32, Color(COL_BRASS, 0.9), 1.0)
	var font: Font = Settings.ui_font
	var txt_col: Color = COL_DARK if pressed else Color(COL_TEXT, 1.0 if ready_ratio >= 1.0 else 0.5)
	_canvas.draw_string(font, Vector2(pos.x - r, pos.y + 4.0), String(b["label"]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 10, txt_col)
