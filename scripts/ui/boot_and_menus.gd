extends Control

@export var screen_type: String = "boot"

var _anim_t: float = 0.0
var _smoke_puffs: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
const SKY_TEX: Array[Texture2D] = [
	preload("res://assets/sprites/menu/sky_night.png"),
	preload("res://assets/sprites/menu/sky_day.png"),
	preload("res://assets/sprites/menu/sky_sunset.png"),
]
const CLOUD_TEX: Array[Texture2D] = [
	preload("res://assets/sprites/menu/cloud_0.png"),
	preload("res://assets/sprites/menu/cloud_1.png"),
	preload("res://assets/sprites/menu/cloud_2.png"),
]
const POLE_TEX: Texture2D = preload("res://assets/sprites/menu/telegraph_pole.png")
const EMBER_TEX: Texture2D = preload("res://assets/sprites/fx/ember.png")
const BALLAST_TEX: Texture2D = preload("res://assets/sprites/train/ballast_tile.png")
const SHUTTER_TEX: Texture2D = preload("res://assets/sprites/menu/shutter.png")
const NAMEPLATE_TEX: Texture2D = preload("res://assets/sprites/ui/kit/nameplate.png")
const LAMP_TEX: Texture2D = preload("res://assets/sprites/menu/station_lamp.png")
const PLATFORM_TEX: Texture2D = preload("res://assets/sprites/menu/platform_tile.png")
const CABIN_BG_TEX: Texture2D = preload("res://assets/sprites/backgrounds/wagon_5.png")
const BAR_FILL_TEX: Texture2D = preload("res://assets/sprites/ui/kit/bar_fill.png")
const BEAM_TEX: Texture2D = preload("res://assets/sprites/train/headlight_beam.png")
const COUPLER_TEX: Texture2D = preload("res://assets/sprites/train/coupler.png")
var _ui_gear_sprites: Array[Sprite2D] = []
var _gauge_needle: Sprite2D
var _tex_moon: Texture2D
var _tex_sun_day: Texture2D
var _tex_sun_sunset: Texture2D

# Estado da Animação de Boot
var _boot_progress: float = 0.0
var _boot_clang_done: bool = false
var _boot_whistle_done: bool = false

# Estado da Cutscene de Introdução
var _intro_stage: int = 0
var _intro_sub_t: float = 0.0
var _intro_teo_x: float = 24.0
var _intro_teo_interior_pos: Vector2 = Vector2(218.0, 96.0)
var _intro_boarding_alpha: float = 1.0
var _intro_door_close_ratio: float = 0.0
var _intro_train_x: float = 0.0
var _intro_door_open: bool = true
var _intro_skip_hold: float = 0.0
var _intro_skipping: bool = false
var _intro_teo_spr: Sprite2D
var _intro_wagon_bg: Sprite2D
var _intro_bomb_spr: Sprite2D
var _intro_bomb_visor_lbl: Label
var _skip_box_style: StyleBoxTexture
var _intro_receiver_lbl: Label

# Estado do Menu de Opções e Remapeamento de Teclas
var _opt_tabs: Array[Control] = []
var _opt_tab_btns: Array[Button] = []
var _current_opt_tab: int = 0
var _btn_master_vol: Button
var _btn_music_vol: Button
var _btn_sfx_vol: Button
var _btn_fs: Button
var _btn_shake: Button
var _btn_flash: Button
var _btn_aim: Button
var _btn_hb: Button
var _btn_dmg: Button
var _btn_hc: Button
var _btn_vib: Button
var _keybind_buttons: Dictionary = {}
var _waiting_remap_action: String = ""
var _remap_status_lbl: Label
var _pad_bind_buttons: Dictionary = {}
var _waiting_pad_action: String = ""
var _pad_status_lbl: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_custom_mouse_cursor(null)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(480.0, 270.0)
	custom_minimum_size = Vector2(480.0, 270.0)

	_init_sky_and_smoke()

	match screen_type:
		"boot":
			AudioManager.set_train_ambience(true, 1.0)
			_build_boot()
		"main_menu":
			AudioManager.set_train_ambience(true, 1.0)
			_build_main_menu()
		"difficulty":
			AudioManager.set_train_ambience(true, 1.0)
			_build_difficulty()
		"intro":
			AudioManager.set_train_ambience(true, 0.9)
			_build_intro()
		"options":
			AudioManager.set_train_ambience(true, 1.0)
			_build_options()


func _init_sky_and_smoke() -> void:
	if ResourceLoader.exists("res://assets/sprites/ui/sky_moon.png"):
		_tex_moon = load("res://assets/sprites/ui/sky_moon.png")
	if ResourceLoader.exists("res://assets/sprites/ui/sky_sun_day.png"):
		_tex_sun_day = load("res://assets/sprites/ui/sky_sun_day.png")
	if ResourceLoader.exists("res://assets/sprites/ui/sky_sun_sunset.png"):
		_tex_sun_sunset = load("res://assets/sprites/ui/sky_sun_sunset.png")

	_smoke_puffs.clear()
	for i in range(36):
		var age_ratio: float = float(i) / 36.0
		_smoke_puffs.append({
			"age": age_ratio * 2.4,
			"max_age": 2.4,
			"phase": float(i) * 1.37,
			"vy": randf_range(16.0, 26.0),
			"vx": randf_range(68.0, 88.0),
			"base_r": randf_range(3.5, 5.5)
		})

	_embers.clear()
	for i in range(10):
		_embers.append({
			"age": randf() * 1.1,
			"max_age": randf_range(0.8, 1.3),
			"vx": randf_range(75.0, 115.0),
			"vy": randf_range(22.0, 42.0),
			"phase": float(i) * 2.1
		})


func _process(delta: float) -> void:
	_anim_t += delta
	var gear_frame: int = int(_anim_t * 6.0) % 4
	if _gauge_needle != null:
		_gauge_needle.rotation = -PI * 0.6 + sin(_anim_t * 3.5) * 0.75
	for gs in _ui_gear_sprites:
		if is_instance_valid(gs):
			gs.frame = gear_frame

	if screen_type == "boot":
		_boot_progress += delta
		if _boot_progress >= 0.65 and not _boot_clang_done:
			_boot_clang_done = true
			AudioManager.play_sfx("clang")
			AudioManager.play_sfx("steam_pulse")
		if _boot_progress >= 1.25 and not _boot_whistle_done:
			_boot_whistle_done = true
			AudioManager.play_sfx("whistle")
		queue_redraw()
	elif screen_type in ["main_menu", "difficulty", "options"]:
		_update_smoke_system(delta)
		queue_redraw()
	elif screen_type == "intro":
		_intro_sub_t += delta
		_update_intro_sprites()
		_process_intro_skip(delta)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if _waiting_pad_action != "":
		_handle_pad_remap_input(event)
		return
	if _waiting_remap_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		get_viewport().set_input_as_handled()
		if kev.keycode == KEY_ESCAPE:
			_waiting_remap_action = ""
			AudioManager.play_sfx("ui_hover")
			_refresh_keybind_buttons()
			return
		Settings.remap_action_key(_waiting_remap_action, int(kev.keycode))
		_waiting_remap_action = ""
		AudioManager.play_sfx("ui_confirm")
		_refresh_keybind_buttons()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# esperando uma TECLA: no controle, B ou Start só cancelam a espera
		get_viewport().set_input_as_handled()
		if event is InputEventJoypadButton and event.pressed and (event.is_action("cancel") or event.is_action("pause")):
			_waiting_remap_action = ""
			AudioManager.play_sfx("ui_hover")
			_refresh_keybind_buttons()


