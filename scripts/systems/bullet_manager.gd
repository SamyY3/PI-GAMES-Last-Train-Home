extends Node2D

const POOL_SIZE: int = 400
const MAX_ENEMY_BULLETS: int = 300
const PLAYER_BULLET_LAYER: int = 1 << 3
const PLAYER_BULLET_MASK: int = 1 << 4

class PooledBullet:
	var idx: int = 0
	var area: Area2D
	var sprite: Sprite2D
	var active: bool = false
	var is_player: bool = false
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var damage: float = 1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 2.0
	var pierce_left: int = 0
	var bounce_left: int = 0
	var homing_deg_per_sec: float = 0.0
	var explosive_chance: float = 0.0
	var splits_on_expire: bool = false
	var grazing: bool = false
	var grazed: bool = false
	var frozen: bool = false
	var fragment: bool = false

var _pool: Array[PooledBullet] = []
var _free: Array[int] = []
var _active_enemy_count: int = 0
var _enemy_speed_mult: float = 1.0
var _enemies_cache: Array[Node] = []
var _enemies_cache_frame: int = -1
const TEX_PLAYER: Texture2D = preload("res://assets/sprites/bullets/player_bolt.png")
const TEX_ENEMY: Texture2D = preload("res://assets/sprites/bullets/enemy_orb.png")
const TEX_ENEMY_HC: Texture2D = preload("res://assets/sprites/bullets/enemy_orb_hc.png")
const ECHO_TINT := Color(0.45, 1.6, 1.8)
const ARC_TIME: float = 0.16

var _arcs: Array[Dictionary] = []
var _fx_layer: Node2D
var _shot_counter: int = 0
var _last_idx: int = -1


func _ready() -> void:
	z_index = 250
	z_as_relative = false

	for i in range(POOL_SIZE):
		var b := PooledBullet.new()
		var area := Area2D.new()
		area.monitoring = false
		area.monitorable = false

		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 4.0
		col.shape = shape
		area.add_child(col)

		var spr := Sprite2D.new()
		area.add_child(spr)

		area.visible = false
		area.area_entered.connect(_on_bullet_hit_area.bind(b))
		area.body_entered.connect(_on_bullet_hit_body.bind(b))
		add_child(area)

		b.idx = i
		b.area = area
		b.sprite = spr
		_pool.append(b)
		_free.append(POOL_SIZE - 1 - i)


func spawn_bullet(pos: Vector2, dir: Vector2, speed: float, is_player: bool,
		damage: float = 1.0, lifetime: float = 4.0, splits: bool = false) -> void:
	_last_idx = -1
	if not is_player and _active_enemy_count >= MAX_ENEMY_BULLETS:
		return
	if _free.is_empty():
		return

	var b: PooledBullet = _pool[_free.pop_back()]
	b.active = true
	b.is_player = is_player
	b.pos = pos
	b.vel = dir.normalized() * speed * (1.0 if is_player else _enemy_speed_mult)
	b.damage = damage
	b.lifetime = 0.0
	b.max_lifetime = lifetime
	b.splits_on_expire = splits
	b.grazing = false
	b.grazed = false
	b.frozen = false
	b.fragment = false
	b.sprite.modulate = Color.WHITE
	b.sprite.scale = Vector2.ONE

	if is_player:
		b.sprite.texture = TEX_PLAYER
		b.sprite.scale = Vector2.ONE * clampf(0.8 + damage / 40.0, 1.0, 1.8)
		b.sprite.rotation = b.vel.angle()
		b.pierce_left = GameState.get_upgrade_level("perfurante")
		b.bounce_left = GameState.get_upgrade_level("ricochete")
		b.homing_deg_per_sec = GameState.get_upgrade_value("giroscopio", 0.0)
		b.explosive_chance = GameState.get_upgrade_value("instavel", 0.0)
		if GameState.has_combo("missil_latao"):
			b.explosive_chance += 0.3
		b.area.collision_layer = PLAYER_BULLET_LAYER
		b.area.collision_mask = PLAYER_BULLET_MASK
	else:
		b.sprite.texture = TEX_ENEMY_HC if Settings.high_contrast_bullets else TEX_ENEMY
		b.sprite.rotation = 0.0
		b.pierce_left = 0
		b.bounce_left = 0
		b.homing_deg_per_sec = 0.0
		b.explosive_chance = 0.0
		b.area.collision_layer = 1 << 5
		b.area.collision_mask = (1 << 2)
		_active_enemy_count += 1

	b.area.global_position = pos
	b.area.visible = true
	b.area.set_deferred("monitoring", true)
	_last_idx = b.idx


