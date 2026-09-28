extends Ability
## Short poison cone in front of the actor.

func _perform() -> void:
	for t in targets_in_front(56.0, 24.0):
		t.receive_hit(value(), "poison")
