extends Ability
## Long dash along the aim (vertical part damped so it stays a dash, not a launch).

const SPEED := 700.0
const VERTICAL_SCALE := 0.6

func _perform() -> void:
	var dir := aim_dir()
	actor.apply_impulse(Vector2(dir.x * SPEED, dir.y * SPEED * VERTICAL_SCALE))
	Vfx.puffs(actor, Art.texture("slime_idle"), [actor.global_position], Color(0.6, 0.9, 1.0, 0.6), 0.25)  # afterimage
