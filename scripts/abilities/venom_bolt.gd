extends Ability
## Evolved Poison Breath: an instant line along the aim that pierces. Every enemy on it takes the poison once; rock ends it.
## The moving bolt is drawn by the effects; only the hit is gameplay.

const RANGE := 260.0
const HALF_WIDTH := 20.0

func _perform() -> void:
	var dir := aim_dir()
	var from := actor.global_position
	var rock = terrain_hit(from, from + dir * RANGE)
	var reach := RANGE if rock == null else from.distance_to(rock)
	for t in targets_in_front(reach, HALF_WIDTH):
		t.receive_hit(Damage.skill_power(value(), actor_atk()), "poison", from, "poison")
	Vfx.line(actor, from, from + dir * reach, Color(0.55, 0.95, 0.3), 2.0, 0.25)
