extends CanvasLayer

@export var overlay_mode: String = "pause"

var _root: Control
var _title_lbl: Label
var _tab_pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _current_tab: int = 0
var _retry_btn: Button
var _upgrades_grid: VBoxContainer
var _stats_label: Label
var _invincible_btn: Button
var _freeze_btn: Button
var _speed_btn: Button
var _debug_list: VBoxContainer

var _exploding_anim: bool = false
var _explosion_t: float = 0.0
var _explosion_drawer: Control
var _game_over_card: Panel


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	_root.visible = false
	if overlay_mode == "game_over":
		Events.player_died.connect(_on_player_died)
	elif overlay_mode == "pause":
		add_to_group("pause_overlay")


func is_open() -> bool:
	return _root.visible


func _process(delta: float) -> void:
	if _exploding_anim and _explosion_drawer != null:
		_explosion_t += delta
		_explosion_drawer.queue_redraw()


func _build_overlay() -> void:
	_root = Control.new()
	_root.position = Vector2.ZERO
	_root.size = Vector2(480.0, 270.0)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.88)
	bg.position = Vector2.ZERO
	bg.size = Vector2(480.0, 270.0)
	_root.add_child(bg)

	if overlay_mode == "game_over":
		_build_game_over_ui()
	else:
		_build_fixed_pause_ui()


