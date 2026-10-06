extends Node2D
## A stand-in for a barrier in a test: a wall body the swarm can slip through (`_body`, as RoomBlock keeps it).

var _body: StaticBody2D

func _ready() -> void:
	_body = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 120)
	shape.shape = rect
	_body.add_child(shape)
	add_child(_body)
