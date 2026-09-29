class_name ThreadAbility
extends Ability
## Sticky Thread, Swing Thread and Binding Web. The thread flies along the aim and the first thing it touches decides the
## effect: an enemy is slowed (tier 1) or held (tier 2); terrain becomes an anchor the actor swings from (unless `ropes` is
## false, as for Binding Web). `_land` is told where the thread ended.

var rope_range := 120.0
var reel_speed := 60.0
var release_boost := 1.0
## False for a thread that never ropes (Binding Web): terrain is just where it ends.
var ropes := true

func _perform() -> void:
	var dir := aim_dir()
	var from := actor.global_position
	var target: Node2D = null
	for t in targets_in_front(rope_range, 24.0):
		if t.has_method("receive_thread"):
			target = t
			break
	var anchor = terrain_hit(from, from + dir * rope_range)
	if target != null and (anchor == null or from.distance_to(target.global_position) <= from.distance_to(anchor)):
		target.receive_thread(value())
		Vfx.strand(actor, from, target.global_position, 0.35)
		_land(target.global_position)
	elif ropes and anchor != null and actor.has_method("attach_rope"):
		actor.attach_rope(anchor, rope_range, reel_speed, release_boost)  # the actor draws the rope
	else:
		var end: Vector2 = anchor if (anchor != null and not ropes) else from + dir * rope_range
		Vfx.strand(actor, from, end, 0.35)
		_land(end)

## Called with where the thread ended: the enemy it held, the rock it met, or full range. The base does nothing.
func _land(_end: Vector2) -> void:
	pass
