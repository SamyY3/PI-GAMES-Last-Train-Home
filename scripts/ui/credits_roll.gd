extends Control
class_name CreditsRoll

# Créditos rolando sobre o trem noturno: fotos e clipes reais do jogo em molduras de latão,
# elenco com os personagens animados e a foto da família no fim, ao som de «A Caminho de Casa».
# Usado pelo menu (Credits.tscn) e pelo final do jogo (ending.gd), que espera `finished`.

signal finished

const DATA_PATH: String = "res://data/credits.json"
const MEDIA_DIR: String = "res://assets/sprites/credits/"
const SKY_TEX: Texture2D = preload("res://assets/sprites/menu/sky_night.png")
const MOON_TEX: Texture2D = preload("res://assets/sprites/ui/sky_moon.png")
const MOUNTAINS_TEX: Texture2D = preload("res://assets/sprites/menu/bg_mountains.png")
const CITY_BACK_TEX: Texture2D = preload("res://assets/sprites/menu/bg_city_back.png")
const LOCO_TEX: Texture2D = preload("res://assets/sprites/train/locomotive_anim.png")
const WAGON_TEX: Texture2D = preload("res://assets/sprites/train/wagon.png")
const BOGIE_TEX: Texture2D = preload("res://assets/sprites/train/wagon_bogie.png")
const RAIL_TEX: Texture2D = preload("res://assets/sprites/train/rail_tile.png")
const BALLAST_TEX: Texture2D = preload("res://assets/sprites/train/ballast_tile.png")
const PUFF_TEX: Texture2D = preload("res://assets/sprites/fx/steam_puff.png")
const BEAM_TEX: Texture2D = preload("res://assets/sprites/train/headlight_beam.png")
const NAMEPLATE_TEX: Texture2D = preload("res://assets/sprites/ui/kit/nameplate.png")
const FAMILY_PHOTO_TEX: Texture2D = preload("res://assets/sprites/credits/family_photo.png")

# sprites do elenco: textura, tamanho da célula, linha/quadros da animação exibida
const CAST_SPRITES: Dictionary = {
	"teo": ["res://assets/sprites/player/teo_sheet_8dir.png", 48, 9, 4],
	"lia": ["res://assets/sprites/family/lia.png", 48, 1, 6],
	"mae": ["res://assets/sprites/family/mae.png", 48, 1, 4],
	"pai": ["res://assets/sprites/family/pai.png", 48, 1, 4],
	"boss": ["res://assets/sprites/boss/maquinista_p1.png", 108, 0, 8],
	"npcs": ["res://assets/sprites/npcs/npc_nervous.png", 48, 0, 4],
}

const SCROLL_SPEED: float = 22.0
const FAST_MULT: float = 5.0
const VIDEO_FPS: float = 10.0
const COL_GOLD := Color("#f2c35b")
const COL_CREAM := Color("#fff1c9")
const COL_STEAM := Color("#8fb8c4")

var from_ending: bool = false

var _t: float = 0.0
var _content: Control
var _end_y: float = 0.0
var _done: bool = false
var _emitted: bool = false
var _scroll: float = 270.0
var _fast_toggle: bool = false
var _videos: Array[Dictionary] = []   # {atlas: AtlasTexture, cols: int}
var _cast: Array[Dictionary] = []     # {atlas: AtlasTexture, cell: int, row: int, frames: int}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(480.0, 270.0)
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	AudioManager.play_music("credits")
	AudioManager.set_train_ambience(true, 0.6)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.position = Vector2(0.0, 270.0)
	add_child(_content)
	_build_content()

	var hint := _label("", 10, COL_STEAM)
	if Settings.touch_mode:
		hint.text = "TOQUE: ACELERAR   ·   VOLTAR: PULAR"
	else:
		Settings.bind_prompt_text(hint, "SEGURE {shoot}: ACELERAR   ·   {confirm} PULAR")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = Vector2(172.0, 254.0)
	hint.size = Vector2(300.0, 14.0)
	add_child(hint)


