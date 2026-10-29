extends Control

const TEX_HEART_FULL: Texture2D = preload("res://assets/sprites/ui/heart_full.png")
const TEX_HEART_EMPTY: Texture2D = preload("res://assets/sprites/ui/heart_empty.png")
const MAP_LEFT: float = 34.0
const MAP_RIGHT: float = 446.0
const MAP_CENTER_Y: float = 130.0
const ROW_GAP: float = 40.0
const NODE_RADIUS: float = 11.0
const TYPE_COLORS: Dictionary = {
	"combat": "#c98a3c",
	"elite": "#b3342e",
	"shop": "#f2c35b",
	"rest": "#8fb8c4",
	"boss": "#ff3d6e",
	"event": "#dce9ee",
	"station": "#f2c35b",
}
const TYPE_LETTERS: Dictionary = {"combat": "C", "elite": "E", "shop": "F", "rest": "D", "boss": "!", "event": "?", "station": "$"}
const MODIFIER_NAMES: Dictionary = {"tunnel": "Túnel", "curve": "Curva fechada", "passenger": "Passageiro em perigo"}

var _anim_t: float = 0.0
var _canvas: Control
var _buttons: Dictionary = {}
var _available: Array[int] = []
var _reachable: Dictionary = {}
var _hover_id: int = -1
var _hearts_box: HBoxContainer
var _status_lbl: Label
var _info_lbl: Label
var _panel: Panel
var _panel_box: VBoxContainer
var _panel_title: Label
var _panel_text: Label
var _upgrade_screen: CanvasLayer
var _busy: bool = false
var _bg_tex: Texture2D
var _node_tex: Dictionary = {}
var _line_tex: Texture2D
var _curio_box: HBoxContainer

signal _choice_made(value: String)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(480.0, 270.0)
	AudioManager.set_train_ambience(true, 0.9)
	AudioManager.play_music("intro")
	TrainClock.is_running = false
	_load_textures()
	_build_ui()
	_upgrade_screen = preload("res://scenes/ui/UpgradeScreen.tscn").instantiate()
	add_child(_upgrade_screen)
	_refresh()
	if Malha.victory:
		_show_victory()
	else:
		var cur: Dictionary = Malha.current()
		if not cur.is_empty() and not bool(cur.get("done", false)) and cur.get("type", "") in ["shop", "rest", "event", "station"]:
			_open_service(String(cur["type"]))
		else:
			_focus_first_available()


func _load_textures() -> void:
	var base: String = "res://assets/sprites/malha/"
	if ResourceLoader.exists(base + "map_bg.png"):
		_bg_tex = load(base + "map_bg.png")
	for t in TYPE_COLORS:
		var file: String = "node_shop.png" if t == "station" else "node_%s.png" % t
		if ResourceLoader.exists(base + file):
			_node_tex[t] = load(base + file)
	if ResourceLoader.exists(base + "line_%s.png" % Malha.line_id):
		_line_tex = load(base + "line_%s.png" % Malha.line_id)


func _process(delta: float) -> void:
	_anim_t += delta
	_canvas.queue_redraw()


func _node_pos(n: Dictionary) -> Vector2:
	var cols: int = maxi(1, Malha.total_stops() - 1)
	var x: float = MAP_LEFT + (MAP_RIGHT - MAP_LEFT) * float(n["col"]) / float(cols)
	var y: float = MAP_CENTER_Y + (float(n["row"]) - (float(n["rows"]) - 1.0) * 0.5) * ROW_GAP
	return Vector2(round(x), round(y))


