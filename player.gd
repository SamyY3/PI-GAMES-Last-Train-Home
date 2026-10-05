extends CharacterBody2D

const SPEED = 300.0
const FIRE_RATE = 0.1
var fire_timer = 0.0

@export var bullet_scene: PackedScene
@onready var shoot_point = $ShootPoint

func _physics_process(_delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	velocity = direction * SPEED
	
	move_and_slide()

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		shoot()

func _process(delta):
	fire_timer -= delta
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_timer <= 0:
		shoot()

func shoot():
	var bullet = bullet_scene.instantiate()
	bullet.global_position = shoot_point.global_position
	bullet.direction = (get_global_mouse_position() - shoot_point.global_position).normalized()
	get_tree().current_scene.add_child(bullet)
	fire_timer = FIRE_RATE
