class_name RoomWeakFloor
extends Node2D
## A patch of floor that gives way under whoever stands on it for a moment, unless it was found: a reveal (a tap) shows it and it holds. When it falls the way
## underneath is open. Group `hidden` until found. `pos` is the surface, `width` how wide.

const HOLD_SECONDS := 0.5
const THICKNESS := 8.0

var id := ""
var width := 40.0
var _revealed := false
var _fallen := false
var _body: StaticBody2D
var _stood := 0.0

func setup(f: Dictionary, _ctx: Dictionary) -> void:
	id = f.get("id", "")
	position = f.get("pos", Vector2.ZERO)
	width = float(f.get("width", width))
	add_to_group("hidden")

func _ready() -> void:
	_body = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(width, THICKNESS)
	shape.shape = box
	_body.add_child(shape)
	_body.position = Vector2(0.0, THICKNESS / 2.0)
	add_child(_body)

func is_revealed() -> bool:
	return _revealed

func has_fallen() -> bool:
	return _fallen

func reveal() -> void:
	_revealed = true
	remove_from_group("hidden")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _revealed or _fallen:
		return
	var stood := false
	for body in get_tree().get_nodes_in_group("player"):
		if body is Node2D:
			var d: Vector2 = body.global_position - global_position
			if absf(d.x) <= width / 2.0 and d.y <= 6.0 and d.y >= -30.0:
				stood = true
	_stood = _stood + delta if stood else 0.0
	if _stood >= HOLD_SECONDS:
		_fallen = true
		if is_instance_valid(_body):
			_body.queue_free()  # the way underneath is open

func _draw() -> void:
	if _revealed:
		for x in range(int(-width / 2.0), int(width / 2.0), 8):
			draw_line(Vector2(x, 1), Vector2(x + 4, 6), Color(0.9, 0.85, 0.6, 0.8), 1.0)
