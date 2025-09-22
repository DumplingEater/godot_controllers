extends Node3D
class_name SimulatorInterface

@export var move_speed: float = 2.0
@export var sprint_speed: float = 10.0
@export var jump_impulse: float = 4.0
@export var gravity: float = -9.81

var player: Player
var body: CharacterBody3D
var camera: Camera3D = null

var locked: bool = false

var accumulator: float = 0

const INPUT_TICK_KEY: int = 0
const POS_KEY: int = 1
const VEL_KEY: int = 2
const SERVER_TICK_KEY: int = 3

func set_owning_player(owning_player: Player):
	player = owning_player
	body = owning_player.body
	camera = owning_player.camera

func _generate_velocity_from_input_bits(delta: float, input_bits: int, yaw_bits: int) -> Vector3:
	if locked:
		return Vector3.ZERO

	var desired_velocity: Vector3 = Vector3.ZERO

	var speed: float = move_speed
	if input_bits & LocalInputController.SPRINT:
		speed = sprint_speed

	var yaw: float = _decode_yaw(yaw_bits)
	var forward: Vector3 = get_forward(yaw)
	var right: Vector3 = get_right(yaw)
	var left: Vector3 = right * -1.0
	var backward: Vector3 = forward * -1.0
	
	
	if input_bits & LocalInputController.FORWARD:
		desired_velocity += Vector3(forward.x, 0, forward.z).normalized() * speed
	if input_bits & LocalInputController.BACK:
		desired_velocity += Vector3(backward.x, 0, backward.z).normalized() * speed
	if input_bits & LocalInputController.LEFT:
		desired_velocity += Vector3(left.x, 0, left.z).normalized() * speed
	if input_bits & LocalInputController.RIGHT:
		desired_velocity += Vector3(right.x, 0, right.z).normalized() * speed

	if input_bits & LocalInputController.JUMP and body.is_on_floor():
		desired_velocity.y = jump_impulse
	
	return desired_velocity
	
func _apply_velocity(delta: float, desired_velocity: Vector3) -> void:
	body.velocity.x = desired_velocity.x
	body.velocity.z = desired_velocity.z
	body.velocity.y += desired_velocity.y
	if not body.is_on_floor():
		body.velocity.y += gravity * delta
	
	body.move_and_slide()

func _decode_yaw(yaw_as_uint16:  int) -> float:
	var yaw: float = float(float(yaw_as_uint16) / float(MathUtils.MAX_UINT16)) * TAU
	return yaw

func get_forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, -cos(yaw))

func get_right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0, sin(yaw))
