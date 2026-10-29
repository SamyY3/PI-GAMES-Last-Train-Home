extends CanvasLayer

signal upgrade_selected
signal shop_closed(bought: bool)

const RARITY_COLORS: Dictionary = {
	"common": "#4a4668",
	"rare": "#c98a3c",
	"epic": "#f2c35b",
	"cursed": "#b3342e"
}
const RARITY_NAMES: Dictionary = {
	"common": "COMUM",
	"rare": "RARO",
	"epic": "ÉPICO",
	"cursed": "MALDIÇÃO"
}

var _cards_data: Array[Dictionary] = []
var _card_panels: Array[Panel] = []
var _card_icons: Array[TextureRect] = []
var _card_titles: Array[Label] = []
var _card_levels: Array[Label] = []
var _card_descs: Array[Label] = []
var _card_cats: Array[Label] = []
var _card_cat_bgs: Array[NinePatchRect] = []
var _card_curses: Array[Control] = []
var _reroll_btn: Button
var _decline_btn: Button
var _title: Label
var _hint: Label
var _shop_hint: Label
var _shop_price: float = -1.0
var _kind: String = "normal"
var _root_control: Control
var _focused_idx: int = 0


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root_control.visible = false


func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.position = Vector2.ZERO
	_root_control.size = Vector2(480.0, 270.0)
	add_child(_root_control)

	var bg := ColorRect.new()
	bg.color = Color(0.051, 0.043, 0.071, 0.86)
	bg.position = Vector2.ZERO
	bg.size = Vector2(480.0, 270.0)
	_root_control.add_child(bg)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0.0, 10.0)
	_title.size = Vector2(480.0, 18.0)
	_title.add_theme_font_size_override("font_size", 10)
	_title.add_theme_color_override("font_color", Color("#f2c35b"))
	_root_control.add_child(_title)

	var start_x: Array[float] = [28.0, 172.0, 316.0]
	for i in range(3):
		var card := Panel.new()
		card.position = Vector2(start_x[i], 30.0)
		card.size = Vector2(136.0, 170.0)
		card.clip_contents = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx: int = i
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_pick_card(idx)
		)
		card.mouse_entered.connect(func() -> void:
			_set_focused_card(idx)
			AudioManager.play_sfx("ui_hover")
		)
		_root_control.add_child(card)
		_card_panels.append(card)

		var curse := Control.new()
		curse.position = Vector2.ZERO
		curse.size = card.size
		curse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		curse.visible = false
		curse.draw.connect(_draw_curse_frame.bind(curse))
		card.add_child(curse)
		_card_curses.append(curse)

		var icon_rect := TextureRect.new()
		icon_rect.position = Vector2(56.0, 5.0)
		icon_rect.size = Vector2(24.0, 24.0)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		card.add_child(icon_rect)
		_card_icons.append(icon_rect)

		var lbl_name := Label.new()
		lbl_name.position = Vector2(4.0, 30.0)
		lbl_name.size = Vector2(128.0, 28.0)
		lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_name.add_theme_font_size_override("font_size", 10)
		lbl_name.add_theme_constant_override("line_spacing", -3)
		lbl_name.add_theme_color_override("font_color", Color("#fff1c9"))
		card.add_child(lbl_name)
		_card_titles.append(lbl_name)

		var lbl_lvl := Label.new()
		lbl_lvl.position = Vector2(4.0, 58.0)
		lbl_lvl.size = Vector2(128.0, 14.0)
		lbl_lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_lvl.add_theme_font_size_override("font_size", 10)
		lbl_lvl.add_theme_color_override("font_color", Color("#8fb8c4"))
		card.add_child(lbl_lvl)
		_card_levels.append(lbl_lvl)

		var lbl_desc := Label.new()
		lbl_desc.position = Vector2(5.0, 73.0)
		lbl_desc.size = Vector2(126.0, 74.0)
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_desc.add_theme_font_size_override("font_size", 10)
		lbl_desc.add_theme_constant_override("line_spacing", -1)
		lbl_desc.add_theme_color_override("font_color", Color("#dce9ee"))
		card.add_child(lbl_desc)
		_card_descs.append(lbl_desc)

		var cat_bg := NinePatchRect.new()
		cat_bg.texture = load("res://assets/sprites/ui/kit/panel_small.png")
		cat_bg.patch_margin_left = 3
		cat_bg.patch_margin_right = 3
		cat_bg.patch_margin_top = 3
		cat_bg.patch_margin_bottom = 3
		cat_bg.position = Vector2(4.0, 148.0)
		cat_bg.size = Vector2(128.0, 19.0)
		cat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cat_bg)
		_card_cat_bgs.append(cat_bg)

		var lbl_cat := Label.new()
		lbl_cat.position = Vector2(4.0, 151.0)
		lbl_cat.size = Vector2(128.0, 15.0)
		lbl_cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_cat.add_theme_font_size_override("font_size", 10)
		lbl_cat.add_theme_color_override("font_color", Color("#f2c35b"))
		card.add_child(lbl_cat)
		_card_cats.append(lbl_cat)

	_reroll_btn = Button.new()
	Settings.bind_prompt_text(_reroll_btn, "SORTEAR DE NOVO {menu_alt} (1)")
	_reroll_btn.position = Vector2(165.0, 208.0)
	_reroll_btn.size = Vector2(150.0, 24.0)
	_reroll_btn.add_theme_font_size_override("font_size", 10)
	_reroll_btn.pressed.connect(_do_reroll)
	_root_control.add_child(_reroll_btn)

	_decline_btn = Button.new()
	Settings.bind_prompt_text(_decline_btn, "RECUSAR {cancel}")
	_decline_btn.position = Vector2(165.0, 208.0)
	_decline_btn.size = Vector2(150.0, 24.0)
	_decline_btn.add_theme_font_size_override("font_size", 10)
	_decline_btn.pressed.connect(_decline_shop)
	_root_control.add_child(_decline_btn)

	_hint = Label.new()
	if Settings.touch_mode:
		_hint.text = "Toque em uma carta para escolher"
	else:
		Settings.bind_prompt_text(_hint, "[A/D ou Setas] Selecionar   |   [ENTER ou Clique] Confirmar", "[◀/▶] Selecionar   |   {confirm} Confirmar   |   {menu_alt} Sortear")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0.0, 236.0)
	_hint.size = Vector2(480.0, 16.0)
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Color("#8fb8c4"))
	_root_control.add_child(_hint)

	_shop_hint = Label.new()
	_shop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_hint.position = Vector2(0.0, 236.0)
	_shop_hint.size = Vector2(480.0, 16.0)
	_shop_hint.add_theme_font_size_override("font_size", 10)
	_shop_hint.add_theme_color_override("font_color", Color("#8fb8c4"))
	_root_control.add_child(_shop_hint)


