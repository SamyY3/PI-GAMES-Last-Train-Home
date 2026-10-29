extends Node

var balance_data: Dictionary = {}
var upgrades_db: Array = []
var combos_db: Array = []
var rarity_weights: Dictionary = {}
var dialogue_db: Dictionary = {}

var difficulty: String = "medium"
var mode: String = "story"
var max_hp: int = 5
var current_hp: int = 5
var current_wagon: int = 1
var upgrades: Dictionary = {}
var rerolls_left: int = 1
var has_cargo_key: bool = false
var has_picked_first_upgrade: bool = false
var random_drops_spawned: int = 0
var debug_invincible: bool = false
var debug_time_scale: float = 1.0

var kills: int = 0
var sucata_kill_counter: int = 0
var active_run_time: float = 0.0
var run_finished: bool = false
var deaths_in_run: int = 0
var damage_taken_in_run: int = 0
var run_seed: int = 0
var grazes: int = 0
var graze_time_this_level: float = 0.0
var fiscal_purchases: int = 0
var fiscal_met: bool = false
var is_daily: bool = false
var story_skill: String = ""
var wave_variants: Dictionary = {}
var wagon_modifiers: Dictionary = {}
var run_rng := RandomNumberGenerator.new()
var card_rng := RandomNumberGenerator.new()

const WAVE_VARIANT_COUNTS: Dictionary = {2: 3, 3: 2, 4: 3}
const MODIFIER_IDS: Array[String] = ["tunnel", "curve", "passenger"]

var checkpoint_state: Dictionary = {}


func _ready() -> void:
	_load_json_data()
	Events.enemy_died.connect(_on_enemy_died)


func _process(delta: float) -> void:
	if TrainClock.is_running and not run_finished:
		active_run_time += delta


