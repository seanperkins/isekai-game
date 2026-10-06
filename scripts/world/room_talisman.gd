class_name RoomTalisman
extends Node2D
## A paper charm on the door frame: a hopping corpse (the Jiangshi's Hop) cannot hop within its reach. Group `talismans`. `radius` is in the feature's data.

var id := ""
var radius := 64.0

func setup(f: Dictionary, _ctx: Dictionary) -> void:
	id = f.get("id", "")
	position = f.get("pos", Vector2.ZERO)
	radius = float(f.get("radius", radius))
	add_to_group("talismans")

func covers(n: Node2D) -> bool:
	return n.global_position.distance_to(global_position) <= radius

func _draw() -> void:
	draw_rect(Rect2(-3, -16, 6, 14), Color(0.95, 0.85, 0.35))
	draw_line(Vector2(-2, -12), Vector2(2, -12), Color(0.7, 0.1, 0.1), 1.0)
	draw_line(Vector2(-2, -8), Vector2(2, -8), Color(0.7, 0.1, 0.1), 1.0)