# Esperando um BOTÃO do controle: o próximo botão/gatilho válido vira o novo bind; Start ou ESC cancelam
func _handle_pad_remap_input(event: InputEvent) -> void:
	var cancel: bool = (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE) \
		or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START)
	if event is InputEventJoypadButton or event is InputEventJoypadMotion or cancel:
		get_viewport().set_input_as_handled()
	if cancel:
		_waiting_pad_action = ""
		AudioManager.play_sfx("ui_hover")
		_refresh_pad_bind_buttons()
		return
	var code: int = Settings.pad_code_from_event(event)
	if code == -1:
		return # D-pad, analógicos, solturas: ignorados
	Settings.remap_action_pad(_waiting_pad_action, code)
	_waiting_pad_action = ""
	AudioManager.play_sfx("ui_confirm")
	_refresh_pad_bind_buttons()


func _update_intro_sprites() -> void:
	if _intro_teo_spr == null:
		return
	if _intro_stage == 1:
		_intro_wagon_bg.visible = false
		_intro_bomb_spr.visible = false
		_intro_teo_spr.visible = (_intro_boarding_alpha > 0.02)
		var enter_scale: float = lerpf(0.92, 1.0, _intro_boarding_alpha)
		_intro_teo_spr.scale = Vector2(enter_scale, enter_scale)
		_intro_teo_spr.modulate = Color(1.0, 1.0, 1.0, _intro_boarding_alpha)
		var step_up: float = clampf((_intro_teo_x - 122.0) * 0.42, 0.0, 6.0)
		_intro_teo_spr.position = Vector2(round(_intro_teo_x), round(194.0 - step_up))
		# Linhas do teo_sheet_8dir: idle 9+dir, walk 17+dir (dir 2 = leste, 4 = norte)
		if _intro_teo_x < 128.0:
			_intro_teo_spr.frame_coords = Vector2i(int(_anim_t * 10.0) % 6, 17 + 2)
		else:
			_intro_teo_spr.frame_coords = Vector2i(int(_anim_t * 10.0) % 6, 17 + 4)
	elif _intro_stage == 2:
		_intro_wagon_bg.visible = true
		_intro_wagon_bg.modulate = Color.WHITE
		_intro_bomb_spr.visible = false
		_intro_teo_spr.visible = true
		_intro_teo_spr.modulate = Color.WHITE
		_intro_teo_spr.scale = Vector2(1.0, 1.0)
		_intro_teo_spr.position = _intro_teo_interior_pos.round()
		_intro_teo_spr.frame_coords = Vector2i(int(_anim_t * 5.0) % 4, 9 + 0)
	elif _intro_stage == 3:
		_intro_wagon_bg.visible = true
		var flicker: bool = (_intro_sub_t < 0.85 and int(_intro_sub_t * 12.0) % 2 == 0)
		_intro_wagon_bg.modulate = Color(0.25, 0.15, 0.20, 1.0) if flicker else Color(1.0, 0.65, 0.65, 1.0)
		_intro_bomb_spr.visible = true
		_intro_bomb_spr.scale = Vector2(0.42, 0.42)
		_intro_bomb_spr.position = Vector2(218.0, 96.0)
		_intro_bomb_visor_lbl.text = TrainClock.format_time()
		_intro_teo_spr.visible = true
		_intro_teo_spr.modulate = Color.WHITE
		_intro_teo_spr.scale = Vector2(1.0, 1.0)
		_intro_teo_spr.position = _intro_teo_interior_pos.round()
		var walking_inside: bool = _intro_teo_interior_pos.distance_to(Vector2(196.0, 114.0)) > 1.5
		if walking_inside:
			_intro_teo_spr.frame_coords = Vector2i(int(_anim_t * 10.0) % 6, 17 + 7) # sudoeste
		else:
			_intro_teo_spr.frame_coords = Vector2i(int(_anim_t * 6.0) % 4, 9 + 3) # olha para a bomba (nordeste)
	elif _intro_stage == 4:
		_intro_receiver_lbl.visible = true
		_intro_wagon_bg.visible = false
		_intro_teo_spr.visible = false
		_intro_bomb_spr.visible = true
		_intro_bomb_spr.scale = Vector2(2.4, 2.4)
		_intro_bomb_spr.position = Vector2(240.0, 108.0)
		if _intro_sub_t < 0.9:
			var fake_m: int = int(_intro_sub_t * 37.0) % 10
			var fake_s: int = int(_intro_sub_t * 83.0) % 60
			_intro_bomb_visor_lbl.text = "0%d:%02d" % [fake_m, fake_s]
		else:
			_intro_bomb_visor_lbl.text = TrainClock.format_time()


