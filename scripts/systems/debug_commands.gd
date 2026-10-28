class_name DebugCommands

const SECTIONS: Array[String] = ["wagon_1", "wagon_2", "wagon_3", "wagon_4", "cabin", "boss", "disarm", "ending"]
const SECTION_NAMES: Dictionary = {
	"wagon_1": "Vagão 1", "wagon_2": "Vagão 2", "wagon_3": "Vagão 3", "wagon_4": "Vagão 4",
	"cabin": "Cabine", "boss": "Chefe", "disarm": "Desarme", "ending": "Final",
}
const SECTION_SCENES: Dictionary = {
	"wagon_1": "res://scenes/levels/Level_Wagon1.tscn",
	"wagon_2": "res://scenes/levels/Level_Wagon2.tscn",
	"wagon_3": "res://scenes/levels/Level_Wagon3.tscn",
	"wagon_4": "res://scenes/levels/Level_Wagon4.tscn",
	"cabin": "res://scenes/levels/Level_Cabin.tscn",
	"boss": "res://scenes/levels/Level_Boss.tscn",
	"disarm": "res://scenes/levels/Disarm.tscn",
	"ending": "res://scenes/levels/Ending.tscn",
}
const SECTION_WAGON: Dictionary = {
	"wagon_1": 1, "wagon_2": 2, "wagon_3": 3, "wagon_4": 4, "cabin": 5, "boss": 5, "disarm": 6, "ending": 6,
}
const SPEEDS: Array[float] = [1.0, 0.5, 2.0]
const MODIFIER_NAMES: Dictionary = {"": "Nenhum", "tunnel": "Túnel", "curve": "Curva", "passenger": "Passageiro"}


static func enabled() -> bool:
	return OS.is_debug_build()


static func current_section(tree: SceneTree) -> String:
	var scene: Node = tree.current_scene
	if scene == null:
		return ""
	for id in SECTION_SCENES:
		if SECTION_SCENES[id] == scene.scene_file_path:
			return id
	return ""


static func goto_section(id: String) -> void:
	if not SECTION_SCENES.has(id):
		return
	GameState.current_wagon = int(SECTION_WAGON[id])
	if id == "ending":
		_finish_run()
	SceneRouter.goto_scene(String(SECTION_SCENES[id]))


static func next_section(tree: SceneTree) -> void:
	var id: String = current_section(tree)
	match id:
		"", "ending":
			return
		"boss":
			var boss: Node = _boss(tree)
			if boss != null and not bool(boss.get("_is_dead")):
				boss.take_damage(999999.0)
			elif boss == null:
				goto_section("disarm")
		_:
			goto_section(SECTIONS[SECTIONS.find(id) + 1])


static func _finish_run() -> void:
	TrainClock.is_running = false
	GameState.run_finished = true


static func _boss(tree: SceneTree) -> Node:
	var scene: Node = tree.current_scene
	if scene == null or not ("boss" in scene):
		return null
	var boss: Node = scene.get("boss")
	return boss if is_instance_valid(boss) else null


static func has_boss(tree: SceneTree) -> bool:
	return _boss(tree) != null


static func boss_phase(tree: SceneTree, target: int) -> void:
	var boss: Node = _boss(tree)
	if boss == null or bool(boss.get("_is_dead")) or bool(boss.get("is_transitioning")):
		return
	if int(boss.get("phase")) >= target:
		return
	var key: String = "_phase%d_threshold" % target
	boss.set("hp", float(boss.get("max_hp")) * (float(boss.get(key)) - 0.01))
	Events.boss_hp_changed.emit(float(boss.get("hp")), float(boss.get("max_hp")))
	boss.call("_transition_to_phase", target)


static func boss_next_phase(tree: SceneTree) -> void:
	var boss: Node = _boss(tree)
	if boss != null:
		boss_phase(tree, int(boss.get("phase")) + 1)


static func toggle_invincible() -> void:
	GameState.debug_invincible = not GameState.debug_invincible


static func toggle_clock_freeze() -> void:
	TrainClock.debug_frozen = not TrainClock.debug_frozen


static func cycle_speed() -> void:
	var i: int = SPEEDS.find(GameState.debug_time_scale)
	GameState.debug_time_scale = SPEEDS[(i + 1) % SPEEDS.size()]
	Engine.time_scale = GameState.debug_time_scale


static func kill_enemies(tree: SceneTree) -> void:
	for e in tree.get_nodes_in_group("enemies"):
		if e.has_method("take_damage") and e != _boss(tree):
			e.take_damage(99999.0)


static func random_upgrade() -> void:
	var pool: Array = []
	for u in GameState.upgrades_db:
		var id_str: String = String(u.get("id", ""))
		if GameState.get_upgrade_level(id_str) < int(u.get("max_level", 1)):
			pool.append(id_str)
	if not pool.is_empty():
		GameState.add_upgrade(String(pool.pick_random()))


static func max_upgrades() -> void:
	for u in GameState.upgrades_db:
		if String(u.get("rarity", "")) == "cursed":
			continue
		var id_str: String = String(u.get("id", ""))
		while GameState.get_upgrade_level(id_str) < int(u.get("max_level", 1)):
			GameState.add_upgrade(id_str)


static func open_card_choice(tree: SceneTree) -> void:
	var scene: Node = tree.current_scene
	if scene == null or not ("upgrade_screen" in scene):
		return
	var screen: Node = scene.get("upgrade_screen")
	if screen != null and not Modals.is_open():
		screen.open_upgrade_choices()


static func heal_and_time() -> void:
	GameState.heal_player(GameState.max_hp)
	TrainClock.set_time(TrainClock.time_left + 30.0)


static func add_reserve() -> void:
	TrainClock.set_reserve(TrainClock.reserve + 60.0)


static func set_modifier(tree: SceneTree, modifier: String) -> void:
	var id: String = current_section(tree)
	if not id in ["wagon_2", "wagon_3", "wagon_4"]:
		return
	var w: int = int(SECTION_WAGON[id])
	if modifier == "":
		GameState.wagon_modifiers.erase(w)
	else:
		GameState.wagon_modifiers[w] = modifier
	goto_section(id)


static func status_text(tree: SceneTree) -> String:
	var id: String = current_section(tree)
	var w: int = int(SECTION_WAGON.get(id, 0))
	var modifier: String = String(GameState.wagon_modifiers.get(w, "")) if w >= 2 and w <= 4 else ""
	return "Seção: %s | Variante: %d | Modificador: %s | Seed: %d | Velocidade: %sx | Relógio: %s" % [
		String(SECTION_NAMES.get(id, "—")),
		GameState.get_wave_variant(w) + 1 if w >= 2 and w <= 4 else 1,
		String(MODIFIER_NAMES.get(modifier, modifier)),
		GameState.run_seed,
		str(GameState.debug_time_scale),
		"CONGELADO" if TrainClock.debug_frozen else "normal",
	]
