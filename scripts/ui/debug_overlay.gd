extends CanvasLayer

var _label: Label


func _ready() -> void:
	layer = 90
	_label = Label.new()
	_label.position = Vector2(8.0, 46.0)
	_label.visible = false
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color("#dce9ee"))
	add_child(_label)


func _process(_delta: float) -> void:
	if _label.visible:
		var enemies_cnt: int = get_tree().get_nodes_in_group("enemies").size()
		_label.text = "FPS: %d | Inimigos: %d | Clock: %s | Invencível [F3]: %s" % [
			Engine.get_frames_per_second(),
			enemies_cnt,
			TrainClock.format_time(),
			"SIM" if GameState.debug_invincible else "NÃO"
		]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_F1:
			_label.visible = not _label.visible
		KEY_F2:
			var next_w: int = GameState.current_wagon + 1
			if next_w <= 4:
				GameState.current_wagon = next_w
				SceneRouter.goto_scene("res://scenes/levels/Level_Wagon%d.tscn" % next_w)
			else:
				SceneRouter.goto_scene("res://scenes/levels/Level_Cabin.tscn")
		KEY_F3:
			GameState.debug_invincible = not GameState.debug_invincible
			_label.visible = true
		KEY_F4:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.has_method("take_damage"):
					e.take_damage(99999.0)
		KEY_F5:
			for e in get_tree().get_nodes_in_group("enemies"):
				if "hp" in e and "max_hp" in e:
					var target_hp: float = float(e.max_hp) * 0.31
					if float(e.hp) > target_hp:
						e.take_damage(float(e.hp) - target_hp)
		KEY_F6:
			if not GameState.upgrades_db.is_empty():
				var u: Dictionary = GameState.upgrades_db.pick_random()
				GameState.add_upgrade(String(u.get("id", "dano")))