func _build_ui() -> void:
	_canvas = Control.new()
	_canvas.size = size
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)

	var top := NinePatchRect.new()
	top.texture = load("res://assets/sprites/ui/kit/panel_hud.png")
	_patch(top, 6)
	top.position = Vector2(-4.0, -4.0)
	top.size = Vector2(488.0, 40.0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var icon_x: float = 8.0
	if _line_tex != null:
		var emblem := TextureRect.new()
		emblem.texture = _line_tex
		emblem.position = Vector2(6.0, 4.0)
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(emblem)
		icon_x = 34.0

	var title := _label("MALHA FERROVIÁRIA", Vector2(icon_x, 3.0), Vector2(160.0, 12.0), Color("#f2c35b"))
	add_child(title)
	var line_lbl := _label(String(Malha.get_line().get("name", "")).to_upper(), Vector2(icon_x, 15.0), Vector2(170.0, 12.0), Malha.get_line_color())
	add_child(line_lbl)

	_hearts_box = HBoxContainer.new()
	_hearts_box.position = Vector2(190.0, 10.0)
	_hearts_box.add_theme_constant_override("separation", 2)
	add_child(_hearts_box)

	_curio_box = HBoxContainer.new()
	_curio_box.position = Vector2(8.0, 38.0)
	_curio_box.add_theme_constant_override("separation", 3)
	add_child(_curio_box)

	_status_lbl = _label("", Vector2(272.0, 3.0), Vector2(200.0, 26.0), Color("#fff1c9"))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_lbl.add_theme_constant_override("line_spacing", -2)
	add_child(_status_lbl)

	for n in Malha.nodes:
		var b := Button.new()
		b.position = _node_pos(n) - Vector2(NODE_RADIUS + 2.0, NODE_RADIUS + 2.0)
		b.size = Vector2(NODE_RADIUS * 2.0 + 4.0, NODE_RADIUS * 2.0 + 4.0)
		b.flat = true
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var id: int = int(n["id"])
		b.pressed.connect(_on_node_pressed.bind(id))
		b.mouse_entered.connect(_on_node_hover.bind(id))
		b.focus_entered.connect(_on_node_hover.bind(id))
		add_child(b)
		_buttons[id] = b

	var info_bg := NinePatchRect.new()
	info_bg.texture = load("res://assets/sprites/ui/kit/panel_small.png")
	_patch(info_bg, 3)
	info_bg.position = Vector2(8.0, 216.0)
	info_bg.size = Vector2(464.0, 48.0)
	info_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_bg)

	_info_lbl = _label("", Vector2(14.0, 219.0), Vector2(452.0, 42.0), Color("#dce9ee"))
	_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_lbl.add_theme_constant_override("line_spacing", -2)
	add_child(_info_lbl)

	_panel = Panel.new()
	_panel.position = Vector2(90.0, 46.0)
	_panel.size = Vector2(300.0, 168.0)
	_panel.add_theme_stylebox_override("panel", Settings.make_ui_style("panel"))
	_panel.visible = false
	add_child(_panel)

	_panel_title = _label("", Vector2(8.0, 8.0), Vector2(284.0, 14.0), Color("#f2c35b"))
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_panel_title)

	_panel_text = _label("", Vector2(12.0, 24.0), Vector2(276.0, 36.0), Color("#dce9ee"))
	_panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_text.add_theme_constant_override("line_spacing", -2)
	_panel.add_child(_panel_text)

	_panel_box = VBoxContainer.new()
	_panel_box.position = Vector2(20.0, 62.0)
	_panel_box.size = Vector2(260.0, 100.0)
	_panel_box.add_theme_constant_override("separation", 4)
	_panel.add_child(_panel_box)


