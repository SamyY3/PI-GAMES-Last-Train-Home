class_name LineSkills

const TEX_MORTEIRO: Texture2D = preload("res://assets/sprites/fx/skill_morteiro.png")
const TEX_EXPRESSO: Texture2D = preload("res://assets/sprites/fx/skill_expresso.png")
const TEX_DEPLOY: Texture2D = preload("res://assets/sprites/fx/skill_torre_deploy.png")
const TEX_TURRET: Texture2D = preload("res://assets/sprites/fx/skill_turret.png")
const TEX_PUFF: Texture2D = preload("res://assets/sprites/fx/steam_puff.png")


static func cast(player: Node2D, line_id: String, _tier: int) -> void:
	var cfg: Dictionary = Malha.get_skill_cfg(line_id)
	var parent: Node = player.get_parent()
	match line_id:
		"polvora":
			var target: Vector2 = _aim_point(player)
			_launch_shell(parent, player.global_position, target, cfg)
			if GameState.get_upgrade_level("salva_dupla") > 0:
				var second: Vector2 = _nearest_enemy_pos(player.get_tree(), target, 40.0)
				if second == Vector2.INF:
					second = Arena.clamp_point(target + Vector2(randf_range(-50.0, 50.0), randf_range(-40.0, 40.0)), Arena.PLAYER)
				_launch_shell(parent, player.global_position, second, cfg, 0.15)
		"vapor":
			if player.has_method("start_expresso"):
				var dmg: float = float(cfg.get("damage", 60.0)) * (1.0 + GameState.get_upgrade_value("pistao"))
				player.start_expresso(dmg, false)
		"engrenagem":
			var count: int = 2 if GameState.get_upgrade_level("torre_dupla") > 0 else 1
			for i in range(count):
				var offset := Vector2(0.0 if count == 1 else (-20.0 + 40.0 * float(i)), 6.0)
				var turret := GearTurret.new()
				turret.global_position = Arena.clamp_point(player.global_position + offset, Arena.PLAYER)
				turret.duration = float(cfg.get("duration", 8.0)) + 3.0 * GameState.get_upgrade_value("engrenagens_extra") + (4.0 if GameState.has_combo("fabrica") else 0.0)
				turret.interval = float(cfg.get("interval", 0.25)) * maxf(0.4, 1.0 - 0.15 * GameState.get_upgrade_value("engrenagens_extra"))
				turret.damage_mult = float(cfg.get("damage_mult", 0.7))
				turret.block_radius = 40.0 if GameState.has_combo("fabrica") else 18.0
				parent.add_child(turret)
				SheetFx.spawn(parent, TEX_DEPLOY, turret.global_position, Vector2(116.0, 56.0), 4, 8, 14.0, Vector2(58.0, 28.0), 0.7)


static func _launch_shell(parent: Node, from: Vector2, target: Vector2, cfg: Dictionary, delay: float = 0.0) -> void:
	var calibre: float = GameState.get_upgrade_value("calibre")
	var shell := MortarShell.new()
	shell.from = from
	shell.target = target
	shell.damage = float(cfg.get("damage", 90.0)) * (1.0 + calibre)
	shell.radius = float(cfg.get("radius", 46.0)) * (1.0 + calibre * 0.5)
	shell.flight = 0.5 + delay
	parent.add_child(shell)


static func _nearest_enemy_pos(tree: SceneTree, from: Vector2, min_dist: float) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = 220.0 * 220.0
	for node in tree.get_nodes_in_group("enemies"):
		if node is Node2D:
			var d: float = from.distance_squared_to((node as Node2D).global_position)
			if d < best_d and d > min_dist * min_dist:
				best_d = d
				best = (node as Node2D).global_position
	return best


static func _aim_point(player: Node2D) -> Vector2:
	var target: Vector2
	if not Settings.auto_aim and not Settings.using_gamepad and not Settings.touch_mode:
		target = player.get_global_mouse_position()
	else:
		var near: Vector2 = _nearest_enemy_pos(player.get_tree(), player.global_position, 0.0)
		var aim: Vector2 = player.get("_aim_dir")
		target = near if near != Vector2.INF else player.global_position + aim * 110.0
	return Arena.clamp_point(target, Arena.PLAYER)


