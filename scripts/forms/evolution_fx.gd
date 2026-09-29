class_name EvolutionFx
extends Node2D
## The evolution burst around the slime: a bright ring expanding from its body while the slime itself glows
## and swells (Player._update_visual). Lives EVOLVE_SECONDS, then frees itself.

const SECONDS := 1.2
const MAX_RADIUS := 64.0

var tint := Color(0.7, 0.9, 1.0)
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= SECONDS:
		queue_free()

func _draw() -> void:
	var k := clampf(_t / SECONDS, 0.0, 1.0)
	var alpha := (1.0 - k) * 0.9
	var c := Color(tint.r, tint.g, tint.b, alpha)
	draw_arc(Vector2(0, -12), 8.0 + MAX_RADIUS * k, 0.0, TAU, 48, c, 3.0 * (1.0 - k) + 1.0)
	draw_arc(Vector2(0, -12), 4.0 + MAX_RADIUS * 0.6 * k, 0.0, TAU, 32, Color(1, 1, 1, alpha * 0.7), 2.0)
