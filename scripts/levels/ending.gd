extends Control

# Cutscene final em pixel art:
# 0) contagem final na cabine  1) bomba desativada  2) o trem segue pela noite, a Estação Zero fica para trás
# 3) amanhecer: o trem chega à estação da colina, onde a família espera na plataforma
# 4) Teo desce do vagão e a Lia corre até ele  5) o reencontro (ilustração + diálogo com a família)
# 6) a família sobe o caminho até a casa  7) cartão-título com a citação  8) créditos  9) resultados da run

enum Stage { CABIN_COUNT, CABIN_SAFE, NIGHT, ARRIVAL, STEP_OFF, REUNION, HOME, TITLE, CREDITS, RESULTS }

const CABIN_TEX: Texture2D = preload("res://assets/sprites/backgrounds/wagon_5.png")
const BOMB_TEX: Texture2D = preload("res://assets/sprites/tiles/bomb_device.png")
const TEO_TEX: Texture2D = preload("res://assets/sprites/player/teo_sheet_8dir.png")
const MAE_TEX: Texture2D = preload("res://assets/sprites/family/mae.png")
const PAI_TEX: Texture2D = preload("res://assets/sprites/family/pai.png")
const LIA_TEX: Texture2D = preload("res://assets/sprites/family/lia.png")
const SKY_NIGHT_TEX: Texture2D = preload("res://assets/sprites/menu/sky_night.png")
const SKY_DAWN_TEX: Texture2D = preload("res://assets/sprites/menu/sky_sunset.png")
const SUN_TEX: Texture2D = preload("res://assets/sprites/ui/sky_sun_sunset.png")
const MOON_TEX: Texture2D = preload("res://assets/sprites/ui/sky_moon.png")
const MOUNTAINS_TEX: Texture2D = preload("res://assets/sprites/menu/bg_mountains.png")
const CITY_BACK_TEX: Texture2D = preload("res://assets/sprites/menu/bg_city_back.png")
const CITY_FRONT_TEX: Texture2D = preload("res://assets/sprites/menu/bg_city_front.png")
const STATION_TEX: Texture2D = preload("res://assets/sprites/tiles/station_zero.png")
const PLATFORM_TEX: Texture2D = preload("res://assets/sprites/menu/platform_tile.png")
const LAMP_TEX: Texture2D = preload("res://assets/sprites/menu/station_lamp.png")
const LOCO_TEX: Texture2D = preload("res://assets/sprites/train/locomotive_anim.png")
const WAGON_TEX: Texture2D = preload("res://assets/sprites/train/wagon.png")
const COUPLER_TEX: Texture2D = preload("res://assets/sprites/train/coupler.png")
const WAGON_DOOR_TEX: Texture2D = preload("res://assets/sprites/train/wagon_door_anim.png")
const BOGIE_TEX: Texture2D = preload("res://assets/sprites/train/wagon_bogie.png")
const RAIL_TEX: Texture2D = preload("res://assets/sprites/train/rail_tile.png")
const BALLAST_TEX: Texture2D = preload("res://assets/sprites/train/ballast_tile.png")
const PUFF_TEX: Texture2D = preload("res://assets/sprites/fx/steam_puff.png")
const BEAM_TEX: Texture2D = preload("res://assets/sprites/train/headlight_beam.png")
const DAWN_TEX: Texture2D = preload("res://assets/sprites/ending/dawn_home.png")
const REUNION_TEX: Texture2D = preload("res://assets/sprites/ending/reunion.png")
const NAMEPLATE_TEX: Texture2D = preload("res://assets/sprites/ui/kit/nameplate.png")

# Estação da colina: o trem para com a locomotiva à direita; a família espera na frente dela
const TRAIN_STOP_X: float = 300.0
const TRAIN_BASE_Y: float = 197.0
const PLATFORM_EDGE_ROW: float = 30.0
const PLATFORM_FEET_Y: float = 256.0 # no calçamento, bem abaixo da faixa dos trilhos
const TEO_DOOR_X: float = 110.0
const TEO_DOOR_FEET_Y: float = 204.0
const MEET_X: float = 292.0
# Caminho de terra da pintura dawn_home.png, da beira da tela até a porta da casa
const HOME_PATH: Array[Vector2] = [Vector2(150.0, 268.0), Vector2(232.0, 232.0), Vector2(330.0, 203.0), Vector2(350.0, 192.0)]