static func shockwave(parent: Node, center: Vector2, radius: float, damage: float) -> void:
	SheetFx.spawn(parent, TEX_DEPLOY, center, Vector2(116.0, 56.0), 4, 8, 16.0, Vector2(58.0, 28.0), radius / 50.0)
	BulletManager.clear_enemy_bullets_in_radius(center, radius)
	for node in parent.get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and (node as Node2D).global_position.distance_to(center) <= radius:
			if node.has_method("take_damage"):
				node.take_damage(damage)
			if node.has_method("apply_knockback"):
				node.apply_knockback(((node as Node2D).global_position - center).normalized() * 26.0)
	AudioManager.play_sfx("steam_pulse", 0.05)
	Events.request_screen_shake.emit(2.5, 0.2)


class MortarShell extends Node2D:
	var from: Vector2
	var target: Vector2
	var damage: float = 90.0
	var radius: float = 46.0
	var flight: float = 0.5
	var _t: float = 0.0

	func _ready() -> void:
		z_as_relative = false
		z_index = 245
		AudioManager.play_sfx("steam_pulse", 0.05)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= flight:
			_explode()
			return
		queue_redraw()

	func _explode() -> void:
		var parent: Node = get_parent()
		BulletManager.clear_enemy_bullets_in_radius(target, radius)
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Node2D and (node as Node2D).global_position.distance_to(target) <= radius and node.has_method("take_damage"):
				node.take_damage(damage)
		SheetFx.spawn(parent, LineSkills.TEX_MORTEIRO, target, Vector2(116.0, 82.0), 4, 8, 14.0, Vector2(58.0, 41.0), radius / 46.0)
		var shards: int = int(GameState.get_upgrade_value("bombetas", 0.0))
		if shards > 0:
			var player: Node = get_tree().get_first_node_in_group("player")
			var dmg: float = (float(player.call("get_bullet_damage")) if player != null else 10.0) * 0.8
			for i in range(shards):
				BulletManager.spawn_bullet(target, Vector2.RIGHT.rotated(TAU * float(i) / float(shards) + randf() * 0.2), 240.0, true, dmg, 0.8)
		if GameState.get_upgrade_level("napalm") > 0:
			var fire := FireZone.new()
			fire.global_position = target
			fire.radius = radius * 0.8
			fire.duration = GameState.get_upgrade_value("napalm", 3.0)
			fire.damage = damage * 0.1
			parent.add_child(fire)
		if GameState.has_combo("artilharia_eletrica"):
			BulletManager.chain_lightning(target, damage * 0.4, 4, radius * 2.0)
		AudioManager.play_sfx("bomb_explode", 0.05)
		Events.request_screen_shake.emit(3.0, 0.25)
		Settings.rumble(0.6, 0.5, 0.25)
		queue_free()

	func _draw() -> void:
		var k: float = clampf(_t / flight, 0.0, 1.0)
		var ground: Vector2 = from.lerp(target, k)
		var height: float = sin(k * PI) * 46.0
		draw_arc(target - global_position, radius * (1.0 - k * 0.3), 0.0, TAU, 32, Color(1.0, 0.54, 0.24, 0.35 + 0.35 * sin(_t * 30.0)), 2.0)
		draw_circle(ground - global_position, 4.0, Color(0.05, 0.04, 0.07, 0.45))
		var shell: Vector2 = ground - global_position - Vector2(0.0, height)
		draw_circle(shell, 4.0, Color("#0d0b12"))
		draw_circle(shell, 3.0, Color("#c98a3c"))
		draw_circle(shell + Vector2(-1.0, -1.0), 1.0, Color("#fff1c9"))


