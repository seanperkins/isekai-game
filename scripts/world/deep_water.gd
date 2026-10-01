class_name DeepWater
extends Node2D
## One deep-water rect of a room: the volume swimming is measured against (PlayerWater, the swimmers' confinement) and its
## drawing: a translucent tint, a lighter surface line and a few bubbles rising. Solids draw in front of it.

const TINT := Color(0.25, 0.55, 0.85, 0.30)
const SURFACE := Color(0.75, 0.92, 1.0, 0.75)
const BUBBLE := Color(0.85, 0.95, 1.0, 0.6)

## True when the rect reaches the room's top edge: its top is a door a swimmer may cross, not a surface it must stay under.
var reaches_top := false
var local_rect := Rect2()
var _t := 0.0

static func make(rect: Rect2) -> DeepWater:
	var w := DeepWater.new()
	w.local_rect = Rect2(Vector2.ZERO, rect.size)
	w.position = rect.position
	w.reaches_top = rect.position.y <= 0.5
	w.add_to_group("deep_water")
	return w

func world_rect() -> Rect2:
	return Rect2(global_position, local_rect.size)

## The deep water holding `world_point` (the body centre), or null.
static func at(tree: SceneTree, world_point: Vector2) -> DeepWater:
	for n in tree.get_nodes_in_group("deep_water"):
		if (n as DeepWater).world_rect().has_point(world_point):
			return n
	return null

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(local_rect, TINT)
	var wave := sin(_t * 2.0) * 1.0
	draw_line(Vector2(0.0, wave), Vector2(local_rect.size.x, -wave), SURFACE, 1.5)
	for i in 5:
		var x := fposmod(float(i) * 37.0 + 11.0, local_rect.size.x)
		var rise := fposmod(_t * 14.0 + float(i) * 23.0, local_rect.size.y)
		draw_circle(Vector2(x, local_rect.size.y - rise), 1.2, BUBBLE)