func open_upgrade_choices(kind: String = "normal") -> void:
	_shop_price = -1.0
	_kind = kind
	_title.text = "AFINAR A MÁQUINA — SUBA O NÍVEL DE UMA CARTA" if kind == "owned" else "ESCOLHA UMA MELHORIA"
	if kind == "levelup":
		_title.text = "TEO SUBIU PARA O NÍVEL %d! ESCOLHA UMA MELHORIA" % Malha.xp_level
	_open()


func is_open() -> bool:
	return _root_control.visible


func has_owned_upgradable() -> bool:
	for item in GameState.upgrades_db:
		var id_str: String = String(item.get("id", ""))
		var lvl: int = GameState.get_upgrade_level(id_str)
		if lvl > 0 and lvl < int(item.get("max_level", 1)):
			return true
	return false


func open_shop(price: float) -> void:
	_shop_price = price
	_kind = "normal"
	_title.text = "O FISCAL — UMA CARTA POR %s" % TrainClock.format_seconds(price)
	var from_reserve: float = minf(TrainClock.reserve, price)
	if from_reserve <= 0.0:
		_shop_hint.text = "Pago com %s do relógio" % TrainClock.format_seconds(price)
	elif from_reserve >= price:
		_shop_hint.text = "Pago com %s da reserva" % TrainClock.format_seconds(price)
	else:
		_shop_hint.text = "Pago com %s da reserva + %s do relógio" % [TrainClock.format_seconds(from_reserve), TrainClock.format_seconds(price - from_reserve)]
	_open()


func _open() -> void:
	var shop: bool = _shop_price >= 0.0
	_reroll_btn.visible = not shop
	_decline_btn.visible = shop
	_hint.visible = not shop
	_shop_hint.visible = shop
	Modals.push(self)
	_root_control.visible = true
	_roll_three_cards(false)
	_set_focused_card(0)


func _decline_shop() -> void:
	if _shop_price < 0.0 or not _root_control.visible:
		return
	AudioManager.play_sfx("ui_hover")
	_close()
	shop_closed.emit(false)


func _close() -> void:
	_root_control.visible = false
	Modals.pop(self)


