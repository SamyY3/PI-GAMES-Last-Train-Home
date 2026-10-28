extends LevelBase

const FX_VENT_WARN: Texture2D = preload("res://assets/sprites/fx/vent_warning.png")
const FX_PUFF: Texture2D = preload("res://assets/sprites/fx/steam_puff.png")

const WORKER_POS: Vector2 = Vector2(395.0, 92.0)
# Centro dos dois canos de cobre do cenário wagon_2.png (x da imagem - 16 de deslocamento do fundo)
const VENT_X: Array[float] = [111.0, 369.0]
const VENT_HALF_W: float = 12.0

const WAVES: Array = [
	[
		[["wrench", Vector2(390.0, 110.0)], ["wrench", Vector2(390.0, 205.0)]],
		[["drone", Vector2(120.0, 95.0)], ["drone", Vector2(240.0, 95.0)], ["drone", Vector2(360.0, 95.0)], ["wrench", Vector2(410.0, 157.0)]],
		[["sentinel", Vector2(100.0, 120.0)], ["sentinel", Vector2(100.0, 200.0)], ["turret", Vector2(240.0, 157.0)]],
	],
	[
		[["wrench", Vector2(410.0, 157.0)], ["drone", Vector2(360.0, 100.0)], ["drone", Vector2(360.0, 215.0)]],
		[["sniper", Vector2(420.0, 110.0)], ["sentinel", Vector2(400.0, 205.0)], ["wrench", Vector2(60.0, 157.0)]],
		[["turret", Vector2(180.0, 157.0)], ["turret", Vector2(300.0, 157.0)], ["drone", Vector2(240.0, 95.0)]],
	],
	[
		[["sentinel", Vector2(400.0, 110.0)], ["sentinel", Vector2(400.0, 205.0)], ["wrench", Vector2(420.0, 157.0)]],
		[["drone", Vector2(150.0, 95.0)], ["drone", Vector2(330.0, 95.0)], ["drone", Vector2(150.0, 215.0)], ["drone", Vector2(330.0, 215.0)]],
		[["wrench", Vector2(60.0, 120.0)], ["wrench", Vector2(60.0, 200.0)], ["turret", Vector2(300.0, 157.0)]],
	],
]

var _dialogue_triggered: bool = false
var _started_combat: bool = false
var _talking_extra: bool = false
var _wave: int = 0
var _wave_timer: float = 0.0
var _anim_t: float = 0.0
var _next_wave_delay: float = 0.0
var _hazard_timer: float = 0.0
var _worker_spr: Sprite2D
var _hazard_drawer: Node2D


func _ready() -> void:
	wagon_number = 2
	next_scene_path = "res://scenes/levels/Level_Wagon3.tscn"
	super._ready()
	TrainClock.apply_section_rubber_band("wagon_2")
	TrainClock.is_running = true
	AudioManager.play_music("wagon_2")
	hud.set_wagon_title("VAGÃO 2/4")
	hud.set_wave_info(0, 3)
	hud.set_contextual_tip("Cuidado com as tubulações! Afaste-se quando os canos brilharem.")

	_worker_spr = Sprite2D.new()
	_worker_spr.texture = load("res://assets/sprites/npcs/npc_worker.png")
	_worker_spr.hframes = 4
	_worker_spr.position = WORKER_POS
	_worker_spr.z_index = int(WORKER_POS.y)
	add_child(_worker_spr)

	_hazard_drawer = Node2D.new()
	_hazard_drawer.z_index = 230
	_hazard_drawer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_hazard_drawer.draw.connect(_draw_hazards)
	add_child(_hazard_drawer)

	if bool(GameState.get_difficulty_config().get("guaranteed_wagon2_drop", false)):
		_spawn_steam_cell(Vector2(240.0, 200.0))


func _process(delta: float) -> void:
	super._process(delta)
	_wave_timer += delta
	_anim_t += delta

	if is_instance_valid(_worker_spr):
		_worker_spr.frame = int(_anim_t * 5.0) % 4
		if player != null:
			_worker_spr.flip_h = player.global_position.x < _worker_spr.global_position.x

	if not _dialogue_triggered and (_wave_timer >= 2.5 or player.global_position.x >= 340.0):
		_start_wagon2_events()
	elif _started_combat and _wave >= 1 and _wave <= 3:
		_process_hazards(delta)
		_hazard_drawer.queue_redraw()
		var alive: int = get_tree().get_nodes_in_group("enemies").size()
		if alive <= 1:
			_next_wave_delay += delta
		else:
			_next_wave_delay = 0.0

		if _wave == 1 and (alive == 0 or _next_wave_delay >= 3.0):
			_spawn_wave_2()
		elif _wave == 2 and (alive == 0 or _next_wave_delay >= 3.0):
			_spawn_wave_3()
		elif _wave == 3 and alive == 0:
			_wave = 4
			_hazard_drawer.queue_redraw()
			_finish_wagon_2()
	elif _wave >= 4 and not _talking_extra:
		_hazard_drawer.queue_redraw()
		if player != null and player.global_position.distance_to(WORKER_POS) <= 48.0:
			if Input.is_action_just_pressed("interact"):
				_talk_to_worker_after()


