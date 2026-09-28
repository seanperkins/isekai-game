extends Ability
## Instant water blade: hits the nearest other-team actor ahead.

func _perform() -> void:
	var targets := targets_in_front(160.0, 20.0)
	if not targets.is_empty():
		targets[0].receive_hit(value(), "physical")
