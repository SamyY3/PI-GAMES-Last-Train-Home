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
		get_node("/root/Progress").set_selected_skill("")
		await get_tree().process_frame
		for t in ["test_clock_format", "test_rubber_band", "test_disarm_countdown", "test_checkpoint",
				"test_caldeira", "test_upgrade_values", "test_card_roll", "test_bullet_pool",
				"test_audio_buses", "test_modals", "test_run_time_freeze", "test_debug_gate",
				"test_malha_map", "test_malha_clock", "test_malha_cards", "test_malha_apito", "test_malha_checkpoint",
				"test_malha_curios", "test_malha_events", "test_malha_bosses",
				"test_malha_levels", "test_malha_skills", "test_malha_new_enemies", "test_bullet_freeze",
				"test_malha_xp", "test_malha_affixes", "test_malha_perks", "test_aim_assist", "test_malha_debug", "test_story_skill"]:
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

	func test_malha_map() -> void:
		var malha: Node = get_node("/root/Malha")
		for seed_i in range(40):
			gs.start_new_run("medium", false, "malha")
			gs.run_seed = seed_i * 977 + 3
			malha.start("polvora")
			var cols: Array = malha.columns
			expect(cols.size() == int(malha.data["map"]["columns"]) + 2, "malha tem colunas + estação + chefe")
			expect((cols[cols.size() - 1] as Array).size() == 1 and malha.nodes[cols[cols.size() - 1][0]]["type"] == "boss", "última parada é o chefe")
			expect((cols[cols.size() - 2] as Array).size() == 1 and malha.nodes[cols[cols.size() - 2][0]]["type"] == "station", "estação obrigatória antes do chefe")
			var incoming: Dictionary = {}
			var types: Dictionary = {}
			for n in malha.nodes:
				types[n["type"]] = true
				if int(n["col"]) < cols.size() - 1:
					expect(not (n["next"] as Array).is_empty(), "toda parada tem saída")
				for nx in n["next"]:
					incoming[int(nx)] = true
					expect(int(malha.nodes[int(nx)]["col"]) == int(n["col"]) + 1, "trilho liga colunas vizinhas")
			for n in malha.nodes:
				if int(n["col"]) > 0:
					expect(incoming.has(int(n["id"])), "toda parada tem entrada")
			for c in range(cols.size() - 1):
				for a_id in cols[c]:
					for b_id in cols[c]:
						if int(malha.nodes[a_id]["row"]) >= int(malha.nodes[b_id]["row"]):
							continue
						for x in malha.nodes[a_id]["next"]:
							for y in malha.nodes[b_id]["next"]:
								expect(int(malha.nodes[int(x)]["row"]) <= int(malha.nodes[int(y)]["row"]), "trilhos não se cruzam")
			expect(types.has("shop") and types.has("elite"), "malha tem Fiscal e elite")
			for n in malha.nodes:
				if n["type"] in ["combat", "elite"]:
					var waves: Array = malha.build_waves(n)
					expect(waves.size() >= 3, "parada de combate tem ondas")
					expect(str(waves) == str(malha.build_waves(n)), "ondas iguais ao tentar de novo")
		gs.start_new_run("medium")

	func test_malha_clock() -> void:
		gs.start_new_run("medium", false, "malha")
		get_node("/root/Malha").start("vapor")
		clock.is_running = true
		var before: float = clock.time_left
		await get_tree().create_timer(0.3).timeout
		expect(is_equal_approx(clock.time_left, before), "relógio da bomba parado na malha")
		clock.is_running = false
		gs.start_new_run("medium")
		expect(gs.mode == "story", "nova partida volta ao modo história")

	func test_malha_cards() -> void:
		var us: Node = load("res://scenes/ui/UpgradeScreen.tscn").instantiate()
		get_tree().root.add_child(us)
		await get_tree().process_frame
		var line_hits: int = 0
		var total: int = 0
		for run in range(30):
			gs.start_new_run("medium", false, "malha")
			get_node("/root/Malha").start("engrenagem")
			us._kind = "normal"
			us._roll_three_cards(false)
			var first_line: bool = false
			for c in us._cards_data:
				expect(not (String(c.get("id")) in ["freio", "sobrecarga"]), "cartas só da história ficam fora da malha")
				if String(c.get("line", "")) == "engrenagem":
					first_line = true
			expect(first_line, "primeira oferta da malha inclui a linha escolhida")
			gs.has_picked_first_upgrade = true
			for k in range(5):
				us._roll_three_cards(false)
				for c in us._cards_data:
					total += 1
					if String(c.get("line", "")) == "engrenagem":
						line_hits += 1
		expect(float(line_hits) / float(maxi(1, total)) > 0.3, "linha escolhida aparece mais (%d/%d)" % [line_hits, total])
		for run in range(10):
			gs.start_new_run("medium")
			us._roll_three_cards(false)
			for c in us._cards_data:
				expect(not (String(c.get("id")) in ["rebites", "remendo"]), "cartas da malha ficam fora da história")
		gs.start_new_run("medium", false, "malha")
		get_node("/root/Malha").start("polvora")
		gs.add_upgrade("dano")
		gs.add_upgrade("ricochete")
		us._kind = "owned"
		expect(us.has_owned_upgradable(), "há carta para afinar")
		us._roll_three_cards(false)
		var owned_ok: bool = not us._cards_data.is_empty()
		for c in us._cards_data:
			var cid: String = String(c.get("id"))
			if gs.get_upgrade_level(cid) <= 0 or gs.get_upgrade_level(cid) >= int(c.get("max_level", 1)):
				owned_ok = false
		expect(owned_ok, "afinar oferece só cartas suas abaixo do máximo")
		us._kind = "normal"
		us.queue_free()
		gs.start_new_run("medium")

	func test_malha_apito() -> void:
		var malha: Node = get_node("/root/Malha")
		gs.start_new_run("medium", false, "malha")
		malha.start("polvora")
		expect(malha.apito_tier() >= 1, "habilidade ativa desde o início")
		var base_tier: int = malha.apito_tier()
		gs.add_upgrade("dano")
		expect(malha.apito_tier() == base_tier, "carta comum não sobe a habilidade")
		gs.add_upgrade("calibre")
		expect(malha.apito_tier() == base_tier + 1, "carta de habilidade sobe o nível da habilidade")
		expect(malha.card_allowed(gs.get_upgrade_info("bombetas")), "carta de habilidade da linha pode sair")
		expect(not malha.card_allowed(gs.get_upgrade_info("leque")), "carta de habilidade de outra linha não sai")
		var cd0: float = malha.skill_cooldown_max()
		gs.add_upgrade("pressao")
		expect(malha.skill_cooldown_max() < cd0, "Pressão Contínua reduz a recarga da habilidade")
		malha.skill_cd = 0.0
		expect(malha.skill_ready(), "habilidade pronta")
		clock.is_running = true
		malha.skill_cd = 0.2
		await get_tree().create_timer(0.35).timeout
		expect(malha.skill_ready(), "habilidade recarrega com o tempo")
		clock.is_running = false
		malha.skill_cd = 3.0
		malha.on_stop_start()
		expect(malha.skill_ready(), "cada parada começa com a habilidade pronta")
		gs.start_new_run("medium")
		expect(not malha.skill_ready(), "sem habilidade escolhida, a história usa o Pulso")

	func test_story_skill() -> void:
		var malha: Node = get_node("/root/Malha")
		var prog: Node = get_node("/root/Progress")
		gs.start_new_run("medium")
		expect(malha.card_allowed(gs.get_upgrade_info("refletor")), "carta do Pulso sai sem habilidade")
		expect(not malha.card_allowed(gs.get_upgrade_info("calibre")), "carta de habilidade não sai sem habilidade")
		expect(prog.get_starter_skills().size() == 3, "três habilidades para liberar na história")
		gs.story_skill = "polvora"
		malha.reset_skill()
		expect(malha.apito_tier() == 1, "Morteiro equipado na história")
		expect(malha.skill_ready(), "habilidade pronta no começo")
		expect(not malha.card_allowed(gs.get_upgrade_info("refletor")), "Pulso Refletor não sai com o Morteiro")
		expect(not malha.card_allowed(gs.get_upgrade_info("freio")), "Freio de Emergência não sai com o Morteiro")
		expect(malha.card_allowed(gs.get_upgrade_info("calibre")), "carta do Morteiro sai na história")
		expect(gs.upgrade_in_mode(gs.get_upgrade_info("calibre")), "cartas de habilidade valem na história")
		expect(not malha.card_allowed(gs.get_upgrade_info("leque")), "carta da Torre não sai com o Morteiro")
		gs.add_upgrade("calibre")
		expect(malha.apito_tier() == 2, "carta de habilidade sobe o nível na história")
		gs.start_new_run("medium", true)
		expect(gs.story_skill == "" and malha.apito_tier() == 0, "Viagem do Dia usa o Pulso")
		gs.start_new_run("medium")

	func test_malha_levels() -> void:
		var malha: Node = get_node("/root/Malha")
		var hp_prev: float = 0.0
		for lvl in range(1, 11):
			malha.level = lvl
			gs.start_new_run("medium", false, "malha")
			var cfg: Dictionary = gs.get_difficulty_config()
			expect(float(cfg["enemy_hp_mult"]) > hp_prev, "nível %d mais difícil que o anterior" % lvl)
			hp_prev = float(cfg["enemy_hp_mult"])
			expect(gs.max_hp == int(cfg["player_hp"]), "vida inicial do nível %d" % lvl)
		var prog: Node = get_node("/root/Progress")
		var before: int = prog.get_malha_unlocked_level()
		prog.register_malha_win("polvora", 500.0, before, 10)
		expect(prog.get_malha_unlocked_level() == mini(10, before + 1), "vencer libera o próximo nível")
		prog.register_malha_win("polvora", 400.0, 1, 10)
		expect(prog.get_malha_unlocked_level() == mini(10, before + 1), "vencer nível baixo não regride")
		malha.level = 1
		gs.start_new_run("medium")

	func test_malha_skills() -> void:
		var malha: Node = get_node("/root/Malha")
		for line in ["polvora", "vapor", "engrenagem"]:
			gs.start_new_run("medium", false, "malha")
			malha.start(line)
			var lvl := Node2D.new()
			get_tree().root.add_child(lvl)
			var p: Node2D = load("res://scenes/actors/Player.tscn").instantiate()
			lvl.add_child(p)
			p.global_position = Vector2(200.0, 160.0)
			var e: Node2D = load("res://scenes/actors/Enemy_Base.tscn").instantiate()
			e.set("enemy_type", "shield")
			lvl.add_child(e)
			e.global_position = Vector2(260.0, 160.0)
			await get_tree().physics_frame
			for id in gs.upgrades_db:
				if String(id.get("skill", "")) == line:
					while gs.get_upgrade_level(String(id["id"])) < int(id.get("max_level", 1)):
						gs.add_upgrade(String(id["id"]))
			expect(malha.apito_tier() >= 5, "%s com todas as cartas de habilidade" % line)
			malha.skill_cd = 0.0
			expect(malha.use_skill(p), "%s usa a habilidade" % line)
			expect(not malha.skill_ready(), "%s entra em recarga" % line)
			for i in range(40):
				await get_tree().physics_frame
			if line == "engrenagem":
				expect(get_tree().get_nodes_in_group("skill_turrets").size() == 2, "Torre Dupla monta duas torres")
			lvl.queue_free()
			await get_tree().process_frame
		gs.start_new_run("medium")

	func test_malha_new_enemies() -> void:
		gs.start_new_run("medium", false, "malha")
		get_node("/root/Malha").start("polvora")
		var lvl := Node2D.new()
		get_tree().root.add_child(lvl)
		var p: Node2D = load("res://scenes/actors/Player.tscn").instantiate()
		lvl.add_child(p)
		p.global_position = Vector2(240.0, 200.0)
		var shield: Node2D = null
		for t in ["bomber", "shield", "spark", "flamer", "medic", "magnet"]:
			var e: Node2D = load("res://scenes/actors/Enemy_Base.tscn").instantiate()
			e.set("enemy_type", t)
			lvl.add_child(e)
			e.global_position = Vector2(240.0, 110.0)
			if t == "shield":
				shield = e
		gs.debug_invincible = true
		for i in range(240):
			await get_tree().physics_frame
		expect(bm.get_active_count() > 0, "inimigos novos atacam")
		shield.set("_shield_down_t", 0.0)
		shield.set("_facing", Vector2.DOWN)
		expect(shield.blocks_bullet(Vector2.UP * 300.0), "escudo segura tiro de frente")
		expect(not shield.blocks_bullet(Vector2.DOWN * 300.0), "escudo não segura tiro pelas costas")
		gs.debug_invincible = false
		bm.clear_all_bullets()
		lvl.queue_free()
		await get_tree().process_frame
		gs.start_new_run("medium")

	func test_malha_xp() -> void:
		var malha: Node = get_node("/root/Malha")
		gs.start_new_run("medium", false, "malha")
		malha.start("vapor")
		expect(malha.xp_level == 1 and malha.xp == 0, "começa no nível 1")
		var need: int = malha.xp_next()
		malha.add_xp(need + 1)
		expect(malha.xp_level == 2 and malha.pending_levelups == 1 and malha.xp == 1, "engrenagens sobem o nível do Teo")
		expect(malha.xp_next() > need, "próximo nível pede mais engrenagens")
		malha.add_xp(500)
		expect(malha.pending_levelups > 2, "vários níveis de uma vez viram várias escolhas")
		expect(malha.xp_value("drone", "") < malha.xp_value("drone", "veloz"), "variante rende mais engrenagens")
		gs.save_wagon_checkpoint()
		var lvl_saved: int = malha.xp_level
		malha.add_xp(500)
		gs.restore_wagon_checkpoint()
		expect(malha.xp_level == lvl_saved and malha.pending_levelups == 0, "tentar de novo restaura o nível do Teo")
		gs.start_new_run("medium")

	func test_malha_affixes() -> void:
		var malha: Node = get_node("/root/Malha")
		gs.start_new_run("medium", false, "malha")
		malha.start("polvora")
		var rng := RandomNumberGenerator.new()
		var seen: Dictionary = {}
		for i in range(400):
			var a: String = malha.roll_affix(rng, 2, true)
			seen[a] = true
		expect(seen.size() >= 4, "elites sorteiam variantes")
		var none: bool = true
		for i in range(100):
			if malha.roll_affix(rng, 0, false) != "":
				none = false
		expect(none, "começo da malha sem variantes")
		var lvl := Node2D.new()
		get_tree().root.add_child(lvl)
		var plain: Node = load("res://scenes/actors/Enemy_Base.tscn").instantiate()
		plain.set("enemy_type", "drone")
		lvl.add_child(plain)
		var armored: Node = load("res://scenes/actors/Enemy_Base.tscn").instantiate()
		armored.set("enemy_type", "drone")
		armored.set("affix", "blindado")
		lvl.add_child(armored)
		expect(float(armored.get("max_hp")) > float(plain.get("max_hp")) * 1.5, "Blindado tem mais vida")
		lvl.queue_free()
		await get_tree().process_frame
		gs.start_new_run("medium")

	func test_malha_perks() -> void:
		var malha: Node = get_node("/root/Malha")
		var prog: Node = get_node("/root/Progress")
		prog._cfg.set_value("malha", "unlocked_level", 6)
		gs.start_new_run("medium", false, "malha")
		var hp0: int = gs.max_hp
		malha.start("engrenagem")
		expect(malha.unlocked_perks().size() == 5, "5 bônus com o nível 6 liberado")
		expect(gs.max_hp == hp0 + 1, "Caldeira Reforçada dá coração")
		expect(malha.fichas >= 35, "Bolsa de Viagem dá fichas")
		expect(malha.curios.size() == 1, "Bagagem Esquecida dá um achado")
		expect(malha.skill_card_levels() == 1, "Treino da Linha dá uma carta de habilidade")
		prog._cfg.set_value("malha", "unlocked_level", 1)
		gs.start_new_run("medium")

	func test_aim_assist() -> void:
		gs.start_new_run("medium", false, "malha")
		get_node("/root/Malha").start("polvora")
		var lvl := Node2D.new()
		get_tree().root.add_child(lvl)
		var p: Node2D = load("res://scenes/actors/Player.tscn").instantiate()
		lvl.add_child(p)
		p.global_position = Vector2(200.0, 160.0)
		var e: Node2D = load("res://scenes/actors/Enemy_Base.tscn").instantiate()
		e.set("enemy_type", "drone")
		lvl.add_child(e)
		e.global_position = Vector2(300.0, 160.0) + Vector2(0.0, 30.0)
		await get_tree().process_frame
		var to_enemy: Vector2 = (e.global_position - p.global_position).normalized()
		var assisted: Vector2 = p._assisted_aim(Vector2.RIGHT)
		expect(assisted.is_equal_approx(to_enemy), "assistência gruda no inimigo perto da direção")
		var off: Vector2 = p._assisted_aim(Vector2.UP)
		expect(off.is_equal_approx(Vector2.UP), "assistência ignora inimigo fora do cone")
		lvl.queue_free()
		await get_tree().process_frame
		gs.start_new_run("medium")

	func test_malha_debug() -> void:
		var malha: Node = get_node("/root/Malha")
		var dc = load("res://scripts/systems/debug_commands.gd")
		gs.start_new_run("medium", false, "malha")
		malha.start("engrenagem")
		var f0: int = malha.fichas
		dc.malha_add_fichas(100)
		expect(malha.fichas == f0 + 100, "debug dá fichas")
		dc.malha_level_up()
		expect(malha.xp_level == 2 and malha.pending_levelups == 1, "debug sobe o nível do Teo")
		dc.malha_max_skill_cards()
		expect(malha.skill_card_levels() >= 7, "debug maximiza cartas de habilidade")
		dc.malha_all_curios()
		expect(malha.available_curios().is_empty(), "debug dá todos os achados")
		dc.malha_set_boss("relojoeiro")
		expect(malha.boss_id == "relojoeiro", "debug troca o chefe")
		expect(dc.malha_status().contains("relojoeiro"), "status da malha no F1")
		gs.start_new_run("medium")

	func test_bullet_freeze() -> void:
		bm.clear_all_bullets()
		bm.spawn_bullet(Vector2(240.0, 150.0), Vector2.RIGHT, 100.0, false)
		expect(bm.freeze_enemy_bullets() == 1, "congela balas inimigas")
		await get_tree().physics_frame
		var b = bm._pool[bm._last_idx]
		var pos: Vector2 = b.pos
		await get_tree().physics_frame
		expect(b.pos == pos, "bala congelada não anda")
		bm.release_enemy_bullets(true)
		expect(b.vel.x < 0.0, "rebobinar inverte a bala")
		bm.clear_all_bullets()

	func test_malha_checkpoint() -> void:
		var malha: Node = get_node("/root/Malha")
		gs.start_new_run("medium", false, "malha")
		malha.start("vapor")
		malha.fichas = 50
		gs.save_wagon_checkpoint()
		malha.fichas = 5
		gs.restore_wagon_checkpoint()
		expect(malha.fichas == 50, "tentar de novo restaura as fichas")
		var first: int = int(malha.available_nodes()[0])
		malha.select_node(first)
		expect(malha.available_nodes().is_empty(), "parada em andamento trava o mapa")
		malha.complete_current()
		expect(not malha.available_nodes().is_empty(), "parada concluída libera as próximas")
		gs.start_new_run("medium")

	func test_malha_curios() -> void:
		var malha: Node = get_node("/root/Malha")
		gs.start_new_run("medium", false, "malha")
		malha.start("polvora")
		expect(malha.available_curios().size() == malha.data["curios"].size(), "começa sem achados")
		var hp_before: int = gs.max_hp
		malha.add_curio("carvao")
		expect(gs.max_hp == hp_before - 1, "Carvão tira 1 coração máximo")
		expect(is_equal_approx(malha.damage_mult(), 1.2), "Carvão aumenta o dano")
		malha.add_curio("carvao")
		expect(malha.curios.count("carvao") == 1, "achado não repete")
		malha.add_curio("moeda")
		expect(malha.price(40) == 28, "Moeda Viciada barateia o Fiscal")
		malha.add_curio("bilhete")
		malha.on_stop_start()
		expect(malha.consume_bilhete() and not malha.consume_bilhete(), "Bilhete Rasgado vale uma vez por parada")
		malha.add_curio("fotografia")
		gs.save_wagon_checkpoint()
		expect(malha.consume_fotografia() and not malha.consume_fotografia(), "Fotografia vale uma vez por viagem")
		gs.restore_wagon_checkpoint()
		expect(malha.curios.has("fotografia") and not malha.fotografia_used, "tentar de novo restaura achados")
		var rolled: Array = malha.roll_curios(20)
		expect(not rolled.has("carvao") and rolled.size() == malha.available_curios().size(), "sorteio só traz achados novos")
		gs.start_new_run("medium")
		expect(not malha.has_curio("carvao") and is_equal_approx(malha.damage_mult(), 1.0), "achados não valem na história")

	func test_malha_events() -> void:
		var malha: Node = get_node("/root/Malha")
		gs.start_new_run("medium", false, "malha")
		malha.start("vapor")
		var found_event: bool = false
		for n in malha.nodes:
			if n["type"] == "event":
				found_event = true
				expect(not malha.get_event(String(n["event"])).is_empty(), "parada de evento aponta para um evento")
		for ev in malha.data["events"]:
			expect((ev["options"] as Array).size() >= 2, "evento tem escolhas")
		malha.fichas = 10
		expect(not malha.option_allowed({"requires": {"fichas": 15}}), "escolha cara fica bloqueada")
		gs.current_hp = 1
		expect(not malha.option_allowed({"requires": {"hp": 2}}), "escolha que fere exige vida")
		gs.current_hp = gs.max_hp
		var res: Dictionary = malha.resolve_effects([{"type": "fichas", "amount": 30}, {"type": "damage", "amount": 99}, {"type": "curio_choice", "count": 2}])
		expect(malha.fichas == 40, "evento dá fichas")
		expect(gs.current_hp == 1, "dano de evento nunca mata")
		expect((res["actions"] as Array).size() == 1, "escolha de achado vira ação da tela")
		var mx: int = gs.max_hp
		malha.resolve_effects([{"type": "max_hp", "amount": 1}])
		expect(gs.max_hp == mx + 1, "evento aumenta o coração máximo")
		gs.start_new_run("medium")

	func test_malha_bosses() -> void:
		var malha: Node = get_node("/root/Malha")
		for id in ["fortaleza", "sinaleiro", "relojoeiro"]:
			gs.start_new_run("medium", false, "malha")
			malha.start("polvora")
			malha.boss_id = id
			var boss_node: int = int(malha.columns[malha.columns.size() - 1][0])
			expect(malha.scene_for(boss_node) == malha.MALHA_BOSS_SCENE, "chefe novo usa a fase própria")
			var lvl := Node2D.new()
			get_tree().root.add_child(lvl)
			var b: Node = load("res://scenes/actors/Boss_Malha.tscn").instantiate()
			b.setup(id)
			lvl.add_child(b)
			await get_tree().process_frame
			expect(b.boss_name == String(malha.get_boss_def(id)["name"]), "nome do chefe %s" % id)
			if id == "fortaleza":
				var hp0: float = b.hp
				b.take_damage(100.0)
				expect(is_equal_approx(hp0 - b.hp, 30.0), "couraça da Fortaleza segura 70% do dano")
				b.set("_armored", false)
			b.take_damage(b.max_hp * (0.25 if id == "fortaleza" else 0.4))
			expect(b.phase == 2, "%s passa para a fase 2" % id)
			b.is_transitioning = false
			b.set("_armored", false)
			b.take_damage(b.max_hp * (0.2 if id == "fortaleza" else 0.3))
			expect(b.phase == 3, "%s passa para a fase 3" % id)
			for mv in ["salva", "investida", "muralha", "espiral", "fornalha", "sinal", "trilhos", "lanterna", "vermelho", "ponteiros", "tique", "badalada", "rebobinar", "eco"]:
				b.is_transitioning = false
				b.phase = 3
				b._run_move(mv)
			for i in range(30):
				await get_tree().physics_frame
			expect(bm.get_active_count() > 0, "golpes de %s disparam balas" % id)
			bm.clear_all_bullets()
			lvl.queue_free()
			await get_tree().process_frame
		malha.boss_id = "maquinista"
		expect(malha.scene_for(int(malha.columns[malha.columns.size() - 1][0])) == malha.BOSS_SCENE, "Maquinista usa a fase da história")
		gs.start_new_run("medium")

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
