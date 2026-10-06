extends Node2D
## Fluxo principal do MVP: (menu inicial fica no menu.tscn) -> Intro -> Vagão 1 -> 2 -> 3 -> 4 -> Boss -> Desarme -> Final.
## Cada fase é uma coroutine linear (com await), então é tranquilo de editar e de estender.

const PLAYER_START := Vector2(640, 420)

var hud: HUD
var player: Player
var props: Node2D
var boss: Enemy = null
var theme_color := Color(0.2, 0.14, 0.1)
var scroll := 0.0
var ending := false
var _last_hp := -1
var _shake := 0.0
var _shake_amp := 0.0


func _ready() -> void:
	randomize()
	Game.reset()
	props = Node2D.new()
	add_child(props)
	Game.enemies_root = Node2D.new()
	add_child(Game.enemies_root)
	player = Player.new()
	player.position = PLAYER_START
	add_child(player)
	Game.player = player
	Game.bullets_root = Node2D.new()
	add_child(Game.bullets_root)
	hud = HUD.new()
	add_child(hud)
	player.died.connect(_on_player_died)
	player.hp_changed.connect(hud.set_hp)
	player.hp_changed.connect(_on_hp_changed)
	hud.set_difficulty(Game.diff())
	hud.set_hp(player.hp, player.max_hp)
	_last_hp = player.hp
	player.active = false
	_run()


func _process(delta: float) -> void:
	scroll += delta * 260.0
	queue_redraw()
	if Game.clock_on and not Game.paused and not Game.over:
		Game.time_left -= delta
		if Game.time_left <= 0.0:
			Game.time_left = 0.0
			_game_over("A bomba explodiu na Estação Zero...")
	hud.set_timer(Game.time_left)
	hud.set_dash(clampf(1.0 - player.dash_cd / maxf(0.01, 0.8 * Game.dash_mult), 0.0, 1.0))
	if is_instance_valid(boss) and not boss.dead:
		hud.set_boss(boss.hp, boss.max_hp, boss.phase)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amp * (_shake / 0.2)
		if _shake == 0.0:
			position = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if Game.over and event.keycode == KEY_R:
		get_tree().reload_current_scene()
	elif Game.over and (event.keycode == KEY_M or event.keycode == KEY_ESCAPE):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	elif not OS.is_debug_build():
		return                      # as teclas de debug só existem no editor e em builds de debug
	elif event.keycode == KEY_F1:    # DEBUG: mata todos os inimigos
		for e in get_tree().get_nodes_in_group("enemies"):
			e.t = 0.0
			e.hurt(99999.0)
	elif event.keycode == KEY_F2:    # DEBUG: +60s no relógio
		Game.time_left += 60.0
	elif event.keycode == KEY_F3:    # DEBUG: god mode
		Game.god_mode = not Game.god_mode
		hud.flash("GOD MODE: %s" % ("ON" if Game.god_mode else "OFF"), 1.0)


# =====================================================================
#  FLUXO
# =====================================================================

func _run() -> void:
	await _stage_passengers()
	if not _alive(): return
	await _stage_maintenance()
	if not _alive(): return
	await _stage_cargo()
	if not _alive(): return
	await _stage_boiler()
	if not _alive(): return
	await _stage_locomotive()
	if not _alive(): return
	await _stage_boss()
	if not _alive(): return
	await _disarm()
	if not _alive(): return
	await _ending()


