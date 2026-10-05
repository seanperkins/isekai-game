class_name VerbAbility
extends Ability
## A verb defined only by data: the skill's active effect carries a `spec` and VerbKinds does what it says.

func _perform() -> void:
	VerbKinds.run(self, spec)
	if spec.has("cooldown"):
		_cooldown = float(spec["cooldown"])