# ------------------------------------------------------------------------------
# Montagem do conteúdo (coluna que sobe)
# ------------------------------------------------------------------------------
func _build_content() -> void:
	var data: Dictionary = {}
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			data = parsed
	var y: float = 0.0

	# Abertura: placa com o título
	var plate := TextureRect.new()
	plate.texture = NAMEPLATE_TEX
	plate.position = Vector2(240.0 - NAMEPLATE_TEX.get_width() * 0.5, y)
	_content.add_child(plate)
	var title := _label(String(data.get("title", "LAST TRAIN HOME")), 20, COL_GOLD, true)
	title.position = Vector2(0.0, y + NAMEPLATE_TEX.get_height() * 0.5 - 14.0)
	title.size = Vector2(480.0, 28.0)
	_content.add_child(title)
	y += NAMEPLATE_TEX.get_height() + 6.0
	var sub := _label(String(data.get("subtitle", "")), 10, COL_STEAM)
	sub.position = Vector2(0.0, y)
	sub.size = Vector2(480.0, 14.0)
	_content.add_child(sub)
	y += 60.0

	# Funções da equipe intercaladas com fotos/clipes, alternando os lados
	var sections: Array = data.get("sections", [])
	var media: Array = data.get("media", [])
	var n_blocks: int = maxi(media.size(), int(ceil(sections.size() / 2.0)))
	var sec_i: int = 0
	for b in range(n_blocks):
		var media_left: bool = b % 2 == 1
		var media_x: float = 12.0 if media_left else 228.0
		var text_x: float = 268.0 if media_left else 12.0
		var block_h: float = 0.0
		if b < media.size():
			block_h = _add_media(media[b], Vector2(media_x, y))
		# até duas funções por bloco, centralizadas verticalmente ao lado da mídia
		var lines: Array = []
		for _k in range(2):
			if sec_i < sections.size():
				lines.append(sections[sec_i])
				sec_i += 1
		var text_h: float = 0.0
		for sec in lines:
			text_h += 44.0 + float(String(sec.get("name", "")).count("\n")) * 13.0
		var ty: float = y + maxf(0.0, (block_h - text_h) * 0.5)
		for sec in lines:
			ty = _add_role(sec, Vector2(text_x, ty), 200.0)
		y += maxf(block_h, text_h) + 34.0

	# Elenco
	y += 10.0
	var cast_title := _label("ELENCO", 20, COL_GOLD, true)
	cast_title.position = Vector2(0.0, y)
	cast_title.size = Vector2(480.0, 28.0)
	_content.add_child(cast_title)
	y += 40.0
	var cast: Array = data.get("cast", [])
	for i in range(cast.size()):
		var c: Dictionary = cast[i]
		var col: int = i % 2
		var cx: float = 40.0 + float(col) * 220.0
		_add_cast(c, Vector2(cx, y))
		if col == 1 or i == cast.size() - 1:
			y += 86.0

	# Agradecimentos
	y += 20.0
	var thanks := _label(String(data.get("thanks", "")), 10, COL_CREAM)
	thanks.position = Vector2(20.0, y)
	thanks.size = Vector2(440.0, 40.0)
	_content.add_child(thanks)
	y += 90.0

	# Final: a foto da família e o obrigado (a rolagem para com eles centralizados)
	var photo_size: Vector2 = FAMILY_PHOTO_TEX.get_size()
	var frame_size: Vector2 = photo_size + Vector2(12.0, 12.0)
	var fp := Vector2(240.0 - frame_size.x * 0.5, y)
	_add_frame(fp, frame_size)
	var photo := TextureRect.new()
	photo.texture = FAMILY_PHOTO_TEX
	photo.position = fp + Vector2(6.0, 6.0)
	_content.add_child(photo)
	var footer := _label(String(data.get("footer", "Obrigado por jogar!")), 20, COL_GOLD, true)
	footer.position = Vector2(0.0, fp.y + frame_size.y + 8.0)
	footer.size = Vector2(480.0, 28.0)
	_content.add_child(footer)
	var block_bottom: float = fp.y + frame_size.y + 40.0
	# posição final do conteúdo: o bloco final fica no meio da tela
	_end_y = -(fp.y + (block_bottom - fp.y) * 0.5) + 135.0


