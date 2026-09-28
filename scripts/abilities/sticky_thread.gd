extends Ability
## Thread that slows (tier 1) or holds (tier 2) the nearest enemy ahead, drawn as a thread.

const RANGE := 96.0

func _perform() -> void:
	var end := actor.global_position + Vector2(actor.facing * RANGE, 0.0)
	for t in targets_in_front(RANGE, 24.0):
		if t.has_method("receive_thread"):
			t.receive_thread(value())
			end = t.global_position
			break
	Vfx.line(actor, actor.global_position, end, Color(0.95, 0.95, 1.0, 0.9), 1.0, 0.35)
