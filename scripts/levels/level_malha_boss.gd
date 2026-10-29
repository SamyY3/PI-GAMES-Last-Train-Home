extends LevelBase

var boss: CharacterBody2D
var cutscene: BossCutscene
var _def: Dictionary = {}


func _ready() -> void:
	wagon_number = 5
	next_scene_path = Malha.MAP_SCENE
	super._ready()
	Malha.on_stop_start()
	_def = Malha.get_boss_def()
	AudioManager.play_music("boss_p1_p2")
	hud.set_wagon_title("PARADA FINAL · %s" % String(_def.get("name", "")))
	hud.set_boss_info(String(_def.get("name", "")), _def.get("phase_names", []))
	hud.show_boss_bar(true)

	boss = preload("res://scenes/actors/Boss_Malha.tscn").instantiate()
	boss.setup(Malha.boss_id)
	add_child(boss)
	Events.boss_phase_changed.connect(_on_boss_phase_changed)

	cutscene = BossCutscene.new()
	add_child(cutscene)
	TrainClock.is_running = false
	await get_tree().process_frame
	await cutscene.play_card(self, boss, {
		"tag": String(_def.get("tag", "CHEFE")),
		"name": String(_def.get("name", "")),
		"sub": String(_def.get("sub", "")),
		"art": boss.get_texture(),
		"art_scale": 2.5,
		"zoom": 2.0,
		"approach": 1.0,
		"hold": 2.4,
		"sfx_in": "whistle",
	})
	TrainClock.is_running = true
	hud.set_contextual_tip(boss.get_mechanic_tip())
	boss.start_fight()


func _on_boss_phase_changed(new_phase: int) -> void:
	if new_phase == 3:
		AudioManager.play_music("boss_p3")
	else:
		AudioManager.play_music("boss_p1_p2", 1.05)