func _stage_passengers() -> void:
	_set_wagon("VAGÃO 1 — PASSAGEIROS", Color(0.24, 0.16, 0.1))
	hud.set_objective("")
	await _say([
		"As luzes do trem piscam. Um alarme começa a tocar.",
		["SISTEMA", "ATENÇÃO. DESTINO: ESTAÇÃO ZERO."],
		["Mecânico", "Esse trem não para na Estação Zero... Por que estamos indo pra lá?"],
		"Sob um banco, ele encontra um dispositivo escondido: um temporizador. 15:00.",
		["Mecânico", "Quando chegarmos lá, isso vai explodir. E a Estação Zero fica colada na minha cidade..."],
		["Mecânico", "Preciso achar a bomba e desarmá-la. Antes do relógio zerar."],
	])
	Game.clock_on = true
	player.active = true

	var ps: Array = [
		_prop(Vector2(300, 260), "circle", Color(0.8, 0.6, 0.4), "Passageiro nervoso",
			[["Passageiro nervoso", "N-não deveria haver paradas hoje... não deveria!"]]),
		_prop(Vector2(640, 220), "circle", Color(0.5, 0.5, 0.7), "Passageiro calado",
			[["Passageiro calado", "..."], ["Mecânico", "Ele parece estar escondendo alguma coisa."]]),
		_prop(Vector2(980, 290), "circle", Color(0.6, 0.8, 0.5), "Passageira",
			[["Passageira", "Você também ouviu aquele barulho?"]]),
	]
	hud.set_objective("Converse com os passageiros (chegue perto e aperte E)")
	await _talk_all(ps)
	if not _alive(): return

	await _say(["CLANG!  As portas se fecham.", "Um grupo de autômatos de segurança aparece."])
	hud.set_objective("Derrote os autômatos")
	for p in ps:
		p.queue_free()
	await _run_waves([_w(3), _w(4), _w(5)])
	if not _alive(): return
	await _transition()


func _stage_maintenance() -> void:
	_set_wagon("VAGÃO 2 — MANUTENÇÃO", Color(0.16, 0.18, 0.2))
	var worker := _prop(Vector2(1000, 240), "circle", Color(0.9, 0.7, 0.2), "Funcionário",
		[["Funcionário", "Alguém invadiu o sistema do trem."],
		 ["Funcionário", "Eu vi uma pessoa carregando uma caixa para os vagões da frente."],
		 ["Mecânico", "Então a bomba provavelmente está mais adiante."]])
	hud.set_objective("Fale com o funcionário")
	await _talk_all([worker])
	if not _alive(): return

	hud.set_objective("Sobreviva! Cuidado com o vapor")
	worker.queue_free()
	for pos in [Vector2(300, 420), Vector2(640, 300), Vector2(980, 440)]:
		var h := Hazard.new()
		h.position = pos
		h.size = Vector2(140, 50)
		h.t = randf() * 2.0
		props.add_child(h)
	await _run_waves([_w(2, 1), _w(2, 2), _w(3, 2)])
	if not _alive(): return

	for h in props.get_children():
		h.queue_free()

	var woman := _prop(Vector2(640, 220), "circle", Color(0.8, 0.3, 0.6), "Mulher misteriosa")
	await _say([
		["Mulher misteriosa", "Você não vai conseguir chegar à locomotiva."],
		["Mecânico", "Por quê?"],
		["Mulher misteriosa", "Porque quem colocou a bomba já sabe que você está procurando por ela."],
		["Mulher misteriosa", "Use isso no vagão de carga."],
		"Ela entrega uma chave... e desaparece.",
	])
	Game.has_key = true
	woman.queue_free()
	await _transition()


func _stage_cargo() -> void:
	_set_wagon("VAGÃO 3 — CARGA", Color(0.2, 0.15, 0.08))
	await _say([
		"A chave abre a porta do vagão de carga.",
		["Mecânico", "A bomba está aqui... mas qual dessas caixas é a certa?"],
	])
	# o que tem em cada caixa: 1 bomba, 2 armadilhas e 3 peças mecânicas (melhoria)
	var contents: Array = ["bomb", "trap", "trap", "loot", "loot", "loot"]
	contents.shuffle()
	var crates: Array = []
	for i in 6:
		var c := _prop(Vector2(260 + (i % 3) * 380, 250 + (i / 3) * 190), "rect", Color(0.55, 0.38, 0.2), "Caixa %d" % (i + 1))
		c.size = Vector2(60, 50)
		c.id = i
		c.locked = true
		crates.append(c)

	hud.set_objective("Derrote os guardas — as caixas estão trancadas")
	await _run_waves([_w(2, 1, 1), _w(1, 2, 2)])
	if not _alive(): return

	for c in crates:
		c.locked = false
		c.queue_redraw()
	hud.set_objective("Ache a bomba! Abra as caixas (E): peças, armadilhas... e a bomba")
	while _alive() and not Game.found_bomb:
		var c: Prop = _nearest(crates.filter(func(x): return not x.opened), 70.0)
		hud.set_prompt("[E] Abrir caixa" if c else "")
		if c and Input.is_action_just_pressed("interact"):
			c.opened = true
			c.color = c.color.darkened(0.5)
			match contents[c.id]:
				"bomb":
					Game.found_bomb = true
					hud.set_prompt("")
					c.color = Color(0.9, 0.15, 0.15)
					c.label = "BOMBA"
				"trap":
					c.label = "Vazia"
					hud.flash("ARMADILHA!", 1.2)
					_spawn(Enemy.Kind.AUTOMATON)
					_spawn(Enemy.Kind.AUTOMATON)
				"loot":
					c.label = "Peça"
					hud.set_prompt("")
					await _pick_upgrade()
			c.queue_redraw()
		await get_tree().process_frame
	hud.set_prompt("")
	if not _alive(): return

	await _say([
		"A BOMBA.",
		["Mecânico", "Não dá pra desarmar daqui... o mecanismo está ligado ao sistema da locomotiva."],
		["Mecânico", "Preciso chegar à frente do trem."],
	])
	await _transition()


