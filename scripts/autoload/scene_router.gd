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


func goto_scene(scene_path: String, fade_time: float = 0.35, on_swap: Callable = Callable()) -> bool:
	if _is_transitioning:
		push_warning("SceneRouter: troca para %s ignorada (transição em andamento)" % scene_path)
		return false
	_is_transitioning = true
	Engine.time_scale = GameState.debug_time_scale
	get_tree().paused = true
	BulletManager.clear_all_bullets()

	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, fade_time)
	await tw.finished

	if on_swap.is_valid():
		on_swap.call()
	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: falha ao abrir %s (erro %d)" % [scene_path, err])
	BulletManager.clear_all_bullets()
	Modals.reset()
	get_tree().paused = false

	var tw_in := create_tween()
	tw_in.tween_property(_fade_rect, "color:a", 0.0, fade_time)
	await tw_in.finished
	_is_transitioning = false
	return true
