extends SimulatorInterface
class_name ServerSimulator
## Authoritative simulation of one peer's player, running on the server.

## Most inputs held for one peer. At the client's 60 Hz send rate this is about
## 200 ms of slack; past that the oldest are dropped rather than allowed to add
## unbounded latency to everything the peer does.
const MAX_QUEUED_INPUTS: int = 12

var queued_input_arrays: Array[PackedByteArray] = []

## Input tick most recently simulated, echoed back to the owning client so it
## knows how far its prediction has been confirmed. -1 until the first input.
var last_processed_input_tick: int = -1

## Last input actually simulated. Repeated when the queue runs dry so that
## gravity and momentum keep advancing instead of the body stalling mid-air.
var _last_input_array: PackedByteArray = PackedByteArray()

func _ready() -> void:
	SignalManager.Networking.ServerSimulatorSpawned.emit(player.owning_peer_id, self)

func queue_input(input_array: PackedByteArray) -> void:
	queued_input_arrays.append(input_array)
	while queued_input_arrays.size() > MAX_QUEUED_INPUTS:
		queued_input_arrays.pop_front()

## Advance this peer's authoritative body by exactly one physics step, consuming
## at most one queued input.
##
## This used to drain the whole queue in a single pass, calling move_and_slide
## several times back to back inside one frame. The client simulates one input
## per physics frame, so the two integrations disagreed about collisions and
## slopes and the client was being corrected constantly. Consuming one input per
## step keeps the server's integration identical to the client's.
func simulate_tick(physics_delta: float) -> void:
	var input_array: PackedByteArray
	if queued_input_arrays.is_empty():
		input_array = LocalInputController.without_one_shot_bits(_last_input_array)
	else:
		input_array = queued_input_arrays.pop_front()
		_last_input_array = input_array
		last_processed_input_tick = LocalInputController.packet_tick(input_array)

	if not LocalInputController.is_packet_valid(input_array):
		# Nothing has ever arrived for this peer, so there is no input to apply.
		return

	var input_bits: int = LocalInputController.packet_input_bits(input_array)
	var yaw_bits: int = LocalInputController.packet_yaw(input_array)
	var desired_velocity: Vector3 = _generate_velocity_from_input_bits(
		physics_delta, input_bits, yaw_bits
	)
	_apply_velocity(physics_delta, desired_velocity, wants_jump(input_bits))

## Authoritative state for this peer as of [param current_server_tick].
func build_snapshot(current_server_tick: int) -> Dictionary:
	return {
		INPUT_TICK_KEY: last_processed_input_tick,
		POS_KEY: body.global_position,
		VEL_KEY: body.velocity,
		SERVER_TICK_KEY: current_server_tick,
		PEER_ID_KEY: player.owning_peer_id,
	}