func _build_game_over_ui() -> void:
	_explosion_drawer = Control.new()
	_explosion_drawer.position = Vector2.ZERO
	_explosion_drawer.size = Vector2(480.0, 270.0)
	_explosion_drawer.draw.connect(_draw_bomb_explosion)
	_root.add_child(_explosion_drawer)

	_game_over_card = _make_fixed_panel(Vector2(100.0, 56.0), Vector2(280.0, 158.0))
	_root.add_child(_game_over_card)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.position = Vector2(10.0, 14.0)
	_title_lbl.size = Vector2(260.0, 22.0)
	_title_lbl.text = "GAME OVER"
	_title_lbl.add_theme_font_size_override("font_size", 20)
	if Settings.title_font != null:
		_title_lbl.add_theme_font_override("font", Settings.title_font)
	_title_lbl.add_theme_color_override("font_color", Color("#ff3d6e"))
	_game_over_card.add_child(_title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.position = Vector2(10.0, 40.0)
	sub_lbl.size = Vector2(260.0, 18.0)
	sub_lbl.text = "Checkpoint da seção pronto."
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color("#8fb8c4"))
	_game_over_card.add_child(sub_lbl)

	var b_retry := Button.new()
	Settings.bind_prompt_text(b_retry, "TENTAR DE NOVO {menu_alt}")
	_retry_btn = b_retry
	b_retry.position = Vector2(40.0, 72.0)
	b_retry.size = Vector2(200.0, 28.0)
	b_retry.pressed.connect(_retry_current_wagon)
	_game_over_card.add_child(b_retry)

	var b_menu := Button.new()
	b_menu.text = "MENU PRINCIPAL"
	b_menu.position = Vector2(40.0, 110.0)
	b_menu.size = Vector2(200.0, 28.0)
	b_menu.pressed.connect(func() -> void: SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn"))
	_game_over_card.add_child(b_menu)


const EXPLOSION_TIME: float = 3.2
const EXPLOSION_TEX: Texture2D = preload("res://assets/sprites/fx/bomb_explosion.png") # 8 quadros 64x64
const STEAM_PUFF_TEX: Texture2D = preload("res://assets/sprites/fx/steam_puff.png") # 8 estágios 32x32
const SKY_NIGHT_TEX: Texture2D = preload("res://assets/sprites/menu/sky_night.png")
const SKY_DAY_TEX: Texture2D = preload("res://assets/sprites/menu/sky_day.png")
const BALLAST_TEX: Texture2D = preload("res://assets/sprites/train/ballast_tile.png")
const RAIL_TILE_TEX: Texture2D = preload("res://assets/sprites/train/rail_tile.png")
const LOCO_TEX: Texture2D = preload("res://assets/sprites/train/locomotive.png")
const WAGON_TEX: Texture2D = preload("res://assets/sprites/train/wagon.png")
const COUPLER_TEX: Texture2D = preload("res://assets/sprites/train/coupler.png")


# Cutscene em pixel art: trem à noite -> alarme -> explosão (sprite 3x) -> fumaça sobre os destroços
func _draw_bomb_explosion() -> void:
	if not _exploding_anim:
		return
	var d: Control = _explosion_drawer
	var t: float = _explosion_t
	var blast_t: float = t - 0.7
	d.draw_texture(SKY_NIGHT_TEX, Vector2.ZERO)

	# Trem parado nos trilhos (escurece/avermelha conforme a explosão consome)
	var burn: float = clampf(blast_t / 1.0, 0.0, 1.0)
	var train_col: Color = Color.WHITE.lerp(Color(0.35, 0.12, 0.12), burn)
	if t < 0.7 and int(t * 8.0) % 2 == 0:
		train_col = Color(1.0, 0.55, 0.55)
	for w in range(3):
		d.draw_texture(COUPLER_TEX, Vector2(123.0 + float(w) * 100.0, 192.0), train_col)
		d.draw_texture(WAGON_TEX, Vector2(30.0 + float(w) * 100.0, 158.0), train_col)
	d.draw_texture(LOCO_TEX, Vector2(330.0, 144.0), train_col)
	for i in range(16):
		d.draw_texture(RAIL_TILE_TEX, Vector2(float(i) * 32.0, 206.0))
	d.draw_texture_rect(BALLAST_TEX, Rect2(0.0, 218.0, 480.0, 52.0), true)

	# Clarão branco no instante da detonação
	if blast_t >= 0.0 and blast_t < 0.25:
		d.draw_texture(SKY_DAY_TEX, Vector2.ZERO, Color(3.0, 2.8, 2.5, 1.0 - blast_t / 0.25))

	# Explosão: 8 quadros a 3x (escala inteira, pixels nítidos)
	if blast_t >= 0.0 and blast_t < 1.6:
		var frame: int = mini(int(blast_t / 0.2), 7)
		for e in [[Vector2(200.0, 150.0), 0.0], [Vector2(330.0, 160.0), 0.25], [Vector2(90.0, 165.0), 0.4]]:
			var ef: int = frame - int(float(e[1]) / 0.2)
			if ef < 0 or ef > 7:
				continue
			var c: Vector2 = e[0]
			d.draw_texture_rect_region(EXPLOSION_TEX, Rect2(c.x - 96.0, c.y - 96.0, 192.0, 192.0), Rect2(ef * 64.0, 0.0, 64.0, 64.0))

	# Fumaça escura subindo dos destroços
	if blast_t > 0.6:
		for k in range(7):
			var age: float = fmod(blast_t - 0.6 + float(k) * 0.23, 1.6)
			var stage: int = mini(int(age / 1.6 * 8.0), 7)
			var sp := Vector2(round(70.0 + float(k) * 52.0 + sin(float(k) * 2.1) * 10.0), round(170.0 - age * 55.0))
			d.draw_texture_rect_region(STEAM_PUFF_TEX, Rect2(sp.x - 32.0, sp.y - 32.0, 64.0, 64.0), Rect2(stage * 32.0, 0.0, 32.0, 32.0), Color(0.3, 0.27, 0.32, 0.9))


func _build_fixed_pause_ui() -> void:
	var modal := _make_fixed_panel(Vector2(60.0, 23.0), Vector2(360.0, 224.0))
	_root.add_child(modal)

	var header_bg := NinePatchRect.new()
	header_bg.texture = load("res://assets/sprites/ui/kit/panel_focus.png")
	header_bg.patch_margin_left = 6
	header_bg.patch_margin_right = 6
	header_bg.patch_margin_top = 6
	header_bg.patch_margin_bottom = 6
	header_bg.position = Vector2(0.0, 0.0)
	header_bg.size = Vector2(360.0, 30.0)
	modal.add_child(header_bg)

	var header_lbl := Label.new()
	header_lbl.text = "PAUSA — TERMINAL DA LOCOMOTIVA"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_lbl.position = Vector2(0.0, 2.0)
	header_lbl.size = Vector2(360.0, 26.0)
	header_lbl.add_theme_font_size_override("font_size", 10)
	header_lbl.add_theme_color_override("font_color", Color("#f2c35b"))
	modal.add_child(header_lbl)

	var tab_titles: Array[String] = ["JOGO", "MELHORIAS"]
	if DebugCommands.enabled():
		tab_titles.append("DEBUG")
	for i in range(tab_titles.size()):
		var tb := Button.new()
		tb.text = tab_titles[i]
		tb.position = Vector2(18.0 + float(i) * 110.0, 36.0)
		tb.size = Vector2(104.0, 24.0)
		var idx: int = i
		tb.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_hover")
			_switch_pause_tab(idx)
		)
		modal.add_child(tb)
		_tab_buttons.append(tb)

	var page_game := Control.new()
	page_game.position = Vector2(14.0, 68.0)
	page_game.size = Vector2(332.0, 148.0)
	modal.add_child(page_game)
	_tab_pages.append(page_game)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.position = Vector2(0.0, 2.0)
	_stats_label.size = Vector2(332.0, 18.0)
	_stats_label.add_theme_font_size_override("font_size", 10)
	_stats_label.add_theme_color_override("font_color", Color("#8fb8c4"))
	page_game.add_child(_stats_label)

	var b_cont := Button.new()
	Settings.bind_prompt_text(b_cont, "CONTINUAR VIAGEM {pause}")
	b_cont.position = Vector2(46.0, 24.0)
	b_cont.size = Vector2(240.0, 26.0)
	b_cont.pressed.connect(_toggle_pause)
	page_game.add_child(b_cont)

	var b_retry := Button.new()
	b_retry.text = "REINICIAR SEÇÃO ATUAL"
	b_retry.position = Vector2(46.0, 56.0)
	b_retry.size = Vector2(240.0, 26.0)
	b_retry.pressed.connect(_retry_current_wagon)
	page_game.add_child(b_retry)

	var b_menu := Button.new()
	b_menu.text = "MENU PRINCIPAL"
	b_menu.position = Vector2(46.0, 88.0)
	b_menu.size = Vector2(240.0, 26.0)
	b_menu.pressed.connect(func() -> void: SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn"))
	page_game.add_child(b_menu)

	var ctrl_hint := Label.new()
	ctrl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl_hint.position = Vector2(0.0, 124.0)
	ctrl_hint.size = Vector2(332.0, 20.0)
	Settings.bind_prompt_text(ctrl_hint, "{move} Mover · {shoot} Atirar · {dash} Dash · {ability} Pulso · {interact} Ação",
		"{move} Mover · {aim} Mirar · {shoot} Tiro · {dash} Dash · {ability} Pulso")
	ctrl_hint.add_theme_font_size_override("font_size", 10)
	ctrl_hint.add_theme_color_override("font_color", Color("#dce9ee"))
	page_game.add_child(ctrl_hint)

	var page_upg := Control.new()
	page_upg.position = Vector2(14.0, 68.0)
	page_upg.size = Vector2(332.0, 148.0)
	page_upg.visible = false
	modal.add_child(page_upg)
	_tab_pages.append(page_upg)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0.0, 0.0)
	scroll.size = Vector2(332.0, 144.0)
	page_upg.add_child(scroll)

	_upgrades_grid = VBoxContainer.new()
	_upgrades_grid.custom_minimum_size = Vector2(316.0, 0.0)
	_upgrades_grid.add_theme_constant_override("separation", 6)
	scroll.add_child(_upgrades_grid)

	if DebugCommands.enabled():
		_build_debug_page(modal)