func _process_intro_skip(delta: float) -> void:
	if _intro_skipping:
		return
	if Settings.is_skip_held():
		_intro_skip_hold += delta
		if _intro_skip_hold >= 0.8:
			_intro_skipping = true
			AudioManager.set_dialogue_ducking(false)
			AudioManager.play_sfx("ui_confirm")
			SceneRouter.goto_scene("res://scenes/levels/Level_Wagon1.tscn")
	else:
		_intro_skip_hold = maxf(0.0, _intro_skip_hold - delta * 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_remap_action != "" or _waiting_pad_action != "":
		return
	if screen_type == "boot" and (event.is_action_pressed("confirm") or event.is_action_pressed("cancel")):
		SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn")
		return

	if screen_type in ["options", "difficulty"]:
		if event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			AudioManager.play_sfx("ui_confirm")
			SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn")
			return


	if screen_type == "options" and (event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next")):
		get_viewport().set_input_as_handled()
		var step_dir: int = -1 if event.is_action_pressed("tab_prev") else 1
		AudioManager.play_sfx("ui_hover")
		_switch_options_tab(posmod(_current_opt_tab + step_dir, _opt_tabs.size()))
		_focus_first_button(_opt_tabs[_current_opt_tab])
		return


func _update_smoke_system(delta: float) -> void:
	for puff in _smoke_puffs:
		puff["age"] = float(puff["age"]) + delta
		if float(puff["age"]) >= float(puff["max_age"]):
			puff["age"] = fmod(float(puff["age"]), float(puff["max_age"]))
			puff["vy"] = randf_range(16.0, 26.0)
			puff["vx"] = randf_range(68.0, 88.0)

	for emb in _embers:
		emb["age"] = float(emb["age"]) + delta
		if float(emb["age"]) >= float(emb["max_age"]):
			emb["age"] = 0.0
			emb["vx"] = randf_range(75.0, 115.0)
			emb["vy"] = randf_range(22.0, 42.0)


const BG_MOUNTAINS_TEX: Texture2D = preload("res://assets/sprites/menu/bg_mountains.png")
const BG_CITY_BACK_TEX: Texture2D = preload("res://assets/sprites/menu/bg_city_back.png")
const BG_CITY_FRONT_TEX: Texture2D = preload("res://assets/sprites/menu/bg_city_front.png")

# Camadas já espelhadas no PNG (960px): repetir lado a lado emenda sem costura
func _draw_parallax_layer(tex: Texture2D, y: float, scroll: float, tint: Color) -> void:
	var w: float = float(tex.get_width())
	var x0: float = -round(fmod(scroll, w))
	for i in range(3):
		draw_texture(tex, Vector2(x0 + float(i) * w, y), tint)


# ==============================================================================
# TREM EM SPRITES PIXELLAB (locomotiva + vagões com janelas acesas, sem passageiros)
# ==============================================================================
const TRAIN_WAGON_TEX: Texture2D = preload("res://assets/sprites/train/wagon.png")
const TRAIN_LOCO_ANIM_TEX: Texture2D = preload("res://assets/sprites/train/locomotive_anim.png") # 9 quadros 112x64
const TRAIN_BOGIE_TEX: Texture2D = preload("res://assets/sprites/train/wagon_bogie.png") # 4 quadros 26x12
const STEAM_PUFF_TEX: Texture2D = preload("res://assets/sprites/fx/steam_puff.png") # 8 estágios 32x32
const RAIL_TILE_TEX: Texture2D = preload("res://assets/sprites/train/rail_tile.png") # 32x12, emenda sem costura
const TRAIN_WAGON_DOOR_TEX: Texture2D = preload("res://assets/sprites/train/wagon_door.png")

func _draw_rail_row(y: float, scroll: float) -> void:
	var x0: float = -round(fmod(scroll, 32.0))
	for i in range(17):
		draw_texture(RAIL_TILE_TEX, Vector2(x0 + float(i) * 32.0, y))


func _draw_steampunk_train_composition(offset_x: float, base_y: float, bob: float, wheel_rot: float,
		show_boarding_door: bool = false, door_close_ratio: float = 1.0, light_intensity: float = 1.0) -> void:
	var lit := Color(1.0, 1.0, 1.0).lerp(Color(0.75, 0.8, 0.9), 1.0 - clampf(light_intensity, 0.0, 1.0))
	var anim_frame: int = int(absf(wheel_rot) / 1.5)
	var wagon_y: float = round(base_y - 52.0 + bob)

	for w in range(3):
		var wx: float = round(offset_x + 34.0 + float(w) * 102.0)
		# Engate entre vagões
		draw_texture(COUPLER_TEX, Vector2(wx + 94.0, wagon_y + 34.0))
		var wy: float = wagon_y
		draw_texture(TRAIN_WAGON_TEX, Vector2(wx, wy), lit)
		if show_boarding_door and w == 0:
			var open_a: float = 1.0 - clampf(door_close_ratio, 0.0, 1.0)
			if open_a > 0.01:
				draw_texture(TRAIN_WAGON_DOOR_TEX, Vector2(wx, wy), Color(lit.r, lit.g, lit.b, open_a))
		# Truques com rodas em pixel art (4 quadros de giro)
		var bogie_frame: int = anim_frame % 4
		for bogie_x in [wx + 18.0, wx + 76.0]:
			draw_texture_rect_region(TRAIN_BOGIE_TEX, Rect2(bogie_x - 13.0, round(base_y - 11.0), 26.0, 12.0), Rect2(bogie_frame * 26.0, 0.0, 26.0, 12.0), lit)

	var lx: float = round(offset_x + 340.0)
	var ly: float = round(base_y - 62.0 + bob)
	var lf: int = anim_frame % 9
	draw_texture_rect_region(TRAIN_LOCO_ANIM_TEX, Rect2(lx, ly, 112.0, 64.0), Rect2(lf * 112.0, 0.0, 112.0, 64.0), lit)

	# Facho do farol (cone pontilhado em pixel art)
	draw_texture(BEAM_TEX, Vector2(lx + 92.0, ly + 20.0 - 36.0), Color(1.0, 1.0, 1.0, clampf(0.35 + 0.65 * light_intensity, 0.0, 1.0)))


# ==============================================================================
# ARQUITETURA URBANA COM PERSPECTIVA DE PROFUNDIDADE E ZERO FLICKERING
# ==============================================================================
func _draw_boot_splash() -> void:
	# Portas de ferro rebitadas se fecham; ao travar, clarão e a placa com a locomotiva aparece
	draw_texture(SKY_TEX[0], Vector2.ZERO, Color(0.5, 0.5, 0.6))
	var close_ratio: float = clampf(_boot_progress / 0.65, 0.0, 1.0)
	var ease_close: float = 1.0 - pow(1.0 - close_ratio, 3.0)
	var left_x: float = round(-240.0 + 240.0 * ease_close)
	draw_texture(SHUTTER_TEX, Vector2(left_x, 0.0))
	# porta direita: a mesma arte espelhada
	draw_set_transform(Vector2(480.0 - left_x, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture(SHUTTER_TEX, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _boot_progress >= 0.65:
		var post_t: float = _boot_progress - 0.65
		if post_t < 0.30:
			draw_texture(SKY_TEX[1], Vector2.ZERO, Color(1.0, 1.0, 1.0, (1.0 - post_t / 0.30) * 0.6))
		var boot_frame: int = int(post_t * 10.0) % 9
		draw_texture_rect_region(TRAIN_LOCO_ANIM_TEX, Rect2(184.0, 70.0, 112.0, 64.0), Rect2(boot_frame * 112.0, 0.0, 112.0, 64.0))
		draw_texture(BEAM_TEX, Vector2(184.0 + 92.0, 70.0 + 20.0 - 36.0))
		_draw_rail_row(133.0, post_t * 60.0)
		draw_texture(NAMEPLATE_TEX, Vector2(144.0, 150.0))


func _draw() -> void:
	if screen_type == "boot":
		_draw_boot_splash()
		return
	if screen_type == "intro":
		_draw_intro_cutscene()
		return
	if not (screen_type in ["main_menu", "difficulty", "options"]):
		return

	var cycle_duration: float = 18.0
	var phase_f: float = fmod(_anim_t / cycle_duration, 3.0)
	var p_idx: int = int(floor(phase_f))
	var frac: float = phase_f - float(p_idx)
	var blend: float = smoothstep(0.65, 1.0, frac)

	var next_idx: int = (p_idx + 1) % 3
	var light_weights: Array[float] = [1.0, 0.15, 0.80]
	var city_light: float = lerpf(light_weights[p_idx], light_weights[next_idx], blend)

	# PLANO Z0: Céu (noite / dia / entardecer) em crossfade
	draw_texture(SKY_TEX[p_idx], Vector2.ZERO)
	if blend > 0.0:
		draw_texture(SKY_TEX[next_idx], Vector2.ZERO, Color(1.0, 1.0, 1.0, blend))

	var moon_alpha: float = 0.0
	var moon_y: float = 42.0
	var sun_alpha: float = 0.0
	var sun_y: float = 42.0
	var sunset_ratio: float = 0.0

	if p_idx == 0:
		if frac < 0.15:
			moon_alpha = smoothstep(0.0, 0.15, frac)
			moon_y = lerpf(78.0, 42.0, moon_alpha)
		elif frac <= 0.72:
			moon_alpha = 1.0
			moon_y = 42.0
		else:
			moon_alpha = 1.0 - smoothstep(0.72, 0.98, frac)
			moon_y = lerpf(42.0, 92.0, 1.0 - moon_alpha)
	elif p_idx == 1:
		if frac < 0.20:
			sun_alpha = smoothstep(0.02, 0.20, frac)
			sun_y = lerpf(96.0, 42.0, sun_alpha)
		else:
			sun_alpha = 1.0
			sun_y = lerpf(42.0, 68.0, blend)
		sunset_ratio = blend
	else:
		sunset_ratio = 1.0
		if frac <= 0.70:
			sun_alpha = 1.0
			sun_y = lerpf(68.0, 98.0, frac / 0.70)
		else:
			sun_alpha = 1.0 - smoothstep(0.70, 0.98, frac)
			sun_y = lerpf(98.0, 128.0, 1.0 - sun_alpha)

	var celestial_pos := Vector2(408.0, round(moon_y if moon_alpha > 0.0 else sun_y))

	if moon_alpha > 0.01 and _tex_moon != null:
		var m_rect := Rect2(celestial_pos - Vector2(24.0, 24.0), Vector2(48.0, 48.0))
		draw_texture_rect(_tex_moon, m_rect, false, Color(1.0, 1.0, 1.0, moon_alpha))
	elif sun_alpha > 0.01:
		var s_rect := Rect2(celestial_pos - Vector2(24.0, 24.0), Vector2(48.0, 48.0))
		if _tex_sun_day != null and (1.0 - sunset_ratio) > 0.01:
			draw_texture_rect(_tex_sun_day, s_rect, false, Color(1.0, 1.0, 1.0, sun_alpha * (1.0 - sunset_ratio)))
		if _tex_sun_sunset != null and sunset_ratio > 0.01:
			draw_texture_rect(_tex_sun_sunset, s_rect, false, Color(1.0, 1.0, 1.0, sun_alpha * sunset_ratio))

		for c in range(6):
			var ctex: Texture2D = CLOUD_TEX[c % 3]
			var cx: float = fmod(float(c * 97) - _anim_t * (5.0 + float(c % 3)), 560.0)
			if cx < -60.0:
				cx += 560.0
			var ccol: Color = Color.WHITE.lerp(Color("#f2c35b"), sunset_ratio * 0.6)
			ccol.a = sun_alpha * 0.85
			draw_texture(ctex, Vector2(round(cx), 18.0 + float((c * 29) % 52)), ccol)

	# PLANO Z1-Z3: Montanhas e Cidade em sprites PixelLab (paralaxe com espelhamento para emendar sem costura)
	var day_ratio: float = 1.0 - city_light
	var layer_tint: Color = Color(0.72, 0.74, 0.92).lerp(Color(1.15, 1.12, 1.08), day_ratio)
	draw_texture(BG_MOUNTAINS_TEX, Vector2(0.0, 116.0), layer_tint)
	_draw_parallax_layer(BG_CITY_BACK_TEX, 74.0, _anim_t * 5.0, layer_tint * Color(0.72, 0.72, 0.8))
	_draw_parallax_layer(BG_CITY_FRONT_TEX, 104.0, _anim_t * 12.0, layer_tint)

	# PLANO Z4: Postes de telégrafo (sprite) passando rápido
	for p in range(8):
		var px: float = fmod(float(p * 72) - _anim_t * 85.0, 576.0)
		if px < -40.0:
			px += 576.0
		draw_texture(POLE_TEX, Vector2(round(px), 148.0), layer_tint)

	# PLANO Z5: Fumaça Volumétrica, Trem e Trilhos
	var bob: float = 0.0
	var chimney_origin := Vector2(417.0, 168.0 + bob) # topo da chaminé do sprite da locomotiva

	# Fumaça em pixel art: 8 estágios (de baforada pequena a dissipando), 32x32 cada
	for puff in _smoke_puffs:
		var age: float = float(puff["age"])
		var ratio: float = clampf(age / float(puff["max_age"]), 0.0, 1.0)
		var px: float = chimney_origin.x - age * float(puff["vx"])
		var py: float = chimney_origin.y - pow(age, 0.82) * float(puff["vy"]) + sin(age * 5.0 + float(puff["phase"])) * 3.5
		var stage: int = mini(int(ratio * 8.0), 7)
		var alpha: float = 1.0 - smoothstep(0.65, 1.0, ratio)
		var tint: Color = Color(1.0, 1.0, 1.0).lerp(Color(0.62, 0.6, 0.78), ratio)
		tint.a = alpha * 0.9
		draw_texture_rect_region(STEAM_PUFF_TEX, Rect2(round(px) - 16.0, round(py) - 16.0, 32.0, 32.0), Rect2(stage * 32.0, 0.0, 32.0, 32.0), tint)

	for emb in _embers:
		var age: float = float(emb["age"])
		var max_age: float = float(emb["max_age"])
		var ratio: float = clampf(age / max_age, 0.0, 1.0)
		var ex: float = chimney_origin.x - age * float(emb["vx"])
		var ey: float = chimney_origin.y - age * float(emb["vy"]) + sin(age * 14.0 + float(emb["phase"])) * 4.0
		var ecol: Color = Color.WHITE.lerp(Color("#ff6b3d"), ratio)
		ecol.a = 1.0 - ratio
		draw_texture(EMBER_TEX, Vector2(round(ex) - 1.0, round(ey) - 1.0), ecol)

	_draw_steampunk_train_composition(0.0, 228.0, bob, _anim_t * 15.0, false, 1.0, city_light)

	# Trilho em pixel art rolando sob o trem + cascalho
	draw_texture_rect(BALLAST_TEX, Rect2(-round(fmod(_anim_t * 220.0, 32.0)), 238.0, 512.0, 32.0), true)
	_draw_rail_row(227.0, _anim_t * 220.0)


func _make_stylized_brass_frame(pos: Vector2, sz: Vector2, gear_corners: Array[Vector2] = []) -> Control:
	var ctrl := Control.new()
	ctrl.position = pos
	ctrl.size = sz
	ctrl.mouse_filter = Control.MOUSE_FILTER_PASS

	var p := Panel.new()
	p.position = Vector2.ZERO
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", Settings.make_ui_style("panel"))
	ctrl.add_child(p)

	var gear_tex: Texture2D = load("res://assets/sprites/ui/gear_anim.png")
	for gpos in gear_corners:
		var gs := Sprite2D.new()
		gs.texture = gear_tex
		gs.hframes = 4
		gs.position = gpos
		ctrl.add_child(gs)
		_ui_gear_sprites.append(gs)

	return ctrl


func _build_boot() -> void:
	_boot_progress = 0.0
	_boot_clang_done = false
	_boot_whistle_done = false

	var title := Label.new()
	title.text = "LAST TRAIN HOME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(144.0, 150.0)
	title.size = Vector2(192.0, 57.0)
	title.add_theme_font_size_override("font_size", 20)
	if Settings.title_font != null:
		title.add_theme_font_override("font", Settings.title_font)
	title.add_theme_color_override("font_color", Color("#f2c35b"))
	title.visible = false
	add_child(title)
	var sub := Label.new()
	sub.text = "— RUMO À ESTAÇÃO ZERO —"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(90.0, 214.0)
	sub.size = Vector2(300.0, 14.0)
	sub.add_theme_color_override("font_color", Color("#8fb8c4"))
	sub.visible = false
	add_child(sub)
	get_tree().create_timer(0.65).timeout.connect(func() -> void: title.visible = true)
	get_tree().create_timer(1.0).timeout.connect(func() -> void: sub.visible = true)

	await get_tree().create_timer(2.5).timeout
	SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn")


func _build_main_menu() -> void:
	AudioManager.play_music("menu")

	var h_sz := Vector2(236.0, 50.0)
	var h_gears: Array[Vector2] = [
		Vector2(2.0, 2.0), Vector2(h_sz.x - 2.0, 2.0),
		Vector2(2.0, h_sz.y - 2.0), Vector2(h_sz.x - 2.0, h_sz.y - 2.0)
	]
	var header := _make_stylized_brass_frame(Vector2(16.0, 10.0), h_sz, h_gears)
	add_child(header)

	var gauge_spr := Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/ui/pressure_gauge.png"):
		gauge_spr.texture = load("res://assets/sprites/ui/pressure_gauge.png")
	gauge_spr.position = Vector2(24.0, 25.0)
	header.add_child(gauge_spr)

	var needle := Sprite2D.new()
	needle.texture = load("res://assets/sprites/ui/kit/gauge_needle.png")
	needle.centered = false
	needle.offset = Vector2(-1.0, -1.0)
	needle.position = Vector2(24.0, 25.0)
	header.add_child(needle)
	_gauge_needle = needle

	# Contentor vertical ocupando toda a largura (0..236) e altura (0..50) da placa para centralização exata!
	var title_vbox := VBoxContainer.new()
	title_vbox.position = Vector2(0.0, 0.0)
	title_vbox.size = h_sz
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.add_theme_constant_override("separation", 2)
	title_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_vbox)

	var title := Label.new()
	title.text = "LAST TRAIN HOME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	if Settings.title_font != null:
		title.add_theme_font_override("font", Settings.title_font)
	title.add_theme_color_override("font_color", Color("#f2c35b"))
	title_vbox.add_child(title)

	var sub := Label.new()
	sub.text = "— RUMO À ESTAÇÃO ZERO —"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color("#8fb8c4"))
	title_vbox.add_child(sub)

	var m_sz := Vector2(184.0, 140.0)
	var m_gears: Array[Vector2] = [
		Vector2(2.0, 2.0), Vector2(m_sz.x - 2.0, 2.0),
		Vector2(2.0, m_sz.y - 2.0), Vector2(m_sz.x - 2.0, m_sz.y - 2.0)
	]
	var menu_box := _make_stylized_brass_frame(Vector2(16.0, 80.0), m_sz, m_gears)
	add_child(menu_box)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(12.0, 10.0)
	vbox.size = Vector2(160.0, 120.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	menu_box.add_child(vbox)

	var btn_play := _make_stylized_btn("JOGAR", func() -> void: SceneRouter.goto_scene("res://scenes/menus/DifficultySelect.tscn"))
	var btn_opt := _make_stylized_btn("OPÇÕES", func() -> void: SceneRouter.goto_scene("res://scenes/menus/Options.tscn"))
	var btn_cred := _make_stylized_btn("CRÉDITOS", func() -> void: SceneRouter.goto_scene("res://scenes/menus/Credits.tscn"))
	vbox.add_child(btn_play)
	vbox.add_child(btn_opt)
	vbox.add_child(btn_cred)

	if not OS.has_feature("web"):
		var btn_quit := _make_stylized_btn("SAIR", func() -> void: get_tree().quit())
		vbox.add_child(btn_quit)

	var ver := Label.new()
	ver.text = "v%s" % String(ProjectSettings.get_setting("application/config/version", "1.0"))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.position = Vector2(372.0, 252.0)
	ver.size = Vector2(100.0, 14.0)
	ver.add_theme_font_size_override("font_size", 10)
	ver.add_theme_color_override("font_color", Color("#c98a3c"))
	add_child(ver)
	btn_play.grab_focus()


func _build_difficulty() -> void:
	var sz := Vector2(268.0, 178.0)
	var corners: Array[Vector2] = [Vector2(2, 2), Vector2(sz.x - 2, 2), Vector2(2, sz.y - 2), Vector2(sz.x - 2, sz.y - 2)]
	var frame := _make_stylized_brass_frame(Vector2(16.0, 18.0), sz, corners)
	add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(14.0, 12.0)
	vbox.size = Vector2(240.0, 154.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	frame.add_child(vbox)

	var title := Label.new()
	title.text = "SELECIONE A DIFICULDADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("#f2c35b"))
	vbox.add_child(title)

	var b_easy := _make_stylized_btn("FÁCIL · 6 ♥ · 08:00", func() -> void: _start_game("easy"))
	var b_med := _make_stylized_btn("MÉDIA · 5 ♥ · 06:30", func() -> void: _start_game("medium"))
	var b_hard := _make_stylized_btn("DIFÍCIL · 4 ♥ · 05:30", func() -> void: _start_game("hard"))
	var b_back := _make_stylized_btn("VOLTAR [ESC]", func() -> void: SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn"))

	vbox.add_child(b_easy)
	vbox.add_child(b_med)
	vbox.add_child(b_hard)
	vbox.add_child(b_back)
	Settings.bind_prompt_text(b_back, "VOLTAR {cancel}")

	if Settings.last_difficulty == "easy":
		b_easy.grab_focus()
	elif Settings.last_difficulty == "hard":
		b_hard.grab_focus()
	else:
		b_med.grab_focus()


func _start_game(diff: String) -> void:
	GameState.start_new_run(diff)
	SceneRouter.goto_scene("res://scenes/levels/Intro.tscn")


func _build_intro() -> void:
	_intro_stage = 1
	_intro_sub_t = 0.0
	_intro_teo_x = 24.0
	_intro_teo_interior_pos = Vector2(218.0, 96.0)
	_intro_boarding_alpha = 1.0
	_intro_door_close_ratio = 0.0
	_intro_train_x = 0.0
	_intro_door_open = true

	_intro_wagon_bg = Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/backgrounds/wagon_1.png"):
		_intro_wagon_bg.texture = load("res://assets/sprites/backgrounds/wagon_1.png")
	_intro_wagon_bg.position = Vector2(240.0, 135.0)
	_intro_wagon_bg.visible = false
	add_child(_intro_wagon_bg)

	_intro_bomb_spr = Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/tiles/bomb_device.png"):
		_intro_bomb_spr.texture = load("res://assets/sprites/tiles/bomb_device.png")
	_intro_bomb_spr.visible = false
	add_child(_intro_bomb_spr)

	_intro_bomb_visor_lbl = Label.new()
	_intro_bomb_visor_lbl.text = TrainClock.format_time()
	_intro_bomb_visor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_bomb_visor_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_bomb_visor_lbl.position = Vector2(-16.5, -5.5) # centro do visor do sprite em (1.5, 2.5)
	_intro_bomb_visor_lbl.size = Vector2(36.0, 16.0)
	_intro_bomb_visor_lbl.add_theme_font_size_override("font_size", 10)
	_intro_bomb_visor_lbl.add_theme_color_override("font_color", Color("#fff1c9"))
	_intro_bomb_spr.add_child(_intro_bomb_visor_lbl)

	_skip_box_style = Settings.make_ui_style("panel_small")
	var skip_lbl := Label.new()
	Settings.bind_prompt_text(skip_lbl, "Segure {cancel} p/ Pular")
	skip_lbl.position = Vector2(334.0, 8.0)
	skip_lbl.size = Vector2(134.0, 14.0)
	skip_lbl.z_index = 5
	add_child(skip_lbl)
	_intro_receiver_lbl = Label.new()
	_intro_receiver_lbl.text = "RECEPTOR DA BOMBA · ESTAÇÃO ZERO"
	_intro_receiver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_receiver_lbl.position = Vector2(90.0, 160.0)
	_intro_receiver_lbl.size = Vector2(300.0, 14.0)
	_intro_receiver_lbl.add_theme_color_override("font_color", Color("#f2c35b"))
	_intro_receiver_lbl.visible = false
	add_child(_intro_receiver_lbl)

	_intro_teo_spr = Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/player/teo_sheet_8dir.png"):
		_intro_teo_spr.texture = load("res://assets/sprites/player/teo_sheet_8dir.png")
		_intro_teo_spr.hframes = 8
		_intro_teo_spr.vframes = 66
	add_child(_intro_teo_spr)

	var dbox := preload("res://scenes/ui/DialogueBox.tscn").instantiate()
	add_child(dbox)

	var all_intro_lines: Array = GameState.dialogue_db.get("intro", [])

	AudioManager.play_sfx("whistle")
	var tw1 := create_tween()
	tw1.tween_property(self, "_intro_teo_x", 136.0, 1.85)
	await tw1.finished
	if _intro_skipping:
		return

	var tw_enter := create_tween()
	tw_enter.tween_property(self, "_intro_boarding_alpha", 0.0, 0.32)
	await tw_enter.finished
	if _intro_skipping:
		return

	AudioManager.play_sfx("steam_pulse")
	var tw_door := create_tween()
	tw_door.tween_property(self, "_intro_door_close_ratio", 1.0, 0.35)
	await tw_door.finished
	if _intro_skipping:
		return

	_intro_door_open = false
	var tw_depart := create_tween()
	tw_depart.tween_property(self, "_intro_train_x", 220.0, 1.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_depart.finished
	if _intro_skipping:
		return

	_intro_stage = 2
	_intro_sub_t = 0.0
	_intro_teo_interior_pos = Vector2(218.0, 96.0)
	if all_intro_lines.size() >= 1:
		dbox.start_custom_lines([all_intro_lines[0]])
		await dbox.dialogue_finished
	if _intro_skipping:
		return

	_intro_stage = 3
	_intro_sub_t = 0.0
	var tw_walk_in := create_tween()
	tw_walk_in.tween_property(self, "_intro_teo_interior_pos", Vector2(196.0, 114.0), 0.55)
	for f in range(3):
		AudioManager.play_sfx("clang", 0.08)
		await get_tree().create_timer(0.28).timeout
		if _intro_skipping:
			return

	AudioManager.play_sfx("boss_phase", 0.02)
	if all_intro_lines.size() >= 2:
		dbox.start_custom_lines([all_intro_lines[1]])
		await dbox.dialogue_finished
	if _intro_skipping:
		return

	_intro_stage = 4
	_intro_sub_t = 0.0
	_update_intro_sprites()
	queue_redraw()

	for i in range(3):
		AudioManager.play_sfx("tick", 0.05)
		await get_tree().create_timer(0.5, true, false, true).timeout
		if _intro_skipping:
			return

	if all_intro_lines.size() >= 5:
		dbox.start_custom_lines([all_intro_lines[2], all_intro_lines[3], all_intro_lines[4]])
		await dbox.dialogue_finished
	if _intro_skipping:
		return

	for sec_tick in range(3):
		AudioManager.play_sfx("tick", 0.0)
		TrainClock.set_time(TrainClock.time_left - 1.0)
		_intro_bomb_visor_lbl.text = TrainClock.format_time()
		var tw_pulse := create_tween()
		tw_pulse.tween_property(_intro_bomb_spr, "scale", Vector2(2.65, 2.65), 0.15)
		tw_pulse.tween_property(_intro_bomb_spr, "scale", Vector2(2.4, 2.4), 0.25)
		await get_tree().create_timer(1.0, true, false, true).timeout
		if _intro_skipping:
			return

	SceneRouter.goto_scene("res://scenes/levels/Level_Wagon1.tscn")


func _draw_platform_boarding_scene() -> void:
	draw_texture(SKY_TEX[0], Vector2.ZERO)
	if _tex_moon != null:
		draw_texture(_tex_moon, Vector2(44.0, 14.0))
	draw_texture(BG_MOUNTAINS_TEX, Vector2(0.0, 104.0), Color(0.72, 0.74, 0.92))
	# Cidade em pixel art (mesmas camadas do menu), parada na plataforma
	draw_texture(BG_CITY_BACK_TEX, Vector2(-120.0, 70.0), Color(0.62, 0.62, 0.72))
	draw_texture(BG_CITY_FRONT_TEX, Vector2(-300.0, 76.0), Color(0.6, 0.6, 0.72))

	var wheel_rot: float = _intro_train_x * 0.15
	_draw_steampunk_train_composition(_intro_train_x + 56.0, 197.0, 0.0, wheel_rot, true, _intro_door_close_ratio, 1.0)

	# Plataforma de pedra (textura repetida) com o trilho por cima
	draw_texture_rect(PLATFORM_TEX, Rect2(0.0, 198.0, 480.0, 72.0), true, Color(0.55, 0.52, 0.62))
	_draw_rail_row(196.0, 0.0)

	for lx_lamp in [28.0, 102.0, 260.0, 410.0]:
		draw_texture(LAMP_TEX, Vector2(lx_lamp - 7.0, 130.0))

	# Névoa de vapor rasteira na plataforma
	for m in range(6):
		var mx: float = fmod(float(m * 85) + _anim_t * 14.0, 540.0) - 40.0
		var my: float = 186.0 + float(m % 3) * 7.0
		draw_texture_rect_region(STEAM_PUFF_TEX, Rect2(round(mx), my, 64.0, 32.0), Rect2(5.0 * 32.0, 0.0, 32.0, 32.0), Color(1.0, 1.0, 1.0, 0.25))


func _draw_intro_cutscene() -> void:
	if _intro_stage == 1:
		_draw_platform_boarding_scene()
	elif _intro_stage == 4:
		# Receptor da bomba: a cabine escurecida em alerta ao fundo
		draw_texture(CABIN_BG_TEX, Vector2(-16.0, -16.0), Color(0.45, 0.25, 0.28))

	# Caixa "Segure ESC": moldura do kit + barra de progresso texturizada
	draw_style_box(_skip_box_style, Rect2(328.0, 6.0, 144.0, 18.0))
	if _intro_skip_hold > 0.0:
		var prog_w: float = round(clampf(_intro_skip_hold / 0.8, 0.0, 1.0) * 138.0)
		draw_texture_rect(BAR_FILL_TEX, Rect2(331.0, 9.0, prog_w, 12.0), true, Color(0.95, 0.76, 0.36, 0.5))


func _build_options() -> void:
	var sz := Vector2(336.0, 214.0)
	var corners: Array[Vector2] = [Vector2(2, 2), Vector2(sz.x - 2, 2), Vector2(2, sz.y - 2), Vector2(sz.x - 2, sz.y - 2)]
	var frame := _make_stylized_brass_frame(Vector2(14.0, 10.0), sz, corners)
	add_child(frame)

	var title := Label.new()
	title.text = "OPÇÕES E CONFIGURAÇÕES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(10.0, 6.0)
	title.size = Vector2(316.0, 16.0)
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("#f2c35b"))
	frame.add_child(title)

	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.position = Vector2(12.0, 26.0)
	tabs_hbox.size = Vector2(312.0, 22.0)
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_hbox.add_theme_constant_override("separation", 4)
	frame.add_child(tabs_hbox)

	var tab_names: Array[String] = ["ÁUDIO", "VÍDEO", "JOGO", "TECLADO", "CONTROLE"]
	for i in range(tab_names.size()):
		var tb := Button.new()
		tb.text = tab_names[i]
		tb.custom_minimum_size = Vector2(58.0, 20.0)
		tb.add_theme_font_size_override("font_size", 10)
		var idx: int = i
		tb.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_hover")
			_switch_options_tab(idx)
		)
		tabs_hbox.add_child(tb)
		_opt_tab_btns.append(tb)

	var page_audio := VBoxContainer.new()
	page_audio.position = Vector2(18.0, 54.0)
	page_audio.size = Vector2(300.0, 122.0)
	page_audio.alignment = BoxContainer.ALIGNMENT_CENTER
	page_audio.add_theme_constant_override("separation", 6)
	frame.add_child(page_audio)
	_opt_tabs.append(page_audio)

	_btn_master_vol = _make_stylized_btn("", func() -> void: _change_volume("master", 10))
	_btn_music_vol = _make_stylized_btn("", func() -> void: _change_volume("music", 10))
	_btn_sfx_vol = _make_stylized_btn("", func() -> void: _change_volume("sfx", 10))
	page_audio.add_child(_btn_master_vol)
	page_audio.add_child(_btn_music_vol)
	page_audio.add_child(_btn_sfx_vol)
	# ◀/▶ ajustam o volume no próprio botão: tratado aqui (antes da navegação de foco do Godot),
	# senão D-pad e setas pulariam o foco para outro botão em vez de mudar o volume
	for vol_def in [[_btn_master_vol, "master"], [_btn_music_vol, "music"], [_btn_sfx_vol, "sfx"]]:
		var vol_btn: Button = vol_def[0]
		var vol_kind: String = vol_def[1]
		vol_btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev.is_action_pressed("move_left") or ev.is_action_pressed("move_right"):
				_change_volume(vol_kind, -10 if ev.is_action_pressed("move_left") else 10)
				vol_btn.accept_event()
		)

	var audio_hint := Label.new()
	Settings.bind_prompt_text(audio_hint, "Dica: Use [A/D], Setas [◀/▶] ou Clique para ajustar o volume", "Dica: Use {move_left}/{move_right} para ajustar · {tab_prev}/{tab_next} trocam de aba")
	audio_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio_hint.add_theme_font_size_override("font_size", 10)
	audio_hint.add_theme_color_override("font_color", Color("#8fb8c4"))
	page_audio.add_child(audio_hint)

	var page_video := VBoxContainer.new()
	page_video.position = Vector2(18.0, 54.0)
	page_video.size = Vector2(300.0, 122.0)
	page_video.alignment = BoxContainer.ALIGNMENT_CENTER
	page_video.add_theme_constant_override("separation", 6)
	page_video.visible = false
	frame.add_child(page_video)
	_opt_tabs.append(page_video)

	_btn_fs = _make_stylized_btn("", func() -> void:
		Settings.fullscreen = not Settings.fullscreen
		Settings.apply_settings()
		Settings.save_settings()
		_refresh_options_texts()
	)
	_btn_shake = _make_stylized_btn("", func() -> void:
		Settings.screen_shake_mode = (Settings.screen_shake_mode + 1) % 3
		Settings.save_settings()
		_refresh_options_texts()
	)
	_btn_flash = _make_stylized_btn("", func() -> void:
		Settings.reduce_flashes = not Settings.reduce_flashes
		Settings.save_settings()
		_refresh_options_texts()
	)
	page_video.add_child(_btn_fs)
	page_video.add_child(_btn_shake)
	page_video.add_child(_btn_flash)

	var page_game := VBoxContainer.new()
	page_game.position = Vector2(18.0, 54.0)
	page_game.size = Vector2(300.0, 122.0)
	page_game.alignment = BoxContainer.ALIGNMENT_CENTER
	page_game.add_theme_constant_override("separation", 2)
	page_game.visible = false
	frame.add_child(page_game)
	_opt_tabs.append(page_game)

	_btn_aim = _make_stylized_btn("", func() -> void:
		Settings.auto_aim = not Settings.auto_aim
		Settings.save_settings()
		_refresh_options_texts()
	)
	_btn_hb = _make_stylized_btn("", func() -> void:
		Settings.always_show_hitbox = not Settings.always_show_hitbox
		Settings.save_settings()
		_refresh_options_texts()
	)
	_btn_dmg = _make_stylized_btn("", func() -> void:
		Settings.show_damage_numbers = not Settings.show_damage_numbers
		Settings.save_settings()
		_refresh_options_texts()
	)
	_btn_hc = _make_stylized_btn("", func() -> void:
		Settings.high_contrast_bullets = not Settings.high_contrast_bullets
		Settings.save_settings()
		_refresh_options_texts()
	)
	_btn_vib = _make_stylized_btn("", func() -> void:
		Settings.vibration_enabled = not Settings.vibration_enabled
		Settings.save_settings()
		_refresh_options_texts()
		Settings.rumble(0.4, 0.4, 0.15) # amostra ao ligar
	)
	page_game.add_child(_btn_aim)
	page_game.add_child(_btn_hb)
	page_game.add_child(_btn_dmg)
	page_game.add_child(_btn_hc)
	page_game.add_child(_btn_vib)

	var page_ctrl := VBoxContainer.new()
	page_ctrl.position = Vector2(12.0, 54.0)
	page_ctrl.size = Vector2(312.0, 124.0)
	page_ctrl.alignment = BoxContainer.ALIGNMENT_BEGIN
	page_ctrl.add_theme_constant_override("separation", 3)
	page_ctrl.visible = false
	frame.add_child(page_ctrl)
	_opt_tabs.append(page_ctrl)

	var grid_ctrl := GridContainer.new()
	grid_ctrl.columns = 3
	grid_ctrl.add_theme_constant_override("h_separation", 4)
	grid_ctrl.add_theme_constant_override("v_separation", 3)
	page_ctrl.add_child(grid_ctrl)

	var bind_defs: Array = [
		["move_up", "Cima"],
		["move_down", "Baixo"],
		["move_left", "Esquerda"],
		["move_right", "Direita"],
		["shoot", "Atirar"],
		["dash", "Dash"],
		["ability", "Pulso Vapor"],
		["focus", "Foco"],
		["interact", "Interagir"]
	]
	_keybind_buttons.clear()
	for def_item in bind_defs:
		var act_id: String = String(def_item[0])
		var act_label: String = String(def_item[1])
		var kb_btn := Button.new()
		kb_btn.custom_minimum_size = Vector2(101.0, 19.0)
		kb_btn.add_theme_font_size_override("font_size", 10)
		kb_btn.clip_text = true
		kb_btn.set_meta("action_id", act_id)
		kb_btn.set_meta("action_label", act_label)
		kb_btn.pressed.connect(_start_remap_for_action.bind(act_id))
		grid_ctrl.add_child(kb_btn)
		_keybind_buttons[act_id] = kb_btn

	_remap_status_lbl = Label.new()
	_remap_status_lbl.text = "Clique em uma ação para trocar a tecla"
	_remap_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remap_status_lbl.add_theme_font_size_override("font_size", 10)
	_remap_status_lbl.add_theme_color_override("font_color", Color("#8fb8c4"))
	page_ctrl.add_child(_remap_status_lbl)

	var mouse_hint := Label.new()
	mouse_hint.text = "(o botão esquerdo do mouse também atira)"
	mouse_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_hint.add_theme_font_size_override("font_size", 10)
	mouse_hint.add_theme_color_override("font_color", Color("#8fb8c4"))
	page_ctrl.add_child(mouse_hint)

	# Aba CONTROLE: um botão por ação de jogo; movimento, mira, pausa e menus ficam fixos
	var page_pad := VBoxContainer.new()
	page_pad.position = Vector2(12.0, 54.0)
	page_pad.size = Vector2(312.0, 124.0)
	page_pad.alignment = BoxContainer.ALIGNMENT_BEGIN
	page_pad.add_theme_constant_override("separation", 3)
	page_pad.visible = false
	frame.add_child(page_pad)
	_opt_tabs.append(page_pad)

	var grid_pad := GridContainer.new()
	grid_pad.columns = 3
	grid_pad.add_theme_constant_override("h_separation", 4)
	grid_pad.add_theme_constant_override("v_separation", 3)
	page_pad.add_child(grid_pad)

	var pad_defs: Array = [
		["shoot", "Atirar"],
		["dash", "Dash"],
		["ability", "Pulso Vapor"],
		["focus", "Foco"],
		["interact", "Interagir"]
	]
	_pad_bind_buttons.clear()
	for def_item in pad_defs:
		var act_id: String = String(def_item[0])
		var pb := Button.new()
		pb.custom_minimum_size = Vector2(101.0, 19.0)
		pb.add_theme_font_size_override("font_size", 10)
		pb.clip_text = true
		pb.set_meta("action_label", String(def_item[1]))
		pb.pressed.connect(_start_pad_remap_for_action.bind(act_id))
		grid_pad.add_child(pb)
		_pad_bind_buttons[act_id] = pb

	_pad_status_lbl = Label.new()
	_pad_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pad_status_lbl.add_theme_font_size_override("font_size", 10)
	page_pad.add_child(_pad_status_lbl)

	for fixed_txt in ["Fixos: LS/D-pad move · RS mira · START pausa", "Menus: A confirma · B volta · LB/RB trocam aba"]:
		var fixed_lbl := Label.new()
		fixed_lbl.text = fixed_txt
		fixed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fixed_lbl.add_theme_font_size_override("font_size", 10)
		fixed_lbl.add_theme_color_override("font_color", Color("#c98a3c"))
		page_pad.add_child(fixed_lbl)

	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.position = Vector2(18.0, 182.0)
	bottom_hbox.size = Vector2(300.0, 24.0)
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 8)
	frame.add_child(bottom_hbox)

	var b_reset := Button.new()
	b_reset.text = "RESTAURAR PADRÕES"
	b_reset.custom_minimum_size = Vector2(142.0, 22.0)
	b_reset.add_theme_font_size_override("font_size", 10)
	b_reset.pressed.connect(func() -> void:
		_waiting_remap_action = ""
		_waiting_pad_action = ""
		Settings.master_volume = 100
		Settings.music_volume = 80
		Settings.sfx_volume = 100
		Settings.fullscreen = false
		Settings.screen_shake_mode = 2
		Settings.reduce_flashes = false
		Settings.auto_aim = false
		Settings.always_show_hitbox = false
		Settings.show_damage_numbers = true
		Settings.high_contrast_bullets = false
		Settings.vibration_enabled = true
		Settings.reset_keybinds_to_default()
		Settings.reset_pad_binds_to_default()
		Settings.apply_settings()
		Settings.save_settings()
		AudioManager.play_sfx("ui_confirm")
		_refresh_options_texts()
		_refresh_keybind_buttons()
		_refresh_pad_bind_buttons()
	)
	bottom_hbox.add_child(b_reset)

	var b_back := Button.new()
	Settings.bind_prompt_text(b_back, "VOLTAR {cancel}")
	b_back.custom_minimum_size = Vector2(142.0, 22.0)
	b_back.add_theme_font_size_override("font_size", 10)
	b_back.pressed.connect(func() -> void:
		_waiting_remap_action = ""
		_waiting_pad_action = ""
		AudioManager.play_sfx("ui_confirm")
		SceneRouter.goto_scene("res://scenes/menus/MainMenu.tscn")
	)
	bottom_hbox.add_child(b_back)

	_refresh_options_texts()
	_refresh_keybind_buttons()
	_refresh_pad_bind_buttons()
	_switch_options_tab(0)
	_btn_master_vol.grab_focus()
	Settings.input_device_changed.connect(_on_input_device_changed)


func _on_input_device_changed(_using_gamepad: bool) -> void:
	_refresh_keybind_buttons()
	_refresh_pad_bind_buttons()


func _start_pad_remap_for_action(act_id: String) -> void:
	_waiting_pad_action = act_id
	AudioManager.play_sfx("ui_confirm")
	_refresh_pad_bind_buttons()


func _refresh_pad_bind_buttons() -> void:
	for act_id in _pad_bind_buttons.keys():
		var btn: Button = _pad_bind_buttons[act_id]
		if not is_instance_valid(btn):
			continue
		var lbl_name: String = String(btn.get_meta("action_label", act_id))
		if _waiting_pad_action == act_id:
			btn.text = "%s: [...]" % lbl_name
			btn.modulate = Color("#f2c35b")
		else:
			btn.text = "%s: [%s]" % [lbl_name, Settings.get_pad_bind_name(act_id)]
			btn.modulate = Color.WHITE

	if _pad_status_lbl != null:
		if _waiting_pad_action != "":
			_pad_status_lbl.text = "Aperte o novo botão (START ou ESC cancela)..."
			_pad_status_lbl.add_theme_color_override("font_color", Color("#f2c35b"))
		else:
			_pad_status_lbl.text = "Escolha uma ação e aperte o novo botão"
			_pad_status_lbl.add_theme_color_override("font_color", Color("#8fb8c4"))


func _focus_first_button(root: Node) -> void:
	for child in root.find_children("*", "Button", true, false):
		var b := child as Button
		if b.is_visible_in_tree() and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus()
			return


func _start_remap_for_action(act_id: String) -> void:
	_waiting_remap_action = act_id
	AudioManager.play_sfx("ui_confirm")
	_refresh_keybind_buttons()


func _refresh_keybind_buttons() -> void:
	for act_id in _keybind_buttons.keys():
		var btn: Button = _keybind_buttons[act_id]
		if not is_instance_valid(btn):
			continue
		var lbl_name: String = String(btn.get_meta("action_label", act_id))
		if _waiting_remap_action == act_id:
			btn.text = "%s: [...]" % lbl_name
			btn.modulate = Color("#f2c35b")
		else:
			btn.text = "%s: [%s]" % [lbl_name, Settings.get_action_key_name(act_id)]
			btn.modulate = Color.WHITE

	if _remap_status_lbl != null:
		if _waiting_remap_action != "":
			_remap_status_lbl.text = "Pressione a nova tecla (ou [%s] para cancelar)..." % Settings.get_prompt("cancel")
			_remap_status_lbl.add_theme_color_override("font_color", Color("#f2c35b"))
		elif Settings.using_gamepad:
			_remap_status_lbl.text = "Os botões do controle ficam na aba CONTROLE"
			_remap_status_lbl.add_theme_color_override("font_color", Color("#8fb8c4"))
		else:
			_remap_status_lbl.text = "Clique em uma ação para trocar a tecla"
			_remap_status_lbl.add_theme_color_override("font_color", Color("#8fb8c4"))


func _switch_options_tab(idx: int) -> void:
	_waiting_remap_action = ""
	_waiting_pad_action = ""
	_current_opt_tab = idx
	for i in range(_opt_tabs.size()):
		_opt_tabs[i].visible = (i == idx)
		_opt_tab_btns[i].modulate = Color("#f2c35b") if i == idx else Color("#fff1c9")
	_refresh_keybind_buttons()
	_refresh_pad_bind_buttons()


func _change_volume(kind: String, step_val: int) -> void:
	if kind == "master":
		Settings.master_volume = posmod(Settings.master_volume + step_val, 110)
	elif kind == "music":
		Settings.music_volume = posmod(Settings.music_volume + step_val, 110)
	elif kind == "sfx":
		Settings.sfx_volume = posmod(Settings.sfx_volume + step_val, 110)

	Settings.apply_settings()
	Settings.save_settings()
	AudioManager.play_sfx("ui_confirm")
	_refresh_options_texts()


func _format_vol_bar(percent: int) -> String:
	var filled: int = clampi(int(round(float(percent) / 10.0)), 0, 10)
	return "▮".repeat(filled) + "▯".repeat(10 - filled) + (" %d%%" % percent)


func _refresh_options_texts() -> void:
	if _btn_master_vol == null:
		return
	_btn_master_vol.set_meta("base_text", "Volume Geral: " + _format_vol_bar(Settings.master_volume))
	_btn_music_vol.set_meta("base_text", "Música: " + _format_vol_bar(Settings.music_volume))
	_btn_sfx_vol.set_meta("base_text", "Efeitos (SFX): " + _format_vol_bar(Settings.sfx_volume))

	var modes: Array[String] = ["DESLIGADO", "REDUZIDO", "NORMAL"]
	_btn_fs.set_meta("base_text", "Tela Cheia (F11): %s" % ("SIM" if Settings.fullscreen else "NÃO"))
	_btn_shake.set_meta("base_text", "Tremor de Câmera: %s" % modes[Settings.screen_shake_mode])
	_btn_flash.set_meta("base_text", "Reduzir Flashes: %s" % ("SIM" if Settings.reduce_flashes else "NÃO"))

	_btn_aim.set_meta("base_text", "Mira Automática: %s" % ("LIGADA" if Settings.auto_aim else "DESLIGADA"))
	_btn_hb.set_meta("base_text", "Mostrar Hitbox Sempre: %s" % ("SIM" if Settings.always_show_hitbox else "NÃO"))
	_btn_dmg.set_meta("base_text", "Números de Dano: %s" % ("SIM" if Settings.show_damage_numbers else "NÃO"))
	_btn_hc.set_meta("base_text", "Balas Alto Contraste: %s" % ("SIM" if Settings.high_contrast_bullets else "NÃO"))
	_btn_vib.set_meta("base_text", "Vibração do Controle: %s" % ("SIM" if Settings.vibration_enabled else "NÃO"))

	for b in [_btn_master_vol, _btn_music_vol, _btn_sfx_vol, _btn_fs, _btn_shake, _btn_flash, _btn_aim, _btn_hb, _btn_dmg, _btn_hc, _btn_vib]:
		var bt: String = String(b.get_meta("base_text", b.text))
		b.text = ("▶ " + bt + " ◀") if b.has_focus() else bt


func _make_stylized_btn(txt: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.set_meta("base_text", txt)
	b.custom_minimum_size = Vector2(156.0, 22.0)
	b.add_theme_font_size_override("font_size", 10)

	if callback.is_valid():
		b.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_confirm")
			callback.call()
		)
	b.mouse_entered.connect(_on_stylized_btn_hover.bind(b))
	b.focus_entered.connect(_on_stylized_btn_focus.bind(b, true))
	b.focus_exited.connect(_on_stylized_btn_focus.bind(b, false))
	return b


func _on_stylized_btn_hover(b: Button) -> void:
	if is_instance_valid(b):
		b.grab_focus()
		AudioManager.play_sfx("ui_hover")


func _on_stylized_btn_focus(b: Button, focused: bool) -> void:
	if not is_instance_valid(b):
		return
	var bt: String = String(b.get_meta("base_text", b.text))
	b.text = ("▶ " + bt + " ◀") if focused else bt