func _load_json_data() -> void:
	balance_data = _read_json("res://data/balance.json")
	var upg_raw: Dictionary = _read_json("res://data/upgrades.json")
	upgrades_db = upg_raw.get("upgrades", [])
	combos_db = upg_raw.get("combos", [])
	rarity_weights = upg_raw.get("rarity_weights", {"common": 60, "rare": 30, "epic": 10})
	dialogue_db = _read_json("res://data/dialogue_pt_br.json")


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("GameState: arquivo de dados ausente: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("GameState: JSON inválido em %s" % path)
	return {}


func start_new_run(diff_key: String, daily: bool = false, run_mode: String = "story") -> void:
	difficulty = diff_key
	mode = run_mode
	Settings.last_difficulty = diff_key
	Settings.save_settings()

	var diff_cfg: Dictionary = get_difficulty_config()
	max_hp = int(diff_cfg.get("player_hp", 5))
	current_hp = max_hp
	current_wagon = 1
	upgrades.clear()
	rerolls_left = 1
	has_cargo_key = false
	has_picked_first_upgrade = false
	random_drops_spawned = 0
	kills = 0
	sucata_kill_counter = 0
	active_run_time = 0.0
	run_finished = false
	deaths_in_run = 0
	damage_taken_in_run = 0
	is_daily = daily
	run_seed = Progress.daily_seed() if daily else randi()
	run_rng.seed = run_seed
	card_rng.seed = run_seed + 7919
	_roll_run_structure()
	grazes = 0
	graze_time_this_level = 0.0
	fiscal_purchases = 0
	fiscal_met = false

	TrainClock.start_clock(float(diff_cfg.get("initial_time", 390.0)))
	story_skill = "" if daily or run_mode != "story" else Progress.get_selected_skill()
	Malha.reset_skill()
	save_wagon_checkpoint()


func _roll_run_structure() -> void:
	wave_variants.clear()
	for w in WAVE_VARIANT_COUNTS.keys():
		wave_variants[w] = run_rng.randi_range(0, int(WAVE_VARIANT_COUNTS[w]) - 1)

	wagon_modifiers.clear()
	var pool: Array[String] = MODIFIER_IDS.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = run_rng.randi_range(0, i)
		var tmp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var chance: float = float(balance_data.get("wagon_modifiers", {}).get("chance", 0.7))
	for i in range(3):
		if run_rng.randf() < chance:
			wagon_modifiers[i + 2] = pool[i]
	if wagon_modifiers.is_empty():
		wagon_modifiers[run_rng.randi_range(2, 4)] = pool[0]


func get_wave_variant(wagon: int) -> int:
	return int(wave_variants.get(wagon, 0))


func get_wagon_modifier(wagon: int) -> String:
	return String(wagon_modifiers.get(wagon, ""))


func get_difficulty_config() -> Dictionary:
	if is_malha():
		var lvl: Dictionary = Malha.level_config()
		if not lvl.is_empty():
			return lvl
	var diffs: Dictionary = balance_data.get("difficulties", {})
	return diffs.get(difficulty, diffs.get("medium", {}))


func save_wagon_checkpoint() -> void:
	checkpoint_state = {
		"max_hp": max_hp,
		"current_hp": current_hp,
		"upgrades": upgrades.duplicate(true),
		"rerolls_left": rerolls_left,
		"has_cargo_key": has_cargo_key,
		"has_picked_first_upgrade": has_picked_first_upgrade,
		"clock_time": TrainClock.time_left,
		"reserve": TrainClock.reserve,
		"fiscal_purchases": fiscal_purchases,
		"kills": kills,
		"sucata_kill_counter": sucata_kill_counter,
		"malha": Malha.snapshot() if is_malha() else {}
	}


func restore_wagon_checkpoint() -> void:
	if checkpoint_state.is_empty():
		return
	deaths_in_run += 1
	max_hp = int(checkpoint_state["max_hp"])
	# Garante piso mínimo de 3 corações ao reiniciar do checkpoint
	current_hp = mini(max_hp, maxi(int(checkpoint_state["current_hp"]), 3))
	upgrades = (checkpoint_state["upgrades"] as Dictionary).duplicate(true)
	rerolls_left = int(checkpoint_state["rerolls_left"])
	has_cargo_key = bool(checkpoint_state["has_cargo_key"])
	has_picked_first_upgrade = bool(checkpoint_state.get("has_picked_first_upgrade", false))
	TrainClock.set_time(float(checkpoint_state["clock_time"]))
	TrainClock.set_reserve(float(checkpoint_state.get("reserve", 0.0)))
	fiscal_purchases = int(checkpoint_state.get("fiscal_purchases", 0))
	kills = int(checkpoint_state.get("kills", kills))
	sucata_kill_counter = int(checkpoint_state.get("sucata_kill_counter", 0))
	if is_malha():
		Malha.restore(checkpoint_state.get("malha", {}))
	Events.player_healed.emit(current_hp, max_hp)


func is_malha() -> bool:
	return mode == "malha"


func upgrade_in_mode(item: Dictionary) -> bool:
	var modes: Array = item.get("modes", [])
	return modes.is_empty() or modes.has(mode)


func get_fiscal_config() -> Dictionary:
	return balance_data.get("fiscal", {})


func get_fiscal_price() -> float:
	var cfg: Dictionary = get_fiscal_config()
	return float(cfg.get("base_price", 20.0)) + float(cfg.get("price_step", 5.0)) * float(fiscal_purchases)


func get_upgrade_level(upg_id: String) -> int:
	return int(upgrades.get(upg_id, 0))


func get_upgrade_value(upg_id: String, default_value: float = 0.0) -> float:
	var lvl: int = get_upgrade_level(upg_id)
	if lvl <= 0:
		return default_value
	var values: Array = get_upgrade_info(upg_id).get("values", [])
	if values.is_empty():
		return default_value
	return float(values[mini(lvl, values.size()) - 1])


func get_upgrade_info(upg_id: String) -> Dictionary:
	for u in upgrades_db:
		if u is Dictionary and String(u.get("id", "")) == upg_id:
			return u
	return {"id": upg_id, "name": upg_id.to_upper(), "description": ""}


func add_upgrade(upg_id: String) -> void:
	var next_lvl: int = get_upgrade_level(upg_id) + 1
	upgrades[upg_id] = next_lvl
	if upg_id == "caldeira":
		max_hp += 1
		heal_player(1)
	elif upg_id == "freio":
		max_hp = maxi(1, max_hp - 1)
		current_hp = mini(current_hp, max_hp)
		Events.player_hit.emit(current_hp, max_hp)
	Events.upgrade_picked.emit(upg_id, next_lvl)
	for combo in combos_db:
		var requires: Array = combo.get("requires", [])
		if requires.has(upg_id) and next_lvl == 1 and has_combo(String(combo.get("id", ""))):
			var first_time: bool = Progress.mark_combo(String(combo.get("id", "")))
			Events.combo_discovered.emit(String(combo.get("id", "")), first_time)


func has_combo(combo_id: String) -> bool:
	for combo in combos_db:
		if String(combo.get("id", "")) == combo_id:
			for req in combo.get("requires", []):
				if get_upgrade_level(String(req)) <= 0:
					return false
			return true
	return false


func get_combo_info(combo_id: String) -> Dictionary:
	for combo in combos_db:
		if String(combo.get("id", "")) == combo_id:
			return combo
	return {}


func heal_player(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)
	Events.player_healed.emit(current_hp, max_hp)


func _on_enemy_died(_pos: Vector2, _is_elite: bool) -> void:
	kills += 1
	if get_upgrade_level("sucata") > 0:
		sucata_kill_counter += 1
		if sucata_kill_counter >= int(get_upgrade_value("sucata", 15.0)):
			sucata_kill_counter = 0
			heal_player(1)
