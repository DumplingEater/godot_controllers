extends SimulatorInterface
class_name LocalSimulator

const LOCAL_HISTORY_SIZE: int = 128

var local_snapshots: Array[Dictionary] = []
var local_input_history: Array[PackedByteArray] = []

var history_start_tick: int = 0
var last_processed_tick: int = 0

var current_input_array: PackedByteArray  # updated every tick by simulator

func _ready() -> void:
	SignalManager.UserInput.UserInputGenerated.connect(_user_input_generated)
	SignalManager.Networking.SimulationSnapshotReceived.connect(_on_snapshot_received)
	local_snapshots.resize(LOCAL_HISTORY_SIZE)
	local_input_history.resize(LOCAL_HISTORY_SIZE)
	
func _user_input_generated(input_array: PackedByteArray):
	current_input_array = input_array

func _on_snapshot_received(peer_id: int, snapshot: Dictionary) -> void:
	if peer_id != player.owning_peer_id:
		return
	
	_reconcile_snapshot(snapshot)

func _physics_process(frame_delta: float) -> void:
	if locked:
		return
	
	accumulator += frame_delta
	while accumulator >= GameManager.physics_delta:
		var delta: float = GameManager.physics_delta
		
		var input_bits: int = current_input_array.decode_u16(LocalInputController.INPUT_OFFSET)
		var yaw_bits: int = current_input_array.decode_u16(LocalInputController.YAW_OFFSET)
		var desired_velocity: Vector3 = _generate_velocity_from_input_bits(delta, input_bits, yaw_bits)
		_apply_velocity(delta, desired_velocity)
		
		var input_tick: int = current_input_array.decode_u16(LocalInputController.TICK_OFFSET)
		var snapshot: Dictionary = _generate_snapshot(input_tick)
		_store_local_snapshot(input_tick, snapshot)
		
		last_processed_tick = input_tick
		accumulator -= delta
		
func _generate_snapshot(tick: int) -> Dictionary:
	return {
		POS_KEY: body.global_position,
		VEL_KEY: body.velocity,
		INPUT_TICK_KEY: tick
	}

func _store_local_snapshot(local_tick: int, snapshot: Dictionary) -> void:
	var index: int = local_tick % LOCAL_HISTORY_SIZE
	local_snapshots[index] = snapshot
	local_input_history[index] = current_input_array.duplicate()

func get_snapshot(tick: int) -> Dictionary:
	var index: int = tick % LOCAL_HISTORY_SIZE
	return local_snapshots[index]

func adjudicate_server_snapshot(server_snapshot: Dictionary) -> void:
	body.global_position = server_snapshot[POS_KEY]
	body.velocity = server_snapshot[VEL_KEY]

func replay_inputs_from_tick(start_tick: int) -> void:
	var tick := start_tick
	while tick <= last_processed_tick:
		var index: int = tick % LOCAL_HISTORY_SIZE
		var input_array: PackedByteArray = local_input_history[index]
		if input_array == null:
			break  # nothing stored, bail out

		var input_bits: int = input_array.decode_u16(LocalInputController.INPUT_OFFSET)
		var yaw_bits: int = input_array.decode_u16(LocalInputController.YAW_OFFSET)
		var delta: float = GameManager.physics_delta
		var desired_velocity: Vector3 = _generate_velocity_from_input_bits(delta, input_bits, yaw_bits)
		_apply_velocity(delta, desired_velocity)

		# update snapshot for this tick
		var snapshot: Dictionary = _generate_snapshot(tick)
		_store_local_snapshot(tick, snapshot)
		
		tick += 1

func _reconcile_snapshot(snapshot: Dictionary) -> void:
	var last_processed_tick: int = snapshot[INPUT_TICK_KEY]
	if last_processed_tick == -1:
		return
	
	
	var matching_local_snapshot: Dictionary = get_snapshot(last_processed_tick)
	if matching_local_snapshot:
		var snapshots_match: bool = _snapshots_close_enough(snapshot, matching_local_snapshot)
		if not snapshots_match:
			adjudicate_server_snapshot(snapshot)
			replay_inputs_from_tick(last_processed_tick + 1)
	else:
		adjudicate_server_snapshot(snapshot)

func _snapshots_close_enough(snap_a: Dictionary, snap_b: Dictionary) -> bool:
	var pos_check: bool = snap_a[POS_KEY].is_equal_approx(snap_b[POS_KEY])
	if not pos_check:
		return false
	
	var vel_check: bool = snap_a[VEL_KEY].is_equal_approx(snap_b[VEL_KEY])
	if not vel_check:
		return false
	
	return true
