extends Node
# Gravador de sequências: godot --path . res://tools/capture/rec.tscn -- <cena> <inicio_s> <pasta_saida> <quadros> <intervalo_s> [skip] [play] [immortal] [pulse] [boss_p2|boss_p3]
# Salva quadros 480x270 (resolução nativa) em <pasta>/f_000.png...
var _skip_dialogue: bool = false
var _autoplay: bool = false
var _t: float = 0.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0]
	var start: float = float(args[1])
	var out_dir: String = args[2]
	var count: int = int(args[3])
	var interval: float = float(args[4])
	_skip_dialogue = "skip" in args
	# play: mira automática, atira sem parar e anda em zigue-zague (para clipes com ação)
	_autoplay = "play" in args
	if _autoplay:
		Settings.auto_aim = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var inst: Node = load(scene_path).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	if "immortal" in args:
		_immortal.call_deferred()
	if "pulse" in args:
		_press_ability.call_deferred(start - 0.05)
	for a in ["boss_p2", "boss_p3"]:
		if a in args:
			_boss.call_deferred(a)
	await get_tree().create_timer(start).timeout
	for i in range(count):
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.resize(480, 270, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/f_%03d.png" % [out_dir, i])
		await get_tree().create_timer(interval).timeout
	get_tree().quit()


func _process(d: float) -> void:
	_t += d
	if _autoplay and not get_tree().paused:
		Input.action_press("shoot")
		var phase: int = int(_t / 0.9) % 4
		for a in ["move_up", "move_down", "move_right", "move_left"]:
			Input.action_release(a)
		Input.action_press(["move_up", "move_right", "move_down", "move_right"][phase] if _t < 6.0 else ["move_up", "move_left", "move_down", "move_right"][phase])
	# avança diálogos automaticamente (Enter a cada ~0,4 s)
	if _skip_dialogue and Engine.get_process_frames() % 24 == 0:
		var ev := InputEventAction.new()
		ev.action = "confirm"
		ev.pressed = true
		Input.parse_input_event(ev)
		var ev2 := InputEventAction.new()
		ev2.action = "confirm"
		ev2.pressed = false
		Input.parse_input_event.call_deferred(ev2)


func _immortal() -> void:
	await get_tree().create_timer(0.5).timeout
	GameState.debug_invincible = true


func _boss(action: String) -> void:
	await get_tree().create_timer(6.5).timeout
	var boss: Node = get_tree().get_first_node_in_group("enemies")
	if boss == null or not ("max_hp" in boss):
		return
	boss.take_damage(boss.hp - boss.max_hp * 0.55)
	if action == "boss_p3":
		await get_tree().create_timer(16.0, false).timeout
		boss.take_damage(boss.hp - boss.max_hp * 0.25)


func _press_ability(at: float) -> void:
	await get_tree().create_timer(at).timeout
	Input.action_press("ability")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("ability")
