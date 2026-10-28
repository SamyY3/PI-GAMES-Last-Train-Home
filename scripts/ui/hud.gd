extends CanvasLayer

var _hearts_box: HBoxContainer
var _clock_title: Label
var _clock_label: Label
var _radar_label: Label
var _wagon_label: Label
var _base_wagon_title: String = ""
var _wave_text: String = ""
var _dash_cd_bar: ProgressBar
var _pulse_cd_bar: ProgressBar
var _pulse_cd_label: Label
var _boss_bar_container: Control
var _boss_bar_ghost: ProgressBar
var _boss_bar_fill: ProgressBar
var _boss_name_label: Label
var _upgrades_box: HBoxContainer
var _upgrade_tooltip: PanelContainer
var _upgrade_tooltip_lbl: Label
var _tip_label: Label
var _banner_panel: PanelContainer
var _banner_label: Label
var _flash_rect: ColorRect
var _vignette_rect: TextureRect
var _clock_gear: TextureRect
const TEX_HEART_FULL: Texture2D = preload("res://assets/sprites/ui/heart_full.png")
const TEX_HEART_EMPTY: Texture2D = preload("res://assets/sprites/ui/heart_empty.png")


func _ready() -> void:
	layer = 30
	_build_hud()
	Events.player_hit.connect(_on_hp_updated)
	Events.player_healed.connect(_on_hp_updated)
	Events.timer_changed.connect(_on_timer_changed)
	Events.upgrade_picked.connect(_on_upgrade_picked)
	Events.item_obtained.connect(_on_item_obtained)
	Events.boss_hp_changed.connect(_on_boss_hp_changed)
	Events.boss_phase_changed.connect(_on_boss_phase_changed)
	Events.request_screen_flash.connect(_on_screen_flash)
	Events.radar_distance_updated.connect(_on_radar_updated)
	_refresh_hp(GameState.current_hp, GameState.max_hp)
	_refresh_upgrades_list()


func _process(delta: float) -> void:
	_clock_gear.rotation += delta * 1.6
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		if player.has_method("get_dash_cooldown_ratio"):
			_dash_cd_bar.value = float(player.get_dash_cooldown_ratio()) * 100.0
		if player.has_method("get_pulse_cooldown_ratio"):
			var pratio: float = float(player.get_pulse_cooldown_ratio())
			_pulse_cd_bar.value = pratio * 100.0
			var secs_left: float = float(player.get_pulse_seconds_left())
			if secs_left > 0.05:
				_pulse_cd_label.text = "%s%.0fs" % [_pulse_prefix(), ceil(secs_left)]
				_pulse_cd_label.add_theme_color_override("font_color", Color("#8fb8c4"))
			else:
				_pulse_cd_label.text = _pulse_prefix() + "PRONTO"
				_pulse_cd_label.add_theme_color_override("font_color", Color("#f2c35b"))


