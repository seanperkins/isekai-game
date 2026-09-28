extends Ability
## Instant water blade along the aim: hits the nearest other-team actor, drawn as a streak.

const RANGE := 160.0

func _perform() -> void:
	var targets := targets_in_front(RANGE, 20.0)
	var end := actor.global_position + aim_dir() * RANGE
	if not targets.is_empty():
		targets[0].receive_hit(value(), "physical")
		end = targets[0].global_position
	Vfx.line(actor, actor.global_position, end, Color(0.45, 0.85, 1.0), 3.0, 0.2)