func _build_debug_page(modal: Control) -> void:
	var page_dbg := Control.new()
	page_dbg.position = Vector2(14.0, 68.0)
	page_dbg.size = Vector2(332.0, 148.0)
	page_dbg.visible = false
	modal.add_child(page_dbg)
	_tab_pages.append(page_dbg)

	var scroll := ScrollContainer.new()
	scroll.size = page_dbg.size
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_dbg.add_child(scroll)
	_debug_list = VBoxContainer.new()
	_debug_list.custom_minimum_size = Vector2(320.0, 0.0)
	_debug_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_debug_list)


func _rebuild_debug_list() -> void:
	if _debug_list == null:
		return
	for child in _debug_list.get_children():
		_debug_list.remove_child(child)
		child.queue_free()
	var list: VBoxContainer = _debug_list
	var tree: SceneTree = get_tree()
	var grid: GridContainer = _debug_section(list, "GERAL")
	_invincible_btn = _make_debug_btn(grid, "", func() -> void: DebugCommands.toggle_invincible())
	_freeze_btn = _make_debug_btn(grid, "", func() -> void: DebugCommands.toggle_clock_freeze())
	_speed_btn = _make_debug_btn(grid, "", func() -> void: DebugCommands.cycle_speed())
	_make_debug_btn(grid, "[F4] Matar inimigos", func() -> void: DebugCommands.kill_enemies(tree))
	_make_debug_btn(grid, "Curar + 30s no relógio", func() -> void: DebugCommands.heal_and_time())
	_make_debug_btn(grid, "+60s na reserva", func() -> void: DebugCommands.add_reserve())

	grid = _debug_section(list, "MELHORIAS")
	_make_debug_btn(grid, "[F6] +1 melhoria", func() -> void: DebugCommands.random_upgrade())
	_make_debug_btn(grid, "[F7] Escolher carta", func() -> void: DebugCommands.open_card_choice(tree), true)
	_make_debug_btn(grid, "Todas no máximo", func() -> void: DebugCommands.max_upgrades())

	if GameState.is_malha():
		_build_malha_debug(list, tree)

	grid = _debug_section(list, "IR PARA")
	_make_debug_btn(grid, "[F2] Concluir parada" if GameState.is_malha() else "[F2] Próxima seção", func() -> void: DebugCommands.next_section(tree), true)
	if not GameState.is_malha():
		for id in DebugCommands.SECTIONS:
			var sec: String = id
			_make_debug_btn(grid, String(DebugCommands.SECTION_NAMES[sec]), func() -> void: DebugCommands.goto_section(sec), true)

	if DebugCommands.has_boss(tree):
		grid = _debug_section(list, "CHEFE")
		_make_debug_btn(grid, "Ir para a fase 2", func() -> void: DebugCommands.boss_phase(tree, 2), true)
		_make_debug_btn(grid, "[F5] Ir para a fase 3", func() -> void: DebugCommands.boss_phase(tree, 3), true)

	if DebugCommands.current_section(tree) in ["wagon_2", "wagon_3", "wagon_4"]:
		grid = _debug_section(list, "MODIFICADOR (REINICIA O VAGÃO)")
		for m in ["", "tunnel", "curve", "passenger"]:
			var mod: String = m
			_make_debug_btn(grid, String(DebugCommands.MODIFIER_NAMES[mod]), func() -> void: DebugCommands.set_modifier(tree, mod), true)

	var dbg_note := Label.new()
	dbg_note.custom_minimum_size = Vector2(320.0, 0.0)
	dbg_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dbg_note.text = "Atalhos: F1 info · F2 próxima seção · F3 invencível · F4 matar · F5 fase do chefe · F6 melhoria · F7 carta · F8 relógio · F9 velocidade"
	dbg_note.add_theme_font_size_override("font_size", 10)
	dbg_note.add_theme_color_override("font_color", Color("#8fb8c4"))
	list.add_child(dbg_note)
	_refresh_debug_buttons()


