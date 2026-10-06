class_name RoomSnare
extends Node2D
## A trap hidden in the floor: the first body that steps on it unseen is hurt once (and held for a moment). Group `hidden`, so a reveal (a tap, an opener) shows it,
## and a trap that is known is a harmless one. `pos` is the surface.

const REACH := Vector2(14.0, 26.0)
const DAMAGE := 3

var id := ""
var _revealed := false
var _sprung := false

func setup(f: Dictionary, _ctx: Dictionary) -> void:
	id = f.get("id", "")
	position = f.get("pos", Vector2.ZERO)
	add_to_group("hidden")

func is_revealed() -> bool:
	return _revealed

func reveal() -> void:
	_revealed = true
	remove_from_group("hidden")
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if _revealed or _sprung:
		return
	for body in get_tree().get_nodes_in_group("player"):
		if body is Node2D and body.has_method("receive_hit"):
			var d: Vector2 = body.global_position - global_position
			if absf(d.x) <= REACH.x and absf(d.y) <= REACH.y:
				_sprung = true
				body.receive_hit(DAMAGE, "physical", global_position, "snare")
				return

func _draw() -> void:
	if _revealed and not _sprung:
		draw_line(Vector2(-8, 0), Vector2(-3, -5), Color(0.9, 0.6, 0.3), 1.0)
		draw_line(Vector2(-3, -5), Vector2(0, 0), Color(0.9, 0.6, 0.3), 1.0)
		draw_line(Vector2(0, 0), Vector2(3, -5), Color(0.9, 0.6, 0.3), 1.0)
		draw_line(Vector2(3, -5), Vector2(8, 0), Color(0.9, 0.6, 0.3), 1.0)