func _label(txt: String, pos: Vector2, sz: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", col)
	return l


func _patch(n: NinePatchRect, m: int) -> void:
	n.patch_margin_left = m
	n.patch_margin_right = m
	n.patch_margin_top = m
	n.patch_margin_bottom = m


func _refresh() -> void:
	_available = Malha.available_nodes()
	_reachable.clear()
	var frontier: Array[int] = _available.duplicate()
	while not frontier.is_empty():
		var id: int = frontier.pop_back()
		if _reachable.has(id):
			continue
		_reachable[id] = true
		for nx in Malha.nodes[id]["next"]:
			frontier.append(int(nx))
	for id in _buttons:
		var b: Button = _buttons[id]
		var ok: bool = _available.has(int(id)) and not _panel.visible
		b.disabled = not ok
		b.focus_mode = Control.FOCUS_ALL if ok else Control.FOCUS_NONE
	for child in _hearts_box.get_children():
		child.queue_free()
	for i in range(GameState.max_hp):
		var h := TextureRect.new()
		h.custom_minimum_size = Vector2(12.0, 12.0)
		h.texture = TEX_HEART_FULL if i < GameState.current_hp else TEX_HEART_EMPTY
		_hearts_box.add_child(h)
	var tier: int = Malha.apito_tier()
	var apito_txt: String = "%s NV %d" % [Malha.skill_name().to_upper(), tier] if tier > 0 else "HABILIDADE %d/%d CARTAS" % [Malha.line_card_count(), int(Malha.get_apito_cfg().get("unlock_cards", 3))]
	_status_lbl.text = "TEO NV %d · %d FICHAS · %d CARTAS\n%s" % [Malha.xp_level, Malha.fichas, GameState.upgrades.size(), apito_txt]
	_refresh_curios()
	if _hover_id < 0:
		_info_lbl.text = _default_info()


func _refresh_curios() -> void:
	for child in _curio_box.get_children():
		child.queue_free()
	for cid in Malha.curios:
		var info: Dictionary = Malha.get_curio(cid)
		var path: String = "res://assets/sprites/malha/curio_%s.png" % cid
		var item: Control
		if ResourceLoader.exists(path):
			var tex := TextureRect.new()
			tex.texture = load(path)
			tex.custom_minimum_size = Vector2(16.0, 16.0)
			item = tex
		else:
			var lbl := Label.new()
			lbl.text = String(info.get("name", cid)).substr(0, 3).to_upper()
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color("#8fb8c4"))
			item = lbl
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.mouse_entered.connect(func() -> void:
			_hover_id = -2
			_info_lbl.text = "ACHADO · %s — %s" % [String(info.get("name", cid)).to_upper(), String(info.get("description", ""))]
		)
		_curio_box.add_child(item)


func _default_info() -> String:
	if Malha.victory:
		return "Malha concluída!"
	if _available.is_empty():
		return ""
	var prompt: String = "Toque" if Settings.touch_mode and not Settings.using_gamepad else "Escolha"
	return "%s a próxima parada. Os trilhos mostram os caminhos possíveis até o Maquinista." % prompt


func _focus_first_available() -> void:
	if _available.is_empty():
		return
	(_buttons[_available[0]] as Button).grab_focus()


func _on_node_hover(id: int) -> void:
	_hover_id = id
	_info_lbl.text = _describe(Malha.get_node_data(id))


func _describe(n: Dictionary) -> String:
	var type: String = String(n.get("type", ""))
	var txt: String = ""
	match type:
		"combat":
			txt = "COMBATE — ondas de autômatos. Recompensa: 1 carta e %d fichas." % Malha.stop_reward(n)
		"elite":
			txt = "ELITE — ondas reforçadas e um Cargueiro. Recompensa: carta com mais chance de rara ou épica, um achado, %d fichas e +1 coração." % Malha.stop_reward(n)
		"shop":
			txt = "FISCAL — troque fichas por cartas, achados, reparos e sorteios extras."
		"event":
			txt = "EVENTO — algo inesperado acontece no vagão. Escolha com cuidado."
		"station":
			txt = "ESTAÇÃO — parada obrigatória antes do chefe: descanse para recuperar corações e compre com o Fiscal."
		"rest":
			txt = "DORMITÓRIO — descanse para recuperar corações ou afine uma carta que você já tem."
		"boss":
			var boss_def: Dictionary = Malha.get_boss_def()
			txt = "CHEFE — %s. %s Vença para concluir a malha." % [String(boss_def.get("name", "")), String(boss_def.get("description", ""))]
	var modifier: String = String(n.get("modifier", ""))
	if modifier != "":
		txt += " Modificador: %s." % String(MODIFIER_NAMES.get(modifier, modifier))
	if bool(n.get("done", false)):
		txt += " (concluída)"
	return txt


func _on_node_pressed(id: int) -> void:
	if _busy or not _available.has(id) or _panel.visible:
		return
	AudioManager.play_sfx("ui_confirm")
	Malha.select_node(id)
	var type: String = String(Malha.current().get("type", ""))
	if type in ["shop", "rest", "event", "station"]:
		_open_service(type)
		return
	_busy = true
	AudioManager.play_sfx("whistle", 0.03)
	SceneRouter.goto_scene(Malha.scene_for(id))


