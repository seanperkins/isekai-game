class_name PredationHold
extends RefCounted
## Hold-to-eat timer. Base 1 s, scaled by the predation_time stat (percent of base).

const BASE_SECONDS := 1.0

var target: Object = null
var _elapsed := 0.0
var _required := BASE_SECONDS

func start(p_target: Object, predation_time_percent: int) -> void:
	target = p_target
	_elapsed = 0.0
	_required = BASE_SECONDS * predation_time_percent / 100.0

func update(delta: float) -> bool:
	if target == null:
		return false
	_elapsed += delta
	return _elapsed >= _required - 0.0001

## How far through the hold we are, 0 to 1.
func progress() -> float:
	if target == null or _required <= 0.0:
		return 0.0
	return clampf(_elapsed / _required, 0.0, 1.0)

func cancel() -> void:
	target = null
	_elapsed = 0.0

func active() -> bool:
	return target != null
