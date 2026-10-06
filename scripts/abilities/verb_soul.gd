class_name VerbSoul
extends Node2D
## A hidden soul (Hidden soul): an anchor the caster places. If the caster would die within `range` of it, it rises here instead, once per life, and the anchor is
## spent. An enemy that stays at the anchor wears it down, and when it is destroyed it is gone. Group `verb_souls`.

const HURT_REACH := Vector2(14.0, 24.0)
const HURT_SECONDS := 1.0

var caster: Node2D
var range_px := 240.0
var hp := 6
var _hurt_in := 0.0

func launch(p_caster: Node2D, at: Vector2, p_hp: int, p_range: float) -> void:
	add_to_group("verb_souls")
	caster = p_caster
	global_position = at
	hp = p_hp
	range_px = p_range
	z_index = 1

func covers(n: Node2D) -> bool:
	return n.global_position.distance_to(global_position) <= range_px

func _physics_process(delta: float) -> void:
	_hurt_in = maxf(0.0, _hurt_in - delta)
	if _hurt_in > 0.0:
		return
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Enemy) or n.dormant or n.status.state != EnemyStatus.ACTIVE or n.is_turned():
			continue
		var d: Vector2 = n.global_position - global_position
		if absf(d.x) <= HURT_REACH.x and absf(d.y) <= HURT_REACH.y:
			hp -= int(n.def.stats.get("atk", 1))
			_hurt_in = HURT_SECONDS
			queue_redraw()
			if hp <= 0:
				remove_from_group("verb_souls")
				queue_free()
			return

func _draw() -> void:
	draw_circle(Vector2(0, -6), 4.0, Color(0.7, 0.9, 1.0, 0.9))
	draw_arc(Vector2(0, -6), 7.0, 0.0, TAU, 16, Color(0.7, 0.9, 1.0, 0.4), 1.0)