func _build_hud() -> void:
	# Barra superior: moldura de latão (kit pixel art) com placa central do relógio
	var top_bar := NinePatchRect.new()
	top_bar.texture = load("res://assets/sprites/ui/kit/panel_hud.png")
	_set_patch(top_bar, 6)
	top_bar.position = Vector2(-4.0, -4.0)
	top_bar.size = Vector2(488.0, 34.0)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	var clock_plate := NinePatchRect.new()
	clock_plate.texture = load("res://assets/sprites/ui/kit/panel_focus.png")
	_set_patch(clock_plate, 6)
	clock_plate.position = Vector2(132.0, -4.0)
	clock_plate.size = Vector2(216.0, 39.0) # mais alta que a barra: título + relógio cabem dentro da moldura
	clock_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clock_plate)

	_clock_gear = TextureRect.new()
	_clock_gear.texture = load("res://assets/sprites/ui/golden_gear.png")
	_clock_gear.position = Vector2(140.0, 7.0)
	_clock_gear.size = Vector2(20.0, 20.0)
	_clock_gear.pivot_offset = Vector2(10.0, 10.0)
	_clock_gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clock_gear)

	_hearts_box = HBoxContainer.new()
	_hearts_box.position = Vector2(8.0, 8.0)
	_hearts_box.add_theme_constant_override("separation", 2)
	add_child(_hearts_box)

	var center_vbox := VBoxContainer.new()
	center_vbox.position = Vector2(0.0, 1.0)
	center_vbox.size = Vector2(480.0, 30.0)
	center_vbox.add_theme_constant_override("separation", -3)
	center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_vbox)

	_clock_title = Label.new()
	_clock_title.text = "TEMPO ATÉ A ESTAÇÃO ZERO"
	_clock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock_title.add_theme_font_size_override("font_size", 10)
	_clock_title.add_theme_color_override("font_color", Color("#8fb8c4"))
	center_vbox.add_child(_clock_title)

	_clock_label = Label.new()
	_clock_label.text = "06:30"
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock_label.add_theme_font_size_override("font_size", 10)
	_clock_label.add_theme_color_override("font_color", Color("#fff1c9"))
	center_vbox.add_child(_clock_label)

	_radar_label = Label.new()
	_radar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_radar_label.position = Vector2(160.0, 36.0)
	_radar_label.size = Vector2(160.0, 14.0)
	_radar_label.visible = false
	_radar_label.add_theme_font_size_override("font_size", 10)
	_radar_label.add_theme_color_override("font_color", Color("#f2c35b"))
	add_child(_radar_label)

	_wagon_label = Label.new()
	_wagon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_wagon_label.position = Vector2(8.0, 31.0)
	_wagon_label.size = Vector2(260.0, 12.0)
	_wagon_label.add_theme_font_size_override("font_size", 10)
	_wagon_label.add_theme_color_override("font_color", Color("#c98a3c"))
	add_child(_wagon_label)

	var dash_lbl := Label.new()
	Settings.bind_prompt_text(dash_lbl, "DASH" if Settings.touch_mode else "{dash} DASH")
	dash_lbl.position = Vector2(354.0, 6.0)
	dash_lbl.add_theme_font_size_override("font_size", 10)
	dash_lbl.add_theme_color_override("font_color", Color("#fff1c9"))
	add_child(dash_lbl)

	_dash_cd_bar = _make_bar(Color("#f2c35b"))
	_dash_cd_bar.position = Vector2(354.0, 22.0)
	_dash_cd_bar.size = Vector2(54.0, 6.0)
	_dash_cd_bar.value = 100.0
	add_child(_dash_cd_bar)

	_pulse_cd_label = Label.new()
	_pulse_cd_label.text = _pulse_prefix() + "PRONTO"
	_pulse_cd_label.position = Vector2(414.0, 6.0)
	_pulse_cd_label.add_theme_font_size_override("font_size", 10)
	_pulse_cd_label.add_theme_color_override("font_color", Color("#f2c35b"))
	add_child(_pulse_cd_label)

	_pulse_cd_bar = _make_bar(Color("#8fb8c4"))
	_pulse_cd_bar.position = Vector2(414.0, 22.0)
	_pulse_cd_bar.size = Vector2(60.0, 6.0)
	_pulse_cd_bar.value = 100.0
	add_child(_pulse_cd_bar)

	_boss_bar_container = Control.new()
	_boss_bar_container.position = Vector2(120.0, 36.0)
	_boss_bar_container.size = Vector2(240.0, 22.0)
	_boss_bar_container.visible = false
	add_child(_boss_bar_container)

	_boss_name_label = Label.new()
	_boss_name_label.text = "O MAQUINISTA — FASE 1/3"
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.position = Vector2(0.0, 0.0)
	_boss_name_label.size = Vector2(240.0, 12.0)
	_boss_name_label.add_theme_font_size_override("font_size", 10)
	_boss_name_label.add_theme_color_override("font_color", Color("#fff1c9"))
	_boss_bar_container.add_child(_boss_name_label)

	_boss_bar_ghost = _make_bar(Color("#fff1c9"))
	_boss_bar_ghost.position = Vector2(0.0, 12.0)
	_boss_bar_ghost.size = Vector2(240.0, 7.0)
	_boss_bar_ghost.value = 100.0
	_boss_bar_container.add_child(_boss_bar_ghost)

	_boss_bar_fill = _make_bar(Color("#b3342e"))
	_boss_bar_fill.position = Vector2(0.0, 12.0)
	_boss_bar_fill.size = Vector2(240.0, 7.0)
	_boss_bar_fill.value = 100.0
	# só o preenchimento: o fundo já vem da barra fantasma
	_boss_bar_fill.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_boss_bar_container.add_child(_boss_bar_fill)

	_upgrades_box = HBoxContainer.new()
	_upgrades_box.position = Vector2(6.0, 249.0) # selos de 18px de altura: terminam em 267, dentro dos 270
	_upgrades_box.add_theme_constant_override("separation", 3)
	add_child(_upgrades_box)

	_upgrade_tooltip = PanelContainer.new()
	_upgrade_tooltip.position = Vector2(8.0, 206.0)
	_upgrade_tooltip.visible = false
	_upgrade_tooltip.add_theme_stylebox_override("panel", Settings.make_ui_style("panel_small"))
	add_child(_upgrade_tooltip)

	_upgrade_tooltip_lbl = Label.new()
	_upgrade_tooltip_lbl.add_theme_font_size_override("font_size", 10)
	_upgrade_tooltip_lbl.add_theme_color_override("font_color", Color("#fff1c9"))
	_upgrade_tooltip.add_child(_upgrade_tooltip_lbl)

	_tip_label = Label.new()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tip_label.position = Vector2(140.0, 233.0) # linha própria, acima dos selos de upgrade
	_tip_label.size = Vector2(332.0, 14.0)
	_tip_label.add_theme_font_size_override("font_size", 10)
	_tip_label.add_theme_color_override("font_color", Color("#dce9ee"))
	if Settings.touch_mode:
		_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_tip_label.position = Vector2(100.0, 221.0)
		_tip_label.size = Vector2(372.0, 26.0)
	add_child(_tip_label)

	_banner_panel = PanelContainer.new()
	_banner_panel.position = Vector2(90.0, 52.0)
	_banner_panel.custom_minimum_size = Vector2(300.0, 24.0)
	_banner_panel.visible = false
	_banner_panel.add_theme_stylebox_override("panel", Settings.make_ui_style("panel_focus"))
	add_child(_banner_panel)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 10)
	_banner_label.add_theme_color_override("font_color", Color("#fff1c9"))
	_banner_panel.add_child(_banner_label)

	_vignette_rect = TextureRect.new()
	_vignette_rect.texture = load("res://assets/sprites/ui/kit/danger_vignette.png")
	_vignette_rect.modulate.a = 0.0
	_vignette_rect.position = Vector2.ZERO
	_vignette_rect.size = Vector2(480.0, 270.0)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette_rect)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_rect.position = Vector2.ZERO
	_flash_rect.size = Vector2(480.0, 270.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)


