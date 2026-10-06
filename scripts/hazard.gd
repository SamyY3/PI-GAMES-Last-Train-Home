class_name Hazard
extends Node2D
## Jato de vapor (Vagão 2): primeiro avisa em laranja, depois machuca quem estiver dentro.

var size := Vector2(120.0, 40.0)
var period := 3.0
var t := 0.0
var active_color := Color(0.9, 0.95, 1.0, 0.75)
var warn_color := Color(1.0, 0.6, 0.2, 0.3)


func _process(delta: float) -> void:
	if Game.paused or Game.over:
		return
	t += delta
	queue_redraw()
	if _is_active():
		var p = Game.player
		if p and Rect2(position - size * 0.5, size).has_point(p.position):
			p.hurt(1)


func _phase() -> float:
	return fposmod(t, period)


func _is_active() -> bool:
	return _phase() > period - 0.7


func _is_warning() -> bool:
	return _phase() > period - 1.7 and not _is_active()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)
	if _is_warning():
		draw_rect(r, warn_color)
	elif _is_active():
		draw_rect(r, active_color)
