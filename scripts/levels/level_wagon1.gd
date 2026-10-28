extends LevelBase

const NPC_DATA: Array[Dictionary] = [
	{
		"pos": Vector2(115.0, 100.0),
		"dialogue_pre": "wagon1_nervous",
		"dialogue_post": "wagon1_nervous_after",
		"triggers_clang": false,
		"tex": "res://assets/sprites/npcs/npc_nervous.png"
	},
	{
		"pos": Vector2(225.0, 210.0),
		"dialogue_pre": "wagon1_suspicious",
		"dialogue_post": "wagon1_suspicious_after",
		"triggers_clang": false,
		"tex": "res://assets/sprites/npcs/npc_suspicious.png"
	},
	{
		"pos": Vector2(310.0, 115.0),
		"dialogue_pre": "wagon1_curious",
		"dialogue_post": "wagon1_curious_after",
		"triggers_clang": true,
		"tex": "res://assets/sprites/npcs/npc_curious.png"
	}
]

var _clang_triggered: bool = false
var _talking_to_npc: bool = false
var _wave: int = 0
var _elapsed: float = 0.0
var _anim_t: float = 0.0
var _next_wave_delay: float = 0.0
var _first_dash_slowmo_done: bool = false
var _nearest_npc_idx: int = -1
var _npc_sprites: Array[Sprite2D] = []
var _npc_drawer: Node2D


func _ready() -> void:
	wagon_number = 1
	next_scene_path = "res://scenes/levels/Level_Wagon2.tscn"
	super._ready()
	TrainClock.apply_section_rubber_band("wagon_1")
	TrainClock.is_running = true
	AudioManager.play_music("wagon_1")
	hud.set_wagon_title("VAGÃO 1/4")
	hud.set_wave_info(0, 2)
	hud.set_contextual_tip("{move} Mover  |  Aproxime-se de qualquer Passageiro e pressione {interact}")
	_spawn_wagon1_npcs()


func _spawn_wagon1_npcs() -> void:
	for item in NPC_DATA:
		var spr := Sprite2D.new()
		spr.texture = load(String(item["tex"]))
		spr.hframes = 4 # npc_*.png: 4 quadros 48x48 (breathing-idle sudeste, PixelLab)
		var p: Vector2 = item["pos"]
		spr.position = p
		spr.z_index = int(p.y)
		add_child(spr)
		_npc_sprites.append(spr)

	_npc_drawer = Node2D.new()
	_npc_drawer.z_index = 255
	_npc_drawer.draw.connect(_draw_npc_prompts)
	add_child(_npc_drawer)


func _draw_npc_prompts() -> void:
	var can_talk_now: bool = (not _talking_to_npc) and (not _clang_triggered or _wave >= 3)
	if not can_talk_now:
		return
	for i in range(NPC_DATA.size()):
		var npc_pos: Vector2 = NPC_DATA[i]["pos"]
		if i == _nearest_npc_idx:
			draw_centered_f_prompt(_npc_drawer, npc_pos + Vector2(0.0, -22.0), 0.0)
		else:
			draw_speech_bubble_hint(_npc_drawer, npc_pos + Vector2(0.0, -20.0))


