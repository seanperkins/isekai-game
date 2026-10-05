class_name Remains
extends Node2D
## What a life carried when it died, lying where it fell: standing on it gives every part back (through collect_part, so the usual
## rules apply) and says `recovered`, so the world forgets it.

## Said when some of the pile was taken, with what is still left in it (empty when it is all gone).
signal recovered(left: Array)

var parts: Array = []
var _taken := false

func setup(ids: Array, pos: Vector2) -> void:
	parts = ids.duplicate()
	position = pos

func _ready() -> void:
	add_to_group("remains")
	z_index = 1
	var mound := Polygon2D.new()
	mound.name = "Mound"
	mound.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(-6, -5), Vector2(0, -7), Vector2(6, -5), Vector2(8, 0)])
	mound.color = Color(0.82, 0.78, 0.68)
	add_child(mound)
	var cross := Line2D.new()
	cross.points = PackedVector2Array([Vector2(0, -7), Vector2(0, -15), Vector2(-3, -12), Vector2(3, -12)])
	cross.width = 1.0
	cross.default_color = Color(0.95, 0.9, 0.78)
	add_child(cross)

func _physics_process(_delta: float) -> void:
	if _taken:
		return
	for body in get_tree().get_nodes_in_group("player"):
		if body is Node2D and body.has_method("collect_part") and body.global_position.distance_to(global_position) <= PartPickup.COLLECT_RANGE \
				and (not body.has_method("can_collect_parts") or body.can_collect_parts()):
			var left := []
			for id in parts:
				if not body.collect_part(id):
					left.append(id)  # no room for it: it stays in the pile
			if left.size() == parts.size():
				return  # nothing fit: nothing happens, and nothing is said
			parts = left
			recovered.emit(left)
			if left.is_empty():
				_taken = true
				queue_free()
			return
