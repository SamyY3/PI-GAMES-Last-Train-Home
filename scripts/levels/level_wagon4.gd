extends LevelBase

var _wave_idx: int = 0
var _wave_timer: float = 0.0
var _clear_delay: float = 0.0
var _mid_upgrade_offered: bool = false
var _awaiting_upgrade: bool = false


func _ready() -> void:
	wagon_number = 4
	next_scene_path = "res://scenes/levels/Level_Cabin.tscn"
	super._ready()
	TrainClock.apply_section_rubber_band("wagon_4")
	AudioManager.play_music("wagon_4")
	hud.set_wagon_title("VAGÃO 4/4")
	hud.set_wave_info(0, 4)

	dialogue_box.start_dialogue("wagon4_start")
	await dialogue_box.dialogue_finished
	TrainClock.is_running = true
	_spawn_next_wave()


func _process(delta: float) -> void:
	super._process(delta)
	if not TrainClock.is_running or _awaiting_upgrade:
		return

	_wave_timer += delta
	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	if alive <= 1:
		_clear_delay += delta
	else:
		_clear_delay = 0.0

	# Ao limpar a Onda 2, oferece uma escolha adicional de melhoria!
	if _wave_idx == 2 and not _mid_upgrade_offered and alive == 0:
		_mid_upgrade_offered = true
		_awaiting_upgrade = true
		upgrade_screen.open_upgrade_choices()
		await upgrade_screen.upgrade_selected
		_awaiting_upgrade = false
		_wave_timer = 0.0
		_clear_delay = 0.0
		_spawn_next_wave()
		return

	# Avança onda apenas se alive <= 1 (após 2.2s) ou após 8.0s (exceto na transição da Onda 2 que aguarda limpeza)
	if _wave_idx < 4 and _wave_idx != 2:
		if alive == 0 or _clear_delay >= 2.2 or _wave_timer >= 8.0:
			_wave_timer = 0.0
			_clear_delay = 0.0
			_spawn_next_wave()
	elif _wave_idx == 2 and _wave_timer >= 10.0 and alive <= 1:
		_mid_upgrade_offered = true
		_awaiting_upgrade = true
		upgrade_screen.open_upgrade_choices()
		await upgrade_screen.upgrade_selected
		_awaiting_upgrade = false
		_wave_timer = 0.0
		_clear_delay = 0.0
		_spawn_next_wave()

	# A porta para a cabine só destrava quando a onda final (Onda 4) for totalmente derrotada
	if _wave_idx >= 4 and not door_unlocked and alive == 0:
		hud.set_wave_info(0, 0)
		_spawn_steam_cell(Vector2(240.0, 157.0))
		unlock_exit_door()


func _spawn_next_wave() -> void:
	_wave_idx += 1
	hud.set_wave_info(_wave_idx, 4)
	match _wave_idx:
		1:
			spawn_enemy("drone", Vector2(380.0, 100.0))
			spawn_enemy("drone", Vector2(410.0, 157.0))
			spawn_enemy("drone", Vector2(380.0, 215.0))
		2:
			spawn_enemy("sentinel", Vector2(390.0, 110.0))
			spawn_enemy("sentinel", Vector2(390.0, 200.0))
			spawn_enemy("wrench", Vector2(420.0, 157.0))
		3:
			spawn_enemy("turret", Vector2(240.0, 157.0))
			spawn_enemy("sniper", Vector2(410.0, 105.0))
			spawn_enemy("sniper", Vector2(410.0, 210.0))
		4:
			spawn_enemy("wrench", Vector2(100.0, 110.0))
			spawn_enemy("wrench", Vector2(100.0, 200.0))
			spawn_enemy("wrench", Vector2(410.0, 157.0))
			spawn_enemy("drone", Vector2(350.0, 100.0))
			spawn_enemy("drone", Vector2(350.0, 215.0))
