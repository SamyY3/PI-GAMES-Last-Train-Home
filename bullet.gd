extends Area2D

const SPEED = 800.0
var direction = Vector2.UP

func _process(delta):
	position += direction * SPEED * delta