func _unhandled_input(event: InputEvent) -> void:
	if not _root_control.visible:
		return
	if event.is_action_pressed("move_left"):
		_set_focused_card(posmod(_focused_idx - 1, _cards_data.size()))
		AudioManager.play_sfx("ui_hover")
	elif event.is_action_pressed("move_right"):
		_set_focused_card(posmod(_focused_idx + 1, _cards_data.size()))
		AudioManager.play_sfx("ui_hover")
	elif event.is_action_pressed("confirm"):
		_pick_card(_focused_idx)
	elif event.is_action_pressed("menu_alt"):
		_do_reroll()
	elif event.is_action_pressed("cancel") and _shop_price >= 0.0:
		get_viewport().set_input_as_handled()
		_decline_shop()


func _set_focused_card(idx: int) -> void:
	_focused_idx = clampi(idx, 0, maxi(0, _cards_data.size() - 1))
	var start_x: Array[float] = [28.0, 172.0, 316.0]
	for i in range(3):
		if i >= _cards_data.size():
			continue
		var card: Panel = _card_panels[i]
		var data: Dictionary = _cards_data[i]
		var rarity: String = String(data.get("rarity", "common"))
		var base_col := Color(String(RARITY_COLORS.get(rarity, "#4a4668")))

		card.add_theme_stylebox_override("panel", Settings.make_ui_style("panel_focus" if i == _focused_idx else "panel"))
		card.self_modulate = Color.WHITE.lerp(base_col, 0.85 if rarity == "cursed" else 0.35)
		card.position = Vector2(start_x[i], 25.0 if i == _focused_idx else 30.0)


func _do_reroll() -> void:
	if _shop_price >= 0.0 or GameState.rerolls_left <= 0:
		return
	GameState.rerolls_left -= 1
	AudioManager.play_sfx("ui_confirm")
	_roll_three_cards(true)
	_set_focused_card(_focused_idx)


func _roll_three_cards(exclude_current: bool) -> void:
	var current_ids: Array[String] = []
	if exclude_current:
		for c in _cards_data:
			current_ids.append(String(c.get("id", "")))

	var available: Array[Dictionary] = []
	for item in GameState.upgrades_db:
		if item is Dictionary:
			var id_str: String = String(item.get("id", ""))
			var max_lvl: int = int(item.get("max_level", 1))
			var lvl: int = GameState.get_upgrade_level(id_str)
			if not GameState.upgrade_in_mode(item) or not Malha.card_allowed(item) or (_kind == "owned" and lvl <= 0):
				continue
			if lvl < max_lvl:
				if not exclude_current or not current_ids.has(id_str):
					available.append(item)

	var weights: Dictionary = GameState.rarity_weights
	if _shop_price >= 0.0 or _kind == "shop":
		weights = GameState.get_fiscal_config().get("rarity_weights", weights)
	elif _kind == "elite":
		weights = Malha.data.get("elite_rarity_weights", weights)

	_cards_data.clear()
	if available.is_empty():
		for i in range(3):
			_cards_data.append({
				"id": "reparos",
				"name": "Reparos",
				"description": "Restaura toda a vida.",
				"rarity": "common",
				"category": "Defesa",
				"max_level": 1
			})
	else:
		if not GameState.has_picked_first_upgrade and _kind != "owned":
			var atk_pool: Array[Dictionary] = []
			for u in available:
				var first_ok: bool = String(u.get("line", "")) == Malha.line_id if GameState.is_malha() else String(u.get("category", "")) == "Ataque"
				if first_ok and String(u.get("rarity", "")) != "cursed":
					atk_pool.append(u)
			if not atk_pool.is_empty():
				var first_atk: Dictionary = atk_pool[GameState.card_rng.randi_range(0, atk_pool.size() - 1)]
				_cards_data.append(first_atk)
				available.erase(first_atk)

		while _cards_data.size() < 3 and not available.is_empty():
			var picked: Dictionary = _weighted_pick(available, weights)
			_cards_data.append(picked)
			available.erase(picked)

	_update_card_contents()


func _weighted_pick(pool: Array[Dictionary], weights: Dictionary) -> Dictionary:
	var total_weight: float = 0.0
	for u in pool:
		total_weight += _card_weight(u, weights)

	var roll: float = GameState.card_rng.randf() * total_weight
	var accum: float = 0.0
	for u in pool:
		accum += _card_weight(u, weights)
		if roll < accum:
			return u
	return pool[0]


func _card_weight(u: Dictionary, weights: Dictionary) -> float:
	return float(weights.get(String(u.get("rarity", "common")), 10)) * Malha.card_weight(u)