func _build_malha_debug(list: VBoxContainer, tree: SceneTree) -> void:
	var grid: GridContainer = _debug_section(list, "MALHA")
	_make_debug_btn(grid, "+100 fichas", func() -> void: DebugCommands.malha_add_fichas(100))
	_make_debug_btn(grid, "Subir nível do Teo", func() -> void: DebugCommands.malha_level_up(), true)
	_make_debug_btn(grid, "Habilidade pronta", func() -> void: DebugCommands.malha_skill_ready())
	_make_debug_btn(grid, "Cartas de habilidade máx.", func() -> void: DebugCommands.malha_max_skill_cards())
	_make_debug_btn(grid, "Achado aleatório", func() -> void: DebugCommands.malha_random_curio())
	_make_debug_btn(grid, "Todos os achados", func() -> void: DebugCommands.malha_all_curios())
	_make_debug_btn(grid, "Liberar os 10 níveis", func() -> void: DebugCommands.malha_unlock_levels())
	_make_debug_btn(grid, "Vencer a malha", func() -> void: DebugCommands.malha_win(), true)

	grid = _debug_section(list, "MALHA · IR PARA")
	for t in [["station", "Estação"], ["event", "Evento"], ["elite", "Elite"], ["shop", "Fiscal"], ["rest", "Dormitório"], ["boss", "Chefe"]]:
		var kind: String = t[0]
		_make_debug_btn(grid, String(t[1]), func() -> void: DebugCommands.malha_goto(kind), true)

	grid = _debug_section(list, "MALHA · CHEFE DA VIAGEM (atual: %s)" % Malha.boss_id)
	for b in Malha.data.get("bosses", []):
		var bid: String = String(b)
		_make_debug_btn(grid, String(Malha.get_boss_def(bid).get("name", bid)), func() -> void:
			DebugCommands.malha_set_boss(bid)
			_rebuild_debug_list())

	grid = _debug_section(list, "MALHA · GERAR INIMIGO")
	for e in ["flamer", "medic", "magnet", "bomber", "shield", "spark"]:
		var et: String = e
		_make_debug_btn(grid, et, func() -> void: DebugCommands.malha_spawn(tree, et), true)
	for a in ["blindado", "veloz", "explosivo", "divisor"]:
		var af: String = a
		_make_debug_btn(grid, "Sentinela %s" % af, func() -> void: DebugCommands.malha_spawn(tree, "sentinel", af), true)


