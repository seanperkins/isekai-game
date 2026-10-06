class_name VerbNetwork
extends Node2D
## A growth that spreads along the floor (Network): it starts small and creeps outward, slows the enemies it reaches, and shows the way to a mark. Group `verb_networks`.

const START_RADIUS := 24.0
const SLOW_SECONDS := 0.5

var caster: Node2D
var _r := START_RADIUS
var _max_r := 140.0
var _grow := 20.0
var _left := 0.0

func launch(p_caster: Node2D, at: Vector2, max_radius: float, seconds: float, grow: float) -> void:
	add_to_group("verb_networks")
	caster = p_caster
	global_position = at
	_max_r = max_radius
	_left = seconds
	_grow = grow
	z_index = 0

func current_radius() -> float:
	return _r

## What it shows the way to: the start of the caster's trail, else the nearest thing it can use (a pool, a tablet, a switch).
func route_target() -> Node2D:
	for t in get_tree().get_nodes_in_group("verb_trails"):
		if t.caster == caster:
			return t
	var best: Node2D = null
	var best_d := 1.0e9
	for n in get_tree().get_nodes_in_group("interactable"):
		var d: float = n.global_position.distance_to(global_position)
		if d < best_d:
			best = n
			best_d = d
	return best

## Where the route to its target goes: the start of a trail (the node itself sits at the origin), else the thing's own place.
func route_point() -> Vector2:
	var t := route_target()
	if t == null:
		return global_position
	return t.start_point() if t.has_method("start_point") else t.global_position

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or not is_instance_valid(caster):
		queue_free()
		return
	_r = minf(_max_r, _r + _grow * delta)
	for n in get_tree().get_nodes_in_group("actors"):
		if n is Enemy and n.global_position.distance_to(global_position) <= _r:
			n.slow_for(SLOW_SECONDS)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, _r, Color(0.6, 0.8, 0.4, 0.2))
	draw_arc(Vector2.ZERO, _r, 0.0, TAU, 40, Color(0.7, 0.9, 0.5, 0.5), 1.0)
	if route_target() != null:
		var to := to_local(route_point())
		var steps := int(to.length() / 10.0)
		for i in range(0, steps, 2):
			draw_line(to * (float(i) / float(steps)), to * (float(i + 1) / float(steps)), Color(1.0, 0.95, 0.5, 0.7), 1.0)