var _stage: int = Stage.CABIN_COUNT
var _anim_t: float = 0.0
var _stage_t: float = 0.0
var _fade: float = 0.0
var _bomb_visor_lbl: Label
var _caption: Label
var _title_lbl: Label
var _quote_lbl: Label
var _results_panel: Panel
var _fader: ColorRect
var _frame_style: StyleBox

# estado das cenas novas (animado por tweens)
var train_x: float = -160.0
var door_open: float = 0.0
var teo_x: float = TEO_DOOR_X
var teo_alpha: float = 0.0
var teo_y: float = PLATFORM_FEET_Y
var teo_door_t: float = 1.0
var lia_x: float = 340.0
var lia_running: bool = false
var reunion_alpha: float = 0.0
var home_walk: float = 0.0
var _wheel_dist: float = 0.0
var _last_train_x: float = -160.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(480.0, 270.0)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# a caixa de diálogo do reencontro pausa a árvore; a cena segue animando por baixo
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Visor da bomba (texto centrado no visor do sprite, que é desenhado a 2x em (176, 60))
	_bomb_visor_lbl = _make_label(Vector2(176.0 + 21.0 * 2.0, 60.0 + 16.0 * 2.0), Vector2(25.0 * 2.0, 13.0 * 2.0), 20, true)
	_bomb_visor_lbl.text = "00:03"

	# legenda no topo: embaixo ficam a plataforma e os personagens
	_caption = _make_label(Vector2(16.0, 6.0), Vector2(448.0, 26.0), 10, false)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_color_override("font_outline_color", Color("#0d0b12"))
	_caption.add_theme_constant_override("outline_size", 4)

	_title_lbl = _make_label(Vector2(144.0, 96.0), Vector2(192.0, 57.0), 20, true)
	_title_lbl.add_theme_color_override("font_color", Color("#f2c35b"))
	_title_lbl.text = "LAST TRAIN HOME"
	_title_lbl.visible = false

	_quote_lbl = _make_label(Vector2(40.0, 166.0), Vector2(400.0, 40.0), 10, false)
	_quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote_lbl.add_theme_color_override("font_color", Color("#dce9ee"))
	_quote_lbl.visible = false

	_results_panel = Panel.new()
	_results_panel.position = Vector2(60.0, 22.0)
	_results_panel.size = Vector2(360.0, 226.0)
	_results_panel.add_theme_stylebox_override("panel", Settings.make_ui_style("panel"))
	_results_panel.visible = false
	add_child(_results_panel)

	_frame_style = Settings.make_ui_style("panel")
	# véu de transição por cima de tudo (inclusive dos créditos, que entram como nó filho)
	_fader = ColorRect.new()
	_fader.color = Color(0.0, 0.0, 0.0, 0.0)
	_fader.size = size
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fader)

	_run_cinematic()


func _make_label(pos: Vector2, sz: Vector2, font_size: int, title: bool) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.size = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	if title and Settings.title_font != null:
		lbl.add_theme_font_override("font", Settings.title_font)
	lbl.add_theme_color_override("font_color", Color("#fff1c9"))
	add_child(lbl)
	return lbl


func _process(delta: float) -> void:
	_anim_t += delta
	_stage_t += delta
	_wheel_dist += absf(train_x - _last_train_x)
	_last_train_x = train_x
	_bomb_visor_lbl.visible = _stage <= Stage.CABIN_SAFE
	_fader.color.a = _fade
	queue_redraw()


func _draw() -> void:
	match _stage:
		Stage.CABIN_COUNT, Stage.CABIN_SAFE:
			_draw_cabin()
		Stage.NIGHT:
			_draw_night_ride()
		Stage.ARRIVAL, Stage.STEP_OFF:
			_draw_station()
		Stage.REUNION:
			_draw_station()
			_draw_reunion()
		Stage.HOME:
			_draw_dawn()
		Stage.CREDITS:
			pass
		_:
			draw_texture(SKY_NIGHT_TEX, Vector2.ZERO, Color(0.6, 0.6, 0.7))
			if _stage == Stage.TITLE:
				draw_texture(NAMEPLATE_TEX, Vector2(144.0, 96.0))


