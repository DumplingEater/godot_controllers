extends Node
class_name LocalInputController

var locked: bool = false

var tick_counter: int = 0

# consts to define packets
const PACKET_BYTE_COUNT: int = 6
const TICK_OFFSET: int = 0   # size 2
const INPUT_OFFSET: int = 2  # size 2
const YAW_OFFSET: int = 4    # size 2

# added in order that I thought of them
static var NONE: int = 1 << 0
static var FORWARD: int = 1 << 1
static var LEFT: int = 1 << 2
static var RIGHT: int = 1 << 3
static var BACK: int = 1 << 4
static var JUMP: int = 1 << 5
static var INTERACT: int = 1 << 6
static var SHOOT: int = 1 << 7
static var THROW_GRENADE: int = 1 << 8
static var SPRINT: int = 1 << 9

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
		
	var input_array: PackedByteArray = PackedByteArray()
	input_array.resize(4)  # reserve 2 bytes
	input_array.encode_u16(0, bits)  # write bits at position 0
	return bits

func get_yaw_as_uint16() -> int:
	var forward: Vector3 = GameManager.local_player.camera.basis.z * -1.0
	forward = forward.normalized()
	
	var angle_to_forward: float = forward.signed_angle_to(Vector3.FORWARD, Vector3.UP)
	if angle_to_forward < 0.0:
		angle_to_forward += PI * 2.0
	
	var yaw: float = angle_to_forward
	var yaw_as_int: int = int(((yaw / MathUtils.PI2) * MathUtils.MAX_UINT16))
	return yaw_as_int

func _physics_process(_delta: float) -> void:
	if locked:
		return
	# gather input
	var input_array: PackedByteArray = PackedByteArray()
	input_array.resize(PACKET_BYTE_COUNT)  # make it 4 bytes long
	
	# encode tick
	input_array.encode_u8(TICK_OFFSET, tick_counter)
	# this line below is from gpt. Apparently this increments a u16
	tick_counter = (tick_counter + 1) & 0xFFFF  # wrap at 65535
	
	var yaw: int = get_yaw_as_uint16()
	input_array.encode_u16(YAW_OFFSET, yaw)
	
	# encode inpuut bits into position 1. takes bytes 1 and 2
	var input_bits: int = pack_inputs()
	input_array.encode_u16(INPUT_OFFSET, input_bits)
	
	SignalManager.UserInput.UserInputGenerated.emit(input_array)
