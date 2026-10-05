class_name PartPickup
extends Node2D
## A part lying on the floor. A body in the `player` group that can take parts (it has collect_part) takes it by standing on it.

const COLLECT_RANGE := 14.0
const RADIUS := 5.0

var part: PartDef
## Seconds it lies before it can be taken: a graft just knocked off is not picked straight back up.
var delay := 0.0
var _taken := false

func setup(p: PartDef, pos: Vector2) -> void:
	part = p
	position = pos

func _ready() -> void:
	add_to_group("pickups")
	z_index = 1
	var diamond := PackedVector2Array([Vector2(0, -RADIUS), Vector2(RADIUS, 0), Vector2(0, RADIUS), Vector2(-RADIUS, 0)])
	var gem := Polygon2D.new()
	gem.name = "Gem"
	gem.polygon = diamond
	gem.color = part.color
	add_child(gem)
	var rim := Line2D.new()
	rim.points = diamond
	rim.closed = true
	rim.width = 1.0
	rim.default_color = part.color.darkened(0.55)
	add_child(rim)

func _physics_process(delta: float) -> void:
	if _taken:
		return
	if delay > 0.0:
		delay -= delta
		return
	for body in get_tree().get_nodes_in_group("player"):
		if body is Node2D and body.has_method("collect_part") and body.global_position.distance_to(global_position) <= COLLECT_RANGE \
				and (not body.has_method("can_collect_parts") or body.can_collect_parts()):
			_taken = true
			body.collect_part(part.id)
			queue_free()
			return