func set_wagon_title(title_text: String) -> void:
	_base_wagon_title = title_text
	_update_wagon_header_label()


func set_wave_info(current_wave: int, total_waves: int) -> void:
	if current_wave <= 0 or total_waves <= 0:
		_wave_text = ""
	else:
		_wave_text = " · ONDA %d/%d" % [current_wave, total_waves]
	_update_wagon_header_label()


func _update_wagon_header_label() -> void:
	var key_str: String = " [CHAVE]" if GameState.has_cargo_key else ""
	_wagon_label.text = _base_wagon_title + _wave_text + key_str


func _pulse_prefix() -> String:
	if Settings.touch_mode and not Settings.using_gamepad:
		return ""
	return "[%s] " % Settings.get_prompt("ability")


# Aceita marcadores {acao} (ex.: "{interact}"), trocados pela tecla ou botão do controle em uso
func set_contextual_tip(text_str: String) -> void:
	Settings.bind_prompt_text(_tip_label, text_str)


func show_boss_bar(visible_flag: bool) -> void:
	_boss_bar_container.visible = visible_flag


func _on_hp_updated(cur: int, max_v: int) -> void:
	_refresh_hp(cur, max_v)


func _refresh_hp(cur: int, max_v: int) -> void:
	for child in _hearts_box.get_children():
		child.queue_free()
	for i in range(max_v):
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(12.0, 12.0)
		tex_rect.texture = TEX_HEART_FULL if i < cur else TEX_HEART_EMPTY
		_hearts_box.add_child(tex_rect)
	_vignette_rect.modulate.a = 0.55 if cur <= 1 else 0.0


func _on_timer_changed(secs: float) -> void:
	_clock_label.text = TrainClock.format_time()
	if secs < 15.0:
		_clock_label.add_theme_color_override("font_color", Color("#ff3d6e"))
		_vignette_rect.modulate.a = 0.7
	elif secs < 60.0:
		_clock_label.add_theme_color_override("font_color", Color("#b3342e"))
	elif secs < 180.0:
		_clock_label.add_theme_color_override("font_color", Color("#f2c35b"))
	else:
		_clock_label.add_theme_color_override("font_color", Color("#fff1c9"))


func _on_upgrade_picked(upg_id: String, _lvl: int) -> void:
	_refresh_upgrades_list()
	var info: Dictionary = GameState.get_upgrade_info(upg_id)
	_show_banner("MELHORIA OBTIDA: %s" % String(info.get("name", upg_id)))


func _on_item_obtained(item_name: String) -> void:
	_update_wagon_header_label()
	_show_banner("ITEM OBTIDO: %s" % item_name)


