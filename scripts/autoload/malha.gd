extends Node

const MAP_SCENE: String = "res://scenes/malha/MalhaMap.tscn"
const STOP_SCENE: String = "res://scenes/levels/Level_Malha.tscn"
const BOSS_SCENE: String = "res://scenes/levels/Level_Boss.tscn"
const MALHA_BOSS_SCENE: String = "res://scenes/levels/Level_MalhaBoss.tscn"
const TYPE_NAMES: Dictionary = {
	"combat": "COMBATE",
	"elite": "ELITE",
	"shop": "FISCAL",
	"rest": "DORMITÓRIO",
	"event": "EVENTO",
	"station": "ESTAÇÃO",
	"boss": "CHEFE",
}

var data: Dictionary = {}
var line_id: String = ""
var level: int = 1
var nodes: Array[Dictionary] = []
var columns: Array = []
var current_node: int = -1
var path: Array[int] = []
var fichas: int = 0
var skill_cd: float = 0.0
var xp: int = 0
var xp_level: int = 1
var pending_levelups: int = 0
var perks: Array[String] = []
var boss_id: String = "maquinista"
var victory: bool = false
var victory_registered: bool = false
var new_record: bool = false
var map_rng := RandomNumberGenerator.new()
var loot_rng := RandomNumberGenerator.new()
var curios: Array[String] = []
var bilhete_ready: bool = false
var fotografia_used: bool = false
var _apito_tier_seen: int = 0


func _ready() -> void:
	data = GameState._read_json("res://data/malha.json")
	Events.upgrade_picked.connect(_on_upgrade_picked)
	Events.enemy_died.connect(_on_enemy_died_curios)


func is_active() -> bool:
	return GameState.mode == "malha"


func start(line: String) -> void:
	line_id = line
	fichas = int(get_economy().get("start_fichas", 20))
	skill_cd = 0.0
	xp = 0
	xp_level = 1
	pending_levelups = 0
	current_node = -1
	path.clear()
	victory = false
	victory_registered = false
	new_record = false
	map_rng.seed = GameState.run_seed + 104729
	loot_rng.seed = GameState.run_seed + 130363
	curios.clear()
	bilhete_ready = false
	fotografia_used = false
	var bosses: Array = data.get("bosses", ["maquinista"])
	boss_id = String(bosses[map_rng.randi_range(0, bosses.size() - 1)])
	generate_map()
	_apply_perks()
	_apito_tier_seen = apito_tier()


func get_economy() -> Dictionary:
	return data.get("economy", {})


func get_apito_cfg() -> Dictionary:
	return data.get("apito", {})


func get_lines() -> Array:
	return data.get("lines", [])


func get_line(id: String = "") -> Dictionary:
	var wanted: String = line_id if id == "" else id
	for l in get_lines():
		if String(l.get("id", "")) == wanted:
			return l
	return {}


func get_line_color(id: String = "") -> Color:
	return Color(String(get_line(id).get("color", "#fff1c9")))


func generate_map() -> void:
	nodes.clear()
	columns.clear()
	var cfg: Dictionary = data.get("map", {})
	var col_count: int = int(cfg.get("columns", 8))
	var col_types: Array = cfg.get("column_types", [])
	var min_rows: int = int(cfg.get("min_rows", 2))
	var max_rows: int = int(cfg.get("max_rows", 4))
	var mod_chance: float = float(cfg.get("modifier_chance", 0.4))

	var bg_count: int = (data.get("backgrounds", []) as Array).size()
	for c in range(col_count + 2):
		var ids: Array[int] = []
		var count: int = 1 if c >= col_count else map_rng.randi_range(min_rows, max_rows)
		for r in range(count):
			var type: String = "boss" if c == col_count + 1 else "station"
			if c < col_count:
				type = _roll_type(col_types[mini(c, col_types.size() - 1)])
			var modifier: String = ""
			if type in ["combat", "elite"] and c >= 1 and map_rng.randf() < mod_chance:
				modifier = GameState.MODIFIER_IDS[map_rng.randi_range(0, GameState.MODIFIER_IDS.size() - 1)]
			var event_id: String = ""
			if type == "event":
				var evs: Array = data.get("events", [])
				event_id = String(evs[map_rng.randi_range(0, evs.size() - 1)].get("id", ""))
			var node := {
				"id": nodes.size(),
				"col": c,
				"row": r,
				"rows": count,
				"type": type,
				"next": [],
				"done": false,
				"bg": map_rng.randi_range(1, maxi(4, bg_count)),
				"modifier": modifier,
				"event": event_id,
				"seed": map_rng.randi(),
			}
			ids.append(nodes.size())
			nodes.append(node)
		columns.append(ids)

	for c in range(col_count + 1):
		_link_columns(columns[c], columns[c + 1])
	_ensure_type_variety()


