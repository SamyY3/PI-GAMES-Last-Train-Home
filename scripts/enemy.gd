class_name Enemy
extends Node2D
## Inimigos (tudo placeholder por enquanto): Autômato, Robô de manutenção, Atirador e o boss Maquinista.

enum Kind { AUTOMATON, ROBOT, BOSS, SNIPER }

signal phase_changed(phase: int)

var kind: int = Kind.AUTOMATON
var hp := 3.0
var max_hp := 3.0
var radius := 16.0
var phase := 1
var t := 0.0            # negativo = ainda tá "nascendo" (não leva dano e não atira)
var cd := 1.0
var shot_n := 0
var spiral := 0.0
var flash := 0.0
var target := Vector2.ZERO
var dead := false
var slow_t := 0.0       # > 0: tá lento (efeito do Vapor gélido)
var elite := false      # elite (só Difícil/Pesadelo): mais vida, mais tiro e um anel dourado em volta


func setup(k: int) -> void:
	kind = k
	match k:
		Kind.AUTOMATON:
			hp = 3.0
			radius = 16.0
		Kind.ROBOT:
			hp = 7.0
			radius = 20.0
		Kind.BOSS:
			hp = Game.boss_hp()   # a vida acompanha o DPS da sua build (olha o Game.boss_hp)
			radius = 46.0
		Kind.SNIPER:
			hp = 4.0
			radius = 15.0
	if k != Kind.BOSS:
		hp *= Game.enemy_hp_factor()
		if Game.waves_cleared >= 2 and randf() < Game.elite_chance():
			elite = true
			hp *= 2.0
			radius *= 1.15
	max_hp = hp
	t = -0.7
	cd = randf_range(0.6, 1.4)


func _ready() -> void:
	add_to_group("enemies")
	target = position


func _process(delta: float) -> void:
	if Game.paused or Game.over or dead:
		return
	flash = maxf(0.0, flash - delta)
	slow_t = maxf(0.0, slow_t - delta)
	var dt := delta * (0.55 if slow_t > 0.0 else 1.0)
	t += delta
	queue_redraw()
	if t < 0.0:
		return
	match kind:
		Kind.AUTOMATON: _automaton(dt)
		Kind.ROBOT: _robot(dt)
		Kind.BOSS: _boss(dt)
		Kind.SNIPER: _sniper(dt)


func hurt(d: float) -> void:
	if dead or t < 0.0:
		return
	hp -= d
	flash = 0.08
	if hp <= 0.0:
		dead = true
		Game.on_kill()
		queue_free()


# ---------- como cada um se comporta ----------

func _automaton(d: float) -> void:
	_wander(70.0, d)
	cd -= d
	if cd <= 0.0:
		cd = _cd(1.6)
		var half := 1 if elite else 0
		for i in range(-half, half + 1):
			_fire(position, _aim().rotated(i * 0.18), 230.0)


func _robot(d: float) -> void:
	_wander(50.0, d)
	cd -= d
	if cd <= 0.0:
		cd = _cd(2.4)
		var off := randf() * TAU
		var n := 14 if elite else 10
		for i in n:
			_fire(position, Vector2.RIGHT.rotated(off + TAU * i / float(n)), 150.0, 5.0, Color(1.0, 0.7, 0.2))


func _sniper(d: float) -> void:
	_wander(40.0, d)
	cd -= d
	if cd <= 0.0:
		cd = _cd(2.0)
		var aim := _aim()
		var half := 2 if elite else 1
		for i in range(-half, half + 1):
			_fire(position, aim.rotated(i * 0.07), 340.0, 4.0, Color(0.8, 0.45, 1.0))