func _clear_panel() -> void:
	for c in _panel_box.get_children():
		c.queue_free()


func _panel_button(txt: String, cb: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(260.0, 20.0)
	b.add_theme_font_size_override("font_size", 10)
	b.disabled = not enabled
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_confirm")
		cb.call()
	)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus()
	)
	_panel_box.add_child(b)
	return b


func _show_panel(title: String, text: String, text_h: float = 36.0) -> void:
	_panel_title.text = title
	_panel_text.text = text
	_panel_text.size.y = text_h
	_panel_box.position.y = 26.0 + text_h
	_panel.visible = true
	_refresh()


func _focus_panel() -> void:
	await get_tree().process_frame
	var count: int = 0
	for c in _panel_box.get_children():
		if not c.is_queued_for_deletion():
			count += 1
	var h: float = _panel_box.position.y + float(count) * 24.0 + 6.0
	_panel.size.y = h
	_panel.position.y = round(maxf(36.0, 126.0 - h * 0.5))
	for c in _panel_box.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).grab_focus()
			return


func _open_service(type: String) -> void:
	match type:
		"shop", "station":
			var offer: Array[String] = Malha.roll_curios(1)
			_open_shop({"curio_offer": offer[0] if not offer.is_empty() else "", "station": type == "station"})
		"event":
			_open_event()
		_:
			_open_rest()


func _open_shop(bought: Dictionary) -> void:
	_clear_panel()
	var eco: Dictionary = Malha.get_economy()
	var card_price: int = Malha.price(int(eco.get("shop_card_price", 40)))
	var repair_price: int = Malha.price(int(eco.get("shop_repair_price", 30)))
	var repair_hearts: int = int(eco.get("shop_repair_hearts", 2))
	var reroll_price: int = Malha.price(int(eco.get("shop_reroll_price", 15)))
	var curio_price: int = Malha.price(int(eco.get("shop_curio_price", 45)))
	var curio_id: String = String(bought.get("curio_offer", ""))
	var station: bool = bool(bought.get("station", false))
	if station:
		_show_panel("ESTAÇÃO — ÚLTIMA PARADA", "O chefe espera no próximo vagão. Descanse e se prepare.\nVocê tem %d fichas." % Malha.fichas)
		var heal: int = maxi(int(eco.get("station_heal_min", 2)), ceili(float(GameState.max_hp) * float(eco.get("station_heal_ratio", 0.5))))
		_panel_button("DESCANSAR — RECUPERA %d ♥" % heal, func() -> void:
			bought["rested"] = true
			GameState.heal_player(heal)
			AudioManager.play_sfx("heal")
			_open_shop(bought)
		, not bought.has("rested") and GameState.current_hp < GameState.max_hp)
	else:
		_show_panel("O FISCAL", "\"Tudo tem seu preço, passageiro.\"\nVocê tem %d fichas." % Malha.fichas)
	_panel_button("CARTA (ESCOLHA 1 DE 3) — %d" % card_price, func() -> void:
		if Malha.spend(card_price):
			bought["card"] = true
			_busy = true
			_upgrade_screen.open_upgrade_choices("shop")
			await _upgrade_screen.upgrade_selected
			_busy = false
			_open_shop(bought)
	, not bought.has("card") and Malha.can_afford(card_price))
	_panel_button("REPARO +%d ♥ — %d" % [repair_hearts, repair_price], func() -> void:
		if Malha.spend(repair_price):
			bought["repair"] = true
			GameState.heal_player(repair_hearts)
			AudioManager.play_sfx("heal")
			_open_shop(bought)
	, not bought.has("repair") and Malha.can_afford(repair_price) and GameState.current_hp < GameState.max_hp)
	if curio_id != "":
		_panel_button("ACHADO: %s — %d" % [String(Malha.get_curio(curio_id).get("name", "")).to_upper(), curio_price], func() -> void:
			if Malha.spend(curio_price):
				bought["curio"] = true
				Malha.add_curio(curio_id)
				_open_shop(bought)
		, not bought.has("curio") and Malha.can_afford(curio_price))
	_panel_button("SORTEIO EXTRA (+1) — %d" % reroll_price, func() -> void:
		if Malha.spend(reroll_price):
			bought["reroll"] = true
			GameState.rerolls_left += 1
			_open_shop(bought)
	, not bought.has("reroll") and Malha.can_afford(reroll_price))
	_panel_button("SEGUIR PARA O CHEFE" if station else "SEGUIR VIAGEM", _close_service)
	_focus_panel()


