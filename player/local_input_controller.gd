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

## Build an input packet. The only place the wire layout is written, so that
## the field widths cannot drift apart from the readers again: the tick was
## previously written with encode_u8 while every reader used decode_u16.
static func build_packet(tick: int, yaw: int, input_bits: int) -> PackedByteArray:
	var packet: PackedByteArray = PackedByteArray()
	packet.resize(PACKET_BYTE_COUNT)
	packet.encode_u16(TICK_OFFSET, posmod(tick, NetTick.TICK_MODULO))
	packet.encode_u16(YAW_OFFSET, yaw)
	packet.encode_u16(INPUT_OFFSET, input_bits)
	return packet

## Whether [param packet] is long enough to read.
static func is_packet_valid(packet: PackedByteArray) -> bool:
	return packet.size() >= PACKET_BYTE_COUNT

static func packet_tick(packet: PackedByteArray) -> int:
	return packet.decode_u16(TICK_OFFSET)

static func packet_yaw(packet: PackedByteArray) -> int:
	return packet.decode_u16(YAW_OFFSET)

static func packet_input_bits(packet: PackedByteArray) -> int:
	return packet.decode_u16(INPUT_OFFSET)

## A copy of [param packet] safe to simulate twice: held movement carries over,
## one-off actions are cleared so a repeat cannot fire them again.
static func without_one_shot_bits(packet: PackedByteArray) -> PackedByteArray:
	if not is_packet_valid(packet):
		return packet
	var repeated: PackedByteArray = packet.duplicate()
	repeated.encode_u16(INPUT_OFFSET, packet_input_bits(packet) & ~ONE_SHOT_BITS)
	return repeated

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

	var input_array: PackedByteArray = build_packet(
		tick_counter, get_yaw_as_uint16(), pack_inputs()
	)
	tick_counter = NetTick.next(tick_counter)

	SignalManager.UserInput.UserInputGenerated.emit(input_array)
