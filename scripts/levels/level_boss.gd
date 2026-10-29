extends LevelBase

var boss: CharacterBody2D
var cutscene: BossCutscene


func _ready() -> void:
	wagon_number = 5
	next_scene_path = "res://scenes/levels/Disarm.tscn"
	super._ready()
	if GameState.is_malha():
		Malha.on_stop_start()
	TrainClock.apply_section_rubber_band("boss_start")
	AudioManager.play_music("boss_p1_p2")
	hud.set_wagon_title("LOCOMOTIVA")
	hud.show_boss_bar(true)

	boss = preload("res://scenes/actors/Boss_Maquinista.tscn").instantiate()
	add_child(boss)
	Events.boss_phase_changed.connect(_on_boss_phase_changed)

	cutscene = BossCutscene.new()
	add_child(cutscene)
	# Apresentação do chefe: o relógio e a luta só começam depois do cartaz
	TrainClock.is_running = false
	await get_tree().process_frame
	await cutscene.play_intro(self, boss)
	TrainClock.is_running = true
	boss.start_fight()


func _on_boss_phase_changed(new_phase: int) -> void:
	if GameState.is_malha():
		return
	# cartaz da fase e, em seguida, a conversa entre o Maquinista e o Teo (o jogo segue pausado)
	await cutscene.play_phase(self, boss, new_phase)
	var talk_key: String = "boss_p%d_talk" % new_phase
	if GameState.dialogue_db.has(talk_key):
		dialogue_box.start_dialogue(talk_key)
		await dialogue_box.dialogue_finished
	if new_phase == 2:
		hud.set_contextual_tip(String(GameState.dialogue_db.get("boss_float_p2", "")))
	elif new_phase == 3:
		hud.set_contextual_tip(String(GameState.dialogue_db.get("boss_float_p3", "")))
