class_name HUD
extends CanvasLayer
## Toda a interface: status (vida em segmentos, escudo, esquiva), timer, ondas, boss, diálogos (dourado),
## melhorias (ciano/cores das categorias) e o feedback de dano (vinheta).

signal advance
signal choice_made(idx: int)
signal key_hit

const GOLD := Color(0.8, 0.6, 0.25)
const PANEL_BG := Color(0.07, 0.05, 0.07, 0.88)

var stage_label: Label
var objective_label: Label
var timer_label: Label
var prompt_label: Label
var flash_label: Label
var center_bg: ColorRect
var center_label: Label
var boss_name: Label
var dlg_panel: Panel
var dlg_speaker: Label
var dlg_text: Label
var choice_root: ColorRect
var choice_title: Label
var card_holder: Control
var reroll_label: Label
var build_row: HFlowContainer
var banner_panel: Panel
var banner_title: Label
var banner_text: Label

var vignette: Vignette
var hp_bar: HpBar
var dash_meter: Meter
var time_meter: Meter
var boss_meter: Meter
var pips: WavePips
var diff_panel: Panel
var diff_label: Label

var _last_hp := -1
var _last_shield := 0
var _awaiting_advance := false
var _lock := 0.0
var _choosing := false
var _choice_count := 0
var _rerolls := 0
var _wait_key := -1
var _flash_id := 0
var _banner_id := 0


func _ready() -> void:
	layer = 10
	_build()


func _process(delta: float) -> void:
	_lock = maxf(0.0, _lock - delta)


# ---------- montando tudo ----------

