class_name PlayerSensors
extends RefCounted
## Edge-triggered player event emitters. Only the player owns one (actor boundary).

var emit_event: Callable = Callable()
var _was_on_wall := false
var _inspected := {}

## wall_touched fires when is_on_wall() goes false -> true while airborne.
func physics_update(on_wall: bool, on_floor: bool) -> void:
	if on_wall and not _was_on_wall and not on_floor:
		_emit(Events.WALL_TOUCHED, {})
	_was_on_wall = on_wall

func jumped(from: String) -> void:
	_emit(Events.JUMPED, {"from": from})

func inspected(target: String, appraisal_target: bool) -> void:
	var first := not _inspected.has(target)
	_inspected[target] = true
	_emit(Events.INSPECTED, {"target": target, "first_time": first, "appraisal_target": appraisal_target})

func _emit(event_name: String, tags: Dictionary) -> void:
	if emit_event.is_valid():
		emit_event.call(event_name, tags)
