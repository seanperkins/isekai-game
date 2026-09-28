extends Ability
## Short water-powered burst; values are percent of base distance.

const BASE_PUSH := 380.0

func _perform() -> void:
	actor.apply_impulse(Vector2(actor.facing * BASE_PUSH * value() / 100.0, -140.0))
