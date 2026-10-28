extends CanvasLayer

signal upgrade_selected

const RARITY_COLORS: Dictionary = {
	"common": "#4a4668",
	"rare": "#c98a3c",
	"epic": "#f2c35b"
}
const RARITY_NAMES: Dictionary = {
	"common": "COMUM",
	"rare": "RARO",
	"epic": "ÉPICO"
}

var _cards_data: Array[Dictionary] = []
var _card_panels: Array[Panel] = []
var _card_icons: Array[TextureRect] = []
var _card_titles: Array[Label] = []
var _card_levels: Array[Label] = []
var _card_descs: Array[Label] = []
var _card_cats: Array[Label] = []
var _reroll_btn: Button
var _root_control: Control
var _focused_idx: int = 0
var _was_clock_running: bool = false


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

	var title := Label.new()
	title.text = "ESCOLHA UMA MELHORIA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 10.0)
	title.size = Vector2(480.0, 18.0)
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("#f2c35b"))
	_root_control.add_child(title)

	var start_x: Array[float] = [52.0, 180.0, 308.0]
	for i in range(3):
		var card := Panel.new()
		card.position = Vector2(start_x[i], 36.0)
		card.size = Vector2(120.0, 152.0)
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

		var icon_rect := TextureRect.new()
		icon_rect.position = Vector2(48.0, 8.0)
		icon_rect.size = Vector2(24.0, 24.0)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		card.add_child(icon_rect)
		_card_icons.append(icon_rect)

		var lbl_name := Label.new()
		lbl_name.position = Vector2(4.0, 34.0)
		lbl_name.size = Vector2(112.0, 22.0)
		lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_name.add_theme_font_size_override("font_size", 10)
		lbl_name.add_theme_color_override("font_color", Color("#fff1c9"))
		card.add_child(lbl_name)
		_card_titles.append(lbl_name)

		var lbl_lvl := Label.new()
		lbl_lvl.position = Vector2(4.0, 58.0)
		lbl_lvl.size = Vector2(112.0, 14.0)
		lbl_lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_lvl.add_theme_font_size_override("font_size", 10)
		lbl_lvl.add_theme_color_override("font_color", Color("#8fb8c4"))
		card.add_child(lbl_lvl)
		_card_levels.append(lbl_lvl)

		var lbl_desc := Label.new()
		lbl_desc.position = Vector2(6.0, 74.0)
		lbl_desc.size = Vector2(108.0, 54.0)
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
		cat_bg.position = Vector2(4.0, 130.0)
		cat_bg.size = Vector2(112.0, 19.0)
		cat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cat_bg)

		var lbl_cat := Label.new()
		lbl_cat.position = Vector2(4.0, 133.0)
		lbl_cat.size = Vector2(112.0, 15.0)
		lbl_cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_cat.add_theme_font_size_override("font_size", 10)
		lbl_cat.add_theme_color_override("font_color", Color("#f2c35b"))
		card.add_child(lbl_cat)
		_card_cats.append(lbl_cat)

	_reroll_btn = Button.new()
	Settings.bind_prompt_text(_reroll_btn, "SORTEAR DE NOVO {menu_alt} (1)")
	_reroll_btn.position = Vector2(165.0, 198.0)
	_reroll_btn.size = Vector2(150.0, 24.0)
	_reroll_btn.add_theme_font_size_override("font_size", 10)
	_reroll_btn.pressed.connect(_do_reroll)
	_root_control.add_child(_reroll_btn)

	var hint := Label.new()
	Settings.bind_prompt_text(hint, "[A/D ou Setas] Selecionar   |   [ENTER ou Clique] Confirmar", "[◀/▶] Selecionar   |   {confirm} Confirmar   |   {menu_alt} Sortear")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0.0, 228.0)
	hint.size = Vector2(480.0, 16.0)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("#8fb8c4"))
	_root_control.add_child(hint)


func open_upgrade_choices() -> void:
	_was_clock_running = TrainClock.is_running
	TrainClock.is_running = false
	get_tree().paused = true
	_root_control.visible = true
	_roll_three_cards(false)
	_set_focused_card(0)


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


func _set_focused_card(idx: int) -> void:
	_focused_idx = clampi(idx, 0, maxi(0, _cards_data.size() - 1))
	var start_x: Array[float] = [52.0, 180.0, 308.0]
	for i in range(3):
		if i >= _cards_data.size():
			continue
		var card: Panel = _card_panels[i]
		var data: Dictionary = _cards_data[i]
		var rarity: String = String(data.get("rarity", "common"))
		var base_col := Color(String(RARITY_COLORS.get(rarity, "#4a4668")))

		card.add_theme_stylebox_override("panel", Settings.make_ui_style("panel_focus" if i == _focused_idx else "panel"))
		# A raridade tinge levemente a moldura da carta
		card.self_modulate = Color.WHITE.lerp(base_col, 0.35)
		card.position = Vector2(start_x[i], 30.0 if i == _focused_idx else 36.0)


func _do_reroll() -> void:
	if GameState.rerolls_left <= 0:
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
			if GameState.get_upgrade_level(id_str) < max_lvl:
				if not exclude_current or not current_ids.has(id_str):
					available.append(item)

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
		if not GameState.has_picked_first_upgrade:
			var atk_pool: Array[Dictionary] = []
			for u in available:
				if String(u.get("category", "")) == "Ataque":
					atk_pool.append(u)
			if not atk_pool.is_empty():
				var first_atk: Dictionary = atk_pool.pick_random()
				_cards_data.append(first_atk)
				available.erase(first_atk)

		while _cards_data.size() < 3 and not available.is_empty():
			var picked: Dictionary = _weighted_pick(available)
			_cards_data.append(picked)
			available.erase(picked)

	_update_card_contents()


func _weighted_pick(pool: Array[Dictionary]) -> Dictionary:
	var total_weight: int = 0
	for u in pool:
		var r: String = String(u.get("rarity", "common"))
		total_weight += int(GameState.rarity_weights.get(r, 10))

	var roll: int = randi() % maxi(1, total_weight)
	var accum: int = 0
	for u in pool:
		var r: String = String(u.get("rarity", "common"))
		accum += int(GameState.rarity_weights.get(r, 10))
		if roll < accum:
			return u
	return pool[0]


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
		if ResourceLoader.exists(icon_path):
			_card_icons[i].texture = load(icon_path)

		_card_titles[i].text = String(data.get("name", ""))
		_card_levels[i].text = "%s · Nv %d -> %d" % [String(RARITY_NAMES.get(rarity, "COMUM")), cur_lvl, next_lvl]
		_card_descs[i].text = String(data.get("description", ""))
		_card_cats[i].text = "[%s]" % String(data.get("category", ""))

	Settings.bind_prompt_text(_reroll_btn, "SORTEAR DE NOVO {menu_alt} (%d)" % GameState.rerolls_left)
	_reroll_btn.disabled = GameState.rerolls_left <= 0


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
	_root_control.visible = false
	get_tree().paused = false
	TrainClock.is_running = _was_clock_running
	upgrade_selected.emit()
