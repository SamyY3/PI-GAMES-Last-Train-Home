extends Control
## Menu inicial: JOGAR, DIFICULDADE, CONTROLES, SAIR.
## O fundo animado (cidade, trem, vapor e engrenagens) é todo desenhado por código, sem asset nenhum.

const MAIN_SCENE := "res://scenes/main.tscn"
const GOLD := Color(0.8, 0.6, 0.25)

var scroll := 0.0
var gear_rot := 0.0
var puffs: Array = []        # [pos: Vector2, age: float, size: float]
var puff_t := 0.0
var screen := "main"
var sel := 1

var main_box: Control
var diff_box: Control
var ctrl_box: Control
var play_btn: Button
var diff_btn: Button
var clock_label: Label
var clock_caption: Label
var cards: Array = []
var fade: ColorRect
var _going := false


func _ready() -> void:
	sel = Game.difficulty
	_build_main()
	_build_diff()
	_build_controls()
	clock_label = _label(self, "", Vector2(880, 24), Vector2(380, 60), 44, Color(1, 0.4, 0.3), HORIZONTAL_ALIGNMENT_RIGHT)
	clock_caption = _label(self, "TEMPO ATÉ A ESTAÇÃO ZERO", Vector2(880, 8), Vector2(380, 18), 13, Color(0.8, 0.6, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh()
	_show("main")
	create_tween().tween_property(fade, "color:a", 0.0, 0.5)


func _process(delta: float) -> void:
	scroll += delta * 170.0
	gear_rot += delta * 0.35
	puff_t -= delta
	if puff_t <= 0.0:
		puff_t = 0.16
		puffs.append([Vector2(1095.0, 470.0), 0.0, randf_range(10.0, 18.0)])
	for p in puffs:
		p[1] += delta
		p[0] += Vector2(-60.0 - scroll * 0.0, -42.0) * delta
	puffs = puffs.filter(func(p): return p[1] < 3.0)
	queue_redraw()


# ---------------------------------------------------------------- montando a tela

func _build_main() -> void:
	main_box = Control.new()
	main_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_box)
	main_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label(main_box, "LAST TRAIN HOME", Vector2(70, 50), Vector2(900, 90), 78, Color(0.95, 0.75, 0.35))
	_label(main_box, "Encontre a bomba. Desarme-a antes da Estação Zero.", Vector2(76, 145), Vector2(800, 30), 22, Color(0.85, 0.8, 0.75))
	play_btn = _button(main_box, "JOGAR", Vector2(76, 225), Vector2(360, 58), 26, GOLD)
	play_btn.pressed.connect(_play)
	diff_btn = _button(main_box, "", Vector2(76, 297), Vector2(360, 50), 20, GOLD)
	diff_btn.pressed.connect(func(): _show("diff"))
	var ctrl_btn := _button(main_box, "CONTROLES", Vector2(76, 361), Vector2(360, 50), 20, GOLD)
	ctrl_btn.pressed.connect(func(): _show("ctrl"))
	var quit_btn := _button(main_box, "SAIR", Vector2(76, 425), Vector2(360, 50), 20, GOLD)
	quit_btn.pressed.connect(get_tree().quit)


func _build_diff() -> void:
	diff_box = Control.new()
	diff_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(diff_box)
	diff_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Panel.new()
	bg.position = Vector2(100, 50)
	bg.size = Vector2(1080, 600)
	bg.add_theme_stylebox_override("panel", _style(GOLD, Color(0.05, 0.04, 0.06, 0.94), 3, 10))
	diff_box.add_child(bg)
	_label(diff_box, "ESCOLHA A DIFICULDADE", Vector2(100, 66), Vector2(1080, 50), 36, Color(0.95, 0.75, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	_label(diff_box, "Os inimigos também ficam mais fortes conforme a sua build evolui — em todas as dificuldades.",
			Vector2(100, 112), Vector2(1080, 24), 16, Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	for i in Game.DIFFICULTIES.size():
		var d: Dictionary = Game.DIFFICULTIES[i]
		var col: Color = d["color"]
		var b := Button.new()
		b.position = Vector2(124.0 + i * 258.0, 150.0)
		b.size = Vector2(246, 410)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_select.bind(i))
		diff_box.add_child(b)
		_label(b, d["name"], Vector2(0, 14), Vector2(246, 40), 32, col, HORIZONTAL_ALIGNMENT_CENTER)
		_label(b, d["tag"], Vector2(0, 54), Vector2(246, 22), 14, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
		var lines: Array = Game.diff_lines(i)
		var l := _label(b, "\n".join(lines), Vector2(16, 90), Vector2(220, 280), 15, Color(0.88, 0.88, 0.92))
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		_label(b, "[ %d ]" % (i + 1), Vector2(0, 372), Vector2(246, 30), 22, col, HORIZONTAL_ALIGNMENT_CENTER)
		cards.append(b)
	var back := _button(diff_box, "CONFIRMAR  (Enter)", Vector2(430, 580), Vector2(420, 50), 20, GOLD)
	back.pressed.connect(func(): _show("main"))


func _build_controls() -> void:
	ctrl_box = Control.new()
	ctrl_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ctrl_box)
	ctrl_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Panel.new()
	bg.position = Vector2(240, 70)
	bg.size = Vector2(800, 580)
	bg.add_theme_stylebox_override("panel", _style(GOLD, Color(0.05, 0.04, 0.06, 0.94), 3, 10))
	ctrl_box.add_child(bg)
	_label(ctrl_box, "CONTROLES", Vector2(240, 86), Vector2(800, 50), 36, Color(0.95, 0.75, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	var rows := [
		["WASD / Setas", "Mover"],
		["Mouse", "Mirar"],
		["Clique esquerdo / J", "Atirar"],
		["Shift", "Esquiva (invulnerável por instantes)"],
		["Ctrl", "Movimento lento (precisão)"],
		["E / Enter / Espaço", "Interagir e avançar diálogos"],
		["1 / 2 / 3  ou  clique", "Escolher melhoria"],
		["R (na escolha)", "Trocar as opções de melhoria"],
		["Desarme final", "Q → E → R → F"],
	]
	for i in rows.size():
		_label(ctrl_box, rows[i][0], Vector2(280, 160.0 + i * 40.0), Vector2(300, 30), 20, Color(1, 0.85, 0.4))
		_label(ctrl_box, rows[i][1], Vector2(590, 160.0 + i * 40.0), Vector2(420, 30), 20, Color(0.9, 0.9, 0.95))
	var back := _button(ctrl_box, "VOLTAR  (Esc)", Vector2(430, 580), Vector2(420, 50), 20, GOLD)
	back.pressed.connect(func(): _show("main"))


# ---------------------------------------------------------------- lógica do menu

func _show(which: String) -> void:
	screen = which
	main_box.visible = which == "main"
	diff_box.visible = which == "diff"
	ctrl_box.visible = which == "ctrl"
	clock_label.visible = which == "main"
	clock_caption.visible = which == "main"
	if which == "main":
		play_btn.grab_focus()


func _select(i: int) -> void:
	sel = wrapi(i, 0, Game.DIFFICULTIES.size())
	Game.set_difficulty(sel)
	_refresh()


func _refresh() -> void:
	var d: Dictionary = Game.diff()
	var col: Color = d["color"]
	diff_btn.text = "DIFICULDADE:  %s" % d["name"]
	diff_btn.add_theme_color_override("font_color", col)
	var t := int(d["time"])
	clock_label.text = "%02d:%02d" % [t / 60, t % 60]
	for i in cards.size():
		var c: Color = Game.DIFFICULTIES[i]["color"]
		var on := i == sel
		var b: Button = cards[i]
		b.add_theme_stylebox_override("normal", _style(c if on else c.darkened(0.55), Color(0.11, 0.14, 0.18) if on else Color(0.06, 0.07, 0.1), 6 if on else 2, 10))
		b.add_theme_stylebox_override("hover", _style(c.lightened(0.15), Color(0.12, 0.16, 0.2), 5, 10))
		b.add_theme_stylebox_override("pressed", _style(c.lightened(0.3), Color(0.16, 0.2, 0.26), 6, 10))


func _play() -> void:
	if _going:
		return
	_going = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	await tw.finished
	get_tree().change_scene_to_file(MAIN_SCENE)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	if screen == "diff":
		if k == KEY_LEFT or k == KEY_A:
			_select(sel - 1)
		elif k == KEY_RIGHT or k == KEY_D:
			_select(sel + 1)
		elif k >= KEY_1 and k <= KEY_4:
			_select(k - KEY_1)
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_ESCAPE or k == KEY_SPACE:
			_show("main")
		else:
			return
		get_viewport().set_input_as_handled()
	elif screen == "ctrl":
		if k == KEY_ESCAPE or k == KEY_ENTER or k == KEY_KP_ENTER:
			_show("main")
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- helpers de UI

func _style(border: Color, bg: Color, width := 3, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


func _label(parent: Node, text: String, pos: Vector2, sz: Vector2, font_size := 18, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	l.size = sz
	return l


func _button(parent: Node, text: String, pos: Vector2, sz: Vector2, font_size: int, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(accent.darkened(0.3), Color(0.08, 0.07, 0.09, 0.92), 2, 8))
	b.add_theme_stylebox_override("hover", _style(accent.lightened(0.2), Color(0.18, 0.14, 0.1, 0.96), 4, 8))
	b.add_theme_stylebox_override("focus", _style(accent.lightened(0.35), Color(0.18, 0.14, 0.1, 0.96), 4, 8))
	b.add_theme_stylebox_override("pressed", _style(Color.WHITE, Color(0.25, 0.18, 0.1), 4, 8))
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- fundo animado

func _draw() -> void:
	# céu
	for i in 24:
		var k := i / 23.0
		draw_rect(Rect2(0, i * 30.0, 1280, 31.0), Color(0.04, 0.03, 0.07).lerp(Color(0.22, 0.1, 0.09), k * k))
	# lua / brilho lá longe
	for i in 6:
		draw_circle(Vector2(1010, 190), 90.0 - i * 13.0, Color(1.0, 0.55, 0.25, 0.035 + i * 0.012))
	# engrenagens lá no fundo
	_gear(Vector2(1180, 330), 90.0, 14, gear_rot, Color(0.25, 0.15, 0.1, 0.55))
	_gear(Vector2(1075, 410), 55.0, 10, -gear_rot * 1.6, Color(0.3, 0.18, 0.1, 0.55))
	_gear(Vector2(40, 560), 80.0, 12, gear_rot * 0.8, Color(0.25, 0.15, 0.1, 0.5))
	# cidade em duas camadas (parallax)
	_skyline(0.12, 470.0, Color(0.08, 0.06, 0.1), 0.0)
	_skyline(0.3, 520.0, Color(0.05, 0.04, 0.07), 7.0)
	# trilhos
	draw_rect(Rect2(0, 596, 1280, 124), Color(0.04, 0.03, 0.04))
	draw_rect(Rect2(0, 600, 1280, 6), Color(0.45, 0.35, 0.2))
	for i in 24:
		var x := fposmod(i * 64.0 - scroll, 1344.0) - 64.0
		draw_rect(Rect2(x, 612, 34, 10), Color(0.2, 0.14, 0.09))
	# trem: 3 vagões + locomotiva (balançando de leve)
	var bob := sin(Time.get_ticks_msec() * 0.016) * 1.2
	for i in 3:
		_car(Vector2(-30.0 + i * 292.0, 520.0 + bob), 280.0)
	_loco(Vector2(850.0, 505.0 + bob))
	# fumaça
	for p in puffs:
		var a: float = 0.45 * (1.0 - float(p[1]) / 3.0)
		draw_circle(p[0], float(p[2]) + float(p[1]) * 14.0, Color(0.85, 0.85, 0.9, a))


func _skyline(speed: float, base_y: float, col: Color, seed_off: float) -> void:
	for i in 34:
		var x := fposmod(i * 62.0 - scroll * speed, 34.0 * 62.0) - 62.0
		var h := 50.0 + float(int(i * 37 + seed_off * 11.0) % 6) * 24.0
		draw_rect(Rect2(x, base_y - h, 56.0, h + 80.0), col)
		if speed > 0.2:
			continue
		for w in 6:
			if (i * 7 + w * 3) % 4 == 0:
				draw_rect(Rect2(x + 8.0 + (w % 3) * 16.0, base_y - h + 10.0 + (w / 3) * 22.0, 7.0, 9.0), Color(1.0, 0.8, 0.4, 0.55))


func _car(pos: Vector2, w: float) -> void:
	draw_rect(Rect2(pos, Vector2(w, 72.0)), Color(0.3, 0.17, 0.1))
	draw_rect(Rect2(pos, Vector2(w, 72.0)), Color(0.75, 0.55, 0.22), false, 3.0)
	draw_rect(Rect2(pos + Vector2(-4, -8), Vector2(w + 8, 10)), Color(0.14, 0.1, 0.09))
	for i in 5:
		draw_rect(Rect2(pos + Vector2(14.0 + i * 52.0, 14.0), Vector2(34, 30)), Color(1.0, 0.82, 0.4, 0.9))
	for i in 3:
		draw_circle(pos + Vector2(40.0 + i * 100.0, 78.0), 14.0, Color(0.12, 0.1, 0.1))
		draw_circle(pos + Vector2(40.0 + i * 100.0, 78.0), 5.0, Color(0.6, 0.45, 0.2))


func _loco(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(0, 25), Vector2(300, 62)), Color(0.18, 0.1, 0.08))            # corpo
	draw_rect(Rect2(pos + Vector2(0, 25), Vector2(300, 62)), Color(0.75, 0.55, 0.22), false, 3.0)
	draw_rect(Rect2(pos + Vector2(20, -20), Vector2(110, 50)), Color(0.22, 0.13, 0.09))         # cabine
	draw_rect(Rect2(pos + Vector2(20, -20), Vector2(110, 50)), Color(0.75, 0.55, 0.22), false, 3.0)
	draw_rect(Rect2(pos + Vector2(40, -8), Vector2(40, 24)), Color(1.0, 0.82, 0.4, 0.9))
	draw_rect(Rect2(pos + Vector2(215, -10), Vector2(30, 40)), Color(0.12, 0.08, 0.07))         # chaminé
	draw_rect(Rect2(pos + Vector2(208, -18), Vector2(44, 10)), Color(0.12, 0.08, 0.07))
	draw_circle(pos + Vector2(290, 56), 26.0, Color(1.0, 0.85, 0.5, 0.18))                      # farol
	draw_circle(pos + Vector2(296, 56), 10.0, Color(1.0, 0.92, 0.6))
	for i in 3:
		draw_circle(pos + Vector2(60.0 + i * 90.0, 95.0), 20.0, Color(0.12, 0.1, 0.1))
		draw_circle(pos + Vector2(60.0 + i * 90.0, 95.0), 7.0, Color(0.75, 0.55, 0.22))


func _gear(c: Vector2, r: float, teeth: int, rot: float, col: Color) -> void:
	draw_arc(c, r, 0.0, TAU, 40, col, 10.0)
	draw_arc(c, r * 0.35, 0.0, TAU, 20, col, 6.0)
	for i in teeth:
		var d := Vector2.RIGHT.rotated(rot + TAU * i / float(teeth))
		draw_line(c + d * (r - 4.0), c + d * (r + 16.0), col, 12.0)
	for i in 4:
		var d2 := Vector2.RIGHT.rotated(rot + TAU * i / 4.0)
		draw_line(c + d2 * r * 0.35, c + d2 * r, col, 6.0)
