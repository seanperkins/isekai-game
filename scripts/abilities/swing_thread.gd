extends Ability
## Grappling-hook swing toward the aim; always pulls upward. Default: up and forward.

const PULL := 440.0
const MIN_LIFT := -200.0

func _perform() -> void:
	var v := Vector2(actor.facing * 260.0, -360.0)
	if aim != Vector2.ZERO:
		v = aim_dir() * PULL
		v.y = minf(v.y, MIN_LIFT)
	actor.apply_impulse(v)
	Vfx.puffs(actor, Art.texture("slime_idle"), [actor.global_position], Color(0.9, 0.9, 1.0, 0.6), 0.25)  # afterimage
