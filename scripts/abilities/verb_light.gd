class_name VerbLight
extends Node2D
## A drifting light (Lure-light): enemies near it follow it, reckless of what is underfoot, and it shows where its caster is. Group `verb_lights`.

var caster: Node2D
var radius := 120.0
var reveal := 120.0
var _dir := Vector2.RIGHT
var _speed := 40.0
var _left := 0.0

func launch(p_caster: Node2D, at: Vector2, dir: Vector2, speed: float, seconds: float, p_radius: float, p_reveal: float) -> void:
	add_to_group("verb_lights")
	caster = p_caster
	global_position = at
	_dir = dir
	_speed = speed
	_left = seconds
	radius = p_radius
	reveal = p_reveal
	z_index = 3
	add_child(Art.light(Color(0.7, 0.95, 1.0), 0.8, 1.2))

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or not is_instance_valid(caster):
		queue_free()
		return
	global_position += _dir * _speed * delta
	for n in get_tree().get_nodes_in_group("actors"):
		if n is Enemy and n.global_position.distance_to(global_position) <= radius:
			n.lure_to(self, 0.25, true)
	if caster.has_method("break_veil") and caster.global_position.distance_to(global_position) <= reveal:
		caster.break_veil()  # the light shows where you are
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(0.8, 1.0, 1.0, 0.9))
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Color(0.6, 0.9, 1.0, 0.4), 1.0)
