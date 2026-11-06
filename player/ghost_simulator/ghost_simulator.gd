extends SimulatorInterface
class_name GhostSimulator
## Displays a player this peer does not own.
##
## The server is authoritative for these bodies, so a ghost never simulates
## physics and never calls move_and_slide. It buffers the authoritative
## snapshots that arrive for its subject and plays them back on a clock held
## deliberately behind the newest one. That delay is what turns a 10 Hz
## broadcast into continuous motion, and what stops a late or dropped packet
## from showing up as a stutter.

## Snapshots retained for interpolation. A couple of seconds at the broadcast
## rate is ample; anything older can never be rendered again.
const BUFFER_CAPACITY: int = 24

## How far behind the newest received snapshot playback is held, in broadcast
## ticks. One tick would leave no slack for jitter at all; two absorbs a single
## late or dropped packet without running dry.
const INTERPOLATION_DELAY_TICKS: float = 2.0

## How far playback will carry on past the newest snapshot before it gives up
## and holds position, in broadcast ticks.
const MAX_EXTRAPOLATION_TICKS: float = 2.0

## Drift beyond this many ticks is corrected by jumping the playback clock
## rather than easing it. Generous on purpose: easing an outage out as a brief
## catch-up slide looks far better than teleporting, so only genuinely stale
## playback (a rejoin, a long freeze) is worth snapping. Lowering this to 6
## turned a 1.5 s outage into a 7 m jump instead of a 0.33 m one.
const RESYNC_THRESHOLD_TICKS: float = 25.0

## Fraction of the remaining drift taken out per physics frame while easing.
const DRIFT_CORRECTION_RATE: float = 0.1

## Ceiling on how fast playback may run while catching up, as a multiple of
## real time. Without it a large drift is eaten in a single frame, which is the
## teleport this is all meant to avoid. Inert unless actually behind.
const MAX_CATCHUP_RATE: float = 4.0

## Broadcast interval assumed when NetworkHub cannot be reached.
const DEFAULT_BROADCAST_DELTA: float = 1.0 / 10.0

## Samples ordered by ascending sequence. Each is
## {"seq": int, "pos": Vector3, "vel": Vector3}.
var _samples: Array[Dictionary] = []

## Sequence of the newest sample, and the wrapped server tick it came from.
## Together they unwrap later ticks across the 16 bit boundary, so that the
## timeline stays monotonic even when the server's tick counter rolls over.
var _newest_seq: int = 0
var _newest_wrapped_tick: int = -1

## Playback position on that sequence timeline, in broadcast ticks.
var _playback_seq: float = 0.0
var _playback_started: bool = false

var _broadcast_delta: float = DEFAULT_BROADCAST_DELTA

func _ready() -> void:
	SignalManager.Networking.SimulationSnapshotReceived.connect(_on_snapshot_received)

	# Read the real cadence from the hub when it is present, so that changing
	# the broadcast rate does not silently desynchronise every ghost.
	var hub: Node = get_node_or_null("/root/NetworkHub")
	if hub != null and hub.broadcast_delta > 0.0:
		_broadcast_delta = hub.broadcast_delta

func _on_snapshot_received(subject_peer_id: int, snapshot: Dictionary) -> void:
	if player == null or subject_peer_id != player.owning_peer_id:
		return

	_insert_sample(snapshot)

func _insert_sample(snapshot: Dictionary) -> void:
	if not snapshot.has(SERVER_TICK_KEY) or not snapshot.has(POS_KEY):
		return

	var wrapped_tick: int = int(snapshot[SERVER_TICK_KEY])
	var seq: int
	if _newest_wrapped_tick < 0:
		seq = 0
		_newest_seq = 0
		_newest_wrapped_tick = wrapped_tick
	else:
		seq = _newest_seq + tick_difference(wrapped_tick, _newest_wrapped_tick)
		if seq > _newest_seq:
			_newest_seq = seq
			_newest_wrapped_tick = wrapped_tick

	var sample: Dictionary = {
		"seq": seq,
		"pos": snapshot[POS_KEY],
		"vel": snapshot.get(VEL_KEY, Vector3.ZERO),
	}

	# Snapshots travel unreliably, so they can arrive late, out of order or
	# duplicated. Insert by sequence rather than assuming arrival order.
	var index: int = _samples.size()
	while index > 0 and _samples[index - 1]["seq"] > seq:
		index -= 1

	if index > 0 and _samples[index - 1]["seq"] == seq:
		_samples[index - 1] = sample
	else:
		_samples.insert(index, sample)

	while _samples.size() > BUFFER_CAPACITY:
		_samples.remove_at(0)

func _physics_process(delta: float) -> void:
	if locked or _samples.is_empty():
		return

	var target_seq: float = float(_samples[-1]["seq"]) - INTERPOLATION_DELAY_TICKS

	if not _playback_started:
		_playback_seq = target_seq
		_playback_started = true
	else:
		var nominal: float = delta / _broadcast_delta
		var drift: float = target_seq - (_playback_seq + nominal)

		# Ease toward the target so that normal jitter does not jerk the body,
		# but jump outright once playback is hopelessly stale.
		if absf(drift) > RESYNC_THRESHOLD_TICKS:
			_playback_seq = target_seq
		else:
			var advance: float = nominal + drift * DRIFT_CORRECTION_RATE
			advance = minf(advance, nominal * MAX_CATCHUP_RATE)
			advance = maxf(advance, 0.0)  # the clock must never run backwards
			_playback_seq += advance

	_apply_playback_state()
	_discard_consumed_samples()

func _apply_playback_state() -> void:
	var oldest: Dictionary = _samples[0]
	var newest: Dictionary = _samples[-1]

	# Playback has not reached the buffer yet, which happens on the first few
	# frames after a ghost appears.
	if _playback_seq <= float(oldest["seq"]):
		_set_body_state(oldest["pos"], oldest["vel"])
		return

	# Ran past everything received. Carry on along the last known velocity for a
	# moment, then hold, rather than freezing the instant a packet is late.
	if _playback_seq >= float(newest["seq"]):
		var overshoot: float = minf(_playback_seq - float(newest["seq"]), MAX_EXTRAPOLATION_TICKS)
		var extrapolated: Vector3 = newest["pos"] + newest["vel"] * (overshoot * _broadcast_delta)
		_set_body_state(extrapolated, newest["vel"])
		return

	for i in range(_samples.size() - 1):
		var from_sample: Dictionary = _samples[i]
		var to_sample: Dictionary = _samples[i + 1]
		var from_seq: float = float(from_sample["seq"])
		var to_seq: float = float(to_sample["seq"])

		if _playback_seq < from_seq or _playback_seq > to_seq:
			continue

		var span: float = to_seq - from_seq
		var t: float = 0.0 if span <= 0.0 else (_playback_seq - from_seq) / span
		_set_body_state(
			from_sample["pos"].lerp(to_sample["pos"], t),
			from_sample["vel"].lerp(to_sample["vel"], t)
		)
		return

func _set_body_state(next_position: Vector3, next_velocity: Vector3) -> void:
	if body == null:
		return

	body.global_position = next_position

	# Published but not integrated: the server owns this body. Anything reading
	# velocity for animation or footstep audio still gets a usable value.
	body.velocity = next_velocity

## Drop samples that playback has already passed, always keeping the one it is
## interpolating from plus everything newer.
func _discard_consumed_samples() -> void:
	while _samples.size() > 2 and float(_samples[1]["seq"]) <= _playback_seq:
		_samples.remove_at(0)
