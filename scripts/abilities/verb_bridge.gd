class_name VerbBridge
extends Node2D
## A plank a verb lays across a gap (Span): one one-way platform at the caster's feet, ahead of it, that a body can stand on and
## walk over. It goes when its time is up. Group `verb_bridges`; `caster` lets a second cast replace the first.

const PLANK_THICKNESS := 4.0

var caster: Node2D
var _seconds := 0.0
var _elapsed := 0.0

## `centre` is where the middle of the plank goes; `length` how long it is.
func launch(p_caster: Node2D, centre: Vector2, length: float, seconds: float) -> void:
	add_to_group("verb_bridges")
	caster = p_caster
	_seconds = seconds
	var body := StaticBody2D.new()
	body.position = centre
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(length, PLANK_THICKNESS)
	shape.shape = box
	shape.one_way_collision = true
	body.add_child(shape)
	add_child(body)
	global_position = Vector2.ZERO
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _seconds:
		queue_free()

func _draw() -> void:
	for c in get_children():
		if c is StaticBody2D:
			var s: CollisionShape2D = c.get_child(0)
			var size: Vector2 = (s.shape as RectangleShape2D).size
			draw_rect(Rect2(c.position - size / 2.0, size), Color(0.8, 0.8, 0.9))