func _debug_section(list: VBoxContainer, title: String) -> GridContainer:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color("#f2c35b"))
	list.add_child(lbl)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	list.add_child(grid)
	return grid


func _make_debug_btn(parent: Control, text: String, action: Callable, close_pause: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(158.0, 22.0)
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_confirm")
		if close_pause and _root.visible:
			_toggle_pause()
		action.call()
		_refresh_debug_buttons()
		_populate_pause_upgrades())
	parent.add_child(b)
	return b


func _make_fixed_panel(pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", Settings.make_ui_style("panel"))
	return p


func _switch_pause_tab(idx: int) -> void:
	_current_tab = idx
	for i in range(_tab_pages.size()):
		_tab_pages[i].visible = (i == idx)
		_tab_buttons[i].modulate = Color("#f2c35b") if i == idx else Color("#fff1c9")


func _refresh_debug_buttons() -> void:
	if _invincible_btn != null:
		_invincible_btn.text = "[F3] Invencível: %s" % ("SIM" if GameState.debug_invincible else "NÃO")
	if _freeze_btn != null:
		_freeze_btn.text = "[F8] Relógio: %s" % ("PARADO" if TrainClock.debug_frozen else "NORMAL")
	if _speed_btn != null:
		_speed_btn.text = "[F9] Velocidade: %sx" % str(GameState.debug_time_scale)


func _populate_pause_upgrades() -> void:
	if _stats_label != null and GameState.is_malha():
		_stats_label.text = "Parada: %d/%d  ·  Abates: %d  ·  Fichas: %d" % [
			Malha.current_column() + 1, Malha.total_stops(), GameState.kills, Malha.fichas
		]
	elif _stats_label != null:
		_stats_label.text = "Vagão: %d/4  ·  Abates: %d  ·  Relógio: %s" % [
			mini(4, GameState.current_wagon), GameState.kills, TrainClock.format_time()
		]
	if _upgrades_grid == null:
		return
	for child in _upgrades_grid.get_children():
		child.queue_free()

	if GameState.is_malha():
		for cid in Malha.curios:
			var info_c: Dictionary = Malha.get_curio(cid)
			var crow := HBoxContainer.new()
			crow.custom_minimum_size = Vector2(316.0, 22.0)
			crow.add_theme_constant_override("separation", 8)
			_upgrades_grid.add_child(crow)
			var cpath: String = "res://assets/sprites/malha/curio_%s.png" % cid
			if ResourceLoader.exists(cpath):
				var ctex := TextureRect.new()
				ctex.custom_minimum_size = Vector2(24.0, 20.0)
				ctex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				ctex.texture = load(cpath)
				crow.add_child(ctex)
			var clbl := Label.new()
			clbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			clbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			clbl.text = "ACHADO · %s — %s" % [String(info_c.get("name", cid)), String(info_c.get("description", ""))]
			clbl.add_theme_font_size_override("font_size", 10)
			clbl.add_theme_color_override("font_color", Color("#8fb8c4"))
			crow.add_child(clbl)

	if GameState.upgrades.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "\nNenhuma melhoria coletada ainda.\nConclua um vagão para escolher!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.custom_minimum_size = Vector2(316.0, 60.0)
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color("#8fb8c4"))
		_upgrades_grid.add_child(empty_lbl)
		return

	for k in GameState.upgrades.keys():
		var uid: String = String(k)
		var lvl: int = int(GameState.upgrades[uid])
		var info: Dictionary = GameState.get_upgrade_info(uid)

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(316.0, 26.0)
		row.add_theme_constant_override("separation", 8)
		_upgrades_grid.add_child(row)

		var icon_path: String = "res://assets/sprites/ui/icon_%s.png" % uid
		if ResourceLoader.exists(icon_path):
			var tex_rect := TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(24.0, 24.0)
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			tex_rect.texture = load(icon_path)
			row.add_child(tex_rect)

		var item_lbl := Label.new()
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var desc: String = String(info.get("description_malha", info.get("description", ""))) if GameState.is_malha() else String(info.get("description", ""))
		item_lbl.text = "%s (Nv %d) — %s" % [
			String(info.get("name", uid)), lvl, desc.replace("\n", " ")
		]
		item_lbl.add_theme_font_size_override("font_size", 10)
		item_lbl.add_theme_color_override("font_color", Color("#fff1c9"))
		row.add_child(item_lbl)