func _add_role(sec: Dictionary, pos: Vector2, w: float) -> float:
	var role := _label(String(sec.get("role", "")).to_upper(), 10, COL_GOLD)
	role.position = pos
	role.size = Vector2(w, 14.0)
	_content.add_child(role)
	var name_lbl := _label(String(sec.get("name", "")), 10, COL_CREAM)
	name_lbl.position = pos + Vector2(0.0, 15.0)
	name_lbl.size = Vector2(w, 14.0)
	_content.add_child(name_lbl)
	var lines: int = String(sec.get("name", "")).count("\n") + 1
	return pos.y + 30.0 + float(lines - 1) * 13.0 + 14.0


func _add_media(m: Dictionary, pos: Vector2) -> float:
	var path: String = MEDIA_DIR + String(m.get("file", "")) + ".png"
	if not ResourceLoader.exists(path):
		return 0.0
	var tex: Texture2D = load(path)
	var view := Vector2(240.0, 135.0)
	var shown := Vector2(232.0, 130.0) # recorta 4px de cada lado: cabe na coluna com a moldura
	_add_frame(pos - Vector2(4.0, 4.0), shown + Vector2(8.0, 8.0))
	var rect := TextureRect.new()
	rect.position = pos
	rect.size = shown
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(Vector2((view.x - shown.x) * 0.5, (view.y - shown.y) * 0.5), shown)
	rect.texture = atlas
	_content.add_child(rect)
	if String(m.get("type", "")) == "video":
		_videos.append({"atlas": atlas, "cols": int(tex.get_width() / view.x), "count": int(tex.get_width() / view.x) * int(tex.get_height() / view.y), "pad": (view - shown) * 0.5})
		var badge := _label("▶ REPLAY", 10, Color("#ff6b3d"))
		badge.position = pos + Vector2(4.0, 2.0)
		badge.add_theme_color_override("font_outline_color", Color("#0d0b12"))
		badge.add_theme_constant_override("outline_size", 3)
		_content.add_child(badge)
	var cap := _label(String(m.get("caption", "")), 10, COL_STEAM)
	cap.position = pos + Vector2(0.0, shown.y + 6.0)
	cap.size = Vector2(shown.x, 14.0)
	_content.add_child(cap)
	return shown.y + 22.0


func _add_cast(c: Dictionary, pos: Vector2) -> void:
	var spec: Array = CAST_SPRITES.get(String(c.get("sprite", "")), [])
	if spec.size() == 4 and ResourceLoader.exists(String(spec[0])):
		var cell: int = int(spec[1])
		var atlas := AtlasTexture.new()
		atlas.atlas = load(String(spec[0]))
		atlas.region = Rect2(0.0, float(int(spec[2]) * cell), float(cell), float(cell))
		var spr := TextureRect.new()
		spr.texture = atlas
		spr.stretch_mode = TextureRect.STRETCH_KEEP
		# pés alinhados numa mesma linha de base, independentemente do tamanho da célula
		spr.position = pos + Vector2(32.0 - cell * 0.5, 70.0 - cell)
		_content.add_child(spr)
		_cast.append({"atlas": atlas, "cell": cell, "row": int(spec[2]), "frames": int(spec[3])})
	var name_lbl := _label(String(c.get("name", "")), 20, COL_CREAM, true)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_lbl.position = pos + Vector2(68.0, 22.0)
	name_lbl.size = Vector2(150.0, 24.0)
	_content.add_child(name_lbl)
	var role := _label(String(c.get("role", "")), 10, COL_STEAM)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	role.position = pos + Vector2(68.0, 46.0)
	role.size = Vector2(150.0, 14.0)
	_content.add_child(role)


func _add_frame(pos: Vector2, sz: Vector2) -> void:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Settings.make_ui_style("panel"))
	_content.add_child(p)