func spawn_echo(pos: Vector2, dir: Vector2, speed: float) -> void:
	spawn_bullet(pos, dir, speed, false, 1.0)
	var idx: int = _last_spawned()
	if idx >= 0:
		_pool[idx].sprite.modulate = ECHO_TINT


func _last_spawned() -> int:
	return _last_idx


func freeze_enemy_bullets(tint: Color = Color(0.6, 1.4, 1.6)) -> int:
	var n: int = 0
	for b in _pool:
		if b.active and not b.is_player and not b.frozen:
			b.frozen = true
			b.sprite.modulate = tint
			n += 1
	return n


func release_enemy_bullets(reverse: bool, speed_mult: float = 1.0) -> void:
	for b in _pool:
		if b.active and not b.is_player and b.frozen:
			b.frozen = false
			b.sprite.modulate = Color.WHITE
			b.vel *= speed_mult
			if reverse:
				b.vel = -b.vel
				b.lifetime = 0.0
				b.grazed = false


func count_frozen() -> int:
	var n: int = 0
	for b in _pool:
		if b.active and b.frozen:
			n += 1
	return n


func add_arc(points: PackedVector2Array) -> void:
	_arcs.append({"points": points, "t": ARC_TIME})


func chain_lightning(from_pos: Vector2, damage: float, jumps: int, first_range: float = 160.0, jump_range: float = 80.0) -> void:
	var hit: Array = []
	var cur: Vector2 = from_pos
	var pts := PackedVector2Array([from_pos])
	for j in range(jumps + 1):
		var best: Node2D = null
		var best_d: float = (first_range if j == 0 else jump_range)
		best_d *= best_d
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Node2D and not hit.has(node):
				var d: float = cur.distance_squared_to((node as Node2D).global_position)
				if d < best_d:
					best_d = d
					best = node
		if best == null:
			break
		hit.append(best)
		cur = best.global_position
		pts.append(cur)
		if best.has_method("take_damage"):
			best.take_damage(damage)
	if pts.size() > 1:
		add_arc(pts)
		AudioManager.play_sfx("blip", 0.08)


func get_active_count() -> int:
	return POOL_SIZE - _free.size()


func refresh_difficulty() -> void:
	_enemy_speed_mult = float(GameState.get_difficulty_config().get("bullet_speed_mult", 1.0))


func spawn_fan(origin: Vector2, base_dir: Vector2, count: int, spread_deg: float, speed: float, is_player: bool, damage: float = 1.0) -> void:
	if count <= 1:
		spawn_bullet(origin, base_dir, speed, is_player, damage)
		return
	var start_angle: float = -deg_to_rad(spread_deg) * 0.5
	var step: float = deg_to_rad(spread_deg) / float(count - 1)
	for i in range(count):
		var d: Vector2 = base_dir.rotated(start_angle + step * float(i))
		spawn_bullet(origin, d, speed, is_player, damage)


func spawn_ring(origin: Vector2, count: int, speed: float, offset_deg: float = 0.0) -> void:
	var step: float = TAU / float(count)
	var base_rad: float = deg_to_rad(offset_deg)
	for i in range(count):
		var d := Vector2.RIGHT.rotated(base_rad + step * float(i))
		spawn_bullet(origin, d, speed, false, 1.0)


func clear_enemy_bullets_in_radius(center: Vector2, radius: float) -> void:
	var r_sq: float = radius * radius
	for b in _pool:
		if b.active and not b.is_player:
			if b.pos.distance_squared_to(center) <= r_sq:
				_deactivate_bullet(b)