class FireZone extends Node2D:
	var radius: float = 36.0
	var duration: float = 3.0
	var damage: float = 9.0
	var _t: float = 0.0
	var _tick: float = 0.0

	func _ready() -> void:
		z_as_relative = false
		z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		_tick -= delta
		if _t >= duration:
			queue_free()
			return
		if _tick <= 0.0:
			_tick = 0.3
			for node in get_tree().get_nodes_in_group("enemies"):
				if node is Node2D and (node as Node2D).global_position.distance_to(global_position) <= radius and node.has_method("take_damage"):
					node.take_damage(damage)
		queue_redraw()

	func _draw() -> void:
		var fade: float = clampf(duration - _t, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.1, 0.22 * fade))
		for i in range(10):
			var a: float = TAU * float(i) / 10.0 + _t * 0.7
			var p := Vector2(cos(a), sin(a) * 0.6) * radius * (0.35 + 0.55 * fmod(float(i) * 0.37 + _t, 1.0))
			var f: int = int(fmod(_t * 10.0 + float(i), 6.0))
			draw_texture_rect_region(LineSkills.TEX_PUFF, Rect2((p - Vector2(8.0, 12.0)).round(), Vector2(16.0, 16.0)), Rect2(float(f) * 32.0, 0.0, 32.0, 32.0), Color(1.0, 0.55, 0.2, 0.8 * fade))


class GearTurret extends Node2D:
	var duration: float = 8.0
	var interval: float = 0.25
	var damage_mult: float = 0.7
	var block_radius: float = 18.0
	var _t: float = 0.0
	var _shot_t: float = 0.0
	var _zap_t: float = 0.0
	var _fire_anim: float = 0.0

	func _ready() -> void:
		add_to_group("skill_turrets")
		z_index = int(global_position.y)
		AudioManager.play_sfx("clang", 0.05)

	func _process(delta: float) -> void:
		_t += delta
		_shot_t -= delta
		_zap_t -= delta
		_fire_anim = maxf(0.0, _fire_anim - delta)
		BulletManager.clear_enemy_bullets_in_radius(global_position, block_radius)
		if _t >= duration:
			SheetFx.spawn(get_parent(), LineSkills.TEX_DEPLOY, global_position, Vector2(116.0, 56.0), 4, 8, 14.0, Vector2(58.0, 28.0), 0.5)
			queue_free()
			return
		var best: Node2D = null
		var best_d: float = 210.0 * 210.0
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Node2D:
				var d: float = global_position.distance_squared_to((node as Node2D).global_position)
				if d < best_d:
					best_d = d
					best = node
		var player: Node = get_tree().get_first_node_in_group("player")
		var dmg: float = (float(player.call("get_bullet_damage")) if player != null else 10.0) * damage_mult
		if best != null and _shot_t <= 0.0:
			_shot_t = interval
			_fire_anim = 0.3
			var dir: Vector2 = (best.global_position - global_position).normalized()
			var n: int = int(GameState.get_upgrade_value("leque", 1.0))
			if n <= 1:
				BulletManager.spawn_bullet(global_position + Vector2(0.0, -6.0), dir, 300.0, true, dmg, 1.0)
			else:
				for i in range(n):
					BulletManager.spawn_bullet(global_position + Vector2(0.0, -6.0), dir.rotated(deg_to_rad(-12.0 * float(n - 1) * 0.5 + 12.0 * float(i))), 300.0, true, dmg * 0.75, 1.0)
		if best != null and _zap_t <= 0.0 and GameState.get_upgrade_level("bobina") > 0:
			_zap_t = GameState.get_upgrade_value("bobina", 1.5)
			BulletManager.chain_lightning(global_position + Vector2(0.0, -10.0), dmg * 1.6, 2 + GameState.get_upgrade_level("corrente"), 200.0)
		queue_redraw()

	func _draw() -> void:
		var f: int = int((0.3 - _fire_anim) / 0.3 * 8.0) if _fire_anim > 0.0 else 0
		var blink: bool = duration - _t < 1.5 and int(_t * 10.0) % 2 == 0
		draw_circle(Vector2(0.0, 6.0), block_radius, Color(0.95, 0.76, 0.36, 0.12))
		draw_arc(Vector2(0.0, 6.0), block_radius, 0.0, TAU, 24, Color(0.95, 0.76, 0.36, 0.35), 1.0)
		draw_texture_rect_region(LineSkills.TEX_TURRET, Rect2(Vector2(-24.0, -26.0), Vector2(48.0, 48.0)), Rect2(Vector2(float(clampi(f, 0, 8)) * 48.0, 0.0), Vector2(48.0, 48.0)), Color(1.0, 1.0, 1.0, 0.45 if blink else 1.0))