func _label(txt: String, font_size: int, col: Color, title: bool = false) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	if title and Settings.title_font != null:
		l.add_theme_font_override("font", Settings.title_font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ------------------------------------------------------------------------------
# Animação
# ------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	if TouchControls.consume_tap():
		if _done:
			_finish()
		else:
			_fast_toggle = not _fast_toggle
	var fast: bool = _fast_toggle or Input.is_action_pressed("shoot")
	if not _done:
		_scroll = maxf(_end_y, _scroll - SCROLL_SPEED * (FAST_MULT if fast else 1.0) * delta)
		if _scroll <= _end_y:
			_done = true
			_finish_after(5.0)
	# rolagem em pixels inteiros (sem borrar o pixel art)
	_content.position.y = round(_scroll)

	var vf: int = int(_t * VIDEO_FPS)
	for v in _videos:
		var i: int = vf % int(v["count"])
		var pad: Vector2 = v["pad"]
		var at: AtlasTexture = v["atlas"]
		at.region.position = Vector2(float(i % int(v["cols"])) * 240.0, float(floori(float(i) / float(v["cols"]))) * 135.0) + pad
	var cf: int = int(_t * 6.0)
	for c in _cast:
		var cat: AtlasTexture = c["atlas"]
		var cell: float = float(c["cell"])
		cat.region.position = Vector2(float(cf % int(c["frames"])) * cell, float(c["row"]) * cell)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_finish()


func _finish_after(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	_finish()


func _finish() -> void:
	if _emitted or not is_inside_tree():
		return
	_emitted = true
	finished.emit()
	if not from_ending:
		SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn")


# Fundo: céu noturno, montanhas, cidade lenta e o trem correndo nos trilhos
func _draw() -> void:
	draw_texture(SKY_TEX, Vector2.ZERO, Color(0.7, 0.7, 0.82))
	draw_texture(MOON_TEX, Vector2(412.0, 10.0), Color(1.0, 1.0, 1.0, 0.8))
	draw_texture(MOUNTAINS_TEX, Vector2(0.0, 132.0), Color(0.5, 0.52, 0.7))
	var bx: float = -round(fmod(_t * 6.0, 960.0))
	draw_texture(CITY_BACK_TEX, Vector2(bx, 112.0), Color(0.38, 0.38, 0.5))
	draw_texture(CITY_BACK_TEX, Vector2(bx + 960.0, 112.0), Color(0.38, 0.38, 0.5))
	# trem atravessando a tela devagar, em laço
	var tx: float = fmod(_t * 26.0, 900.0) - 420.0
	var base_y: float = 246.0
	var frame: int = int(_t * 10.0)
	var dim := Color(0.62, 0.62, 0.74)
	for w in range(3):
		var wx: float = round(tx + float(w) * 102.0)
		draw_texture(WAGON_TEX, Vector2(wx, base_y - 52.0), dim)
		for bogie_x in [wx + 18.0, wx + 76.0]:
			draw_texture_rect_region(BOGIE_TEX, Rect2(bogie_x - 13.0, base_y - 11.0, 26.0, 12.0), Rect2((frame % 4) * 26.0, 0.0, 26.0, 12.0), dim)
	var lx: float = round(tx + 306.0)
	draw_texture_rect_region(LOCO_TEX, Rect2(lx, base_y - 62.0, 112.0, 64.0), Rect2((frame % 9) * 112.0, 0.0, 112.0, 64.0), dim)
	draw_texture(BEAM_TEX, Vector2(lx + 92.0, base_y - 62.0 + 20.0 - 36.0), Color(1.0, 1.0, 1.0, 0.6))
	for k in range(5):
		var age: float = fmod(_t * 0.8 + float(k) / 5.0, 1.0)
		var st: int = mini(int(age * 8.0), 7)
		draw_texture_rect_region(PUFF_TEX, Rect2(round(lx + 78.0 - age * 80.0) - 16.0, round(base_y - 58.0 - age * 36.0) - 16.0, 32.0, 32.0), Rect2(st * 32.0, 0.0, 32.0, 32.0), Color(0.8, 0.8, 0.9, 0.7 - age * 0.6))
	draw_texture_rect(BALLAST_TEX, Rect2(-round(fmod(_t * 40.0, 32.0)), base_y + 12.0, 512.0, 40.0), true, dim)
	var rx: float = -round(fmod(_t * 40.0, 32.0))
	for i in range(17):
		draw_texture(RAIL_TEX, Vector2(rx + float(i) * 32.0, base_y - 1.0), dim)
	# véu escuro atrás da coluna de texto para leitura
	draw_texture(SKY_TEX, Vector2.ZERO, Color(0.0, 0.0, 0.0, 0.35))
