extends Node

var _owners: Array[Object] = []
var _clock_was_running: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func push(requester: Object) -> void:
	if _owners.has(requester):
		return
	if _owners.is_empty():
		_clock_was_running = TrainClock.is_running
	TrainClock.is_running = false
	_owners.append(requester)
	get_tree().paused = true


func pop(requester: Object) -> void:
	if not _owners.has(requester):
		return
	_owners.erase(requester)
	if _owners.is_empty():
		get_tree().paused = false
		TrainClock.is_running = _clock_was_running


func is_open() -> bool:
	return not _owners.is_empty()


func reset() -> void:
	_owners.clear()
