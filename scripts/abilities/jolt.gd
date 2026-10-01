extends Ability
## A burst of shock around the caster: every enemy in range takes shock damage, and the swimmers (the eels and the jelly) are
## stunned. Never touches the caster.

const RADIUS := 40.0
const STUN_SECONDS := 1.5

func _perform() -> void:
	for t in targets_around(RADIUS):
		t.receive_hit(Damage.skill_power(value(), actor_atk()), "shock", actor.global_position)
		var d = t.get("def")
		if d is CreatureDef and d.swimmer and t.get("status") != null:
			t.status.stun(STUN_SECONDS)
	var spots: Array = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		spots.append(actor.global_position + Vector2(cos(a), sin(a)) * RADIUS * 0.8)
	Vfx.puffs(actor, Art.texture("spit_glob"), spots, Color(0.6, 0.95, 1.0, 0.9), 0.3)
