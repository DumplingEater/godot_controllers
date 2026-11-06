extends RefCounted
class_name SnapshotInterpolator
## Buffers authoritative snapshots for one subject and plays them back on a
## clock held deliberately behind the newest one.
##
## This is the whole of the ghost playback algorithm, deliberately free of
## nodes, signals and autoloads so that it can be unit tested on its own.
## GhostSimulator owns one and applies its output to a body.

## Snapshots retained. A couple of seconds at the broadcast rate is ample;
## anything older can never be rendered again.
const BUFFER_CAPACITY: int = 24

## How far behind the newest received snapshot playback is held, in broadcast
## ticks. One tick leaves no slack for jitter; two absorbs a single late or
## dropped packet without running dry.
const INTERPOLATION_DELAY_TICKS: float = 2.0

## How far playback carries on past the newest snapshot before holding.
const MAX_EXTRAPOLATION_TICKS: float = 2.0

## Drift beyond this many ticks is corrected by jumping the clock rather than
## easing it. Generous on purpose: easing an outage out as a brief catch-up
## slide looks far better than teleporting, so only genuinely stale playback
## is worth snapping.
const RESYNC_THRESHOLD_TICKS: float = 25.0

## Fraction of the remaining drift taken out per step while easing.
const DRIFT_CORRECTION_RATE: float = 0.1

## Ceiling on how fast playback may run while catching up, as a multiple of
## real time. Without it a large drift is eaten in a single step, which is the
## teleport this is meant to avoid. Inert unless actually behind.
const MAX_CATCHUP_RATE: float = 4.0

## Samples ordered by ascending sequence, each
## {"seq": int, "pos": Vector3, "vel": Vector3}.
var _samples: Array[Dictionary] = []

## Sequence of the newest sample, and the wrapped tick it came from. Together
## they unwrap later ticks across the 16 bit boundary, so the timeline stays
## monotonic when the sender's counter rolls over.
var _newest_seq: int = 0
var _newest_wrapped_tick: int = -1

var _playback_seq: float = 0.0
var _playback_started: bool = false

var _tick_duration: float = 1.0 / 10.0

func _init(tick_duration: float = 1.0 / 10.0) -> void:
	set_tick_duration(tick_duration)

## Seconds between broadcasts. Ignored if not positive.
func set_tick_duration(tick_duration: float) -> void:
	if tick_duration > 0.0:
		_tick_duration = tick_duration

func tick_duration() -> float:
	return _tick_duration

func sample_count() -> int:
	return _samples.size()

func has_samples() -> bool:
	return not _samples.is_empty()

func playback_sequence() -> float:
	return _playback_seq

func newest_sequence() -> int:
	return _newest_seq

## Sequences currently buffered, oldest first. For tests and debugging.
func buffered_sequences() -> Array[int]:
	var out: Array[int] = []
	for sample in _samples:
		out.append(sample["seq"])
	return out

## Take one authoritative snapshot. Snapshots travel unreliably, so these can
## arrive late, duplicated or out of order; samples are stored by sequence
## rather than arrival order and a duplicate replaces in place.
func insert(wrapped_tick: int, sample_position: Vector3, sample_velocity: Vector3) -> void:
	if wrapped_tick < 0:
		return

	var seq: int
	if _newest_wrapped_tick < 0:
		seq = 0
		_newest_seq = 0
		_newest_wrapped_tick = wrapped_tick
	else:
		seq = _newest_seq + NetTick.difference(wrapped_tick, _newest_wrapped_tick)
		if seq > _newest_seq:
			_newest_seq = seq
			_newest_wrapped_tick = wrapped_tick

	var sample: Dictionary = {
		"seq": seq,
		"pos": sample_position,
		"vel": sample_velocity,
	}

	var index: int = _samples.size()
	while index > 0 and _samples[index - 1]["seq"] > seq:
		index -= 1

	if index > 0 and _samples[index - 1]["seq"] == seq:
		_samples[index - 1] = sample
	else:
		_samples.insert(index, sample)

	while _samples.size() > BUFFER_CAPACITY:
		_samples.remove_at(0)

## Advance playback by [param delta] seconds and return the state to display as
## {"position": Vector3, "velocity": Vector3}, or an empty dictionary when
## nothing has been received yet.
func advance(delta: float) -> Dictionary:
	if _samples.is_empty():
		return {}

	var target_seq: float = float(_samples[-1]["seq"]) - INTERPOLATION_DELAY_TICKS

	if not _playback_started:
		_playback_seq = target_seq
		_playback_started = true
	else:
		var nominal: float = delta / _tick_duration
		var drift: float = target_seq - (_playback_seq + nominal)

		if absf(drift) > RESYNC_THRESHOLD_TICKS:
			_playback_seq = target_seq
		else:
			var advance_by: float = nominal + drift * DRIFT_CORRECTION_RATE
			advance_by = minf(advance_by, nominal * MAX_CATCHUP_RATE)
			advance_by = maxf(advance_by, 0.0)  # the clock must never run backwards
			_playback_seq += advance_by

	var state: Dictionary = _state_at_playback()
	_discard_consumed_samples()
	return state

func _state_at_playback() -> Dictionary:
	var oldest: Dictionary = _samples[0]
	var newest: Dictionary = _samples[-1]

	# Playback has not reached the buffer yet, as on the first frames after a
	# subject appears.
	if _playback_seq <= float(oldest["seq"]):
		return _state(oldest["pos"], oldest["vel"])

	# Ran past everything received. Carry on along the last known velocity for a
	# moment, then hold, rather than freezing the instant a packet is late.
	if _playback_seq >= float(newest["seq"]):
		var overshoot: float = minf(
			_playback_seq - float(newest["seq"]), MAX_EXTRAPOLATION_TICKS
		)
		var extrapolated: Vector3 = newest["pos"] + newest["vel"] * (overshoot * _tick_duration)
		return _state(extrapolated, newest["vel"])

	for i in range(_samples.size() - 1):
		var from_sample: Dictionary = _samples[i]
		var to_sample: Dictionary = _samples[i + 1]
		var from_seq: float = float(from_sample["seq"])
		var to_seq: float = float(to_sample["seq"])

		if _playback_seq < from_seq or _playback_seq > to_seq:
			continue

		var span: float = to_seq - from_seq
		var t: float = 0.0 if span <= 0.0 else (_playback_seq - from_seq) / span
		return _state(
			from_sample["pos"].lerp(to_sample["pos"], t),
			from_sample["vel"].lerp(to_sample["vel"], t)
		)

	return _state(newest["pos"], newest["vel"])

func _state(state_position: Vector3, state_velocity: Vector3) -> Dictionary:
	return {"position": state_position, "velocity": state_velocity}

## Drop samples playback has passed, always keeping the one it interpolates
## from plus everything newer.
func _discard_consumed_samples() -> void:
	while _samples.size() > 2 and float(_samples[1]["seq"]) <= _playback_seq:
		_samples.remove_at(0)
