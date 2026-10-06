class_name RoomGlyph
extends Node2D
## A glyph on the floor a caller stands on: it emits imps only while the glyph is lit. A player who stands on it for DOUSE_SECONDS puts it out, and it relights after
## RELIGHT_SECONDS. Group `glyphs`. `pos` is the surface.

const REACH := Vector2(16.0, 28.0)
const DOUSE_SECONDS := 1.5
const RELIGHT_SECONDS := 6.0

var id := ""
var _lit := true
var _stood := 0.0
var _dark_t := 0.0

func setup(f: Dictionary, _ctx: Dictionary) -> void:
	id = f.get("id", "")
	position = f.get("pos", Vector2.ZERO)
	add_to_group("glyphs")

func is_lit() -> bool:
	return _lit

func douse() -> void:
	_lit = false
	_dark_t = RELIGHT_SECONDS
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _lit:
		_dark_t -= delta
		if _dark_t <= 0.0:
			_lit = true
			_stood = 0.0
			queue_redraw()
		return
	var on := false
	for body in get_tree().get_nodes_in_group("player"):
		if body is Node2D:
			var d: Vector2 = body.global_position - global_position
			on = on or (absf(d.x) <= REACH.x and absf(d.y) <= REACH.y)
	_stood = _stood + delta if on else 0.0
	if _stood >= DOUSE_SECONDS:
		douse()

func _draw() -> void:
	var c := Color(0.95, 0.35, 0.3, 0.9) if _lit else Color(0.35, 0.3, 0.3, 0.5)
	draw_arc(Vector2(0, -2), 14.0, 0.0, TAU, 24, c, 1.5)
	draw_line(Vector2(-10, 0), Vector2(0, -12), c, 1.0)
	draw_line(Vector2(0, -12), Vector2(10, 0), c, 1.0)
	draw_line(Vector2(10, 0), Vector2(-10, 0), c, 1.0)
