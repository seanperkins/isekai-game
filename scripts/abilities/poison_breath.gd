extends Ability
## Short poison cone along the aim, shown as a spray of green globs.

const RANGE := 56.0

func _perform() -> void:
	for t in targets_in_front(RANGE, 24.0):
		t.receive_hit(Damage.skill_power(value(), actor_atk()), "poison", actor.global_position, "poison")
	var dir := aim_dir()
	var side := Vector2(-dir.y, dir.x)
	var puffs: Array = []
	for i in 4:
		puffs.append(actor.global_position + dir * (14.0 + i * 12.0) + side * ((i % 2) * 6.0 - 3.0))
	Vfx.puffs(actor, Art.texture("spit_glob"), puffs, Color(0.6, 1.0, 0.4, 0.9), 0.4)
