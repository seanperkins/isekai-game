extends Ability
## Grappling-hook swing: up and forward.

func _perform() -> void:
	actor.apply_impulse(Vector2(actor.facing * 260.0, -360.0))
	Vfx.puffs(actor, Art.texture("slime_idle"), [actor.global_position], Color(0.9, 0.9, 1.0, 0.6), 0.25)  # afterimage
