extends Ability
## Long horizontal dash.

func _perform() -> void:
	actor.apply_impulse(Vector2(actor.facing * 700.0, 0.0))