func reflect_enemy_bullets_in_radius(center: Vector2, radius: float, damage: float) -> void:
	var r_sq: float = radius * radius
	for b in _pool:
		if b.active and not b.is_player and b.pos.distance_squared_to(center) <= r_sq:
			var away: Vector2 = b.pos - center
			if away == Vector2.ZERO:
				away = -b.vel
			b.is_player = true
			b.vel = away.normalized() * 260.0
			b.damage = damage
			b.lifetime = 0.0
			b.max_lifetime = 1.0
			b.splits_on_expire = false
			b.pierce_left = 0
			b.bounce_left = 0
			b.homing_deg_per_sec = 0.0
			b.explosive_chance = 0.0
			b.sprite.texture = TEX_PLAYER
			b.sprite.rotation = b.vel.angle()
			b.area.collision_layer = PLAYER_BULLET_LAYER
			b.area.collision_mask = PLAYER_BULLET_MASK
			_active_enemy_count = maxi(0, _active_enemy_count - 1)


func hit_enemy_bullets_near(center: Vector2, radius: float) -> int:
	var r_sq: float = radius * radius
	var hits: int = 0
	for b in _pool:
		if b.active and not b.is_player and b.pos.distance_squared_to(center) <= r_sq:
			_deactivate_bullet(b)
			hits += 1
	return hits


func clear_all_bullets() -> void:
	for b in _pool:
		if b.active:
			_deactivate_bullet(b)


func _physics_process(delta: float) -> void:
	refresh_difficulty()
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var graze_r: float = float(GameState.balance_data.get("graze", {}).get("radius", 16.0)) * Malha.graze_radius_mult()
	var graze_r_sq: float = graze_r * graze_r
	_update_arcs(delta)
	for b in _pool:
		if not b.active:
			continue
		if b.frozen:
			continue
		b.lifetime += delta
		if b.lifetime >= b.max_lifetime:
			if b.splits_on_expire:
				spawn_ring(b.pos, 10, 90.0)
			_deactivate_bullet(b)
			continue

		if b.is_player and b.homing_deg_per_sec > 0.0:
			var target: Node2D = _find_nearest_enemy(b.pos)
			if target != null:
				var desired: Vector2 = (target.global_position - b.pos).normalized()
				var max_turn: float = deg_to_rad(b.homing_deg_per_sec) * delta
				var angle_diff: float = clampf(b.vel.angle_to(desired), -max_turn, max_turn)
				b.vel = b.vel.rotated(angle_diff)

		b.pos += b.vel * delta

		var bounce: Rect2 = Arena.BULLET_BOUNCE
		var discard: Rect2 = Arena.BULLET_DISCARD
		if b.pos.x < bounce.position.x or b.pos.x > bounce.end.x:
			if b.bounce_left > 0:
				b.bounce_left -= 1
				_refresh_pierce_on_bounce(b)
				b.vel.x = -b.vel.x
				b.pos.x = clampf(b.pos.x, bounce.position.x, bounce.end.x)
			elif b.pos.x < discard.position.x or b.pos.x > discard.end.x:
				_deactivate_bullet(b)
				continue

		if b.pos.y < bounce.position.y or b.pos.y > bounce.end.y:
			if b.bounce_left > 0:
				b.bounce_left -= 1
				_refresh_pierce_on_bounce(b)
				b.vel.y = -b.vel.y
				b.pos.y = clampf(b.pos.y, bounce.position.y, bounce.end.y)
			elif b.pos.y < discard.position.y or b.pos.y > discard.end.y:
				_deactivate_bullet(b)
				continue

		b.area.global_position = b.pos
		if b.is_player:
			b.sprite.rotation = b.vel.angle()
		elif player != null and not b.grazed:
			if b.pos.distance_squared_to(player.global_position) <= graze_r_sq:
				b.grazing = true
			elif b.grazing:
				b.grazing = false
				b.grazed = true
				player.register_graze(b.pos)


func _on_bullet_hit_area(other: Area2D, b: PooledBullet) -> void:
	if not b.active:
		return
	if not b.is_player and other.name == "PlayerHurtbox":
		var player: Node = other.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(int(b.damage), b.pos)
		_deactivate_bullet(b)


