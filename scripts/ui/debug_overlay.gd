extends CanvasLayer

var _label: Label


func _ready() -> void:
	layer = 90
	if not DebugCommands.enabled():
		set_process(false)
		set_process_unhandled_input(false)
		return
	_label = Label.new()
	_label.position = Vector2(8.0, 46.0)
	_label.size = Vector2(464.0, 40.0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_outline_color", Color("#0d0b12"))
	_label.add_theme_constant_override("outline_size", 3)
	_label.visible = false
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color("#dce9ee"))
	add_child(_label)


func _process(_delta: float) -> void:
	if _label.visible:
		_label.text = "FPS: %d | Física: %.1f ms | Inimigos: %d | Balas: %d (%d inimigas) | Relógio: %s | Invencível [F3]: %s
%s" % [
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			get_tree().get_nodes_in_group("enemies").size(),
			BulletManager.get_active_count(),
			BulletManager._active_enemy_count,
			TrainClock.format_time(),
			"SIM" if GameState.debug_invincible else "NÃO",
			DebugCommands.status_text(get_tree()),
		]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	match (event as InputEventKey).keycode:
		KEY_F1:
			_label.visible = not _label.visible
		KEY_F2:
			DebugCommands.next_section(get_tree())
		KEY_F3:
			DebugCommands.toggle_invincible()
			_label.visible = true
		KEY_F4:
			DebugCommands.kill_enemies(get_tree())
		KEY_F5:
			DebugCommands.boss_next_phase(get_tree())
		KEY_F6:
			DebugCommands.random_upgrade()
		KEY_F7:
			DebugCommands.open_card_choice(get_tree())
		KEY_F8:
			DebugCommands.toggle_clock_freeze()
			_label.visible = true
		KEY_F9:
			DebugCommands.cycle_speed()
			_label.visible = true
