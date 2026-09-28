class_name ThreadAbility
extends Ability
## Sticky Thread and Swing Thread. The thread flies along the aim and the first thing it
## touches decides the effect: an enemy is slowed (tier 1) or held (tier 2); terrain becomes
## an anchor the actor swings from.

const THREAD_COLOR := Color(0.95, 0.95, 1.0, 0.9)

var rope_range := 120.0
var reel_speed := 60.0
var release_boost := 1.0

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
		Vfx.line(actor, from, target.global_position, THREAD_COLOR, 1.0, 0.35)
	elif anchor != null and actor.has_method("attach_rope"):
		actor.attach_rope(anchor, rope_range, reel_speed, release_boost)  # the actor draws the rope
	else:
		Vfx.line(actor, from, from + dir * rope_range, THREAD_COLOR, 1.0, 0.35)

## The first terrain point on the segment, or null. Actors never block the thread.
func terrain_hit(from: Vector2, to: Vector2):
	var query := PhysicsRayQueryParameters2D.create(from, to)
	var skip: Array[RID] = []
	for n in actor.get_tree().get_nodes_in_group("actors"):
		if n is CollisionObject2D:
			skip.append(n.get_rid())
	query.exclude = skip
	var hit := actor.get_world_2d().direct_space_state.intersect_ray(query)
	return null if hit.is_empty() else hit["position"]
