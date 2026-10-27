extends LevelBase


func _ready() -> void:
	wagon_number = 5
	next_scene_path = "res://scenes/levels/Level_Boss.tscn"
	super._ready()
	TrainClock.apply_section_rubber_band("cabin")
	TrainClock.is_running = false
	hud.set_wagon_title("LOCOMOTIVA")

	player.global_position = Vector2(180.0, 157.0)
	dialogue_box.start_dialogue("cabin_intro")
	await dialogue_box.dialogue_finished

	Events.request_screen_shake.emit(3.0, 0.8)
	AudioManager.play_sfx("clang")
	await get_tree().create_timer(1.2).timeout
	SceneRouter.goto_scene(next_scene_path)
