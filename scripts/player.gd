class_name Player
extends Node2D
## Jogador (placeholder: quadrado azul). WASD/setas anda, mouse mira, clique ou J atira, Shift esquiva e Ctrl é o modo foco.

signal died
signal hp_changed(hp: int, max_hp: int)

const BASE_SPEED := 260.0

var max_hp := Game.start_hp()
var hp := Game.start_hp()
var active := true
var cooldown := 0.0
var invuln := 0.0
var dash_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector2.ZERO
var aim := Vector2.RIGHT


func _process(delta: float) -> void:
	if Game.paused or Game.over:
		return
	invuln = maxf(0.0, invuln - delta)
	cooldown -= delta
	dash_cd -= delta
	queue_redraw()
	if not active:
		return

	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 4.0:
		aim = to_mouse.normalized()

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and dash_t <= 0.0:
		dash_dir = dir if dir != Vector2.ZERO else aim
		dash_t = 0.18
		dash_cd = 0.8 * Game.dash_mult
		invuln = maxf(invuln, 0.28 + Game.ghost_extra)

	var v: Vector2
	if dash_t > 0.0:
		dash_t -= delta
		v = dash_dir * 700.0
	else:
		var focus := 0.45 if Input.is_action_pressed("focus") else 1.0
		v = dir * BASE_SPEED * Game.speed_mult * focus
	position += v * delta
	var a := Game.ARENA.grow(-14.0)
	position = position.clamp(a.position, a.end)

	if Input.is_action_pressed("shoot") and cooldown <= 0.0:
		cooldown = 0.16 * Game.rate_mult
		_fire()


func _fire() -> void:
	var n := 1 + Game.extra_shots
	for i in n:
		var off := (float(i) - (n - 1) * 0.5) * 10.0
		_shoot(position + aim * 18.0 + aim.orthogonal() * off, aim, 1.0)
	if Game.rear >= 1:
		_shoot(position - aim * 18.0, -aim, 0.6)
	if Game.rear >= 2:
		_shoot(position + aim.orthogonal() * 18.0, aim.orthogonal(), 0.6)
		_shoot(position - aim.orthogonal() * 18.0, -aim.orthogonal(), 0.6)


func _shoot(pos: Vector2, dir: Vector2, mult: float) -> void:
	var crit := randf() < Game.crit_chance
	var b := Bullet.new()
	b.setup(pos, dir * 700.0, true, Game.damage * mult * (2.0 if crit else 1.0), 5.5 if crit else 4.0,
		Color(1.0, 0.9, 0.3) if crit else Color(0.5, 0.9, 1.0))
	b.pierce = Game.pierce
	b.homing = Game.homing
	b.bounces = Game.bounces
	b.explosive = Game.explosive
	b.slow = Game.slow_time
	Game.bullets_root.add_child(b)


func hurt(n: int = 1) -> void:
	if invuln > 0.0 or Game.over or Game.god_mode:
		return
	if Game.shield > 0:
		Game.shield -= 1
		invuln = 0.8
		hp_changed.emit(hp, max_hp)
		return
	hp -= n
	invuln = Game.hit_invuln()
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		active = false
		died.emit()


func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
	hp_changed.emit(hp, max_hp)


func _draw() -> void:
	if invuln > 0.0 and int(Time.get_ticks_msec() / 80) % 2 == 0:
		draw_circle(Vector2.ZERO, Game.hit_radius, Color.WHITE)
		return
	draw_rect(Rect2(-12, -12, 24, 24), Color(0.25, 0.5, 0.8))
	draw_rect(Rect2(-12, -12, 24, 24), Color(0.8, 0.6, 0.25), false, 2.0)
	draw_line(Vector2.ZERO, aim * 24.0, Color(0.9, 0.9, 0.6), 3.0)
	draw_circle(Vector2.ZERO, Game.hit_radius, Color.WHITE)
	draw_arc(Vector2.ZERO, Game.hit_radius, 0.0, TAU, 12, Color(1, 0.2, 0.2), 1.5)
