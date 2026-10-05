class_name VerbAbility
extends Ability
## A verb defined only by data: the skill's active effect carries a `spec` and VerbKinds does what it says.

## Not ready when it cannot be paid for (a forge without the parts), so the player spends nothing on it.
func ready() -> bool:
	return super.ready() and VerbKinds.can_run(self, spec)

func _perform() -> void:
	if not VerbKinds.can_run(self, spec):
		return
	VerbKinds.run(self, spec)
	if spec.has("cooldown"):
		_cooldown = float(spec["cooldown"])
