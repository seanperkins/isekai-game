extends Ability
## Short poison cone in front of the actor, shown as a spray of green globs.

const RANGE := 56.0

func _perform() -> void:
	for t in targets_in_front(RANGE, 24.0):
		t.receive_hit(value(), "poison")
	var origin := actor.global_position
	var puffs: Array = []
	for i in 4:
		puffs.append(origin + Vector2(actor.facing * (14.0 + i * 12.0), -3.0 + (i % 2) * 6.0 - i))
	Vfx.puffs(actor, Art.texture("spit_glob"), puffs, Color(0.6, 1.0, 0.4, 0.9), 0.4)
