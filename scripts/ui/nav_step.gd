class_name NavStep
extends RefCounted
## The selection step for a stick reading: the dominant axis past THRESHOLD as a four-way direction (Vector2i.UP is up),
## edge-triggered, then slow repeats while held. Stick motion arrives as a stream of events, so reading it per event skipped
## rows. Shared by the skill screen and the goddess's menu.

## Stick navigation: one row per push; held past DELAY it repeats every REPEAT.
const THRESHOLD := 0.5
const DELAY := 0.35
const REPEAT := 0.12

var _dir := Vector2i.ZERO
var _timer := 0.0

func step(stick: Vector2, delta: float) -> Vector2i:
	var dir := Vector2i.ZERO
	if maxf(absf(stick.x), absf(stick.y)) >= THRESHOLD:
		dir = Vector2i(int(signf(stick.x)), 0) if absf(stick.x) > absf(stick.y) else Vector2i(0, int(signf(stick.y)))
	if dir == Vector2i.ZERO:
		_dir = Vector2i.ZERO
		return dir
	if dir != _dir:
		_dir = dir
		_timer = DELAY
		return dir
	_timer -= delta
	if _timer <= 0.0:
		_timer = REPEAT
		return dir
	return Vector2i.ZERO

## Forgets a held push, so the next one is a fresh edge (a screen that closed mid-push).
func reset() -> void:
	_dir = Vector2i.ZERO