func _draw_cabin() -> void:
	var dim: Color = Color(0.85, 0.75, 0.75) if _stage == Stage.CABIN_COUNT else Color(0.6, 0.66, 0.72)
	draw_texture_rect_region(CABIN_TEX, Rect2(-8.0, -16.0, 496.0, 285.0), Rect2(8.0, 0.0, 496.0, 285.0), dim)
	var bomb_col: Color = Color.WHITE if _stage == Stage.CABIN_COUNT else Color(0.7, 0.85, 0.8)
	if _stage == Stage.CABIN_COUNT and int(_stage_t * 4.0) % 2 == 0:
		bomb_col = Color(1.0, 0.75, 0.75)
	draw_texture_rect(BOMB_TEX, Rect2(176.0, 60.0, 128.0, 80.0), false, bomb_col)
	# Teo de costas, olhando a bomba
	var f: int = int(_anim_t * 4.0) % 4
	draw_texture_rect_region(TEO_TEX, Rect2(216.0, 150.0, 48.0, 48.0), Rect2(f * 48.0, (9 + 4) * 48.0, 48.0, 48.0))
	if _stage == Stage.CABIN_SAFE:
		# Alívio: a caldeira solta o vapor acumulado
		for k in range(5):
			var age: float = fmod(_stage_t * 0.8 + float(k) * 0.2, 1.0)
			var st: int = mini(int(age * 8.0), 7)
			draw_texture_rect_region(PUFF_TEX, Rect2(round(150.0 + float(k) * 44.0), round(120.0 - age * 70.0), 32.0, 32.0), Rect2(st * 32.0, 0.0, 32.0, 32.0), Color(1.0, 1.0, 1.0, 0.8))


func _draw_night_ride() -> void:
	draw_texture(SKY_NIGHT_TEX, Vector2.ZERO)
	draw_texture(MOON_TEX, Vector2(404.0, 18.0))
	draw_texture(MOUNTAINS_TEX, Vector2(0.0, 112.0), Color(0.72, 0.74, 0.92))
	var back_x: float = -round(fmod(_stage_t * 10.0, 960.0))
	draw_texture(CITY_BACK_TEX, Vector2(back_x, 70.0), Color(0.6, 0.6, 0.72))
	draw_texture(CITY_BACK_TEX, Vector2(back_x + 960.0, 70.0), Color(0.6, 0.6, 0.72))
	var front_x: float = -round(fmod(_stage_t * 30.0, 960.0))
	draw_texture(CITY_FRONT_TEX, Vector2(front_x, 96.0), Color(0.6, 0.6, 0.72))
	draw_texture(CITY_FRONT_TEX, Vector2(front_x + 960.0, 96.0), Color(0.6, 0.6, 0.72))
	# A Estação Zero, em primeiro plano, passa e fica para trás
	draw_texture(STATION_TEX, Vector2(round(330.0 - _stage_t * 70.0), 112.0))
	_draw_train(250.0, 226.0, _stage_t * 15.0)
	draw_texture_rect(BALLAST_TEX, Rect2(-round(fmod(_stage_t * 200.0, 32.0)), 237.0, 512.0, 40.0), true)
	_draw_rails(225.0, _stage_t * 200.0)


