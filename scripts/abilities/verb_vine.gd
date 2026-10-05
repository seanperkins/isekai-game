class_name VerbVine
extends Node2D
## The steps of a grown vine (Stalk): one-way platforms stacked up from the floor, alternating left and right, that a body can jump up
## through and land on. It goes when its time is up. Group `verb_vines`.

const STEP_GAP := 40.0
const STEP_SIZE := Vector2(32.0, 4.0)
const STEP_SWAY := 12.0

var _seconds := 0.0
var _elapsed := 0.0
var _points := PackedVector2Array()

## `floor_point` is where the vine starts; `height` how far it climbs.
func launch(floor_point: Vector2, height: float, seconds: float) -> void:
	add_to_group("verb_vines")
	_seconds = seconds
	global_position = Vector2.ZERO
	_points.append(floor_point)
	for i in maxi(1, int(height / STEP_GAP)):
		var at := floor_point + Vector2(STEP_SWAY if i % 2 == 0 else -STEP_SWAY, -STEP_GAP * float(i + 1))
		var body := StaticBody2D.new()
		body.position = at
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = STEP_SIZE
		shape.shape = box
		shape.one_way_collision = true
		body.add_child(shape)
		add_child(body)
		_points.append(at)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _seconds:
		queue_free()

func _draw() -> void:
	if _points.size() > 1:
		draw_polyline(_points, Color(0.35, 0.75, 0.3), 3.0)
	for i in range(1, _points.size()):
		draw_rect(Rect2(_points[i] - STEP_SIZE / 2.0, STEP_SIZE), Color(0.45, 0.85, 0.35))
