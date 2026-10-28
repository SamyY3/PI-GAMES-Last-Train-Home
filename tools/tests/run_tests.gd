extends SceneTree

class Runner extends Node:
	var failures: int = 0
	var checks: int = 0
	var gs: Node
	var clock: Node
	var bm: Node
	var modals: Node
	var backups: Dictionary = {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		gs = get_node("/root/GameState")
		clock = get_node("/root/TrainClock")
		bm = get_node("/root/BulletManager")
		modals = get_node("/root/Modals")
		for path in ["user://settings.cfg", "user://stats.cfg"]:
			backups[path] = null
			if FileAccess.file_exists(path):
				backups[path] = FileAccess.get_file_as_bytes(path)
		await get_tree().process_frame
		for t in ["test_clock_format", "test_rubber_band", "test_disarm_countdown", "test_checkpoint",
				"test_caldeira", "test_upgrade_values", "test_card_roll", "test_bullet_pool",
				"test_audio_buses", "test_modals", "test_run_time_freeze", "test_debug_gate"]:
			await call(t)
		await test_dash_cooldown()
		_restore_user_files()
		print("%d verificações, %d falhas" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)

	func _restore_user_files() -> void:
		for path in backups:
			if backups[path] == null:
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			else:
				var f := FileAccess.open(path, FileAccess.WRITE)
				f.store_buffer(backups[path])
				f.close()

	func expect(cond: bool, what: String) -> void:
		checks += 1
		if not cond:
			failures += 1
			printerr("FALHOU: ", what)

	func test_clock_format() -> void:
		clock.is_disarmed = false
		clock.time_left = 125.0
		expect(clock.format_time() == "02:05", "format_time 125s")
		clock.time_left = 5.43
		expect(clock.format_time() == "00:05.4", "format_time abaixo de 10s")
		expect(clock.format_seconds(61.9) == "1:01", "format_seconds")

	func test_rubber_band() -> void:
		for diff in ["easy", "medium", "hard"]:
			gs.start_new_run(diff)
			clock.set_time(999.0)
			clock.reserve = 0.0
			clock.apply_section_rubber_band("wagon_2")
			var scale: float = float(gs.get_difficulty_config().get("target_scale", 1.0))
			var target: float = float(gs.balance_data["clock_targets_medium"]["wagon_2"]) * scale
			expect(is_equal_approx(clock.time_left, target), "rubber band %s corta para o alvo" % diff)
			expect(is_equal_approx(clock.reserve, 999.0 - target), "rubber band %s guarda o excedente" % diff)

	func test_disarm_countdown() -> void:
		clock.set_time(40.0)
		clock.set_disarmed_countdown()
		expect(clock.is_disarmed and is_equal_approx(clock.time_left, 3.0) and clock.is_running, "contagem do desarme em 3s")
		clock.is_running = false
		clock.is_disarmed = false

	func test_checkpoint() -> void:
		gs.start_new_run("medium")
		gs.current_hp = 1
		gs.kills = 7
		gs.save_wagon_checkpoint()
		gs.kills = 30
		gs.add_upgrade("dano")
		var deaths: int = gs.deaths_in_run
		gs.restore_wagon_checkpoint()
		expect(gs.current_hp == 3, "checkpoint restaura com piso de 3 corações")
		expect(gs.get_upgrade_level("dano") == 0, "checkpoint desfaz melhorias")
		expect(gs.kills == 7, "checkpoint restaura abates")
		expect(gs.deaths_in_run == deaths + 1, "reiniciar conta uma morte")

	func test_caldeira() -> void:
		gs.start_new_run("medium")
		var hp0: int = gs.max_hp
		gs.current_hp = 2
		gs.add_upgrade("caldeira")
		expect(gs.max_hp == hp0 + 1 and gs.current_hp == 3, "caldeira dá +1 coração e cura 1")

	func test_upgrade_values() -> void:
		gs.start_new_run("medium")
		expect(gs.get_upgrade_value("dano") == 0.0, "valor sem a carta usa o padrão")
		gs.add_upgrade("dano")
		gs.add_upgrade("dano")
		expect(is_equal_approx(gs.get_upgrade_value("dano"), 0.5), "dano Nv 2 = 0,5")
		gs.add_upgrade("escudo")
		expect(is_equal_approx(gs.get_upgrade_value("escudo", 20.0), 20.0), "escudo Nv 1 = 20s")
		gs.add_upgrade("escudo")
		expect(is_equal_approx(gs.get_upgrade_value("escudo", 20.0), 16.0), "escudo Nv 2 = 16s")
		gs.add_upgrade("valvula")
		gs.add_upgrade("valvula")
		expect(is_equal_approx(gs.get_upgrade_value("valvula"), 0.5), "valvula Nv 2 = 0,5")

	func test_card_roll() -> void:
		var us: Node = load("res://scenes/ui/UpgradeScreen.tscn").instantiate()
		get_tree().root.add_child(us)
		await get_tree().process_frame
		for run in range(30):
			gs.start_new_run("medium")
			gs.add_upgrade("ricochete")
			us._roll_three_cards(false)
			var ids: Array = []
			for c in us._cards_data:
				ids.append(String(c.get("id")))
			expect(ids.size() == 3, "três cartas")
			expect(not ids.has("ricochete"), "carta no nível máximo não aparece")
			var unique: Dictionary = {}
			for id in ids:
				unique[id] = true
			expect(unique.size() == ids.size(), "sem cartas repetidas")
			var has_atk: bool = false
			for c in us._cards_data:
				if String(c.get("category")) == "Ataque" and String(c.get("rarity")) != "cursed":
					has_atk = true
			expect(has_atk, "primeira oferta inclui Ataque não amaldiçoado")
			us._roll_three_cards(true)
			for c in us._cards_data:
				expect(not ids.has(String(c.get("id"))), "sortear de novo exclui as atuais")
		us.queue_free()

	func test_bullet_pool() -> void:
		bm.clear_all_bullets()
		expect(bm.get_active_count() == 0, "pool vazio após clear")
		for i in range(500):
			bm.spawn_bullet(Vector2(240.0, 150.0), Vector2.RIGHT, 0.0, false)
		expect(bm._active_enemy_count == bm.MAX_ENEMY_BULLETS, "teto de balas inimigas")
		for i in range(200):
			bm.spawn_bullet(Vector2(240.0, 150.0), Vector2.RIGHT, 0.0, true)
		expect(bm.get_active_count() == bm.POOL_SIZE, "pool cheio não estoura")
		bm.clear_all_bullets()
		expect(bm.get_active_count() == 0 and bm._active_enemy_count == 0, "clear zera contadores")
		expect(bm._free.size() == bm.POOL_SIZE, "pilha de vagas íntegra")

	func test_audio_buses() -> void:
		var settings: Node = get_node("/root/Settings")
		var idx: int = AudioServer.get_bus_index("Music")
		expect(idx != -1 and AudioServer.get_bus_index("SFX") != -1, "barramentos Music e SFX existem")
		if settings.music_volume > 0:
			expect(is_equal_approx(AudioServer.get_bus_volume_db(idx), settings.music_bus_db()), "volume salvo aplicado no boot")
		else:
			expect(AudioServer.is_bus_mute(idx), "música em 0% começa muda")

	func test_modals() -> void:
		var a := Node.new()
		var b := Node.new()
		clock.is_running = true
		modals.push(a)
		modals.push(b)
		expect(get_tree().paused and not clock.is_running, "modal pausa e para o relógio")
		modals.pop(a)
		expect(get_tree().paused, "continua pausado com outro modal aberto")
		modals.pop(b)
		expect(not get_tree().paused and clock.is_running, "último modal despausa e devolve o relógio")
		clock.is_running = false
		a.free()
		b.free()

	func test_run_time_freeze() -> void:
		gs.start_new_run("medium")
		gs.run_finished = true
		clock.is_running = true
		var t0: float = gs.active_run_time
		await get_tree().create_timer(0.2).timeout
		expect(is_equal_approx(gs.active_run_time, t0), "tempo de partida congela após o desarme")
		clock.is_running = false
		gs.run_finished = false

	func test_debug_gate() -> void:
		var dc: GDScript = load("res://scripts/systems/debug_commands.gd")
		expect(dc.enabled() == OS.is_debug_build(), "cheats seguem o tipo de build")

	func test_dash_cooldown() -> void:
		gs.start_new_run("medium")
		var p: Node2D = load("res://scenes/actors/Player.tscn").instantiate()
		get_tree().root.add_child(p)
		p.global_position = Vector2(240.0, 150.0)
		await get_tree().physics_frame
		var dashes: int = 0
		var was_dashing: bool = false
		var t: float = 0.0
		var press_t: float = 0.0
		while t < 3.0:
			await get_tree().physics_frame
			var dt: float = get_physics_process_delta_time()
			t += dt
			press_t -= dt
			if press_t <= 0.0:
				press_t = 0.125
				p._dash_buffer_timer = 0.12
			var dashing: bool = p._dash_timer > 0.0
			if dashing and not was_dashing:
				dashes += 1
			was_dashing = dashing
		expect(dashes <= 3, "dash respeita a recarga (%d dashes em 3s)" % dashes)
		expect(dashes >= 2, "dash ainda funciona (%d dashes em 3s)" % dashes)
		p.queue_free()


func _initialize() -> void:
	root.add_child.call_deferred(Runner.new())
