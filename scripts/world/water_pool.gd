class_name WaterPool
extends Node2D
## Single-use terrain eat target. Needs no stun.

var def: CreatureDef
var team := "terrain"
var _consumed := false

func setup(p_def: CreatureDef) -> void:
	def = p_def
	add_to_group("predatable")
	add_to_group("inspectable")

func _ready() -> void:
	if get_child_count() == 0:
		var visual := ColorRect.new()
		visual.size = Vector2(24, 6)
		visual.position = Vector2(-12, -3)
		visual.color = Color(0.3, 0.5, 1.0)
		add_child(visual)

func can_be_predated() -> bool:
	return not _consumed

func set_held(_v: bool) -> void:
	pass

func consume() -> CreatureDef:
	_consumed = true
	queue_free()
	return def