func _stage_boiler() -> void:
	_set_wagon("VAGÃO 4 — CALDEIRA", Color(0.22, 0.1, 0.08))
	Game.time_left = minf(Game.time_left, Game.accel_clamp())
	hud.flash("O TREM ACELERA!", 1.6)
	await _say([
		"O calor é sufocante. A caldeira roda no limite, e o trem ganha velocidade.",
	])
	var stoker := _prop(Vector2(980, 250), "circle", Color(0.9, 0.45, 0.2), "Foguista", [
		["Foguista", "Você?! Não devia estar aqui!"],
		["Mecânico", "Tem uma bomba neste trem. Preciso chegar à locomotiva!"],
		["Foguista", "Alguém mexeu na caldeira... ela vai passar do limite. Cuidado com os jatos de fogo!"],
	])
	hud.set_objective("Fale com o foguista")
	await _talk_all([stoker])
	if not _alive(): return

	stoker.queue_free()
	hud.set_objective("Sobreviva ao calor! Cuidado com o fogo")
	for pos in [Vector2(260, 300), Vector2(500, 480), Vector2(780, 300), Vector2(1020, 480)]:
		var h := Hazard.new()
		h.position = pos
		h.size = Vector2(130, 60)
		h.period = 2.8
		h.t = randf() * 2.0
		h.active_color = Color(1.0, 0.35, 0.1, 0.8)
		h.warn_color = Color(1.0, 0.85, 0.2, 0.28)
		props.add_child(h)
	await _run_waves([_w(3, 2, 2), _w(2, 3, 3), _w(4, 2, 3), _w(3, 3, 4)])
	if not _alive(): return

	for h in props.get_children():
		h.queue_free()
	await _transition()


func _stage_locomotive() -> void:
	_set_wagon("VAGÃO 5 — LOCOMOTIVA", Color(0.14, 0.12, 0.16))
	hud.set_objective("Atravesse o último trecho")
	await _run_waves([_w(4, 2, 2), _w(3, 3, 3), _w(5, 3, 3)])
	if not _alive(): return

	var door := _prop(Vector2(640, 190), "rect", Color(0.4, 0.4, 0.5), "Cabine do maquinista")
	door.size = Vector2(100, 60)
	hud.set_objective("Vá até a cabine do maquinista (E)")
	while _alive():
		var d: Prop = _nearest([door], 90.0)
		hud.set_prompt("[E] Entrar na cabine" if d else "")
		if d and Input.is_action_just_pressed("interact"):
			break
		await get_tree().process_frame
	hud.set_prompt("")
	await _transition()


func _stage_boss() -> void:
	_set_wagon("CABINE DO MAQUINISTA", Color(0.12, 0.1, 0.14))
	var m := _prop(Vector2(640, 220), "rect", Color(0.7, 0.2, 0.2), "Maquinista")
	m.size = Vector2(60, 60)
	await _say([
		["Mecânico", "Pare o trem!"],
		["Maquinista", "Não posso."],
		["Mecânico", "Por quê?"],
		["Maquinista", "Porque quando chegarmos à Estação Zero, alguém precisa morrer."],
	])
	m.queue_free()
	hud.set_objective("Derrote o Maquinista")
	boss = _spawn(Enemy.Kind.BOSS, Vector2(640, 200))
	boss.phase_changed.connect(func(p: int): hud.flash("FASE %d" % p, 1.5))
	await _wait_clear()
	boss = null
	hud.hide_boss()
	_clear_bullets()