func _talk_to_worker_after() -> void:
	_talking_extra = true
	dialogue_box.start_dialogue("wagon2_worker_after")
	await dialogue_box.dialogue_finished
	_talking_extra = false


func _draw_hazards() -> void:
	if _wave >= 4 and not _talking_extra and player != null:
		if player.global_position.distance_to(WORKER_POS) <= 48.0:
			draw_centered_f_prompt(_hazard_drawer, WORKER_POS + Vector2(0.0, -22.0), 0.0)
		else:
			draw_speech_bubble_hint(_hazard_drawer, WORKER_POS + Vector2(0.0, -20.0))
		return

	if not _started_combat or _wave < 1 or _wave > 3:
		return
	var cycle: float = fmod(_hazard_timer, 6.0)
	for vx in VENT_X:
		if cycle < 1.0:
			# Aviso: faixa listrada piscando sobre o duto
			if int(cycle * 8.0) % 2 == 0:
				_hazard_drawer.draw_texture_rect(FX_VENT_WARN, Rect2(vx - 12.0, 64.0, 24.0, 186.0), true)
		elif cycle <= 2.2:
			# Jato de vapor: coluna de baforadas pixel art subindo
			for k in range(8):
				var py: float = 250.0 - fmod(float(k) * 24.0 + _hazard_timer * 140.0, 186.0)
				var st: int = clampi(int((250.0 - py) / 186.0 * 6.0), 0, 5)
				_hazard_drawer.draw_texture_rect_region(FX_PUFF, Rect2(vx - 16.0, round(py) - 16.0, 32.0, 32.0), Rect2(st * 32.0, 0.0, 32.0, 32.0), Color(1.0, 1.0, 1.0, 0.9))


func _start_wagon2_events() -> void:
	_dialogue_triggered = true
	dialogue_box.start_dialogue("wagon2_worker")
	await dialogue_box.dialogue_finished
	_started_combat = true
	_wave = 1
	_wave_timer = 0.0
	_next_wave_delay = 0.0
	_hazard_timer = 0.0
	hud.set_wave_info(1, 3)
	spawn_wave(WAVES[GameState.get_wave_variant(2)][0])


func _spawn_wave_2() -> void:
	_wave = 2
	_wave_timer = 0.0
	_next_wave_delay = 0.0
	hud.set_wave_info(2, 3)
	spawn_wave(WAVES[GameState.get_wave_variant(2)][1])


func _spawn_wave_3() -> void:
	_wave = 3
	_wave_timer = 0.0
	_next_wave_delay = 0.0
	hud.set_wave_info(3, 3)
	spawn_wave(WAVES[GameState.get_wave_variant(2)][2])


func _process_hazards(delta: float) -> void:
	_hazard_timer += delta
	var cycle: float = fmod(_hazard_timer, 6.0)
	if cycle >= 1.0 and cycle <= 2.2:
		if absf(player.global_position.x - VENT_X[0]) < VENT_HALF_W or absf(player.global_position.x - VENT_X[1]) < VENT_HALF_W:
			player.take_damage(1, Vector2(player.global_position.x, 64.0))


func _finish_wagon_2() -> void:
	hud.set_wave_info(0, 0)
	upgrade_screen.open_upgrade_choices()
	await upgrade_screen.upgrade_selected

	var woman_spr := Sprite2D.new()
	woman_spr.texture = load("res://assets/sprites/npcs/npc_woman.png")
	woman_spr.hframes = 4
	woman_spr.position = Vector2(240.0, 157.0)
	woman_spr.z_index = 157
	add_child(woman_spr)

	dialogue_box.start_dialogue("wagon2_woman")
	await dialogue_box.dialogue_finished

	# Animação de desaparecer em vapor da Mulher Misteriosa
	var tw_vanish := create_tween()
	tw_vanish.tween_property(woman_spr, "modulate", Color(0.86, 0.91, 0.93, 0.0), 0.3)
	await tw_vanish.finished
	woman_spr.queue_free()

	GameState.has_cargo_key = true
	AudioManager.play_sfx("upgrade_get")
	Events.item_obtained.emit("CHAVE DO VAGÃO DE CARGA")
	unlock_exit_door()