# Estação da colina ao amanhecer: o mesmo tipo de plataforma do embarque, agora na luz da manhã
func _draw_station() -> void:
	var warm := Color(1.0, 0.86, 0.78)
	draw_texture(SKY_DAWN_TEX, Vector2.ZERO)
	draw_texture(SUN_TEX, Vector2(64.0, 58.0))
	draw_texture(MOUNTAINS_TEX, Vector2(0.0, 104.0), Color(0.92, 0.72, 0.74))
	for lx_lamp in [40.0, 214.0, 452.0]:
		draw_texture(LAMP_TEX, Vector2(lx_lamp - 7.0, 130.0), warm)

	# trem chegando (rodas giram conforme a distância percorrida)
	var frame: int = int(_wheel_dist / 6.0)
	var tx: float = round(train_x)
	for w in range(2):
		var wx: float = tx - 200.0 + float(w) * 102.0
		draw_texture(COUPLER_TEX, Vector2(wx + 94.0, TRAIN_BASE_Y - 18.0), warm)
		if w == 0:
			draw_texture_rect_region(WAGON_DOOR_TEX, Rect2(wx, TRAIN_BASE_Y - 52.0, 96.0, 48.0), Rect2(roundi(clampf(door_open, 0.0, 1.0) * 5.0) * 96.0, 0.0, 96.0, 48.0), warm)
		else:
			draw_texture(WAGON_TEX, Vector2(wx, TRAIN_BASE_Y - 52.0), warm)
		for bx in [wx + 18.0, wx + 76.0]:
			draw_texture_rect_region(BOGIE_TEX, Rect2(bx - 13.0, TRAIN_BASE_Y - 11.0, 26.0, 12.0), Rect2((frame % 4) * 26.0, 0.0, 26.0, 12.0), warm)
	draw_texture_rect_region(LOCO_TEX, Rect2(tx + 4.0, TRAIN_BASE_Y - 62.0, 112.0, 64.0), Rect2((frame % 9) * 112.0, 0.0, 112.0, 64.0), warm)
	# vapor: forte enquanto anda, um suspiro longo depois que para
	var moving: bool = absf(train_x - TRAIN_STOP_X) > 1.0
	for k in range(6):
		var age: float = fmod(_anim_t * (0.9 if moving else 0.35) + float(k) / 6.0, 1.0)
		var st: int = mini(int(age * 8.0), 7)
		draw_texture_rect_region(PUFF_TEX, Rect2(round(tx + 81.0 - age * (90.0 if moving else 30.0)) - 16.0, round(TRAIN_BASE_Y - 58.0 - age * 44.0) - 16.0, 32.0, 32.0), Rect2(st * 32.0, 0.0, 32.0, 32.0), Color(1.0, 0.95, 0.92, (0.85 if moving else 0.5) - age * 0.5))

	_draw_platform(198.0, Color(0.8, 0.68, 0.66))
	_draw_rails(196.0, 0.0)

	# Família na plataforma, virada para o trem (oeste): pai e mãe com o idle espelhado
	_draw_cell(PAI_TEX, 48, int(_anim_t * 5.0) % 4, 1, Vector2(404.0, PLATFORM_FEET_Y), 42.0, true)
	_draw_cell(MAE_TEX, 48, int(_anim_t * 5.0 + 2.0) % 4, 1, Vector2(372.0, PLATFORM_FEET_Y + 2.0), 42.0, true)
	if lia_running:
		_draw_cell(LIA_TEX, 48, int(_anim_t * 14.0) % 6, 2, Vector2(round(lia_x), PLATFORM_FEET_Y + 4.0), 40.0, false)
	else:
		_draw_cell(LIA_TEX, 48, int(_anim_t * 9.0) % 6, 1, Vector2(round(lia_x), PLATFORM_FEET_Y + 4.0), 40.0, false)

	# Teo desce do vagão e anda pela plataforma até a família
	if teo_alpha > 0.01:
		var stepping_down: bool = teo_y < PLATFORM_FEET_Y - 0.5
		var walking: bool = stepping_down or (teo_x < MEET_X - 1.0 and _stage == Stage.STEP_OFF)
		var row: int = 17 if stepping_down else (17 + 2 if walking else 9 + 2)
		var nf: int = 6 if walking else 4
		var fps: float = 10.0 if walking else 5.0
		var shade: float = lerpf(0.15, 1.0, teo_door_t)
		_draw_cell(TEO_TEX, 48, int(_anim_t * fps) % nf, row, Vector2(round(teo_x), round(teo_y) + 1.0), 42.0, false, Color(shade, 0.95 * shade, 0.9 * shade, teo_alpha))


# Reencontro: a ilustração do abraço em 2x numa moldura, acima da caixa de diálogo
func _draw_reunion() -> void:
	if reunion_alpha <= 0.01:
		return
	draw_texture(SKY_NIGHT_TEX, Vector2.ZERO, Color(0.0, 0.0, 0.0, 0.6 * reunion_alpha))
	var src := Rect2(0.0, 6.0, 168.0, 88.0)
	var dst := Rect2(72.0, 6.0, src.size.x * 2.0, src.size.y * 2.0)
	if reunion_alpha > 0.99:
		draw_style_box(_frame_style, dst.grow(5.0))
	draw_texture_rect_region(REUNION_TEX, dst, src, Color(1.0, 1.0, 1.0, reunion_alpha))


