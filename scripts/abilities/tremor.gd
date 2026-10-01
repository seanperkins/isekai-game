extends Ability
## Slams the ground: every enemy standing on a floor within RADIUS takes the skill's damage through its DEF and, if it can be stunned
## (all but the serpent), is stunned for STUN_SECONDS. Fliers and drifters are not on a floor, so it never hits them; a stunned flier
## that has fallen is. `targets_around` also yields a shortcut switch (its receive_hit takes four arguments), so only an Enemy counts.
## Never touches the caster; no caster condition.

const RADIUS := 72.0
const STUN_SECONDS := 1.0

func _perform() -> void:
	var power := Damage.skill_power(value(), actor_atk())
	for t in targets_around(RADIUS):
		if not (t is Enemy) or not t.is_on_floor():
			continue
		t.receive_hit(power, "physical", actor.global_position, "other", true)
		if t.def.predatable:
			t.status.stun(STUN_SECONDS)
	var spots: Array = []
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		spots.append(actor.global_position + Vector2(side * RADIUS * float(i / 2 + 1) / 4.0, 8.0))
	Vfx.puffs(actor, Art.texture("spit_glob"), spots, Color(0.85, 0.65, 0.35, 0.9), 0.3)
