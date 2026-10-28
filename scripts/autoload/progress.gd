extends Node

const STATS_PATH: String = "user://stats.cfg"
const GRADE_ORDER: Array[String] = ["S", "A", "B", "C"]

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(STATS_PATH)


func _save() -> void:
	_cfg.save(STATS_PATH)


func get_best_time(diff: String) -> float:
	var t: float = float(_cfg.get_value("records", "best_time_" + diff, -1.0))
	return -1.0 if t >= 999999.0 else t


func get_best_grade(diff: String) -> String:
	return String(_cfg.get_value("records", "best_grade_" + diff, ""))


func get_total_wins() -> int:
	return int(_cfg.get_value("records", "total_wins", 0))


func get_wins(diff: String) -> int:
	return int(_cfg.get_value("records", "wins_" + diff, 0))


func get_starter_tools() -> Array:
	return GameState.balance_data.get("starter_tools", [])


func get_tool(tool_id: String) -> Dictionary:
	for t in get_starter_tools():
		if String(t.get("id", "")) == tool_id:
			return t
	return {}


func is_tool_unlocked(tool: Dictionary) -> bool:
	match String(tool.get("unlock", "")):
		"win_any":
			return get_total_wins() > 0
		"win_medium":
			return get_wins("medium") + get_wins("hard") > 0
		"win_hard":
			return get_wins("hard") > 0
	return false


func get_unlocked_tool_ids() -> Array[String]:
	var ids: Array[String] = []
	for t in get_starter_tools():
		if is_tool_unlocked(t):
			ids.append(String(t.get("id", "")))
	return ids


func get_selected_tool() -> String:
	var tool_id: String = String(_cfg.get_value("profile", "starter_tool", ""))
	return tool_id if get_unlocked_tool_ids().has(tool_id) else ""


func set_selected_tool(tool_id: String) -> void:
	_cfg.set_value("profile", "starter_tool", tool_id)
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
	var unlocked_before: Array[String] = get_unlocked_tool_ids()
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
	for tool_id in get_unlocked_tool_ids():
		if not unlocked_before.has(tool_id):
			newly.append(String(get_tool(tool_id).get("name", tool_id)))
	return {"new_record": new_record, "unlocked": newly}
