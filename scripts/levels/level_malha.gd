extends LevelBase

var _node: Dictionary = {}
var _waves: Array = []
var _wave_idx: int = 0
var _wave_timer: float = 0.0
var _clear_delay: float = 0.0
var _started: bool = false
var _finished: bool = false


func _ready() -> void:
	_node = Malha.current()
	wagon_number = int(_node.get("bg", 1))
	next_scene_path = Malha.MAP_SCENE
	var bg_def: Dictionary = Malha.get_background(wagon_number)
	var bg := get_node_or_null("Background") as Sprite2D
	if bg != null and ResourceLoader.exists(String(bg_def.get("texture", ""))):
		bg.texture = load(String(bg_def["texture"]))
	super._ready()
	Malha.on_stop_start()
	GameState.random_drops_spawned = 2
	AudioManager.play_music(String(bg_def.get("music", "wagon_1")))
	var elite: bool = String(_node.get("type", "")) == "elite"
	hud.set_wagon_title("PARADA %d/%d · %s · NÍVEL %d" % [int(_node.get("col", 0)) + 1, Malha.total_stops(), String(Malha.TYPE_NAMES.get(String(_node.get("type", "")), "")), Malha.level])
	_waves = Malha.build_waves(_node)
	hud.set_wave_info(0, _waves.size())
	hud.set_contextual_tip("Derrote todas as ondas para seguir viagem.")
	TrainClock.is_running = true
	await get_tree().create_timer(0.8, false).timeout
	if elite:
		hud.show_banner("⚠ PARADA DE ELITE ⚠")
	_started = true
	_spawn_next_wave()


func _get_modifier_id() -> String:
	return String(Malha.current().get("modifier", ""))


func _process(delta: float) -> void:
	super._process(delta)
	if not _started or _finished or not TrainClock.is_running:
		return
	_wave_timer += delta
	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	if alive <= 1:
		_clear_delay += delta
	else:
		_clear_delay = 0.0

	if _wave_idx < _waves.size():
		if alive == 0 or (_clear_delay >= 3.0 and _wave_timer >= 4.0):
			_spawn_next_wave()
	elif alive == 0:
		_finish_stop()


func _spawn_next_wave() -> void:
	_wave_idx += 1
	_wave_timer = 0.0
	_clear_delay = 0.0
	hud.set_wave_info(_wave_idx, _waves.size())
	spawn_wave(_waves[_wave_idx - 1])


func _finish_stop() -> void:
	_finished = true
	hud.set_wave_info(0, 0)
	var reward: int = Malha.stop_reward(_node)
	Malha.add_fichas(reward)
	AudioManager.play_sfx("upgrade_get")
	hud.show_banner("PARADA LIMPA! +%d FICHAS" % reward)
	await get_tree().create_timer(0.6, false).timeout
	while upgrade_screen.is_open() or Malha.pending_levelups > 0:
		await get_tree().create_timer(0.2, false).timeout
	var elite: bool = String(_node.get("type", "")) == "elite"
	upgrade_screen.open_upgrade_choices("elite" if elite else "normal")
	await upgrade_screen.upgrade_selected
	if elite:
		_spawn_steam_cell(Vector2(240.0, 157.0))
		var found: Array[String] = Malha.roll_curios(1)
		if not found.is_empty():
			Malha.add_curio(found[0])
	Malha.complete_current()
	unlock_exit_door()
	hud.set_contextual_tip("PORTA ABERTA — SIGA PARA A DIREITA ➔ (volta ao mapa)")
