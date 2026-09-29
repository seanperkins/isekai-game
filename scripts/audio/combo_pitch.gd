class_name ComboPitch
extends RefCounted
## Pitch steps for a cue that retriggers quickly, so a run of absorbs climbs instead of repeating.

var _clock: Callable
var _steps := {}
var _last := {}

func _init(p_clock: Callable) -> void:
	_clock = p_clock

## 0 on the first trigger, +1 per retrigger inside `window` seconds, capped at `max_steps`.
func next(cue: String, window: float, max_steps: int) -> int:
	var now: float = _clock.call()
	var n := 0
	if _last.has(cue) and now - float(_last[cue]) <= window:
		n = mini(int(_steps.get(cue, 0)) + 1, max_steps)
	_steps[cue] = n
	_last[cue] = now
	return n
