class_name Prop
extends Node2D
## Objeto/NPC placeholder: uma forma colorida com um rótulo. Serve pra passageiros, NPCs, caixas e portas.

var shape := "rect"      # "rect" | "circle"
var size := Vector2(36.0, 36.0)
var color := Color.WHITE
var label := ""
var lines: Array = []    # diálogo: [[quem fala, texto], ...]
var done := false
var id := 0
var locked := false
var opened := false


func _draw() -> void:
	if shape == "circle":
		draw_circle(Vector2.ZERO, size.x * 0.5, color)
	else:
		draw_rect(Rect2(-size * 0.5, size), color)
		draw_rect(Rect2(-size * 0.5, size), color.darkened(0.5), false, 2.0)
	if locked:
		draw_line(-size * 0.5, size * 0.5, Color(0, 0, 0, 0.6), 3.0)
		draw_line(Vector2(size.x, -size.y) * 0.5, Vector2(-size.x, size.y) * 0.5, Color(0, 0, 0, 0.6), 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-80.0, -size.y * 0.5 - 8.0), label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 14)
