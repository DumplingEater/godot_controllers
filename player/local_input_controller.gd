extends Node
class_name LocalInputController

var locked: bool = false

var tick_counter: int = 0

# consts to define packets
const PACKET_BYTE_COUNT: int = 6
const TICK_OFFSET: int = 0   # size 2
const INPUT_OFFSET: int = 2  # size 2
const YAW_OFFSET: int = 4    # size 2

## The tick is sent as an unsigned 16 bit value and wraps at this.
const TICK_MODULO: int = 1 << 16

# added in order that I thought of them
const NONE: int = 1 << 0
const FORWARD: int = 1 << 1
const LEFT: int = 1 << 2
const RIGHT: int = 1 << 3
const BACK: int = 1 << 4
const JUMP: int = 1 << 5
const INTERACT: int = 1 << 6
const SHOOT: int = 1 << 7
const THROW_GRENADE: int = 1 << 8
const SPRINT: int = 1 << 9

## Bits that describe a one-off action rather than a held state. The server
## clears these when it has to repeat an input, so that a repeat cannot fire
## the same jump or shot twice.
const ONE_SHOT_BITS: int = JUMP | INTERACT | SHOOT | THROW_GRENADE

func _ready():
	SignalManager.Players.LockPlayer.connect(_on_player_locked)
	SignalManager.Players.UnlockPlayer.connect(_on_player_unlocked)

func _on_player_locked():
	locked = true

func _on_player_unlocked():
	locked = false

func pack_inputs() -> int:
	var bits: int = 0
	if Input.is_action_pressed("move_forward"):
		bits |= FORWARD
	if Input.is_action_pressed("move_left"):
		bits |= LEFT
	if Input.is_action_pressed("move_right"):
		bits |= RIGHT
	if Input.is_action_pressed("move_backward"):
		bits |= BACK
	if Input.is_action_pressed("jump"):
		bits |= JUMP
	if Input.is_action_pressed("throw_grenade"):
		bits |= THROW_GRENADE
	if Input.is_action_pressed("shoot"):
		bits |= SHOOT
	if Input.is_action_pressed("sprint"):
		bits |= SPRINT
	return bits

func get_yaw_as_uint16() -> int:
	if not GameManager.local_player:
		push_warning("No player detected in local_input_controller.gd...")
		# Zero, not -1: this value is written straight into a u16 field, where -1
		# would encode as 65535 and read back as very nearly a full turn.
		return 0

	var forward: Vector3 = GameManager.local_player.camera.basis.z * -1.0
	forward = forward.normalized()

	var angle_to_forward: float = forward.signed_angle_to(Vector3.FORWARD, Vector3.UP)
	if angle_to_forward < 0.0:
		angle_to_forward += MathUtils.PI2

	var yaw: float = angle_to_forward
	var yaw_as_int: int = int((yaw / MathUtils.PI2) * MathUtils.MAX_UINT16)
	return yaw_as_int

func _physics_process(_delta: float) -> void:
	if locked:
		return

	var input_array: PackedByteArray = PackedByteArray()
	input_array.resize(PACKET_BYTE_COUNT)

	# The tick occupies bytes 0-1 and every reader decodes it with decode_u16,
	# so it has to be written as a u16. Writing it with encode_u8 left the high
	# byte zero, which silently folded the counter down to the range 0-255.
	input_array.encode_u16(TICK_OFFSET, tick_counter)
	tick_counter = (tick_counter + 1) % TICK_MODULO

	input_array.encode_u16(YAW_OFFSET, get_yaw_as_uint16())
	input_array.encode_u16(INPUT_OFFSET, pack_inputs())

	SignalManager.UserInput.UserInputGenerated.emit(input_array)