func _draw_dawn() -> void:
	draw_texture(DAWN_TEX, Vector2.ZERO)
	# Fumaça da chaminé da casa (sprite de vapor), subindo devagar
	for k in range(4):
		var age: float = fmod(_stage_t * 0.35 + float(k) * 0.25, 1.0)
		var st: int = mini(int(age * 8.0), 7)
		# topo da chaminé na pintura dawn_home.png ≈ (399, 82); a fumaça sobe e deriva para a direita
		var p := Vector2(399.0 + age * 22.0, 78.0 - age * 48.0).round()
		draw_texture_rect_region(PUFF_TEX, Rect2(p - Vector2(16.0, 16.0), Vector2(32.0, 32.0)), Rect2(st * 32.0, 0.0, 32.0, 32.0), Color(1.0, 0.95, 0.9, 0.6 * (1.0 - age)))
	# a família sobe o caminho até a porta, em escala 1:1 (a porta da pintura tem ~40px: o Teo cabe nela)
	var members: Array = [
		[LIA_TEX, 48, 3, 40.0, 0.10],
		[TEO_TEX, 48, 17 + 2, 42.0, 0.0],
		[MAE_TEX, 48, 2, 42.0, -0.07],
		[PAI_TEX, 48, 2, 42.0, -0.13],
	]
	for m in members:
		var p: float = clampf(home_walk + float(m[4]), 0.0, 1.0)
		if home_walk + float(m[4]) <= 0.0:
			continue
		var a: float = 1.0 - smoothstep(0.9, 1.0, p)
		var pos: Vector2 = _path_point(p)
		var cell: int = int(m[1])
		var frame: int = int(_anim_t * 9.0) % 6
		draw_texture_rect_region(m[0], Rect2(pos.round() - Vector2(cell * 0.5, float(m[3])), Vector2(cell, cell)), Rect2(frame * cell, int(m[2]) * cell, cell, cell), Color(1.0, 0.92, 0.85, a))


func _path_point(p: float) -> Vector2:
	var seg: float = p * float(HOME_PATH.size() - 1)
	var i: int = mini(int(seg), HOME_PATH.size() - 2)
	return HOME_PATH[i].lerp(HOME_PATH[i + 1], seg - float(i))


