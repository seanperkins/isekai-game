class_name RoomForge
extends Node2D
## A forge in a room (the village's): a smith's verb that needs a forge works beside it. Group `forges`. `pos` is the base of the anvil.

var id := ""

func setup(f: Dictionary, _ctx: Dictionary) -> void:
	id = f.get("id", "")
	position = f.get("pos", Vector2.ZERO)
	add_to_group("forges")

func _draw() -> void:
	draw_rect(Rect2(-9, -8, 18, 4), Color(0.35, 0.35, 0.4))
	draw_rect(Rect2(-5, -4, 10, 4), Color(0.3, 0.3, 0.34))
	draw_rect(Rect2(-12, -12, 8, 4), Color(0.4, 0.4, 0.46))
	draw_circle(Vector2(8, -14), 2.0, Color(1.0, 0.55, 0.2, 0.9))