func _open_rest() -> void:
	_clear_panel()
	var eco: Dictionary = Malha.get_economy()
	var heal: int = maxi(int(eco.get("rest_heal_min", 2)), ceili(float(GameState.max_hp) * float(eco.get("rest_heal_ratio", 0.5))))
	_show_panel("DORMITÓRIO", "Um vagão-leito silencioso. Escolha uma opção:")
	_panel_button("DORMIR — RECUPERA %d ♥" % heal, func() -> void:
		GameState.heal_player(heal)
		AudioManager.play_sfx("heal")
		_close_service()
	, GameState.current_hp < GameState.max_hp)
	_panel_button("AFINAR A MÁQUINA — SOBE 1 CARTA", func() -> void:
		_busy = true
		_upgrade_screen.open_upgrade_choices("owned")
		await _upgrade_screen.upgrade_selected
		_busy = false
		_close_service()
	, _upgrade_screen.has_owned_upgradable())
	_panel_button("SEGUIR VIAGEM", _close_service)
	_focus_panel()


func _open_event() -> void:
	_clear_panel()
	var ev: Dictionary = Malha.get_event(String(Malha.current().get("event", "")))
	if ev.is_empty():
		_close_service()
		return
	_show_panel(String(ev.get("title", "EVENTO")), String(ev.get("text", "")), 50.0)
	for opt in ev.get("options", []):
		var o: Dictionary = opt
		_panel_button(String(o.get("label", "")), func() -> void: _choose_event_option(o), Malha.option_allowed(o))
	_focus_panel()