func _update_card_contents() -> void:
	for i in range(3):
		var card: Panel = _card_panels[i]
		if i >= _cards_data.size():
			card.visible = false
			continue
		card.visible = true
		var data: Dictionary = _cards_data[i]
		var id_str: String = String(data.get("id", ""))
		var cur_lvl: int = GameState.get_upgrade_level(id_str)
		var next_lvl: int = cur_lvl + 1
		var rarity: String = String(data.get("rarity", "common"))

		var icon_path: String = "res://assets/sprites/ui/icon_%s.png" % id_str
		_card_icons[i].texture = load(icon_path) if ResourceLoader.exists(icon_path) else null

		_card_titles[i].text = String(data.get("name", ""))
		_card_levels[i].text = "%s · Nv %d -> %d" % [String(RARITY_NAMES.get(rarity, "COMUM")), cur_lvl, next_lvl]
		_card_descs[i].text = String(data.get("description_malha", data.get("description", ""))) if GameState.is_malha() else String(data.get("description", ""))
		var line_info: Dictionary = Malha.get_line(String(data.get("line", ""))) if GameState.is_malha() and data.has("line") else {}
		_card_cats[i].text = "[%s]" % (String(line_info.get("short", "")) if not line_info.is_empty() else String(data.get("category", "")))
		if data.has("skill"):
			_card_cats[i].text = "[HABILIDADE: %s]" % Malha.skill_name(String(data.get("skill", ""))).to_upper().get_slice(" ", 0)
		var cursed: bool = rarity == "cursed"
		_card_curses[i].visible = cursed
		_card_curses[i].queue_redraw()
		_card_titles[i].add_theme_color_override("font_color", Color("#ffb4a8") if cursed else Color("#fff1c9"))
		_card_levels[i].add_theme_color_override("font_color", Color("#ff6b5b") if cursed else Color("#8fb8c4"))
		var cat_col: Color = Color("#f2c35b")
		if cursed:
			cat_col = Color("#ff8a7a")
		elif not line_info.is_empty():
			cat_col = Malha.get_line_color(String(line_info.get("id", "")))
		_card_cats[i].add_theme_color_override("font_color", cat_col)
		_card_cat_bgs[i].self_modulate = Color("#e0574a") if cursed else Color.WHITE

	Settings.bind_prompt_text(_reroll_btn, "SORTEAR DE NOVO {menu_alt} (%d)" % GameState.rerolls_left)
	_reroll_btn.disabled = GameState.rerolls_left <= 0


func _draw_curse_frame(c: Control) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	var red := Color("#ff3d3d")
	var dark := Color("#5a0f12")
	c.draw_rect(Rect2(4.0, 4.0, w - 8.0, h - 8.0), Color(0.35, 0.02, 0.05, 0.45))
	for y in [5.0, h - 6.0]:
		var x: float = 10.0
		while x < w - 12.0:
			c.draw_rect(Rect2(x, y, 3.0, 1.0), dark)
			c.draw_rect(Rect2(x + 1.0, y, 1.0, 1.0), red)
			x += 6.0
	for corner in [Vector2(5.0, 5.0), Vector2(w - 6.0, 5.0), Vector2(5.0, h - 6.0), Vector2(w - 6.0, h - 6.0)]:
		var dir := Vector2(1.0 if corner.x < w * 0.5 else -1.0, 1.0 if corner.y < h * 0.5 else -1.0)
		for k in range(5):
			c.draw_rect(Rect2(corner + dir * float(k), Vector2.ONE), red)
		c.draw_rect(Rect2(corner + Vector2(dir.x * 4.0, 0.0), Vector2.ONE), dark)
		c.draw_rect(Rect2(corner + Vector2(0.0, dir.y * 4.0), Vector2.ONE), dark)
	c.draw_rect(Rect2(w * 0.5 - 2.0, 2.0, 4.0, 4.0), dark)
	c.draw_rect(Rect2(w * 0.5 - 1.0, 3.0, 2.0, 2.0), red)
	c.draw_rect(Rect2(w * 0.5 - 2.0, h - 6.0, 4.0, 4.0), dark)
	c.draw_rect(Rect2(w * 0.5 - 1.0, h - 5.0, 2.0, 2.0), red)


func _pick_card(index: int) -> void:
	if index < 0 or index >= _cards_data.size():
		return
	var chosen: Dictionary = _cards_data[index]
	var id_str: String = String(chosen.get("id", ""))

	GameState.has_picked_first_upgrade = true
	if id_str == "reparos":
		GameState.heal_player(GameState.max_hp)
	else:
		GameState.add_upgrade(id_str)

	AudioManager.play_sfx("upgrade_get")
	_close()
	if _shop_price >= 0.0:
		TrainClock.spend_time(_shop_price)
		GameState.fiscal_purchases += 1
		shop_closed.emit(true)
	else:
		upgrade_selected.emit()