func _on_boss_phase_changed(new_phase: int) -> void:
	_boss_name_label.text = "O MAQUINISTA — FASE %d/3" % new_phase
	if new_phase == 2:
		_boss_bar_fill.self_modulate = Color("#ff6b3d")
		_show_banner("⚠ FASE 2: LOCOMOTIVA EM SOBRECARGA! ⚠")
	elif new_phase == 3:
		_boss_bar_fill.self_modulate = Color("#ff3d6e")
		_show_banner("⚠ FASE 3: ESTAÇÃO ZERO — PULSO PRONTO! ⚠")


func _show_banner(msg: String) -> void:
	_banner_label.text = msg
	_banner_panel.visible = true
	_banner_panel.position.x = 180.0
	var tw := create_tween()
	tw.tween_property(_banner_panel, "position:x", 90.0, 0.22)
	tw.tween_interval(1.6)
	tw.tween_callback(func() -> void: _banner_panel.visible = false)


func _refresh_upgrades_list() -> void:
	for child in _upgrades_box.get_children():
		child.queue_free()

	var keys: Array = GameState.upgrades.keys()
	var max_visible: int = mini(keys.size(), 6)
	for idx in range(max_visible):
		var uid: String = String(keys[idx])
		var lvl: int = int(GameState.upgrades[uid])
		var info: Dictionary = GameState.get_upgrade_info(uid)

		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", Settings.make_ui_style("panel_small"))

		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		badge.add_child(h)

		var icon_path: String = "res://assets/sprites/ui/icon_%s.png" % uid
		if ResourceLoader.exists(icon_path):
			var tex_rect := TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(12.0, 12.0)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.texture = load(icon_path)
			h.add_child(tex_rect)

		var lbl := Label.new()
		lbl.text = "x%d" % lvl
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color("#f2c35b"))
		h.add_child(lbl)

		badge.mouse_entered.connect(func() -> void:
			_upgrade_tooltip_lbl.text = "%s (Nv %d)\n%s" % [
				String(info.get("name", uid)), lvl, String(info.get("description", ""))
			]
			_upgrade_tooltip.visible = true
		)
		badge.mouse_exited.connect(func() -> void:
			_upgrade_tooltip.visible = false
		)
		_upgrades_box.add_child(badge)

	if keys.size() > 6:
		var more_lbl := Label.new()
		Settings.bind_prompt_text(more_lbl, "+%d (Ver no {pause})" % (keys.size() - 6))
		more_lbl.add_theme_font_size_override("font_size", 10)
		more_lbl.add_theme_color_override("font_color", Color("#8fb8c4"))
		_upgrades_box.add_child(more_lbl)


func _on_boss_hp_changed(cur: float, max_v: float) -> void:
	show_boss_bar(true)
	var ratio: float = clampf(cur / maxf(1.0, max_v), 0.0, 1.0)
	_boss_bar_fill.value = ratio * 100.0
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(_boss_bar_ghost, "value", ratio * 100.0, 0.25)


func _on_screen_flash(duration: float) -> void:
	if Settings.reduce_flashes:
		return
	_flash_rect.color.a = 0.85
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration)


func _on_radar_updated(dist: float) -> void:
	if dist > 250.0 or dist < 0.0:
		_radar_label.visible = false
		return
	_radar_label.visible = true
	var segments: int = clampi(int(remap(dist, 250.0, 30.0, 1.0, 5.0)), 1, 5)
	_radar_label.text = "RADAR BOMBA: " + "▮".repeat(segments) + "▯".repeat(5 - segments)


func _set_patch(n: NinePatchRect, m: int) -> void:
	n.patch_margin_left = m
	n.patch_margin_right = m
	n.patch_margin_top = m
	n.patch_margin_bottom = m


# Barra pixel art: moldura de latão + preenchimento branco tingido pela cor do recurso
func _make_bar(fill_col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	var back := StyleBoxTexture.new()
	back.texture = load("res://assets/sprites/ui/kit/bar_back.png")
	back.texture_margin_left = 2.0
	back.texture_margin_right = 2.0
	back.texture_margin_top = 2.0
	back.texture_margin_bottom = 2.0
	var fill := StyleBoxTexture.new()
	fill.texture = load("res://assets/sprites/ui/kit/bar_fill.png")
	fill.modulate_color = fill_col
	fill.expand_margin_top = -2.0
	fill.expand_margin_bottom = -2.0
	fill.expand_margin_left = -2.0
	fill.expand_margin_right = -2.0
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar
