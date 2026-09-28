extends Ability
## Thread that slows (tier 1) or holds (tier 2) the nearest enemy ahead.

func _perform() -> void:
	for t in targets_in_front(96.0, 24.0):
		if t.has_method("receive_thread"):
			t.receive_thread(value())
			return