func _disarm() -> void:
	Game.time_left = maxf(Game.time_left, 25.0)
	hud.set_objective("Desarme a bomba antes que acabe o tempo!")
	var steps := [
		["GIRAR A VÁLVULA", KEY_Q],
		["PUXAR A ALAVANCA", KEY_E],
		["CORTAR O FIO", KEY_R],
		["DESLIGAR O NÚCLEO", KEY_F],
	]
	for i in steps.size():
		hud.set_prompt("Passo %d/4 — pressione [%s] para %s" % [i + 1, OS.get_keycode_string(steps[i][1]), steps[i][0]])
		await hud.wait_key(steps[i][1])
		if not _alive(): return
	hud.set_prompt("")
	Game.clock_on = false
	Game.paused = true
	hud.set_objective("")
	for s in ["00:03", "00:02", "00:01"]:
		hud.show_center(s, 96)
		await get_tree().create_timer(0.9).timeout
	hud.show_center("...", 96)
	await get_tree().create_timer(1.6).timeout
	hud.hide_center()


func _ending() -> void:
	ending = true
	Game.paused = false
	_clear_field()
	player.visible = false
	hud.set_stage("")
	hud.set_objective("")
	await _say([
		"O trem passa pela Estação Zero. Nada acontece. Silêncio.",
		"A cidade está intacta.",
		"Ao longe, as luzes da cidade. Ele vê sua casa — e percebe que conseguiu chegar.",
	])
	hud.show_center("LAST TRAIN HOME\n\n\"Às vezes, chegar em casa significa impedir que ela desapareça.\"\n\nFIM\n\n%s\n\n[R] jogar de novo     [M] menu principal" % _stats_text(), 30)
	Game.won = true
	Game.over = true   # só pra liberar o R / M


# =====================================================================
#  HELPERS
# =====================================================================

func _alive() -> bool:
	return not Game.over


func _say(lines: Array) -> void:
	Game.paused = true
	await hud.say(lines)
	Game.paused = false


func _set_wagon(title: String, col: Color) -> void:
	theme_color = col
	hud.set_stage(title)
	_clear_field()
	player.position = PLAYER_START


func _clear_bullets() -> void:
	for b in Game.bullets_root.get_children():
		b.queue_free()


func _clear_field() -> void:
	for n in props.get_children():
		n.queue_free()
	for e in Game.enemies_root.get_children():
		e.queue_free()
	_clear_bullets()


func _transition() -> void:
	player.heal(Game.transition_heal())
	Game.restore_shield()
	Game.rerolls = mini(Game.rerolls + 1, int(Game.diff()["reroll_cap"]))
	hud.set_objective("")
	hud.flash("Avançando para o próximo vagão...", 1.2)
	await get_tree().create_timer(1.3).timeout


func _prop(pos: Vector2, shape: String, col: Color, label: String, lines: Array = []) -> Prop:
	var p := Prop.new()
	p.position = pos
	p.shape = shape
	p.color = col
	p.label = label
	p.lines = lines
	props.add_child(p)
	return p


func _nearest(list: Array, radius: float) -> Prop:
	var best: Prop = null
	var best_d := radius
	for p in list:
		if is_instance_valid(p):
			var d: float = p.position.distance_to(player.position)
			if d < best_d:
				best_d = d
				best = p
	return best


func _talk_all(list: Array) -> void:
	while _alive():
		var pending := list.filter(func(p): return not p.done)
		if pending.is_empty():
			break
		var p: Prop = _nearest(pending, 80.0)
		hud.set_prompt("[E] Conversar" if p else "")
		if p and Input.is_action_just_pressed("interact"):
			p.done = true
			hud.set_prompt("")
			await _say(p.lines)
		await get_tree().process_frame
	hud.set_prompt("")


func _spawn(kind: int, pos := Vector2.ZERO) -> Enemy:
	var e := Enemy.new()
	e.setup(kind)
	if pos == Vector2.ZERO:
		var a := Game.ARENA
		pos = Vector2(randf_range(a.position.x + 80.0, a.end.x - 80.0), randf_range(a.position.y + 60.0, a.position.y + 220.0))
	e.position = pos
	Game.enemies_root.add_child(e)
	return e


func _enemy_count() -> int:
	var n := 0
	for e in Game.enemies_root.get_children():
		if not e.dead and not e.is_queued_for_deletion():
			n += 1
	return n


