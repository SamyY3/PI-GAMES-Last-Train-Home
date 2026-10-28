extends Node2D

const POOL_SIZE: int = 400
const MAX_ENEMY_BULLETS: int = 300

class PooledBullet:
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

var _pool: Array[PooledBullet] = []
var _active_enemy_count: int = 0
const TEX_PLAYER: Texture2D = preload("res://assets/sprites/bullets/player_bolt.png")
const TEX_ENEMY: Texture2D = preload("res://assets/sprites/bullets/enemy_orb.png")
const TEX_ENEMY_HC: Texture2D = preload("res://assets/sprites/bullets/enemy_orb_hc.png")


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

		b.area = area
		b.sprite = spr
		_pool.append(b)


func spawn_bullet(pos: Vector2, dir: Vector2, speed: float, is_player: bool,
		damage: float = 1.0, lifetime: float = 4.0, splits: bool = false) -> void:
	if not is_player and _active_enemy_count >= MAX_ENEMY_BULLETS:
		return

	var diff_mult: float = 1.0
	if not is_player:
		diff_mult = float(GameState.get_difficulty_config().get("bullet_speed_mult", 1.0))

	for b in _pool:
		if not b.active:
			b.active = true
			b.is_player = is_player
			b.pos = pos
			b.vel = dir.normalized() * speed * diff_mult
			b.damage = damage
			b.lifetime = 0.0
			b.max_lifetime = lifetime
			b.splits_on_expire = splits
			b.grazing = false
			b.grazed = false

			if is_player:
				b.sprite.texture = TEX_PLAYER
				b.sprite.rotation = b.vel.angle()
				b.pierce_left = GameState.get_upgrade_level("perfurante")
				b.bounce_left = GameState.get_upgrade_level("ricochete")
				b.homing_deg_per_sec = float(GameState.get_upgrade_level("giroscopio")) * 110.0
				b.explosive_chance = float(GameState.get_upgrade_level("instavel")) * 0.15
				if GameState.has_combo("missil_latao"):
					b.explosive_chance += 0.3
				b.area.collision_layer = 1 << 3
				b.area.collision_mask = (1 << 0) | (1 << 4)
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
			return


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
			b.area.collision_layer = 1 << 3
			b.area.collision_mask = (1 << 0) | (1 << 4)
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
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var graze_r: float = float(GameState.balance_data.get("graze", {}).get("radius", 16.0))
	var graze_r_sq: float = graze_r * graze_r
	for b in _pool:
		if not b.active:
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

		if b.pos.x < 16.0 or b.pos.x > 464.0:
			if b.bounce_left > 0:
				b.bounce_left -= 1
				_refresh_pierce_on_bounce(b)
				b.vel.x = -b.vel.x
				b.pos.x = clampf(b.pos.x, 16.0, 464.0)
			elif b.pos.x < -24.0 or b.pos.x > 504.0:
				_deactivate_bullet(b)
				continue

		if b.pos.y < 64.0 or b.pos.y > 250.0:
			if b.bounce_left > 0:
				b.bounce_left -= 1
				_refresh_pierce_on_bounce(b)
				b.vel.y = -b.vel.y
				b.pos.y = clampf(b.pos.y, 64.0, 250.0)
			elif b.pos.y < 40.0 or b.pos.y > 294.0:
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
	if b.is_player and body.has_method("take_damage"):
		body.take_damage(b.damage)
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
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D:
			var d: float = from_pos.distance_squared_to(node.global_position)
			if d < best_dist:
				best_dist = d
				best = node
	return best


func _deactivate_bullet(b: PooledBullet) -> void:
	if not b.active:
		return
	b.active = false
	b.area.visible = false
	b.area.set_deferred("monitoring", false)
	if not b.is_player:
		_active_enemy_count = maxi(0, _active_enemy_count - 1)