func _find_nearest_npc_in_range() -> int:
	if player == null:
		return -1
	var best_idx: int = -1
	var best_dist: float = 48.0
	for i in range(NPC_DATA.size()):
		var p: Vector2 = NPC_DATA[i]["pos"]
		var d: float = player.global_position.distance_to(p)
		if d <= best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func _process(delta: float) -> void:
	super._process(delta)
	_elapsed += delta
	_anim_t += delta

	# Anima os 3 passageiros continuamente (e vira para o jogador)
	for i in range(_npc_sprites.size()):
		var spr: Sprite2D = _npc_sprites[i]
		if is_instance_valid(spr):
			spr.frame = int(_anim_t * 5.0 + float(i * 2)) % 4
			if player != null:
				spr.flip_h = player.global_position.x < spr.global_position.x

	_nearest_npc_idx = _find_nearest_npc_in_range()
	if _npc_drawer != null:
		_npc_drawer.queue_redraw()

	if not _clang_triggered and not _talking_to_npc:
		if _nearest_npc_idx != -1 and Input.is_action_just_pressed("interact"):
			_interact_with_npc(_nearest_npc_idx)
		elif _elapsed >= 25.0:
			_start_clang_sequence()
	elif _clang_triggered:
		if not _first_dash_slowmo_done and Input.is_action_just_pressed("dash"):
			_first_dash_slowmo_done = true
			Engine.time_scale = 0.3
			get_tree().create_timer(0.4 * 0.3).timeout.connect(func() -> void: Engine.time_scale = 1.0)

		var alive: int = get_tree().get_nodes_in_group("enemies").size()
		if _wave == 1:
			if alive <= 1:
				_next_wave_delay += delta
			if _next_wave_delay >= 3.0 or alive == 0:
				_start_wave_2()
		elif _wave == 2 and alive == 0:
			_wave = 3
			_on_waves_cleared()
		elif _wave >= 3 and not _talking_to_npc:
			# Permite conversar com qualquer passageiro também após derrotar todos os inimigos!
			if _nearest_npc_idx != -1 and Input.is_action_just_pressed("interact"):
				_interact_with_npc(_nearest_npc_idx)


func _interact_with_npc(idx: int) -> void:
	_talking_to_npc = true
	if _npc_drawer != null:
		_npc_drawer.queue_redraw()

	var info: Dictionary = NPC_DATA[idx]
	if not _clang_triggered:
		if bool(info["triggers_clang"]):
			await _start_clang_sequence()
		else:
			dialogue_box.start_dialogue(String(info["dialogue_pre"]))
			await dialogue_box.dialogue_finished
	else:
		dialogue_box.start_dialogue(String(info["dialogue_post"]))
		await dialogue_box.dialogue_finished

	_talking_to_npc = false


func _start_clang_sequence() -> void:
	if _clang_triggered:
		return
	_clang_triggered = true
	if _npc_drawer != null:
		_npc_drawer.queue_redraw()
	dialogue_box.start_dialogue("wagon1_curious")
	await dialogue_box.dialogue_finished

	AudioManager.play_sfx("clang")
	Events.request_screen_shake.emit(4.0, 0.3)
	Events.request_screen_flash.emit(0.08)
	dialogue_box.start_dialogue("wagon1_clang")
	await dialogue_box.dialogue_finished

	_wave = 1
	_elapsed = 0.0
	_next_wave_delay = 0.0
	hud.set_wave_info(1, 2)
	hud.set_contextual_tip("{shoot} Atirar  |  {dash} Dash (invulnerável)")
	spawn_enemy("sentinel", Vector2(400.0, 110.0))
	spawn_enemy("sentinel", Vector2(420.0, 160.0))
	spawn_enemy("sentinel", Vector2(400.0, 210.0))


func _start_wave_2() -> void:
	_wave = 2
	_elapsed = 0.0
	hud.set_wave_info(2, 2)
	player.reset_pulse_cooldown()
	hud.set_contextual_tip("{ability} Pulso de Vapor: apaga balas e empurra inimigos!")
	spawn_enemy("sentinel", Vector2(80.0, 120.0))
	spawn_enemy("sentinel", Vector2(410.0, 190.0))
	spawn_enemy("drone", Vector2(360.0, 100.0))
	spawn_enemy("drone", Vector2(360.0, 220.0))


func _on_waves_cleared() -> void:
	hud.set_wave_info(0, 0)
	dialogue_box.start_dialogue("wagon1_gear")
	await dialogue_box.dialogue_finished
	upgrade_screen.open_upgrade_choices()
	await upgrade_screen.upgrade_selected
	unlock_exit_door()