# Desenha um quadro de uma folha de sprites com os pés em `feet` (espelhado se `flip`)
func _draw_cell(tex: Texture2D, cell: int, col: int, row: int, feet: Vector2, feet_y_in_cell: float, flip: bool, tint: Color = Color(1.0, 0.95, 0.9)) -> void:
	var src := Rect2(col * cell, row * cell, cell, cell)
	if flip:
		draw_set_transform(feet, 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(tex, Rect2(-cell * 0.5, -feet_y_in_cell, cell, cell), src, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(tex, Rect2(feet.x - cell * 0.5, feet.y - feet_y_in_cell, cell, cell), src, tint)


func _draw_train(x: float, base_y: float, wheel_t: float) -> void:
	var frame: int = int(wheel_t / 1.5)
	for w in range(2):
		var wx: float = x - 200.0 + float(w) * 102.0
		draw_texture(COUPLER_TEX, Vector2(wx + 94.0, base_y - 18.0))
		draw_texture(WAGON_TEX, Vector2(wx, base_y - 52.0))
		for bx in [wx + 18.0, wx + 76.0]:
			draw_texture_rect_region(BOGIE_TEX, Rect2(bx - 13.0, base_y - 11.0, 26.0, 12.0), Rect2((frame % 4) * 26.0, 0.0, 26.0, 12.0))
	draw_texture_rect_region(LOCO_TEX, Rect2(x + 4.0, base_y - 62.0, 112.0, 64.0), Rect2((frame % 9) * 112.0, 0.0, 112.0, 64.0))
	# Facho do farol (sprite separado; a lanterna fica em (92, 20) do quadro da locomotiva)
	draw_texture(BEAM_TEX, Vector2(x + 4.0 + 92.0, base_y - 62.0 + 20.0 - 36.0))
	# Vapor da chaminé
	for k in range(6):
		var age: float = fmod(_anim_t * 0.9 + float(k) / 6.0, 1.0)
		var st: int = mini(int(age * 8.0), 7)
		draw_texture_rect_region(PUFF_TEX, Rect2(round(x + 81.0 - age * 90.0) - 16.0, round(base_y - 58.0 - age * 40.0) - 16.0, 32.0, 32.0), Rect2(st * 32.0, 0.0, 32.0, 32.0), Color(1.0, 1.0, 1.0, 0.85 - age * 0.6))


func _draw_platform(y: float, tint: Color) -> void:
	draw_texture_rect(BALLAST_TEX, Rect2(0.0, y, 480.0, PLATFORM_EDGE_ROW), true, tint)
	var src := Rect2(0.0, PLATFORM_EDGE_ROW, 128.0, 72.0 - PLATFORM_EDGE_ROW)
	var x: float = 0.0
	while x < 480.0:
		draw_texture_rect_region(PLATFORM_TEX, Rect2(Vector2(x, y + PLATFORM_EDGE_ROW), src.size), src, tint)
		x += src.size.x


func _draw_rails(y: float, scroll: float) -> void:
	var x0: float = -round(fmod(scroll, 32.0))
	for i in range(17):
		draw_texture(RAIL_TEX, Vector2(x0 + float(i) * 32.0, y))


func _fade_to(target: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_fade", target, dur)
	await tw.finished


func _tween_prop(prop: String, target: Variant, dur: float, trans: Tween.TransitionType = Tween.TRANS_SINE, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, prop, target, dur).set_trans(trans).set_ease(ease_type)
	return tw


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _set_stage(st: int, caption: String) -> void:
	_stage = st
	_stage_t = 0.0
	_caption.text = caption


func _run_cinematic() -> void:
	var remaining_bomb_time: float = TrainClock.time_left
	TrainClock.set_disarmed_countdown()
	AudioManager.set_train_ambience(true, 0.85)

	_set_stage(Stage.CABIN_COUNT, "")
	for sec in [3, 2, 1, 0]:
		_bomb_visor_lbl.text = "00:0%d" % sec
		_caption.text = "CONTAGEM FINAL: 00:0%d" % sec
		AudioManager.play_sfx("tick", 0.0)
		await _wait(1.0)

	_set_stage(Stage.CABIN_SAFE, "[ 00:00 — BOMBA DESATIVADA ]")
	_bomb_visor_lbl.add_theme_color_override("font_color", Color("#8fb8c4"))
	AudioManager.stop_music()
	AudioManager.play_sfx("steam_pulse")
	await _wait(1.8)

	await _fade_to(1.0, 0.5)
	_set_stage(Stage.NIGHT, "O último trem segue pela noite. A Estação Zero fica para trás, e a cidade está a salvo.")
	AudioManager.play_sfx("whistle")
	AudioManager.play_music("ending")
	await _fade_to(0.0, 0.5)
	await _wait(4.5)

	# --- Amanhecer: o trem chega à estação da colina e a família espera na plataforma
	await _fade_to(1.0, 0.8)
	_set_stage(Stage.ARRIVAL, "Ao amanhecer, o último trem chega à pequena estação da colina.")
	AudioManager.play_music("credits")
	train_x = -160.0
	_last_train_x = train_x
	await _fade_to(0.0, 0.8)
	AudioManager.play_sfx("whistle")
	await _tween_prop("train_x", TRAIN_STOP_X, 5.0, Tween.TRANS_QUART, Tween.EASE_OUT).finished
	AudioManager.play_sfx("steam_pulse")
	AudioManager.set_train_ambience(true, 0.35)
	_caption.text = "Na plataforma, alguém passou a noite inteira esperando."
	await _wait(2.4)

	# --- Teo desce e a Lia corre até ele
	_set_stage(Stage.STEP_OFF, "")
	_tween_prop("door_open", 1.0, 0.4)
	AudioManager.play_sfx("clang")
	await _wait(0.4)
	teo_x = TEO_DOOR_X
	teo_y = TEO_DOOR_FEET_Y
	teo_door_t = 0.0
	await _tween_prop("teo_alpha", 1.0, 0.3).finished
	_tween_prop("teo_door_t", 1.0, 0.6)
	await _tween_prop("teo_y", PLATFORM_FEET_Y, 0.8).finished
	_caption.text = "— TEO!"
	lia_running = true
	_tween_prop("lia_x", MEET_X + 10.0, 2.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	await _tween_prop("teo_x", MEET_X - 10.0, 2.2, Tween.TRANS_SINE, Tween.EASE_IN_OUT).finished
	lia_running = false

	# --- Reencontro: ilustração do abraço e a conversa com a família
	_set_stage(Stage.REUNION, "")
	await _tween_prop("reunion_alpha", 1.0, 0.8).finished
	await _wait(1.2)
	var dlg: CanvasLayer = preload("res://scenes/ui/DialogueBox.tscn").instantiate()
	add_child(dlg)
	dlg.start_dialogue("ending_reunion")
	await dlg.dialogue_finished
	await _wait(0.6)

	# --- Para casa: a família sobe o caminho da colina
	await _fade_to(1.0, 0.8)
	reunion_alpha = 0.0
	_set_stage(Stage.HOME, "E, pela primeira vez em muito tempo, Teo chega em casa.")
	AudioManager.set_train_ambience(false)
	home_walk = 0.0
	await _fade_to(0.0, 0.8)
	await _tween_prop("home_walk", 1.15, 7.0, Tween.TRANS_LINEAR).finished
	await _wait(0.8)

	await _fade_to(1.0, 0.6)
	_set_stage(Stage.TITLE, "")
	_title_lbl.visible = true
	_quote_lbl.visible = true
	_quote_lbl.text = "«%s»" % String(GameState.dialogue_db.get("ending_quote", ""))
	await _fade_to(0.0, 0.6)
	await _wait(3.5)

	# --- Créditos
	await _fade_to(1.0, 0.6)
	_title_lbl.visible = false
	_quote_lbl.visible = false
	_set_stage(Stage.CREDITS, "")
	var roll := CreditsRoll.new()
	roll.from_ending = true
	add_child(roll)
	move_child(roll, 0)
	await _fade_to(0.0, 0.6)
	await roll.finished
	await _fade_to(1.0, 0.6)
	roll.queue_free()

	_set_stage(Stage.RESULTS, "")
	await _fade_to(0.0, 0.4)
	_show_results_screen(remaining_bomb_time)


func _show_results_screen(remaining_bomb: float) -> void:
	_results_panel.visible = true
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(14.0, 12.0)
	vbox.size = Vector2(332.0, 202.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	_results_panel.add_child(vbox)

	var run_t: float = GameState.active_run_time
	var dmg: int = GameState.damage_taken_in_run
	var grade: String = "C"
	if run_t <= 315.0 and dmg <= 3:
		grade = "S"
	elif run_t <= 360.0 and dmg <= 6:
		grade = "A"
	elif run_t <= 420.0:
		grade = "B"

	var win: Dictionary = Progress.register_win(GameState.difficulty, run_t, grade, GameState.is_daily)
	var rec_str: String = "[NOVO RECORDE!]" if bool(win.get("new_record", false)) else ""
	if GameState.is_daily:
		rec_str = ("VIAGEM DO DIA %s  " % Progress.daily_label()) + rec_str
	var unlocked: Array = win.get("unlocked", [])
	if not unlocked.is_empty():
		rec_str += "
HABILIDADE LIBERADA: %s" % ", ".join(PackedStringArray(unlocked)).to_upper()

	var grade_lbl := Label.new()
	grade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_lbl.add_theme_font_size_override("font_size", 20)
	if Settings.title_font != null:
		grade_lbl.add_theme_font_override("font", Settings.title_font)
	grade_lbl.add_theme_color_override("font_color", Color("#f2c35b"))
	grade_lbl.text = "VITÓRIA — NOTA %s" % grade
	vbox.add_child(grade_lbl)

	var m: int = int(floor(run_t / 60.0))
	var s: int = int(run_t) % 60
	var info := Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.text = "%s\nTempo da Run: %02d:%02d\nTempo Restante no Desarme: %02.1fs\nInimigos Derrotados: %d  |  Raspões: %d\nDano Sofrido: %d  |  Mortes: %d  |  Compras do Fiscal: %d" % [
		rec_str, m, s, remaining_bomb, GameState.kills, GameState.grazes, dmg, GameState.deaths_in_run, GameState.fiscal_purchases
	]
	vbox.add_child(info)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	var btn_retry := Button.new()
	btn_retry.text = "Jogar de novo"
	btn_retry.pressed.connect(func() -> void:
		GameState.start_new_run(GameState.difficulty, GameState.is_daily)
		SceneRouter.goto_scene("res://scenes/levels/Level_Wagon1.tscn")
	)
	hbox.add_child(btn_retry)

	var btn_credits := Button.new()
	btn_credits.text = "Créditos"
	btn_credits.pressed.connect(func() -> void:
		SceneRouter.goto_scene("res://scenes/menus/Credits.tscn")
	)
	hbox.add_child(btn_credits)

	var btn_menu := Button.new()
	btn_menu.text = "Menu Principal"
	btn_menu.pressed.connect(func() -> void:
		SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn")
	)
	hbox.add_child(btn_menu)
	btn_retry.grab_focus()