func _boss(d: float) -> void:
	var ratio := hp / max_hp
	var np := 1 if ratio > 0.66 else (2 if ratio > 0.33 else 3)
	if np != phase:
		phase = np
		phase_changed.emit(phase)
		cd = 1.5
		_clear_enemy_bullets()
	var a := Game.ARENA
	var sway := 300.0 if phase < 3 else 380.0
	position.x = a.position.x + a.size.x * 0.5 + sin(t * 0.7) * sway
	position.y = a.position.y + 90.0 + sin(t * 1.3) * 20.0
	cd -= d
	if cd > 0.0:
		return
	shot_n += 1
	var dens: float = Game.diff()["boss_density"]
	match phase:
		1:  # pistola, canhão e minas
			cd = _bcd(0.9)
			var aim := _aim()
			var half := 1 if dens < 1.2 else 2
			for i in range(-half, half + 1):
				_fire(position, aim.rotated(i * 0.25), 260.0)
			if shot_n % 3 == 0:
				_fire(position, Vector2.DOWN.rotated(randf_range(-0.6, 0.6)), 90.0, 9.0, Color(1.0, 0.6, 0.1), 1.4)
		2:  # a locomotiva acorda: vapor/pistões (anéis) e canhões laterais
			cd = _bcd(1.0)
			var off := shot_n * 0.21
			var ring_n := int(round(14.0 * dens))
			for i in ring_n:
				_fire(position, Vector2.RIGHT.rotated(off + TAU * i / float(ring_n)), 170.0)
			if shot_n % 2 == 0:
				var py: float = Game.player.position.y
				_fire(Vector2(a.position.x, py), Vector2.RIGHT, 320.0, 6.0, Color(1.0, 0.85, 0.2))
				_fire(Vector2(a.end.x, py), Vector2.LEFT, 320.0, 6.0, Color(1.0, 0.85, 0.2))
		3:  # Estação Zero: bala pra todo lado
			cd = _bcd(0.11)
			spiral += 0.33
			_fire(position, Vector2.RIGHT.rotated(spiral), 210.0, 4.5, Color(1.0, 0.3, 0.3))
			_fire(position, Vector2.RIGHT.rotated(spiral + PI), 210.0, 4.5, Color(1.0, 0.3, 0.3))
			if shot_n % 14 == 0:
				var aim3 := _aim()
				for i in range(-2, 3):
					_fire(position, aim3.rotated(i * 0.2), 300.0, 5.0, Color(1.0, 0.8, 0.3))
			if dens >= 1.2 and shot_n % 30 == 0:   # Difícil pra cima: anel extra na fase final
				for i in 16:
					_fire(position, Vector2.RIGHT.rotated(TAU * i / 16.0 + spiral), 180.0, 5.0, Color(1.0, 0.6, 0.2))


# ---------- helpers ----------

func _wander(speed: float, d: float) -> void:
	if position.distance_to(target) < 10.0:
		var a := Game.ARENA
		target = Vector2(randf_range(a.position.x + 60.0, a.end.x - 60.0), randf_range(a.position.y + 50.0, a.position.y + 260.0))
	position += (target - position).normalized() * speed * d


func _aim() -> Vector2:
	return (Game.player.position - position).normalized()


## Intervalo entre tiros dos inimigos comuns (depende da dificuldade e das ondas; elite atira mais rápido).
func _cd(base: float) -> float:
	return base * Game.fire_cd_mult() * (0.8 if elite else 1.0)


## O boss sente só metade desse efeito (raiz quadrada), senão vira uma parede de bala impossível.
func _bcd(base: float) -> float:
	return base * sqrt(Game.fire_cd_mult())


func _fire(pos: Vector2, dir: Vector2, speed: float, r := 5.0, col := Color(1.0, 0.4, 0.2), burst := -1.0) -> void:
	var b := Bullet.new()
	b.setup(pos, dir * speed * Game.bullet_speed_mult(), false, 1.0, r, col)
	b.burst_after = burst
	Game.bullets_root.add_child(b)


func _clear_enemy_bullets() -> void:
	for b in Game.bullets_root.get_children():
		if not b.friendly:
			b.queue_free()


# ---------- visual placeholder (troca por sprite depois) ----------

func _draw() -> void:
	if t < 0.0:  # aviso de que o bicho vai nascer
		var k := 1.0 + t
		draw_arc(Vector2.ZERO, radius * (1.8 - k), 0.0, TAU, 24, Color(1, 0.4, 0.2, 0.8), 2.0)
		return
	var white := flash > 0.0
	match kind:
		Kind.AUTOMATON:
			var c := Color.WHITE if white else Color(0.55, 0.55, 0.6)
			draw_rect(Rect2(-14, -14, 28, 28), c)
			draw_rect(Rect2(-14, -14, 28, 28), Color(0.3, 0.3, 0.35), false, 2.0)
			draw_circle(Vector2(0, -2), 5.0, Color(1, 0.15, 0.15))
		Kind.ROBOT:
			var c2 := Color.WHITE if white else Color(0.8, 0.5, 0.2)
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(Vector2.RIGHT.rotated(TAU * i / 6.0) * radius)
			draw_colored_polygon(pts, c2)
			draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.15, 0.1))
		Kind.SNIPER:
			var c4 := Color.WHITE if white else Color(0.55, 0.3, 0.75)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)]), c4)
			draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1))
		Kind.BOSS:
			var shades := [Color(0.6, 0.15, 0.15), Color(0.7, 0.3, 0.1), Color(0.85, 0.1, 0.4)]
			var c3: Color = Color.WHITE if white else shades[phase - 1]
			draw_rect(Rect2(-50, -38, 100, 76), c3)
			draw_rect(Rect2(-50, -38, 100, 76), Color(0.9, 0.7, 0.3), false, 4.0)
			draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 16, Color(0.9, 0.7, 0.3), 4.0)
			draw_circle(Vector2.ZERO, 8.0, Color(1, 0.9, 0.4))
	if elite:
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.2), 3.0)
		draw_arc(Vector2.ZERO, radius + 9.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.2, 0.35), 2.0)
	if slow_t > 0.0:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 20, Color(0.55, 0.85, 1.0, 0.9), 2.0)