func _roll_type(weights: Dictionary) -> String:
	var total: float = 0.0
	for k in weights:
		total += float(weights[k])
	var roll: float = map_rng.randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return String(k)
	return String(weights.keys()[0])


func _link_columns(a: Array[int], b: Array[int]) -> void:
	var i: int = 0
	var j: int = 0
	_add_edge(a[0], b[0])
	while i < a.size() - 1 or j < b.size() - 1:
		if i == a.size() - 1:
			j += 1
		elif j == b.size() - 1:
			i += 1
		else:
			var next_a: float = float(i + 1) / float(a.size())
			var next_b: float = float(j + 1) / float(b.size())
			if absf(next_a - next_b) < 0.08 or map_rng.randf() < 0.25:
				i += 1
				j += 1
			elif next_a < next_b:
				i += 1
			else:
				j += 1
		_add_edge(a[i], b[j])


func _add_edge(from_id: int, to_id: int) -> void:
	var nexts: Array = nodes[from_id]["next"]
	if not nexts.has(to_id):
		nexts.append(to_id)


func _ensure_type_variety() -> void:
	for wanted in [["shop", 2, 6], ["elite", 3, 6]]:
		var found: bool = false
		for n in nodes:
			if n["type"] == wanted[0]:
				found = true
				break
		if not found:
			var col: Array = columns[map_rng.randi_range(int(wanted[1]), int(wanted[2]))]
			var pick: Dictionary = nodes[col[map_rng.randi_range(0, col.size() - 1)]]
			pick["type"] = wanted[0]
			if wanted[0] == "shop":
				pick["modifier"] = ""


func get_node_data(id: int) -> Dictionary:
	return nodes[id] if id >= 0 and id < nodes.size() else {}


func current() -> Dictionary:
	return get_node_data(current_node)


func current_column() -> int:
	return int(current().get("col", -1))


func total_stops() -> int:
	return columns.size()


func available_nodes() -> Array[int]:
	var out: Array[int] = []
	if victory:
		return out
	if current_node < 0:
		for id in columns[0]:
			out.append(int(id))
		return out
	var cur: Dictionary = current()
	if not bool(cur.get("done", false)):
		return out
	for id in cur.get("next", []):
		out.append(int(id))
	return out


func select_node(id: int) -> void:
	current_node = id
	path.append(id)


func scene_for(id: int) -> String:
	match String(get_node_data(id).get("type", "")):
		"combat", "elite":
			return STOP_SCENE
		"boss":
			return BOSS_SCENE if boss_id == "maquinista" else MALHA_BOSS_SCENE
	return ""


func complete_current() -> void:
	var cur: Dictionary = current()
	if cur.is_empty() or bool(cur.get("done", false)):
		return
	cur["done"] = true
	if cur.get("type", "") in ["combat", "elite"]:
		var remendo: int = int(GameState.get_upgrade_value("remendo"))
		if remendo > 0:
			GameState.heal_player(remendo)
	if cur.get("type", "") == "boss":
		victory = true
		GameState.run_finished = true
		TrainClock.is_running = false


