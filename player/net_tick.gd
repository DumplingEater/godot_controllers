extends RefCounted
class_name NetTick
## Arithmetic for the wrapping 16 bit tick counters used by input packets and
## snapshots. Pure statics, so it is directly unit testable.

## Ticks are sent as unsigned 16 bit values and wrap at this.
const TICK_MODULO: int = 1 << 16

## The tick after [param tick], wrapping.
static func next(tick: int) -> int:
	return posmod(tick + 1, TICK_MODULO)

## Shortest signed distance from tick [param b] to tick [param a], accounting
## for the wrap. Positive when a is ahead of b, negative when behind. A tick and
## the tick half a cycle away are equidistant; that case resolves as behind.
static func difference(a: int, b: int) -> int:
	var diff: int = posmod(a - b, TICK_MODULO)
	if diff >= TICK_MODULO >> 1:
		diff -= TICK_MODULO
	return diff
