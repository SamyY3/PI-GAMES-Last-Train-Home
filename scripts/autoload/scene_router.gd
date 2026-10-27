extends CanvasLayer

var _fade_rect: ColorRect
var _is_transitioning: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.051, 0.043, 0.071, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)


func goto_scene(scene_path: String, fade_time: float = 0.35) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	BulletManager.clear_all_bullets()

	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, fade_time)
	await tw.finished

	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)

	var tw_in := create_tween()
	tw_in.tween_property(_fade_rect, "color:a", 0.0, fade_time)
	await tw_in.finished
	_is_transitioning = false
