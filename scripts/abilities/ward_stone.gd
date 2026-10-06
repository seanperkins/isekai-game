class_name WardStone
extends Node2D
## A stone planted where the caster stood (Hearth, Lar, Ward, a fear stone, holy ground). It slows the enemies near it, mends the caster, frightens, protects, and
## wards a packmate; stones of one caster close together link into a wider, stronger aura; a tether keeps its keeper near it. Group `ward_stones`. It stays until
## its caster is gone (or its `seconds` run out, when it has any).

const TICK_SECONDS := 1.0
const LINK_BONUS := 0.5
const SLOW_SECONDS := 1.5
const FEAR_SECONDS := 1.5
const WARD_SECONDS := 0.25

var caster: Node2D
var radius := 70.0
var spec := {}
var _tick := 0.0
var _left := -1.0

func launch(p_caster: Node2D, at: Vector2, p_spec: Dictionary) -> void:
	add_to_group("ward_stones")
	caster = p_caster
	global_position = at
	spec = p_spec
	radius = float(spec.get("radius", radius))
	_left = float(spec.get("seconds", 0.0)) if float(spec.get("seconds", 0.0)) > 0.0 else -1.0
	z_index = 1

## Stones of the same caster within `link` of this one (itself among them) make one wider aura.
func linked() -> int:
	var n := 1
	var link := float(spec.get("link", 0.0))
	if link <= 0.0:
		return n
	for s in get_tree().get_nodes_in_group("ward_stones"):
		if s != self and s.caster == caster and s.global_position.distance_to(global_position) <= link:
			n += 1
	return n

func effective_radius() -> float:
	return radius * (1.0 + LINK_BONUS * float(linked() - 1))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(caster) or not caster.is_inside_tree():
		queue_free()
		return
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			queue_free()
			return
	var r := effective_radius()
	var near_caster := caster.global_position.distance_to(global_position) <= r
	if bool(spec.get("protect", false)) or bool(spec.get("holy", false)):
		if near_caster and caster.has_method("ward"):
			caster.ward(WARD_SECONDS)
		for pal in get_tree().get_nodes_in_group("companions"):
			if pal.caster == caster and pal.global_position.distance_to(global_position) <= r:
				pal.ward_for(WARD_SECONDS)
	if spec.has("tether"):
		_tether()
	_tick += delta
	if _tick < TICK_SECONDS:
		return
	_tick -= TICK_SECONDS
	var n := linked()
	for e in get_tree().get_nodes_in_group("actors"):
		if e is Enemy and e.global_position.distance_to(global_position) <= r:
			if bool(spec.get("slow", false)):
				e.slow_for(SLOW_SECONDS)
			if spec.has("status"):
				VerbKinds._apply_status(e, spec["status"])
	if near_caster and spec.has("heals"):
		var health = caster.get("health")
		if health != null:
			health.heal(int(spec["heals"]) * n)
	if bool(spec.get("afraid_allies", false)):
		for a in get_tree().get_nodes_in_group("verb_allies"):
			if a.caster == caster and a.global_position.distance_to(global_position) <= r:
				a.fear_for(FEAR_SECONDS)
		for pal in get_tree().get_nodes_in_group("companions"):
			if pal.caster == caster and pal.global_position.distance_to(global_position) <= r:
				pal.fear_for(FEAR_SECONDS)
	queue_redraw()

## The keeper may not go farther from a sacred spot than its tether.
func _tether() -> void:
	var reach := float(spec["tether"])
	var d: Vector2 = caster.global_position - global_position
	if d.length() > reach:
		caster.global_position = global_position + d.normalized() * reach
		if "velocity" in caster:
			caster.velocity = Vector2.ZERO

func _draw() -> void:
	var r := effective_radius()
	var color := Color(1.0, 0.95, 0.6, 0.18) if bool(spec.get("holy", false)) else Color(0.7, 0.9, 0.7, 0.14)
	draw_circle(Vector2.ZERO, r, color)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, color * Color(1, 1, 1, 3.0), 1.0)
	draw_rect(Rect2(-4, -12, 8, 12), Color(0.55, 0.55, 0.6))
	draw_rect(Rect2(-3, -14, 6, 3), Color(0.7, 0.7, 0.75))
