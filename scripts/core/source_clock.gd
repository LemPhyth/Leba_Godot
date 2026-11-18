extends RefCounted
## Flash source ticks, independent of display FPS and Godot's 60 Hz physics.
const RATE := 25.0
const STEP := 1.0 / RATE
var accumulator := 0.0
var ticks := 0

func consume(delta: float) -> int:
	if delta < 0.0 or not is_finite(delta):
		return 0
	accumulator += delta
	var count := int(floor((accumulator + 0.00000001) / STEP))
	accumulator -= count * STEP
	ticks += count
	return count

func reset() -> void:
	accumulator = 0.0
	ticks = 0
