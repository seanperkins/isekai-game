class_name VerbVeil
extends Node2D
## A web spun over a doorway (Veil): its caster is unseen while standing in it, until it runs out or the caster attacks.

var caster: Node2D
var radius := 60.0
var broken := false
var _left := 0.0

func launch(p_caster: Node2D, at: Vector2, p_radius: float, seconds: float) -> void:
	caster = p_caster
	global_position = at
	radius = p_radius
	_left = seconds
	add_to_group("verb_veils")
	z_index = 3

func covers(n: Node2D) -> bool:
	return not broken and n.global_position.distance_to(global_position) <= radius

func tear() -> void:
	broken = true
	remove_from_group("verb_veils")  # at once: queue_free waits for the end of the frame
	queue_free()

func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 and not broken:
		tear()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.85, 0.85, 0.95, 0.12))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.9, 0.9, 1.0, 0.5), 1.0)
