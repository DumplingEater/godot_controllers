extends SimulatorInterface
class_name ServerSimulator


var queued_input_arrays: Array[PackedByteArray]

func _ready() -> void:
	SignalManager.Networking.ServerSimulatorSpawned.emit(player.owning_peer_id, self)

func queue_input(input_array: PackedByteArray):
	queued_input_arrays.append(input_array)

func server_step(current_server_tick: int, physics_delta: float) -> Dictionary:
	var last_processed_tick: int = -1
	while not queued_input_arrays.is_empty():
		var input_array: PackedByteArray = queued_input_arrays.pop_front()
		var current_input_bits: int = input_array.decode_u16(LocalInputController.INPUT_OFFSET)
		var yaw_bits: int = input_array.decode_u16(LocalInputController.YAW_OFFSET)
		var desired_velocity: Vector3 = _generate_velocity_from_input_bits(physics_delta, current_input_bits, yaw_bits)
		_apply_velocity(physics_delta, desired_velocity)
		last_processed_tick = input_array.decode_u16(LocalInputController.TICK_OFFSET)

	var peer_id: int = player.owning_peer_id
	var pos: Vector3 = body.global_position
	var vel: Vector3 = body.velocity
	var tick: int =  current_server_tick

	return {
		INPUT_TICK_KEY: last_processed_tick,
		POS_KEY: pos,
		VEL_KEY: vel,
		SERVER_TICK_KEY: tick,
	}

func _process_input_array(input_array: PackedByteArray) -> void:
	pass
