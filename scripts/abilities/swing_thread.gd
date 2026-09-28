extends Ability
## Grappling-hook swing: up and forward.

func _perform() -> void:
	actor.apply_impulse(Vector2(actor.facing * 260.0, -360.0))
