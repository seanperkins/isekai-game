class_name Rubble
extends Node2D
## A loose object lying in the room: what is left of a broken wall. A poltergeist throws it (Hurl); it is spent when thrown. Group `loose`.

func _ready() -> void:
	add_to_group("loose")
	z_index = 1

func _draw() -> void:
	draw_rect(Rect2(-5, -4, 5, 4), Color(0.45, 0.43, 0.4))
	draw_rect(Rect2(0, -6, 6, 6), Color(0.52, 0.5, 0.46))
	draw_rect(Rect2(-2, -9, 4, 3), Color(0.4, 0.38, 0.36))