func stop_reward(node: Dictionary) -> int:
	var eco: Dictionary = get_economy()
	var col: int = int(node.get("col", 0))
	if String(node.get("type", "")) == "elite":
		return int(eco.get("elite_reward", 35)) + int(eco.get("elite_reward_per_column", 3)) * col
	return int(eco.get("combat_reward", 15)) + int(eco.get("combat_reward_per_column", 2)) * col


func add_fichas(amount: int) -> void:
	fichas = maxi(0, fichas + amount)


func can_afford(cost: int) -> bool:
	return fichas >= cost


func spend(cost: int) -> bool:
	if fichas < cost:
		return false
	fichas -= cost
	return true


func tier_for_column(col: int) -> int:
	return clampi(floori(float(col) / 3.0), 0, 2)


func enemy_hp_scale() -> float:
	if not is_active():
		return 1.0
	var mult: float = 1.0 + float(data.get("enemy_hp_per_column", 0.06)) * float(maxi(0, current_column()))
	if has_curio("moeda"):
		mult *= 1.0 + curio_value("moeda_enemy_hp", 0.1)
	return mult


func build_waves(node: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(node.get("seed", 1))
	var tier: int = tier_for_column(int(node.get("col", 0)))
	var budgets: Array = (data.get("wave_budgets", [[3, 4, 5]]) as Array)[tier]
	var pool: Array = (data.get("tier_enemies", [["drone"]]) as Array)[tier]
	var costs: Dictionary = data.get("enemy_costs", {})
	var elite: bool = String(node.get("type", "")) == "elite"
	var waves: Array = []
	for w in range(budgets.size()):
		var budget: int = int(budgets[w]) + (2 if elite else 0)
		var entries: Array = []
		if elite and w == budgets.size() - 1:
			entries.append(["freighter", Vector2(400.0, 157.0), roll_affix(rng, tier, true)])
			budget -= floori(float(costs.get("freighter", 6)) * 0.5)
		var guard: int = 0
		while budget > 0 and guard < 32:
			guard += 1
			var type: String = String(pool[rng.randi_range(0, pool.size() - 1)])
			var cost: int = int(costs.get(type, 1))
			if cost > budget:
				type = "drone"
				cost = int(costs.get("drone", 1))
			budget -= cost
			entries.append([type, _spawn_point(rng, entries.size()), roll_affix(rng, tier, elite)])
		waves.append(entries)
	return waves


func _spawn_point(rng: RandomNumberGenerator, idx: int) -> Vector2:
	var right_side: bool = idx % 3 != 2
	var x: float = rng.randf_range(330.0, 420.0) if right_side else rng.randf_range(60.0, 140.0)
	return Vector2(x, rng.randf_range(96.0, 218.0))


func line_card_count(id: String = "") -> int:
	var wanted: String = line_id if id == "" else id
	var count: int = 0
	for uid in GameState.upgrades:
		if int(GameState.upgrades[uid]) > 0 and String(GameState.get_upgrade_info(String(uid)).get("line", "")) == wanted:
			count += 1
	return count


func active_skill() -> String:
	return line_id if is_active() else GameState.story_skill


func reset_skill() -> void:
	skill_cd = 0.0
	_apito_tier_seen = apito_tier()


func skill_card_levels() -> int:
	var total: int = 0
	for uid in GameState.upgrades:
		if String(GameState.get_upgrade_info(String(uid)).get("skill", "")) == active_skill():
			total += int(GameState.upgrades[uid])
	return total


func apito_tier() -> int:
	if active_skill() == "":
		return 0
	return 1 + skill_card_levels()


func card_allowed(item: Dictionary) -> bool:
	if bool(item.get("pulse", false)) and active_skill() != "":
		return false
	var skill: String = String(item.get("skill", ""))
	return skill == "" or skill == active_skill()


func get_skill_cfg(id: String = "") -> Dictionary:
	return (data.get("skills", {}) as Dictionary).get(active_skill() if id == "" else id, {})


func skill_name(id: String = "") -> String:
	return String(get_line(active_skill() if id == "" else id).get("apito_name", ""))


func skill_cooldown_max() -> float:
	var cd: float = float(get_skill_cfg().get("cooldown", 8.0))
	cd *= maxf(0.3, 1.0 - float(data.get("pressao_skill_cd", 0.2)) * float(GameState.get_upgrade_level("pressao")))
	if has_curio("apito_lata"):
		cd *= curio_value("apito_lata_mult", 0.7)
	return cd


func skill_ratio() -> float:
	if apito_tier() <= 0:
		return 0.0
	return clampf(1.0 - skill_cd / maxf(0.01, skill_cooldown_max()), 0.0, 1.0)


func skill_ready() -> bool:
	return apito_tier() > 0 and skill_cd <= 0.0


func _process(delta: float) -> void:
	if skill_cd <= 0.0 or not TrainClock.is_running:
		return
	skill_cd = maxf(0.0, skill_cd - delta)
	if skill_cd <= 0.0 and apito_tier() > 0:
		AudioManager.play_sfx("whistle", 0.03)
		Events.apito_ready.emit()


func card_weight(item: Dictionary) -> float:
	var w: float = 1.0
	if is_active() and line_id != "" and String(item.get("line", "")) == line_id:
		w = float(data.get("line_card_weight", 3.0))
	if has_curio("ferradura") and String(item.get("rarity", "")) in ["rare", "epic"]:
		w *= curio_value("ferradura_mult", 1.5)
	return w


func _on_upgrade_picked(_upg_id: String, _lvl: int) -> void:
	var tier: int = apito_tier()
	if tier > _apito_tier_seen:
		_apito_tier_seen = tier
		Events.apito_tier_changed.emit(tier)


func use_skill(player: Node2D) -> bool:
	if not skill_ready():
		return false
	skill_cd = skill_cooldown_max()
	AudioManager.play_sfx("whistle")
	Settings.rumble(0.7, 0.4, 0.3)
	LineSkills.cast(player, active_skill(), apito_tier())
	if has_curio("relogio") and BulletManager.freeze_enemy_bullets() > 0:
		get_tree().create_timer(1.5, false).timeout.connect(func() -> void: BulletManager.release_enemy_bullets(false))
	return true


func snapshot() -> Dictionary:
	return {"fichas": fichas, "apito_tier_seen": _apito_tier_seen, "xp": xp, "xp_level": xp_level,
		"curios": curios.duplicate(), "fotografia_used": fotografia_used}


func restore(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	fichas = int(snap.get("fichas", fichas))
	_apito_tier_seen = int(snap.get("apito_tier_seen", _apito_tier_seen))
	xp = int(snap.get("xp", xp))
	xp_level = int(snap.get("xp_level", xp_level))
	pending_levelups = 0
	curios.clear()
	for c in snap.get("curios", []):
		curios.append(String(c))
	fotografia_used = bool(snap.get("fotografia_used", fotografia_used))


func debug_finish_stop() -> void:
	var cur: Dictionary = current()
	if cur.is_empty() or bool(cur.get("done", false)):
		return
	complete_current()
	SceneRouter.goto_scene(MAP_SCENE)


func price(base: int) -> int:
	if has_curio("moeda"):
		return roundi(float(base) * float(get_economy().get("moeda_discount", 0.7)))
	return base


func get_boss_def(id: String = "") -> Dictionary:
	return (data.get("boss_defs", {}) as Dictionary).get(boss_id if id == "" else id, {})


func on_stop_start() -> void:
	bilhete_ready = has_curio("bilhete")
	skill_cd = 0.0


func get_curio(id: String) -> Dictionary:
	for c in data.get("curios", []):
		if String(c.get("id", "")) == id:
			return c
	return {}


func has_curio(id: String) -> bool:
	return is_active() and curios.has(id)


func curio_value(key: String, default_value: float) -> float:
	return float((data.get("curio_values", {}) as Dictionary).get(key, default_value))


func available_curios() -> Array[String]:
	var out: Array[String] = []
	for c in data.get("curios", []):
		var id: String = String(c.get("id", ""))
		if not curios.has(id):
			out.append(id)
	return out


func roll_curios(count: int) -> Array[String]:
	var pool: Array[String] = available_curios()
	var out: Array[String] = []
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(loot_rng.randi_range(0, pool.size() - 1)))
	return out


func add_curio(id: String) -> void:
	if id == "" or curios.has(id):
		return
	curios.append(id)
	if id == "carvao":
		GameState.max_hp = maxi(1, GameState.max_hp - 1)
		GameState.current_hp = mini(GameState.current_hp, GameState.max_hp)
		Events.player_hit.emit(GameState.current_hp, GameState.max_hp)
	if id == "bilhete":
		bilhete_ready = true
	AudioManager.play_sfx("upgrade_get")
	Events.curio_obtained.emit(id)


func damage_mult() -> float:
	return 1.0 + (curio_value("carvao_damage", 0.2) if has_curio("carvao") else 0.0)


func pulse_cooldown_mult() -> float:
	return curio_value("luva_pulse", 0.75) if has_curio("luva") else 1.0


func graze_radius_mult() -> float:
	return curio_value("oculos_graze", 1.5) if has_curio("oculos") else 1.0


func consume_bilhete() -> bool:
	if not bilhete_ready or not has_curio("bilhete"):
		return false
	bilhete_ready = false
	return true


func consume_fotografia() -> bool:
	if fotografia_used or not has_curio("fotografia"):
		return false
	fotografia_used = true
	return true


func _on_enemy_died_curios(_pos: Vector2, _is_elite: bool) -> void:
	if has_curio("gorjeta") and loot_rng.randf() < curio_value("gorjeta_chance", 0.2):
		fichas += 1


func get_event(id: String) -> Dictionary:
	for e in data.get("events", []):
		if String(e.get("id", "")) == id:
			return e
	return {}


func option_allowed(opt: Dictionary) -> bool:
	var req: Dictionary = opt.get("requires", {})
	if fichas < int(req.get("fichas", 0)):
		return false
	if GameState.current_hp < int(req.get("hp", 0)):
		return false
	if GameState.max_hp < int(req.get("max_hp", 0)):
		return false
	if bool(req.get("curio_left", false)) and available_curios().is_empty():
		return false
	if bool(req.get("owned", false)) and not has_owned_upgradable():
		return false
	return true


func has_owned_upgradable() -> bool:
	for item in GameState.upgrades_db:
		var lvl: int = GameState.get_upgrade_level(String(item.get("id", "")))
		if lvl > 0 and lvl < int(item.get("max_level", 1)):
			return true
	return false


func resolve_effects(effects: Array) -> Dictionary:
	var actions: Array = []
	var lines := PackedStringArray()
	for e in effects:
		match String(e.get("type", "")):
			"fichas":
				add_fichas(int(e.get("amount", 0)))
			"heal":
				GameState.heal_player(int(e.get("amount", 1)))
			"damage":
				GameState.current_hp = maxi(1, GameState.current_hp - int(e.get("amount", 1)))
				Events.player_hit.emit(GameState.current_hp, GameState.max_hp)
			"max_hp":
				var amt: int = int(e.get("amount", 0))
				GameState.max_hp = maxi(1, GameState.max_hp + amt)
				if amt > 0:
					GameState.heal_player(amt)
				GameState.current_hp = mini(GameState.current_hp, GameState.max_hp)
				Events.player_healed.emit(GameState.current_hp, GameState.max_hp)
			"reroll":
				GameState.rerolls_left += int(e.get("amount", 1))
			"curio":
				var got: Array[String] = roll_curios(1)
				if got.is_empty():
					add_fichas(20)
					lines.append("Nada de novo... +20 fichas.")
				else:
					add_curio(got[0])
					lines.append("Achado: %s." % String(get_curio(got[0]).get("name", "")))
			"chance":
				var ok: bool = loot_rng.randf() < float(e.get("p", 0.5))
				lines.append(String(e.get("success_text" if ok else "fail_text", "")))
				var sub: Dictionary = resolve_effects(e.get("success" if ok else "fail", []))
				actions.append_array(sub["actions"])
				lines.append_array(sub["text"])
			"curio_choice", "upgrade_owned", "card":
				actions.append(e)
	return {"actions": actions, "text": lines}


func level_config() -> Dictionary:
	var levels: Array = data.get("levels", [])
	if levels.is_empty():
		return {}
	return levels[clampi(level, 1, levels.size()) - 1]


func max_level() -> int:
	return maxi(1, (data.get("levels", []) as Array).size())


func get_background(id: int) -> Dictionary:
	for bgd in data.get("backgrounds", []):
		if int(bgd.get("id", 0)) == id:
			return bgd
	return {"texture": "res://assets/sprites/backgrounds/wagon_1.png", "music": "wagon_1"}


func xp_next() -> int:
	var cfg: Dictionary = data.get("xp", {})
	return int(cfg.get("base", 8)) + int(cfg.get("step", 5)) * (xp_level - 1)


func xp_ratio() -> float:
	return clampf(float(xp) / float(maxi(1, xp_next())), 0.0, 1.0)


func magnet_radius() -> float:
	return float((data.get("xp", {}) as Dictionary).get("magnet_radius", 46.0)) * (1.5 if perks.has("ima") else 1.0)


func xp_value(enemy_type: String, affix: String) -> int:
	var v: int = int((data.get("enemy_costs", {}) as Dictionary).get(enemy_type, 1))
	if affix != "":
		v *= int((data.get("xp", {}) as Dictionary).get("affix_mult", 2))
	return maxi(1, v)


func add_xp(amount: int) -> void:
	if not is_active():
		return
	xp += amount
	while xp >= xp_next():
		xp -= xp_next()
		xp_level += 1
		pending_levelups += 1
		Events.xp_level_up.emit(xp_level)


func get_affix(id: String) -> Dictionary:
	return ((data.get("affixes", {}) as Dictionary).get("list", {}) as Dictionary).get(id, {})


func roll_affix(rng: RandomNumberGenerator, tier: int, elite: bool) -> String:
	var cfg: Dictionary = data.get("affixes", {})
	var chance: float = float((cfg.get("chance_by_tier", [0.0, 0.2, 0.3]) as Array)[clampi(tier, 0, 2)])
	if elite:
		chance = maxf(chance, float(cfg.get("elite_chance", 0.5)))
	if rng.randf() >= chance:
		return ""
	var ids: Array = (cfg.get("list", {}) as Dictionary).keys()
	return String(ids[rng.randi_range(0, ids.size() - 1)])


func unlocked_perks() -> Array:
	var all: Array = data.get("level_perks", [])
	var count: int = clampi(Progress.get_malha_unlocked_level() - 1, 0, all.size())
	return all.slice(0, count)


func _apply_perks() -> void:
	perks.clear()
	for perk in unlocked_perks():
		var id: String = String(perk.get("id", ""))
		perks.append(id)
		match id:
			"fichas":
				fichas += 15
			"fichas2":
				fichas += 25
			"reroll":
				GameState.rerolls_left += 1
			"curio":
				var got: Array[String] = roll_curios(1)
				if not got.is_empty():
					curios.append(got[0])
			"coracao", "coracao2":
				GameState.max_hp += 1
				GameState.current_hp += 1
			"skill_card":
				_grant_random_card(func(u: Dictionary) -> bool: return String(u.get("skill", "")) == line_id)
			"carta":
				_grant_random_card(func(u: Dictionary) -> bool: return String(u.get("line", "")) == line_id and String(u.get("skill", "")) == "" and String(u.get("rarity", "")) == "rare")


func _grant_random_card(filter: Callable) -> void:
	var pool: Array = []
	for u in GameState.upgrades_db:
		if GameState.upgrade_in_mode(u) and card_allowed(u) and filter.call(u) and GameState.get_upgrade_level(String(u.get("id", ""))) < int(u.get("max_level", 1)):
			pool.append(String(u.get("id", "")))
	if not pool.is_empty():
		GameState.add_upgrade(String(pool[loot_rng.randi_range(0, pool.size() - 1)]))
