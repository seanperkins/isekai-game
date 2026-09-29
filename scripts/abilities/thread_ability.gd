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

## What the thread meets first along the aim: {"target": the enemy or null, "anchor": the rock point or null}. An enemy at
## least as near as the rock wins; otherwise the rock (which may be null: nothing in reach).
func _first_contact() -> Dictionary:
	var dir := aim_dir()
	var from := actor.global_position
	var target: Node2D = null
	for t in targets_in_front(rope_range, 24.0):
		if t.has_method("receive_thread"):
			target = t
			break
	var anchor = terrain_hit(from, from + dir * rope_range)
	if target != null and (anchor == null or from.distance_to(target.global_position) <= from.distance_to(anchor)):
		return {"target": target, "anchor": null}
	return {"target": null, "anchor": anchor}

func _perform() -> void:
	var dir := aim_dir()
	var from := actor.global_position
	var contact := _first_contact()
	var target: Node2D = contact["target"]
	var anchor = contact["anchor"]
	if target != null:
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