func _on_bullet_hit_body(body: Node, b: PooledBullet) -> void:
	if not b.active:
		return
	if b.is_player and body.has_method("blocks_bullet") and body.blocks_bullet(b.vel):
		AudioManager.play_sfx("clang", 0.1)
		_deactivate_bullet(b)
		return
	if b.is_player and body.has_method("take_damage"):
		body.take_damage(b.damage)
		if not b.fragment and GameState.get_upgrade_level("fragmentacao") > 0:
			for k in range(3):
				var fd: Vector2 = b.vel.normalized().rotated(deg_to_rad(-35.0 + 35.0 * float(k)))
				spawn_bullet(b.pos + fd * 8.0, fd, 220.0, true, b.damage * 0.35, 0.35)
				if _last_idx < 0:
					break
				_pool[_last_idx].fragment = true
				_pool[_last_idx].pierce_left = 0
				_pool[_last_idx].bounce_left = 0
				_pool[_last_idx].sprite.scale = Vector2(0.6, 0.6)
		if b.explosive_chance > 0.0 and randf() < b.explosive_chance:
			_trigger_unstable_explosion(b.pos, b.damage * 0.6)
		if b.pierce_left > 0:
			b.pierce_left -= 1
			b.damage *= 0.9
		else:
			_deactivate_bullet(b)


func _refresh_pierce_on_bounce(b: PooledBullet) -> void:
	if b.is_player and GameState.has_combo("bala_fantasma"):
		b.pierce_left = maxi(b.pierce_left, GameState.get_upgrade_level("perfurante"))


func _trigger_unstable_explosion(center: Vector2, dmg: float) -> void:
	var radius: float = 34.0 if GameState.has_combo("missil_latao") else 24.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and node.global_position.distance_to(center) <= radius:
			if node.has_method("take_damage"):
				node.take_damage(dmg)


func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist: float = 999999.0
	var frame: int = Engine.get_physics_frames()
	if frame != _enemies_cache_frame:
		_enemies_cache_frame = frame
		_enemies_cache = get_tree().get_nodes_in_group("enemies")
	for node in _enemies_cache:
		if is_instance_valid(node) and node is Node2D:
			var d: float = from_pos.distance_squared_to(node.global_position)
			if d < best_dist:
				best_dist = d
				best = node
	return best


func _deactivate_bullet(b: PooledBullet) -> void:
	if not b.active:
		return
	b.active = false
	_free.append(b.idx)
	b.area.visible = false
	b.area.set_deferred("monitoring", false)
	if not b.is_player:
		_active_enemy_count = maxi(0, _active_enemy_count - 1)


func next_shot_is_lightning() -> bool:
	var lvl: int = GameState.get_upgrade_level("corrente")
	if lvl <= 0:
		return false
	_shot_counter += 1
	var every: int = int(GameState.get_upgrade_value("corrente", 6.0))
	if _shot_counter >= every:
		_shot_counter = 0
		return true
	return false


func _update_arcs(delta: float) -> void:
	if _fx_layer == null:
		_fx_layer = Node2D.new()
		_fx_layer.z_as_relative = false
		_fx_layer.z_index = 250
		_fx_layer.draw.connect(_draw_arcs)
		add_child(_fx_layer)
	for i in range(_arcs.size() - 1, -1, -1):
		_arcs[i]["t"] = float(_arcs[i]["t"]) - delta
		if float(_arcs[i]["t"]) <= 0.0:
			_arcs.remove_at(i)
	_fx_layer.queue_redraw()


func _draw_arcs() -> void:
	for arc in _arcs:
		var pts: PackedVector2Array = arc["points"]
		var a: float = clampf(float(arc["t"]) / ARC_TIME, 0.0, 1.0)
		for i in range(pts.size() - 1):
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var seg := PackedVector2Array([p0])
			var steps: int = maxi(2, int(p0.distance_to(p1) / 10.0))
			var perp: Vector2 = (p1 - p0).normalized().orthogonal()
			for k in range(1, steps):
				seg.append(p0.lerp(p1, float(k) / float(steps)) + perp * randf_range(-4.0, 4.0))
			seg.append(p1)
			_fx_layer.draw_polyline(seg, Color(0.55, 0.85, 1.0, a), 3.0)
			_fx_layer.draw_polyline(seg, Color(1.0, 1.0, 1.0, a), 1.0)
