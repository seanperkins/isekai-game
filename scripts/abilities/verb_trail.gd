class_name VerbTrail
extends Node2D
## A trail laid behind the caster (Recall): its path is kept for `seconds`, and a second cast walks the caster back along it to where it began. Group `verb_trails`.

const STEP_SECONDS := 0.1
const MIN_STEP := 4.0

var caster: Node2D
var points := PackedVector2Array()
var _left := 0.0
var _t := 0.0

func launch(p_caster: Node2D, seconds: float) -> void:
	add_to_group("verb_trails")
	caster = p_caster
	_left = seconds
	global_position = Vector2.ZERO
	points.append(caster.global_position)
	z_index = 1

func start_point() -> Vector2:
	return points[0]

## Gone: the path was walked back, or its time ran out.
func spend() -> void:
	remove_from_group("verb_trails")
	queue_free()

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or not is_instance_valid(caster):
		spend()
		return
	_t += delta
	if _t >= STEP_SECONDS:
		_t = 0.0
		if caster.global_position.distance_to(points[points.size() - 1]) >= MIN_STEP:
			points.append(caster.global_position)
			queue_redraw()

func _draw() -> void:
	if points.size() > 1:
		draw_polyline(points, Color(1.0, 1.0, 1.0, 0.45), 1.0)
	draw_circle(points[0], 3.0, Color(1.0, 0.9, 0.5, 0.8))
