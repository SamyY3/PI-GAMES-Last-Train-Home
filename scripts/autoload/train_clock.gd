extends Node

var time_left: float = 390.0
var reserve: float = 0.0
var is_running: bool = false
var is_disarmed: bool = false
var _tick_accumulator: float = 0.0


func start_clock(initial_seconds: float) -> void:
	time_left = initial_seconds
	reserve = 0.0
	is_disarmed = false
	is_running = false
	_tick_accumulator = 0.0
	Events.timer_changed.emit(time_left)
	Events.reserve_changed.emit(reserve, 0.0)


func set_time(seconds: float) -> void:
	time_left = maxf(0.0, seconds)
	Events.timer_changed.emit(time_left)


func set_reserve(seconds: float) -> void:
	reserve = maxf(0.0, seconds)
	Events.reserve_changed.emit(reserve, 0.0)


func add_time(seconds: float) -> void:
	time_left += seconds
	Events.timer_changed.emit(time_left)


func clock_cost(price: float) -> float:
	return maxf(0.0, price - reserve)


func can_afford(price: float, min_left: float) -> bool:
	return time_left - clock_cost(price) >= min_left


func spend_time(price: float) -> void:
	var from_reserve: float = minf(reserve, price)
	reserve -= from_reserve
	time_left = maxf(0.0, time_left - (price - from_reserve))
	Events.timer_changed.emit(time_left)
	Events.reserve_changed.emit(reserve, -from_reserve)


func apply_section_rubber_band(section_key: String) -> void:
	var targets: Dictionary = GameState.balance_data.get("clock_targets_medium", {})
	if not targets.has(section_key):
		return
	var target_sec: float = float(targets[section_key])
	if section_key != "disarm":
		var scale: float = float(GameState.get_difficulty_config().get("target_scale", 1.0))
		target_sec *= scale

	if time_left > target_sec:
		if section_key.begins_with("wagon_"):
			var gained: float = time_left - target_sec
			reserve += gained
			Events.reserve_changed.emit(reserve, gained)
		time_left = target_sec
		Events.request_screen_shake.emit(2.0, 0.2)
		Events.timer_changed.emit(time_left)


func set_disarmed_countdown() -> void:
	is_disarmed = true
	if time_left > 3.0:
		time_left = 3.0
	is_running = true
	Events.timer_changed.emit(time_left)


func _process(delta: float) -> void:
	if not is_running:
		return

	time_left = maxf(0.0, time_left - delta)
	Events.timer_changed.emit(time_left)

	_tick_accumulator += delta
	var tick_interval: float = 1.0
	if time_left < 10.0 and not is_disarmed:
		tick_interval = 0.2
	elif time_left < 60.0 and not is_disarmed:
		tick_interval = 0.5

	if _tick_accumulator >= tick_interval:
		_tick_accumulator = 0.0
		AudioManager.play_sfx("tick")

	if time_left <= 0.0:
		is_running = false
		if not is_disarmed:
			Events.request_screen_flash.emit(0.4)
			Events.player_died.emit("bomb_exploded")


func format_seconds(seconds: float) -> String:
	var total: int = int(floor(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func format_time() -> String:
	if time_left < 10.0 and not is_disarmed:
		var secs: int = int(floor(time_left))
		var tenths: int = int(floor((time_left - float(secs)) * 10.0))
		return "00:0%d.%d" % [secs, tenths]
	var total_secs: int = int(ceil(time_left))
	var m: int = int(floor(float(total_secs) / 60.0))
	var s: int = total_secs % 60
	return "%02d:%02d" % [m, s]