func _style(border: Color, bg: Color, width := 3, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


func _mk(parent: Node, text: String, pos: Vector2, sz: Vector2, font_size := 18, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	l.size = sz   # tem que setar de novo depois de entrar na árvore, senão a quebra de linha ignora a largura
	return l


func _panel(pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(Color(0.5, 0.38, 0.18), PANEL_BG, 2, 6))
	add_child(p)
	return p


func _build() -> void:
	# Vinheta de dano / vida baixa (fica atrás de todo o resto)
	vignette = Vignette.new()
	vignette.size = Vector2(1280, 720)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# --- painel de status (esquerda) ---
	_panel(Vector2(12, 6), Vector2(470, 98))
	stage_label = _mk(self, "", Vector2(24, 8), Vector2(446, 24), 18)
	stage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	objective_label = _mk(self, "", Vector2(24, 32), Vector2(446, 22), 13, Color(1, 0.85, 0.4))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	objective_label.clip_text = true
	_mk(self, "INTEGRIDADE", Vector2(24, 54), Vector2(200, 14), 11, Color(0.75, 0.6, 0.6))
	hp_bar = HpBar.new()
	hp_bar.position = Vector2(24, 68)
	hp_bar.size = Vector2(300, 28)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bar)
	_mk(self, "ESQUIVA  [Shift]", Vector2(340, 54), Vector2(130, 14), 11, Color(0.6, 0.75, 0.6))
	dash_meter = Meter.new()
	dash_meter.position = Vector2(340, 70)
	dash_meter.size = Vector2(130, 14)
	dash_meter.fill = Color(0.4, 0.9, 0.5)
	dash_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dash_meter)

	# --- painel do tempo (direita) ---
	_panel(Vector2(800, 6), Vector2(468, 98))
	_mk(self, "TEMPO ATÉ A ESTAÇÃO ZERO", Vector2(812, 8), Vector2(444, 16), 13, Color(0.9, 0.8, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	timer_label = _mk(self, "15:00", Vector2(812, 22), Vector2(444, 50), 42, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	time_meter = Meter.new()
	time_meter.position = Vector2(1000, 74)
	time_meter.size = Vector2(256, 10)
	time_meter.fill = Color(0.95, 0.8, 0.4)
	time_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_meter)
	pips = WavePips.new()
	pips.position = Vector2(812, 78)
	pips.size = Vector2(180, 20)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pips)

	# --- selo de dificuldade (centro) ---
	diff_panel = Panel.new()
	diff_panel.position = Vector2(560, 8)
	diff_panel.size = Vector2(160, 26)
	diff_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(diff_panel)
	diff_label = _mk(diff_panel, "", Vector2(0, 2), Vector2(160, 22), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	prompt_label = _mk(self, "", Vector2(240, 614), Vector2(800, 30), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	flash_label = _mk(self, "", Vector2(240, 300), Vector2(800, 80), 48, Color(1, 0.6, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	flash_label.visible = false

	# Faixa fixa com as melhorias (chips coloridos por categoria), embaixo da arena
	build_row = HFlowContainer.new()
	build_row.position = Vector2(20, 656)
	build_row.size = Vector2(1240, 60)
	build_row.add_theme_constant_override("h_separation", 6)
	build_row.add_theme_constant_override("v_separation", 4)
	add_child(build_row)

	boss_name = _mk(self, "O MAQUINISTA", Vector2(490, 38), Vector2(300, 20), 15, Color(1, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	boss_meter = Meter.new()
	boss_meter.position = Vector2(490, 60)
	boss_meter.size = Vector2(300, 20)
	boss_meter.fill = Color(0.85, 0.2, 0.2)
	boss_meter.ghost_on = true
	boss_meter.ticks = [0.33, 0.66]
	boss_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_meter)
	hide_boss()

	# Diálogo da história (dourado)
	dlg_panel = Panel.new()
	dlg_panel.position = Vector2(60, 500)
	dlg_panel.size = Vector2(1160, 190)
	dlg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg_panel.visible = false
	dlg_panel.add_theme_stylebox_override("panel", _style(Color(0.8, 0.6, 0.25), Color(0.11, 0.08, 0.05, 0.96)))
	add_child(dlg_panel)
	dlg_speaker = _mk(dlg_panel, "", Vector2(24, 12), Vector2(800, 30), 22, Color(1, 0.85, 0.4))
	dlg_text = _mk(dlg_panel, "", Vector2(24, 48), Vector2(1110, 120), 22)
	_mk(dlg_panel, "[E / Enter / clique] continuar", Vector2(850, 160), Vector2(300, 24), 14, Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)

	# Escolha de melhoria (cartas)
	choice_root = ColorRect.new()
	choice_root.color = Color(0, 0.02, 0.05, 0.82)
	choice_root.size = Vector2(1280, 720)
	choice_root.visible = false
	add_child(choice_root)
	choice_title = _mk(choice_root, "", Vector2(140, 50), Vector2(1000, 50), 34, Color(0.4, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	card_holder = Control.new()
	card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_root.add_child(card_holder)
	reroll_label = _mk(choice_root, "", Vector2(140, 570), Vector2(1000, 30), 18, Color(0.8, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER)

	# Banner de "melhoria obtida" (não trava o jogo)
	banner_panel = Panel.new()
	banner_panel.position = Vector2(290, 128)
	banner_panel.size = Vector2(700, 74)
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.visible = false
	add_child(banner_panel)
	banner_title = _mk(banner_panel, "", Vector2(16, 6), Vector2(670, 24), 14, Color(0.4, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	banner_text = _mk(banner_panel, "", Vector2(16, 30), Vector2(670, 36), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	# Tela do meio (game over / final)
	center_bg = ColorRect.new()
	center_bg.color = Color(0, 0, 0, 0.85)
	center_bg.size = Vector2(1280, 720)
	center_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_bg.visible = false
	add_child(center_bg)
	center_label = _mk(center_bg, "", Vector2(140, 140), Vector2(1000, 460), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


# ---------- API ----------

func set_stage(s: String) -> void:
	stage_label.text = s


func set_objective(s: String) -> void:
	objective_label.text = ("» " + s) if s != "" else ""


func set_difficulty(d: Dictionary) -> void:
	var col: Color = d["color"]
	diff_panel.add_theme_stylebox_override("panel", _style(col, Color(0.05, 0.04, 0.06, 0.9), 2, 13))
	diff_label.add_theme_color_override("font_color", col)
	diff_label.text = d["name"]


func set_hp(hp: int, max_hp: int) -> void:
	var sh: int = Game.shield
	if _last_hp >= 0:
		if hp < _last_hp:
			vignette.hit(Color(1.0, 0.1, 0.1), 1.0)
		elif hp == _last_hp and sh < _last_shield:
			vignette.hit(Color(0.4, 0.75, 1.0), 0.6)
	_last_hp = hp
	_last_shield = sh
	hp_bar.set_values(hp, max_hp, sh)
	vignette.low = hp > 0 and (hp <= 1 or float(hp) / float(max_hp) <= 0.25)


func set_dash(ratio: float) -> void:
	dash_meter.ratio = ratio
	dash_meter.fill = Color(0.4, 0.95, 0.5) if ratio >= 1.0 else Color(0.9, 0.6, 0.25)
	dash_meter.text = "PRONTA" if ratio >= 1.0 else ""


func set_wave(cur: int, total: int) -> void:
	pips.set_wave(cur, total)


func set_timer(t: float) -> void:
	var s := int(ceilf(maxf(t, 0.0)))
	timer_label.text = "%02d:%02d" % [s / 60, s % 60]
	var col := Color.WHITE
	if t < 60.0:
		col = Color(1, 0.3, 0.25).lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
	elif t < 120.0:
		col = Color(1, 0.6, 0.25)
	timer_label.add_theme_color_override("font_color", col)
	time_meter.ratio = clampf(t / Game.time_total(), 0.0, 1.0)
	time_meter.fill = Color(1, 0.3, 0.25) if t < 60.0 else (Color(1, 0.6, 0.25) if t < 120.0 else Color(0.95, 0.8, 0.4))


func set_prompt(s: String) -> void:
	prompt_label.text = s


func set_boss(hp: float, max_hp: float, phase := 1) -> void:
	boss_meter.visible = true
	boss_name.visible = true
	boss_meter.ratio = clampf(hp / max_hp, 0.0, 1.0)
	boss_meter.fill = [Color(0.85, 0.2, 0.2), Color(0.95, 0.5, 0.15), Color(1.0, 0.2, 0.55)][clampi(phase - 1, 0, 2)]
	boss_meter.text = "%d" % int(ceilf(maxf(hp, 0.0)))
	boss_name.text = "O MAQUINISTA   —   FASE %d/3" % phase


func hide_boss() -> void:
	boss_meter.visible = false
	boss_name.visible = false


func show_center(text: String, font_size := 28) -> void:
	center_label.add_theme_font_size_override("font_size", font_size)
	center_label.text = text
	center_bg.visible = true


func hide_center() -> void:
	center_bg.visible = false


func flash(text: String, secs := 1.5) -> void:
	_flash_id += 1
	var my_id := _flash_id
	flash_label.text = text
	flash_label.visible = true
	await get_tree().create_timer(secs).timeout
	if my_id == _flash_id:
		flash_label.visible = false


## Faixa fixa com as melhorias que você já tem. entries = Game.build_entries()
func set_build(entries: Array) -> void:
	for c in build_row.get_children():
		c.queue_free()
	for e in entries:
		var col: Color = e["color"]
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := _style(col, Color(0.05, 0.07, 0.1, 0.92), 2, 4)
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_top = 2.0
		sb.content_margin_bottom = 2.0
		chip.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = "%s  %d/%d" % [e["name"], e["lvl"], e["max"]]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", col.lightened(0.35))
		chip.add_child(l)
		build_row.add_child(chip)


## Banner colorido que aparece quando você pega uma melhoria. inf = Game.info(id) (já com o nível atualizado)
func upgrade_banner(inf: Dictionary) -> void:
	_banner_id += 1
	var my_id := _banner_id
	var col: Color = inf["color"]
	banner_panel.add_theme_stylebox_override("panel", _style(col, Color(0.04, 0.07, 0.1, 0.93)))
	banner_title.add_theme_color_override("font_color", col)
	banner_title.text = "[+] MELHORIA OBTIDA  —  %s" % inf["cat_name"]
	var lv := "" if inf["id"] == "repair" else "  Nv %d" % inf["lvl"]
	banner_text.text = "%s%s  —  %s" % [inf["name"], lv, inf["desc"]]
	banner_panel.modulate.a = 1.0
	banner_panel.visible = true
	await get_tree().create_timer(2.8).timeout
	if my_id != _banner_id:
		return
	var tw := create_tween()
	tw.tween_property(banner_panel, "modulate:a", 0.0, 0.4)
	await tw.finished
	if my_id == _banner_id:
		banner_panel.visible = false


## lines: [[quem fala, texto], ...] ou strings soltas (narração)
func say(lines: Array) -> void:
	dlg_panel.visible = true
	for l in lines:
		if l is Array:
			dlg_speaker.text = l[0]
			dlg_text.text = l[1]
			dlg_text.add_theme_color_override("font_color", Color.WHITE)
		else:
			dlg_speaker.text = ""
			dlg_text.text = str(l)
			dlg_text.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
		_lock = 0.15
		_awaiting_advance = true
		await advance
	_awaiting_advance = false
	dlg_panel.visible = false


func wait_advance() -> void:
	_lock = 0.15
	_awaiting_advance = true
	await advance
	_awaiting_advance = false


func wait_key(code: int) -> void:
	_wait_key = code
	await key_hit


## Mostra as cartas de melhoria. Devolve o índice escolhido, ou -1 se o jogador pediu pra trocar (R).
func choose(title: String, ids: Array, rerolls := 0) -> int:
	choice_title.text = title
	for c in card_holder.get_children():
		c.queue_free()
	var n := ids.size()
	var w := 340.0
	var gap := 30.0
	var x0 := 640.0 - (n * w + (n - 1) * gap) * 0.5
	for i in n:
		card_holder.add_child(_make_card(ids[i], i, Vector2(x0 + i * (w + gap), 130.0), Vector2(w, 400.0)))
	reroll_label.text = ("[R] Trocar as opções  (restam %d)" % rerolls) if rerolls > 0 else ""
	_rerolls = rerolls
	_choice_count = n
	choice_root.visible = true
	_choosing = true
	var idx: int = await choice_made
	return idx


func _make_card(id: String, i: int, pos: Vector2, sz: Vector2) -> Button:
	var inf: Dictionary = Game.info(id)
	var col: Color = inf["color"]
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _style(col.darkened(0.15), Color(0.06, 0.09, 0.12), 3, 10))
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.2), Color(0.12, 0.17, 0.22), 6, 10))
	b.add_theme_stylebox_override("pressed", _style(col.lightened(0.4), Color(0.16, 0.22, 0.28), 6, 10))
	b.pressed.connect(_pick.bind(i))
	_mk(b, inf["cat_name"], Vector2(20, 16), Vector2(300, 22), 15, col)
	_mk(b, inf["name"], Vector2(20, 46), Vector2(300, 80), 28)
	if id == "repair":
		_mk(b, "Efeito imediato", Vector2(20, 140), Vector2(300, 24), 16, Color(0.7, 0.7, 0.75))
	else:
		_pips(b, Vector2(20, 138), inf["lvl"], inf["max"], col)
		_mk(b, "Nv %d  ->  %d" % [inf["lvl"], inf["lvl"] + 1], Vector2(20, 160), Vector2(300, 26), 18, col)
	var desc := _mk(b, "", Vector2(20, 206), Vector2(300, 140), 20, Color(0.85, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_OFF
	desc.text = _wrap(inf["desc"], 20, 290.0)
	_mk(b, "[ %d ]" % (i + 1), Vector2(20, 352), Vector2(300, 34), 26, col, HORIZONTAL_ALIGNMENT_CENTER)
	return b


## Quebra de linha na mão (medindo a fonte), pro texto nunca vazar da carta.
func _wrap(text: String, font_size: int, max_w: float) -> String:
	var font := ThemeDB.fallback_font
	var lines: Array = []
	var cur := ""
	for word in text.split(" "):
		var test: String = word if cur == "" else cur + " " + word
		if cur != "" and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w:
			lines.append(cur)
			cur = word
		else:
			cur = test
	lines.append(cur)
	return "\n".join(lines)


func _pips(parent: Node, pos: Vector2, cur: int, mx: int, col: Color) -> void:
	for i in mini(mx, 6):
		var r := ColorRect.new()
		r.size = Vector2(22, 10)
		r.position = pos + Vector2(i * 28.0, 0.0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < cur:
			r.color = col
		elif i == cur:
			r.color = Color(col.r, col.g, col.b, 0.45)   # mostra uma prévia do próximo nível
		else:
			r.color = Color(0.2, 0.22, 0.27)
		parent.add_child(r)


func _pick(i: int) -> void:
	if not _choosing:
		return
	_choosing = false
	choice_root.visible = false
	choice_made.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if _choosing and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and _rerolls > 0:
			_pick(-1)
			return
		var n: int = int(event.keycode) - int(KEY_1)
		if n >= 0 and n < _choice_count:
			_pick(n)
		return
	if _wait_key >= 0 and event is InputEventKey and event.pressed and not event.echo \
			and int(event.physical_keycode) == _wait_key:
		_wait_key = -1
		key_hit.emit()
		return
	if _awaiting_advance and _lock <= 0.0:
		var go: bool = event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		if go:
			advance.emit()


# =====================================================================
#  Pecinhas de HUD desenhadas por código
# =====================================================================

## Vinheta nas bordas da tela: pisca quando você toma dano e fica pulsando em vermelho com a vida baixa.
class Vignette extends Control:
	var flash := 0.0
	var flash_col := Color(1.0, 0.1, 0.1)
	var low := false
	var _t := 0.0

	func hit(col: Color, strength: float) -> void:
		flash_col = col
		flash = strength

	func _process(delta: float) -> void:
		_t += delta
		flash = maxf(0.0, flash - delta * 1.6)
		queue_redraw()

	func _draw() -> void:
		var a := flash * 0.55
		var col := flash_col
		if low and a < 0.2:
			a = 0.1 + 0.12 * (0.5 + 0.5 * sin(_t * 6.0))
			col = Color(1.0, 0.1, 0.1)
		if a <= 0.01:
			return
		var th := 7.0
		for i in 10:
			var k := 1.0 - float(i) / 10.0
			var c := Color(col.r, col.g, col.b, a * k * k)
			var o := float(i) * th
			draw_rect(Rect2(o, o, size.x - 2.0 * o, th), c)
			draw_rect(Rect2(o, size.y - o - th, size.x - 2.0 * o, th), c)
			draw_rect(Rect2(o, o + th, th, size.y - 2.0 * o - 2.0 * th), c)
			draw_rect(Rect2(size.x - o - th, o + th, th, size.y - 2.0 * o - 2.0 * th), c)


## Barra de vida em segmentos + escudo (losangos azuis) + número. Deixa um rastro branco quando você perde vida.
class HpBar extends Control:
	var hp := 5
	var max_hp := 5
	var shield := 0
	var lost_to := 5
	var trail := 0.0
	var heal_t := 0.0
	var _t := 0.0

	func set_values(h: int, m: int, s: int) -> void:
		if h < hp:
			lost_to = hp
			trail = 0.7
		elif h > hp:
			heal_t = 0.6
		hp = h
		max_hp = m
		shield = s

	func _process(delta: float) -> void:
		_t += delta
		trail = maxf(0.0, trail - delta)
		heal_t = maxf(0.0, heal_t - delta)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.05, 0.92))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.38, 0.18), false, 2.0)
		var pad := 4.0
		var n := maxi(max_hp, 1)
		var text_w := 50.0
		var shield_w := 22.0 * shield
		var cw := minf(40.0, (size.x - pad * 2.0 - shield_w - text_w) / n)
		var ch := size.y - pad * 2.0
		var low := hp <= 1 or float(hp) / float(n) <= 0.25
		for i in n:
			var r := Rect2(pad + i * cw, pad, cw - 3.0, ch)
			if i < hp:
				var base := Color(0.85, 0.15, 0.2)
				if low:
					base = base.lerp(Color(1.0, 0.55, 0.55), 0.5 + 0.5 * sin(_t * 8.0))
				if heal_t > 0.0:
					base = base.lerp(Color(0.5, 1.0, 0.55), heal_t / 0.6)
				draw_rect(r, base)
				draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), Color(1, 1, 1, 0.22))
			elif i < lost_to and trail > 0.0:
				draw_rect(r, Color(1, 1, 1, trail / 0.7))
			else:
				draw_rect(r, Color(0.16, 0.12, 0.14))
			draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)
		var sx := pad + n * cw + 4.0
		for j in shield:
			var c := Vector2(sx + j * 22.0 + 9.0, size.y * 0.5)
			var d := ch * 0.45
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), Color(0.45, 0.8, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(size.x - text_w + 6.0, size.y * 0.5 + 7.0), "%d/%d" % [maxi(hp, 0), max_hp],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


## Barra genérica (esquiva, tempo, boss): preenchimento, brilho, "rastro" opcional e marcadores de fase.
class Meter extends Control:
	var ratio := 1.0
	var fill := Color(0.9, 0.3, 0.3)
	var ghost_on := false
	var ticks: Array = []
	var text := ""
	var _ghost := 1.0

	func _process(delta: float) -> void:
		if _ghost > ratio:
			_ghost = maxf(ratio, _ghost - delta * 0.35)
		else:
			_ghost = ratio
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.04, 0.03, 0.05, 0.92))
		var inner := r.grow(-2.0)
		if ghost_on and _ghost > ratio:
			draw_rect(Rect2(inner.position, Vector2(inner.size.x * _ghost, inner.size.y)), Color(1, 1, 1, 0.55))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)), fill)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y * 0.4)), Color(1, 1, 1, 0.18))
		for t in ticks:
			var x: float = inner.position.x + inner.size.x * float(t)
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(1, 1, 1, 0.75), 2.0)
		draw_rect(r, Color(0.5, 0.38, 0.18), false, 2.0)
		if text != "":
			draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y * 0.5 + 5.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color.WHITE)


## "ONDA 2/4" + bolinhas (verde = já foi, dourada = a atual).
class WavePips extends Control:
	var cur := 0
	var total := 0

	func set_wave(c: int, t: int) -> void:
		cur = c
		total = t
		queue_redraw()

	func _draw() -> void:
		if total <= 0:
			return
		draw_string(ThemeDB.fallback_font, Vector2(0.0, 15.0), "ONDA %d/%d" % [cur, total], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.85, 0.9))
		for i in total:
			var c := Vector2(92.0 + i * 20.0, 10.0)
			if i < cur - 1:
				draw_circle(c, 6.0, Color(0.5, 1.0, 0.55))
			elif i == cur - 1:
				draw_circle(c, 6.0, Color(1.0, 0.85, 0.4))
				draw_arc(c, 9.0, 0.0, TAU, 16, Color.WHITE, 1.5)
			else:
				draw_arc(c, 6.0, 0.0, TAU, 16, Color(0.5, 0.5, 0.55), 2.0)
