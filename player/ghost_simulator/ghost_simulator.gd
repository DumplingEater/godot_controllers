extends SimulatorInterface
class_name GhostSimulator
## Displays a player this peer does not own.
##
## The server is authoritative for these bodies, so a ghost never simulates
## physics and never calls move_and_slide. All of the playback logic lives in
## SnapshotInterpolator; this is the plumbing that feeds it snapshots and puts
## its output on the body.

var _interpolator: SnapshotInterpolator = SnapshotInterpolator.new()

func _ready() -> void:
	SignalManager.Networking.SimulationSnapshotReceived.connect(_on_snapshot_received)

	# Read the real cadence from the hub when it is present, so that changing the
	# broadcast rate does not silently desynchronise every ghost.
	var hub: Node = get_node_or_null("/root/NetworkHub")
	if hub != null:
		_interpolator.set_tick_duration(hub.broadcast_delta)

func _on_snapshot_received(subject_peer_id: int, snapshot: Dictionary) -> void:
	if player == null or subject_peer_id != player.owning_peer_id:
		return
	if not snapshot.has(SERVER_TICK_KEY) or not snapshot.has(POS_KEY):
		return

	_interpolator.insert(
		int(snapshot[SERVER_TICK_KEY]),
		snapshot[POS_KEY],
		snapshot.get(VEL_KEY, Vector3.ZERO)
	)

func _physics_process(delta: float) -> void:
	if locked or body == null:
		return

	var state: Dictionary = _interpolator.advance(delta)
	if state.is_empty():
		return

	body.global_position = state["position"]

	# Published but not integrated: the server owns this body. Anything reading
	# velocity for animation or footstep audio still gets a usable value.
	body.velocity = state["velocity"]
