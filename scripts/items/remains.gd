class_name Remains
extends Node2D
## What a life carried when it died, lying where it fell: standing on it gives every part back (through collect_part, so the usual
## rules apply) and says `recovered`, so the world forgets it.

signal recovered

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
			_taken = true
			for id in parts:
				body.collect_part(id)
			recovered.emit()
			queue_free()
			return
