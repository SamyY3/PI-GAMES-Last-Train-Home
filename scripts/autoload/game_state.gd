extends Node

var balance_data: Dictionary = {}
var upgrades_db: Array = []
var rarity_weights: Dictionary = {}
var dialogue_db: Dictionary = {}

var difficulty: String = "medium"
var max_hp: int = 5
var current_hp: int = 5
var current_wagon: int = 1
var upgrades: Dictionary = {}
var rerolls_left: int = 1
var has_cargo_key: bool = false
var has_picked_first_upgrade: bool = false
var random_drops_spawned: int = 0
var debug_invincible: bool = false

var kills: int = 0
var sucata_kill_counter: int = 0
var active_run_time: float = 0.0
var deaths_in_run: int = 0
var damage_taken_in_run: int = 0
var run_seed: int = 0
var grazes: int = 0
var graze_time_this_level: float = 0.0
var fiscal_purchases: int = 0
var fiscal_met: bool = false

var checkpoint_state: Dictionary = {}


func _ready() -> void:
	_load_json_data()
	Events.enemy_died.connect(_on_enemy_died)


func _process(delta: float) -> void:
	if TrainClock.is_running:
		active_run_time += delta


func _load_json_data() -> void:
	balance_data = _read_json("res://data/balance.json")
	var upg_raw: Dictionary = _read_json("res://data/upgrades.json")
	upgrades_db = upg_raw.get("upgrades", [])
	rarity_weights = upg_raw.get("rarity_weights", {"common": 60, "rare": 30, "epic": 10})
	dialogue_db = _read_json("res://data/dialogue_pt_br.json")


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func start_new_run(diff_key: String) -> void:
	difficulty = diff_key
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
	deaths_in_run = 0
	damage_taken_in_run = 0
	run_seed = randi()
	grazes = 0
	graze_time_this_level = 0.0
	fiscal_purchases = 0
	fiscal_met = false

	TrainClock.start_clock(float(diff_cfg.get("initial_time", 390.0)))
	save_wagon_checkpoint()


func get_difficulty_config() -> Dictionary:
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
		"fiscal_purchases": fiscal_purchases
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
	Events.player_healed.emit(current_hp, max_hp)


func get_fiscal_config() -> Dictionary:
	return balance_data.get("fiscal", {})


func get_fiscal_price() -> float:
	var cfg: Dictionary = get_fiscal_config()
	return float(cfg.get("base_price", 20.0)) + float(cfg.get("price_step", 5.0)) * float(fiscal_purchases)


func get_upgrade_level(upg_id: String) -> int:
	return int(upgrades.get(upg_id, 0))


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
	Events.upgrade_picked.emit(upg_id, next_lvl)


func heal_player(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)
	Events.player_healed.emit(current_hp, max_hp)


func _on_enemy_died(_pos: Vector2, _is_elite: bool) -> void:
	kills += 1
	if get_upgrade_level("sucata") > 0:
		sucata_kill_counter += 1
		if sucata_kill_counter >= 15:
			sucata_kill_counter = 0
			heal_player(1)
