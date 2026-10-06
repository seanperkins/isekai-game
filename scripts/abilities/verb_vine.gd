class_name VerbVine
extends Node2D
## The steps of a grown vine (Stalk): one-way platforms stacked up from the floor, alternating left and right, that a body can jump up
## through and land on. It goes when its time is up. Group `verb_vines`.

const STEP_GAP := 40.0
const STEP_SIZE := Vector2(32.0, 4.0)
const STEP_SWAY := 12.0

const CLIMB_HALF_WIDTH := 14.0

var caster: Node2D
var _seconds := 0.0
var _elapsed := 0.0
var _points := PackedVector2Array()
var _floor := Vector2.ZERO
var _height := 0.0
var _grown := 0.0
var _grow := 0.0
var _steps := 0

## `floor_point` is where the vine starts; `height` how far it climbs. With `grow` (px/s) it climbs slowly and the steps appear as it reaches them; with `climb` a body
## can hold on to it and climb (group `climbables`).
func launch(floor_point: Vector2, height: float, seconds: float, grow := 0.0, p_caster: Node2D = null, climb := false) -> void:
	add_to_group("verb_vines")
	if climb:
		add_to_group("climbables")
	caster = p_caster
	_seconds = seconds
	_floor = floor_point
	_height = height
	_grow = grow
	global_position = Vector2.ZERO
	_points.append(floor_point)
	if grow <= 0.0:
		_grown = height
		_add_steps()
	queue_redraw()

func grown() -> float:
	return _grown

## The column a body can climb: from the floor up to as far as it has grown.
func zone_rect() -> Rect2:
	return Rect2(_floor.x - CLIMB_HALF_WIDTH, _floor.y - _grown, CLIMB_HALF_WIDTH * 2.0, _grown)

func _add_steps() -> void:
	while _steps < maxi(1, int(_height / STEP_GAP)) and float(_steps + 1) * STEP_GAP <= _grown + 0.001:
		var at := _floor + Vector2(STEP_SWAY if _steps % 2 == 0 else -STEP_SWAY, -STEP_GAP * float(_steps + 1))
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
		_steps += 1

func _process(delta: float) -> void:
	_elapsed += delta
	if _grow > 0.0 and _grown < _height:
		_grown = minf(_height, _grown + _grow * delta)
		_add_steps()
		queue_redraw()
	if _elapsed >= _seconds:
		queue_free()

func _draw() -> void:
	if _points.size() > 1:
		draw_polyline(_points, Color(0.35, 0.75, 0.3), 3.0)
	for i in range(1, _points.size()):
		draw_rect(Rect2(_points[i] - STEP_SIZE / 2.0, STEP_SIZE), Color(0.45, 0.85, 0.35))
