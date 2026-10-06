class_name Bullet
extends Node2D
## Projétil (do jogador e dos inimigos).

var vel := Vector2.ZERO
var friendly := false
var damage := 1.0
var radius := 5.0
var color := Color.WHITE
var pierce := false
var bounces := 0          # ricochete: quantas vezes ele quica nas paredes
var explosive := 0        # nível da munição explosiva
var slow := 0.0           # quanto tempo o inimigo fica lento depois de levar o tiro
var homing := 0           # nível da mira assistida (só vale pros tiros do jogador)
var burst_after := -1.0   # > 0: vira "mina" e explode em anel depois desse tempo
var age := 0.0
var _hit: Array = []


func setup(pos: Vector2, v: Vector2, is_friendly: bool, dmg := 1.0, r := 5.0, col := Color.WHITE) -> void:
	position = pos
	vel = v
	friendly = is_friendly
	damage = dmg
	radius = r
	color = col


func _process(delta: float) -> void:
	if Game.paused or Game.over:
		return
	age += delta
	position += vel * delta
	if friendly and bounces > 0:
		var A := Game.ARENA
		if position.x < A.position.x or position.x > A.end.x:
			vel.x = -vel.x
			position.x = clampf(position.x, A.position.x, A.end.x)
			bounces -= 1
		if position.y < A.position.y or position.y > A.end.y:
			vel.y = -vel.y
			position.y = clampf(position.y, A.position.y, A.end.y)
			bounces -= 1
	if not Game.ARENA.grow(80.0).has_point(position):
		queue_free()
		return
	if burst_after > 0.0 and age >= burst_after:
		_burst()
		queue_free()
		return
	if friendly and homing > 0:
		var tgt := _closest_enemy()
		if tgt:
			var diff := angle_difference(vel.angle(), (tgt.position - position).angle())
			var max_turn := homing * 2.2 * delta
			vel = vel.rotated(clampf(diff, -max_turn, max_turn))
	if friendly:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.dead or e.t < 0.0 or _hit.has(e):
				continue
			if position.distance_to(e.position) < radius + e.radius:
				_hit_enemy(e)
				if pierce:
					_hit.append(e)
				else:
					queue_free()
					return
	else:
		var p = Game.player
		if p and position.distance_to(p.position) < radius + Game.hit_radius:
			p.hurt(1)
			queue_free()


func _hit_enemy(e) -> void:
	e.hurt(damage)
	if slow > 0.0 and e.kind != Enemy.Kind.BOSS:
		e.slow_t = slow
	if explosive > 0:
		var r := 45.0 + 25.0 * explosive
		for o in get_tree().get_nodes_in_group("enemies"):
			if o != e and not o.dead and o.t >= 0.0 and o.position.distance_to(e.position) < r:
				o.hurt(damage * 0.5)
				if slow > 0.0 and o.kind != Enemy.Kind.BOSS:
					o.slow_t = slow
		var fx := Fx.new()
		fx.position = e.position
		fx.radius = r
		get_parent().add_child(fx)


func _closest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 450.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.t < 0.0:
			continue
		var d := position.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _burst() -> void:
	for i in 8:
		var b := Bullet.new()
		b.setup(position, Vector2.RIGHT.rotated(TAU * i / 8.0) * 150.0, false, 1.0, 4.0, Color(1.0, 0.6, 0.2))
		get_parent().add_child(b)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	if not friendly:
		draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.9))
