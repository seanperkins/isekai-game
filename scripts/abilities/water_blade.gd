extends Ability
## Instant water blade along the aim: hits the nearest other-team actor, drawn as a crescent that slides out to the hit.

const RANGE := 160.0

func _perform() -> void:
	var targets := targets_in_front(RANGE, 20.0)
	var end := actor.global_position + aim_dir() * RANGE
	if not targets.is_empty():
		targets[0].receive_hit(value(), "physical", actor.global_position, "blade")
		end = targets[0].global_position
	var dir := aim_dir()
	var crescent := Sprite2D.new()
	crescent.add_to_group("vfx")
	crescent.top_level = true
	crescent.z_index = 6  # over the slime (z 5), so it shows even when the target is at its feet
	crescent.texture = VfxArt.crescent()
	crescent.modulate = Color(0.7, 0.93, 1.0, 0.95)  # paler than the slime, so it reads over it
	crescent.rotation = dir.angle()
	crescent.scale = Vector2(0.6, 0.6)
	Vfx.host(actor).add_child(crescent)
	crescent.global_position = actor.global_position + dir * 24.0
	var tw := crescent.create_tween().set_parallel(true)
	tw.tween_property(crescent, "scale", Vector2(1.3, 1.3), 0.22)
	tw.tween_property(crescent, "global_position", end - dir * 24.0, 0.22)  # arrives a little short of the hit, so it reads as reaching it
	tw.tween_property(crescent, "modulate:a", 0.0, 0.14).set_delay(0.08)  # holds full for the first third, then fades
	tw.chain().tween_callback(crescent.queue_free)