func _choose_event_option(opt: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	var title: String = _panel_title.text
	var res: Dictionary = Malha.resolve_effects(opt.get("effects", []))
	var lines := PackedStringArray()
	if String(opt.get("result", "")) != "":
		lines.append(String(opt["result"]))
	lines.append_array(res["text"])
	for action in res["actions"]:
		match String(action.get("type", "")):
			"curio_choice":
				var picked: String = await _pick_curio(Malha.roll_curios(int(action.get("count", 2))))
				if picked != "":
					Malha.add_curio(picked)
					lines.append("Achado: %s." % String(Malha.get_curio(picked).get("name", "")))
			"upgrade_owned":
				if _upgrade_screen.has_owned_upgradable():
					_upgrade_screen.open_upgrade_choices("owned")
					await _upgrade_screen.upgrade_selected
			"card":
				_upgrade_screen.open_upgrade_choices(String(action.get("kind", "normal")))
				await _upgrade_screen.upgrade_selected
	_busy = false
	_clear_panel()
	_show_panel(title, " ".join(lines), 50.0)
	_panel_button("SEGUIR VIAGEM", _close_service)
	_focus_panel()


func _pick_curio(options: Array[String]) -> String:
	if options.is_empty():
		return ""
	_clear_panel()
	_show_panel("ESCOLHA UM ACHADO", "", 0.0)
	for cid in options:
		var info: Dictionary = Malha.get_curio(cid)
		var b := _panel_button(String(info.get("name", cid)).to_upper(), func() -> void: _choice_made.emit(cid))
		b.focus_entered.connect(func() -> void: _info_lbl.text = String(info.get("description", "")))
		b.mouse_entered.connect(func() -> void: _info_lbl.text = String(info.get("description", "")))
	_focus_panel()
	return await _choice_made


func _close_service() -> void:
	Malha.complete_current()
	_panel.visible = false
	_clear_panel()
	_refresh()
	_focus_first_available()


func _show_victory() -> void:
	_clear_panel()
	var run_t: float = GameState.active_run_time
	if not Malha.victory_registered:
		Malha.victory_registered = true
		Malha.new_record = Progress.register_malha_win(Malha.line_id, run_t, Malha.level, Malha.max_level())
	var record: bool = Malha.new_record
	var unlock_txt: String = "NÍVEL %d LIBERADO!" % (Malha.level + 1) if Malha.level < Malha.max_level() and Progress.get_malha_unlocked_level() == Malha.level + 1 else "NÍVEL %d" % Malha.level
	_show_panel("MALHA CONCLUÍDA!", "%s · %s\nTempo %s%s · Abates %d · Raspões %d\nQuedas %d · Cartas %d" % [
		String(Malha.get_line().get("name", "")).to_upper(), unlock_txt,
		TrainClock.format_seconds(run_t), " (RECORDE!)" if record else "",
		GameState.kills, GameState.grazes, GameState.deaths_in_run, GameState.upgrades.size()
	])
	_panel_text.size.y = 44.0
	_panel_box.position.y = 70.0
	AudioManager.play_music("ending")
	_panel_button("NOVA VIAGEM", func() -> void: SceneRouter.goto_scene("res://scenes/menus/MalhaSetup.tscn"))
	_panel_button("MENU PRINCIPAL", func() -> void: SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn"))
	_focus_panel()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or Modals.is_open():
		return
	if not (event.is_action_pressed("cancel") or event.is_action_pressed("pause")):
		return
	get_viewport().set_input_as_handled()
	if Malha.victory:
		return
	if _panel.visible and _panel_title.text in ["ABANDONAR A VIAGEM?", "DEBUG · MALHA"]:
		_close_quit_panel()
		return
	if _panel.visible:
		return
	_clear_panel()
	_show_panel("ABANDONAR A VIAGEM?", "O progresso desta malha será perdido.")
	_panel_button("CONTINUAR NA MALHA", _close_quit_panel)
	_panel_button("VOLTAR AO MENU", func() -> void: SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn"))
	if DebugCommands.enabled():
		_panel_button("DEBUG", _open_debug_panel)
	_focus_panel()


func _open_debug_panel() -> void:
	_clear_panel()
	_show_panel("DEBUG · MALHA", DebugCommands.malha_status(), 50.0)
	var refresh := func() -> void:
		_open_debug_panel()
	_panel_button("+100 FICHAS · NÍVEL DO TEO · ACHADO", func() -> void:
		DebugCommands.malha_add_fichas(100)
		DebugCommands.malha_level_up()
		Malha.pending_levelups = 0
		DebugCommands.malha_random_curio()
		refresh.call())
	_panel_button("IR PARA A ESTAÇÃO", func() -> void: DebugCommands.malha_goto("station"))
	_panel_button("IR PARA O CHEFE (%s)" % Malha.boss_id.to_upper(), func() -> void: DebugCommands.malha_goto("boss"))
	_panel_button("TROCAR CHEFE", func() -> void:
		var bosses: Array = Malha.data.get("bosses", [])
		DebugCommands.malha_set_boss(String(bosses[(bosses.find(Malha.boss_id) + 1) % bosses.size()]))
		refresh.call())
	_panel_button("VOLTAR", _close_quit_panel)
	_focus_panel()


func _close_quit_panel() -> void:
	_panel.visible = false
	_clear_panel()
	_refresh()
	_focus_first_available()


func _draw_map() -> void:
	var c := _canvas
	if _bg_tex != null:
		c.draw_texture(_bg_tex, Vector2.ZERO)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color("#14111d"))
		var grid := Color(0.29, 0.27, 0.41, 0.25)
		for gx in range(0, 481, 16):
			c.draw_line(Vector2(gx, 36.0), Vector2(gx, 214.0), grid)
		for gy in range(36, 215, 16):
			c.draw_line(Vector2(0.0, gy), Vector2(480.0, gy), grid)

	var path_edges: Dictionary = {}
	for i in range(Malha.path.size() - 1):
		path_edges["%d-%d" % [Malha.path[i], Malha.path[i + 1]]] = true

	for n in Malha.nodes:
		var a: Vector2 = _node_pos(n)
		for nx in n["next"]:
			var m: Dictionary = Malha.nodes[int(nx)]
			var col := Color("#4a4668")
			if path_edges.has("%d-%d" % [int(n["id"]), int(nx)]):
				col = Color("#f2c35b")
			elif int(n["id"]) == Malha.current_node and _available.has(int(nx)):
				col = Color("#fff1c9")
			elif not _reachable.has(int(n["id"])) or not _reachable.has(int(nx)):
				col = Color("#2c2a40")
			_draw_rail(a, _node_pos(m), col)

	if Malha.current_node < 0:
		for id in _available:
			_draw_rail(Vector2(4.0, MAP_CENTER_Y), _node_pos(Malha.nodes[id]), Color("#fff1c9"))

	for n in Malha.nodes:
		_draw_node(n)


func _draw_rail(a: Vector2, b: Vector2, col: Color) -> void:
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = dir.orthogonal() * 2.0
	var dist: float = a.distance_to(b)
	var t: float = NODE_RADIUS
	while t < dist - NODE_RADIUS:
		var p: Vector2 = a + dir * t
		_canvas.draw_line((p - perp * 1.6).round(), (p + perp * 1.6).round(), col.darkened(0.45), 1.0)
		t += 5.0
	var s: Vector2 = a + dir * NODE_RADIUS
	var e: Vector2 = b - dir * NODE_RADIUS
	_canvas.draw_line((s + perp).round(), (e + perp).round(), col, 1.0)
	_canvas.draw_line((s - perp).round(), (e - perp).round(), col, 1.0)


func _draw_node(n: Dictionary) -> void:
	var id: int = int(n["id"])
	var p: Vector2 = _node_pos(n)
	var type: String = String(n["type"])
	var base := Color(String(TYPE_COLORS.get(type, "#c98a3c")))
	var done: bool = bool(n.get("done", false))
	var available: bool = _available.has(id)
	var dim: bool = not available and not done and not _reachable.has(id) and id != Malha.current_node
	var r: float = NODE_RADIUS + (3.0 if type == "boss" else 0.0)

	if available:
		var pulse: float = 0.5 + 0.5 * sin(_anim_t * 5.0)
		_canvas.draw_circle(p, r + 2.0 + pulse * 1.5, Color(Malha.get_line_color(), 0.35 + 0.3 * pulse))
	_canvas.draw_circle(p, r, Color("#0d0b12"))
	_canvas.draw_arc(p, r, 0.0, TAU, 24, base.darkened(0.5) if dim else base, 1.0)

	var tint := Color.WHITE
	if done:
		tint = Color(0.55, 0.55, 0.6)
	elif dim:
		tint = Color(0.4, 0.4, 0.5)
	if _node_tex.has(type):
		var tex: Texture2D = _node_tex[type]
		_canvas.draw_texture(tex, (p - tex.get_size() * 0.5).round(), tint)
	else:
		var fs: int = 10
		var baseline: float = p.y + (Settings.ui_font.get_ascent(fs) - Settings.ui_font.get_descent(fs)) * 0.5
		_canvas.draw_string(Settings.ui_font, Vector2(p.x - 10.0, round(baseline)), String(TYPE_LETTERS.get(type, "?")), HORIZONTAL_ALIGNMENT_CENTER, 20.0, fs, base * tint)

	if done:
		_canvas.draw_line(p + Vector2(-5.0, 0.0), p + Vector2(-1.0, 4.0), Color("#f2c35b"), 2.0)
		_canvas.draw_line(p + Vector2(-1.0, 4.0), p + Vector2(6.0, -4.0), Color("#f2c35b"), 2.0)
	if id == Malha.current_node and not done:
		_canvas.draw_arc(p, r + 3.0, 0.0, TAU, 24, Color("#f2c35b"), 1.0)
	var b: Button = _buttons.get(id)
	if b != null and b.has_focus():
		var f: float = r + 4.0
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var cp: Vector2 = p + corner * f
			_canvas.draw_line(cp, cp - Vector2(corner.x * 4.0, 0.0), Color("#fff1c9"), 1.0)
			_canvas.draw_line(cp, cp - Vector2(0.0, corner.y * 4.0), Color("#fff1c9"), 1.0)
