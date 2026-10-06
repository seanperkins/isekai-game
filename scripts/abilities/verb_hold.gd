class_name VerbHold
extends Node
## Holds a creature inside its holder's body for `seconds` (Engulf): it rides at the holder's centre, seen through the body, and is let out again.

var holder: Node2D
var held: Node2D
var _left := 0.0

func launch(p_holder: Node2D, p_held: Node2D, seconds: float) -> void:
	holder = p_holder
	held = p_held
	_left = seconds
	process_physics_priority = 100  # after the creature's own step: the last word on where it is
	held.modulate.a = 0.45

func _physics_process(delta: float) -> void:
	_left -= delta
	if not is_instance_valid(held):
		queue_free()
		return
	if _left <= 0.0 or not is_instance_valid(holder):
		held.modulate.a = 1.0
		queue_free()
		return
	held.global_position = holder.global_position
	if "velocity" in held:
		held.velocity = Vector2.ZERO
