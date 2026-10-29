extends Node

const STATS_PATH: String = "user://stats.cfg"
const GRADE_ORDER: Array[String] = ["S", "A", "B", "C"]

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(STATS_PATH)


func _save() -> void:
	var err: Error = _cfg.save(STATS_PATH)
	if err != OK:
		push_warning("Progress: falha ao salvar %s (erro %d)" % [STATS_PATH, err])


func get_best_time(diff: String) -> float:
	var t: float = float(_cfg.get_value("records", "best_time_" + diff, -1.0))
	return -1.0 if t >= 999999.0 else t


func get_best_grade(diff: String) -> String:
	return String(_cfg.get_value("records", "best_grade_" + diff, ""))


func get_total_wins() -> int:
	return int(_cfg.get_value("records", "total_wins", 0))


func get_wins(diff: String) -> int:
	return int(_cfg.get_value("records", "wins_" + diff, 0))


func get_starter_skills() -> Array:
	return GameState.balance_data.get("starter_skills", [])


func get_starter_skill(skill_id: String) -> Dictionary:
	for s in get_starter_skills():
		if String(s.get("id", "")) == skill_id:
			return s
	return {}


func is_skill_unlocked(skill: Dictionary) -> bool:
	match String(skill.get("unlock", "")):
		"win_any":
			return get_total_wins() > 0
		"win_medium":
			return get_wins("medium") + get_wins("hard") > 0
		"win_hard":
			return get_wins("hard") > 0
	return false


func get_unlocked_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for s in get_starter_skills():
		if is_skill_unlocked(s):
			ids.append(String(s.get("id", "")))
	return ids


func get_selected_skill() -> String:
	var skill_id: String = String(_cfg.get_value("profile", "story_skill", ""))
	return skill_id if get_unlocked_skill_ids().has(skill_id) else ""


func set_selected_skill(skill_id: String) -> void:
	_cfg.set_value("profile", "story_skill", skill_id)
	_save()


func is_combo_discovered(combo_id: String) -> bool:
	return Array(_cfg.get_value("profile", "combos", [])).has(combo_id)


func get_discovered_combo_count() -> int:
	return Array(_cfg.get_value("profile", "combos", [])).size()


func mark_combo(combo_id: String) -> bool:
	var found: Array = Array(_cfg.get_value("profile", "combos", []))
	if found.has(combo_id):
		return false
	found.append(combo_id)
	_cfg.set_value("profile", "combos", found)
	_save()
	return true


func daily_key() -> String:
	return Time.get_date_string_from_system()


func daily_label() -> String:
	var parts: PackedStringArray = daily_key().split("-")
	return "%s/%s" % [parts[2], parts[1]] if parts.size() == 3 else daily_key()


func daily_seed() -> int:
	return absi(hash("ltz-daily-" + daily_key()))


func get_daily_best() -> float:
	if String(_cfg.get_value("daily", "date", "")) != daily_key():
		return -1.0
	return float(_cfg.get_value("daily", "best_time", -1.0))


func register_win(diff: String, run_time: float, grade: String, daily: bool) -> Dictionary:
	var unlocked_before: Array[String] = get_unlocked_skill_ids()
	_cfg.set_value("records", "total_wins", get_total_wins() + 1)
	_cfg.set_value("records", "wins_" + diff, get_wins(diff) + 1)

	var new_record: bool = false
	if daily:
		var prev_daily: float = get_daily_best()
		if prev_daily < 0.0 or run_time < prev_daily:
			_cfg.set_value("daily", "date", daily_key())
			_cfg.set_value("daily", "best_time", run_time)
			new_record = true
	else:
		var prev: float = get_best_time(diff)
		if prev < 0.0 or run_time < prev:
			_cfg.set_value("records", "best_time_" + diff, run_time)
			new_record = true
		var prev_grade: String = get_best_grade(diff)
		if prev_grade == "" or GRADE_ORDER.find(grade) < GRADE_ORDER.find(prev_grade):
			_cfg.set_value("records", "best_grade_" + diff, grade)
	_save()

	var newly: Array[String] = []
	for skill_id in get_unlocked_skill_ids():
		if not unlocked_before.has(skill_id):
			newly.append(Malha.skill_name(skill_id))
	return {"new_record": new_record, "unlocked": newly}


func get_malha_wins() -> int:
	return int(_cfg.get_value("malha", "wins", 0))


func get_malha_best_time() -> float:
	return float(_cfg.get_value("malha", "best_time", -1.0))


func get_malha_line_wins(line_id: String) -> int:
	return int(_cfg.get_value("malha", "wins_" + line_id, 0))


func get_malha_unlocked_level() -> int:
	return int(_cfg.get_value("malha", "unlocked_level", 1))


func get_malha_level_best(level: int) -> float:
	return float(_cfg.get_value("malha", "best_time_l%d" % level, -1.0))


func register_malha_win(line_id: String, run_time: float, level: int = 1, max_level: int = 10) -> bool:
	if level >= get_malha_unlocked_level():
		_cfg.set_value("malha", "unlocked_level", mini(max_level, level + 1))
	var prev_level: float = get_malha_level_best(level)
	if prev_level < 0.0 or run_time < prev_level:
		_cfg.set_value("malha", "best_time_l%d" % level, run_time)
	_cfg.set_value("malha", "wins", get_malha_wins() + 1)
	_cfg.set_value("malha", "wins_" + line_id, get_malha_line_wins(line_id) + 1)
	var prev: float = get_malha_best_time()
	var new_record: bool = prev < 0.0 or run_time < prev
	if new_record:
		_cfg.set_value("malha", "best_time", run_time)
	_save()
	return new_record
