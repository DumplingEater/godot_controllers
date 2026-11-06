extends Node3D
class_name SimulatorInterface
## Shared movement integration for the local, server and ghost simulators.

const INPUT_TICK_KEY: int = 0
const POS_KEY: int = 1
const VEL_KEY: int = 2
const SERVER_TICK_KEY: int = 3
## Peer whose player a snapshot describes. Required now that snapshots are
## broadcast to every client, because the receiver is no longer always the
## subject of the snapshot it is reading.
const PEER_ID_KEY: int = 4

@export var move_speed: float = 2.0
@export var sprint_speed: float = 10.0
@export var jump_impulse: float = 4.0
@export var gravity: float = -9.81

var player: Player
var body: CharacterBody3D
var camera: Camera3D = null

var locked: bool = false

var accumulator: float = 0

func set_owning_player(owning_player: Player):
	player = owning_player
	body = owning_player.body
	camera = owning_player.camera

func _generate_velocity_from_input_bits(_delta: float, input_bits: int, yaw_bits: int) -> Vector3:
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

	return desired_velocity

## Whether this input should start a jump on this step. Kept separate from the
## desired velocity so that the impulse can be assigned rather than added.
func wants_jump(input_bits: int) -> bool:
	if locked:
		return false
	if not (input_bits & LocalInputController.JUMP):
		return false
	if body == null:
		return false
	return body.is_on_floor()

func _apply_velocity(delta: float, desired_velocity: Vector3, jump_triggered: bool = false) -> void:
	body.velocity.x = desired_velocity.x
	body.velocity.z = desired_velocity.z

	# Assigned rather than accumulated. Adding the impulse let it stack on every
	# frame the jump input was held while the body still counted as on the floor.
	if jump_triggered:
		body.velocity.y = jump_impulse

	if not body.is_on_floor():
		body.velocity.y += gravity * delta

	body.move_and_slide()

func _decode_yaw(yaw_as_uint16: int) -> float:
	var yaw: float = float(float(yaw_as_uint16) / float(MathUtils.MAX_UINT16)) * TAU
	return yaw

func get_forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, -cos(yaw))

func get_right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0, sin(yaw))