func _unhandled_input(event: InputEvent) -> void:
	if overlay_mode == "pause" and event.is_action_pressed("pause"):
		if not get_tree().paused or _root.visible:
			_toggle_pause()
	elif overlay_mode == "pause" and _root.visible and (event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next")):
		get_viewport().set_input_as_handled()
		var step_dir: int = -1 if event.is_action_pressed("tab_prev") else 1
		AudioManager.play_sfx("ui_hover")
		_switch_pause_tab(posmod(_current_tab + step_dir, _tab_pages.size()))
		_focus_tab_page(_current_tab)
	elif overlay_mode == "game_over" and _root.visible and not _exploding_anim:
		if event.is_action_pressed("menu_alt"):
			_retry_current_wagon()


# Foco no primeiro botão da aba (navegação por controle); sem botões, fica na própria aba
func _focus_tab_page(idx: int) -> void:
	for child in _tab_pages[idx].find_children("*", "Button", true, false):
		var b := child as Button
		if b.is_visible_in_tree():
			b.grab_focus()
			return
	_tab_buttons[idx].grab_focus()


func _toggle_pause() -> void:
	if not _root.visible:
		Modals.push(self)
		_refresh_debug_buttons()
		_populate_pause_upgrades()
		_rebuild_debug_list()
		_switch_pause_tab(0)
		_root.visible = true
		_focus_tab_page(0)
	else:
		_root.visible = false
		Modals.pop(self)


func _on_player_died(reason: String) -> void:
	Modals.push(self)
	_root.visible = true
	if reason == "bomb_exploded":
		_title_lbl.text = "A BOMBA EXPLODIU!"
		_exploding_anim = true
		_explosion_t = 0.0
		_game_over_card.visible = false
		AudioManager.play_sfx("bomb_explode", 0.0)
		Settings.rumble(1.0, 1.0, 1.2)
		Events.request_screen_shake.emit(6.0, 1.4)
		await get_tree().create_timer(EXPLOSION_TIME, true, false, true).timeout
		_exploding_anim = false
		_explosion_drawer.queue_redraw()
		_game_over_card.visible = true
		_retry_btn.grab_focus()
	else:
		_exploding_anim = false
		_game_over_card.visible = true
		_title_lbl.text = "VOCÊ NÃO RESISTIU"
		_retry_btn.grab_focus()


func _retry_current_wagon() -> void:
	var w: int = GameState.current_wagon
	var path: String = "res://scenes/levels/Level_Boss.tscn"
	if w >= 6:
		path = "res://scenes/levels/Disarm.tscn"
	elif w <= 4:
		path = "res://scenes/levels/Level_Wagon%d.tscn" % w
	if GameState.is_malha():
		path = Malha.scene_for(Malha.current_node)
	SceneRouter.goto_scene(path, 0.35, func() -> void:
		GameState.restore_wagon_checkpoint()
		TrainClock.is_running = true)