func _wait_clear() -> void:
	await get_tree().create_timer(0.2).timeout
	while _alive() and _enemy_count() > 0:
		await get_tree().process_frame


func _wave_and_clear(kinds: Array) -> void:
	var list: Array = kinds.duplicate()
	if not kinds.is_empty():
		for i in Game.extra_enemies():     # dificuldade + poder da build = ondas maiores
			list.append(kinds.pick_random())
	for k in list:
		_spawn(k)
	await _wait_clear()
	_clear_bullets()


## Monta uma onda: a = autômatos, r = robôs, s = atiradores.
func _w(a := 0, r := 0, s := 0) -> Array:
	var l: Array = []
	for i in a:
		l.append(Enemy.Kind.AUTOMATON)
	for i in r:
		l.append(Enemy.Kind.ROBOT)
	for i in s:
		l.append(Enemy.Kind.SNIPER)
	return l


## Roda uma sequência de ondas; depois de cada uma o jogador escolhe 1 de 3 melhorias.
func _run_waves(waves: Array, pick_after_last := true) -> void:
	for i in waves.size():
		if not _alive():
			return
		hud.set_wave(i + 1, waves.size())
		hud.flash("ONDA %d/%d" % [i + 1, waves.size()], 0.9)
		await _wave_and_clear(waves[i])
		if not _alive():
			return
		Game.waves_cleared += 1
		if i < waves.size() - 1 or pick_after_last:
			await _pick_upgrade()
	hud.set_wave(0, 0)


## Escolha de melhoria (3 cartas, com troca no [R]) + o banner colorido quando pega.
func _pick_upgrade() -> void:
	Game.paused = true
	while true:
		var ids: Array = Game.roll_choices(3)
		if ids.is_empty():
			break
		var idx: int = await hud.choose("ESCOLHA UMA MELHORIA", ids, Game.rerolls)
		if idx < 0:
			Game.rerolls -= 1
			continue
		var picked: String = ids[idx]
		Game.apply_upgrade(picked)
		hud.upgrade_banner(Game.info(picked))
		hud.set_build(Game.build_entries())
		break
	Game.paused = false


func _stats_text() -> String:
	return "Dificuldade: %s   •   Ondas: %d   •   Abates: %d   •   Tempo restante: %s" % [
		Game.diff()["name"], Game.waves_cleared, Game.kills, _fmt_time(Game.time_left)]


func _fmt_time(t: float) -> String:
	var sec := int(ceilf(maxf(t, 0.0)))
	return "%02d:%02d" % [sec / 60, sec % 60]


func _on_hp_changed(hp: int, _max_hp: int) -> void:
	if hp < _last_hp:                 # tomou dano de verdade: sacode a tela
		_shake = 0.2
		_shake_amp = 6.0
	_last_hp = hp


func _on_player_died() -> void:
	_game_over("O mecânico não conseguiu salvar a cidade...")


func _game_over(msg: String) -> void:
	if Game.over:
		return
	Game.over = true
	player.active = false
	hud.set_prompt("")
	hud.show_center("GAME OVER\n\n%s\n\n%s\n\n[R] tentar de novo     [M] menu principal" % [msg, _stats_text()], 32)


# =====================================================================
#  CENÁRIO (trem placeholder)
# =====================================================================

func _draw() -> void:
	var a := Game.ARENA
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.03, 0.05))
	# faixa de janelas com a paisagem passando
	draw_rect(Rect2(a.position.x, 18, a.size.x, 80), Color(0.06, 0.1, 0.18))
	if ending:
		for i in 40:
			var x := a.position.x + fposmod(i * 97.0, a.size.x)
			var y := 30.0 + fposmod(i * 53.0, 60.0)
			draw_circle(Vector2(x, y), 2.5, Color(1.0, 0.9, 0.5))
	else:
		for i in 14:
			var x := a.position.x + fposmod(i * 90.0 - scroll, a.size.x - 30.0)
			draw_rect(Rect2(x, 36, 30, 44), Color(0.12, 0.17, 0.26))
	# piso
	draw_rect(a, theme_color)
	var x2 := a.position.x
	while x2 < a.end.x:
		draw_line(Vector2(x2, a.position.y), Vector2(x2, a.end.y), Color(0, 0, 0, 0.18), 2.0)
		x2 += 80.0
	draw_rect(a, Color(0.65, 0.48, 0.2), false, 4.0)
