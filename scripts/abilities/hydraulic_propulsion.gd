extends Ability
## Water-powered burst along the aim; values are percent of base distance. A horizontal
## burst also lifts a little so it clears small gaps.

const BASE_PUSH := 380.0
const HORIZONTAL_LIFT := -140.0

func _perform() -> void:
	var dir := aim_dir()
	var push := dir * BASE_PUSH * value() / 100.0
	if is_zero_approx(dir.y):
		push.y += HORIZONTAL_LIFT
	actor.apply_impulse(push)
	Vfx.puffs(actor, Art.texture("slime_idle"), [actor.global_position], Color(0.5, 0.8, 1.0, 0.6), 0.25)  # afterimage
