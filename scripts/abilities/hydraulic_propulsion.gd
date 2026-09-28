extends Ability
## Short water-powered burst; values are percent of base distance.

const BASE_PUSH := 380.0

func _perform() -> void:
	actor.apply_impulse(Vector2(actor.facing * BASE_PUSH * value() / 100.0, -140.0))
	Vfx.puffs(actor, Art.texture("slime_idle"), [actor.global_position], Color(0.5, 0.8, 1.0, 0.6), 0.25)  # afterimage
