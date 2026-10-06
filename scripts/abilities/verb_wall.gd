class_name VerbWall
extends Node2D
## A wall of web a verb spins ahead of the caster (the Cave Matriarch's): an enemy that crosses it is caught, held fast for `root` seconds (once each) and slowed
## after. Group `verb_walls`; it goes when its time is up or its caster is gone.

const HALF_WIDTH := 7.0

var caster: Node2D
var height := 60.0
var _root := 1.5
var _left := 0.0
var _caught := {}

func launch(p_caster: Node2D, at: Vector2, p_height: float, seconds: float, root: float) -> void:
	add_to_group("verb_walls")
	caster = p_caster
	global_position = at
	height = p_height
	_left = seconds
	_root = root
	z_index = 2

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or not is_instance_valid(caster):
		queue_free()
		return
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Enemy) or _caught.has(n.get_instance_id()) or n.dormant or n.status.state != EnemyStatus.ACTIVE:
			continue
		var d: Vector2 = n.global_position - global_position
		if absf(d.x) <= HALF_WIDTH and d.y <= 12.0 and d.y >= -height:
			_caught[n.get_instance_id()] = true
			n.root_for(_root)
			n.slow_for(_root * 2.0)

func _draw() -> void:
	var c := Color(0.9, 0.9, 1.0, 0.6)
	draw_line(Vector2(0, 0), Vector2(0, -height), c, 1.0)
	for y in range(0, int(height), 10):
		draw_line(Vector2(-5, -y), Vector2(5, -y - 5), c, 1.0)
		draw_line(Vector2(5, -y), Vector2(-5, -y - 5), c, 1.0)
