extends Node

@export var move_speed: float = 0.05

var cam: Node = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cam = get_parent()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_Q):
		cam.global_position.y += move_speed
	if Input.is_key_pressed(KEY_E):
		cam.global_position.y -= move_speed
	if Input.is_key_pressed(KEY_W):
		var forward = cam.basis.z * -1.0
		forward.y = 0.0
		forward = forward.normalized()
		cam.global_position += forward * move_speed
	if Input.is_key_pressed(KEY_S):
		var backward = cam.basis.z
		backward.y = 0.0
		backward = backward.normalized()
		cam.global_position += backward * move_speed
	if Input.is_key_pressed(KEY_D):
		var right = cam.basis.x
		right.y = 0.0
		right = right.normalized()
		cam.global_position += right * move_speed
	if Input.is_key_pressed(KEY_A):
		var left = cam.basis.x * -1.0
		left.y = 0.0
		left = left.normalized()
		cam.global_position += left * move_speed
