extends Node
# Ferramenta de captura: godot --path . res://tools/capture/shot.tscn -- <cena> <segundos> <saida.png> [acao atraso]
# acao: boss_p2 | boss_p3 | boss_die — dano no boss após <atraso> s (para testar as cutscenes)
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0]
	var secs: float = float(args[1])
	var out: String = args[2]
	var inst: Node = load(scene_path).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	if args.size() >= 5:
		_do_action.call_deferred(args[3], float(args[4]))
	await get_tree().create_timer(secs).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()


func _do_action(action: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var boss: Node = get_tree().get_first_node_in_group("enemies")
	if boss == null or not ("max_hp" in boss):
		return
	match action:
		"boss_p2":
			boss.take_damage(boss.hp - boss.max_hp * 0.55)
		"boss_p3":
			boss.take_damage(boss.hp - boss.max_hp * 0.55)
			await get_tree().create_timer(5.0).timeout
			boss.take_damage(boss.hp - boss.max_hp * 0.25)
		"boss_die":
			boss.take_damage(99999999.0)
