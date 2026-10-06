class_name Fx
extends Node2D
## Anel de explosão (só efeito visual, dura um instante). O `friendly` tá aí só pra não quebrar a limpeza de balas.

var friendly := true
var radius := 60.0
var life := 0.25
var t := 0.0
var color := Color(1.0, 0.6, 0.2)


func _process(delta: float) -> void:
	if Game.paused:
		return
	t += delta
	queue_redraw()
	if t >= life:
		queue_free()


func _draw() -> void:
	var k := clampf(t / life, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 28, Color(color.r, color.g, color.b, 1.0 - k), 3.0)
