class_name RoomBlock
extends Node2D
## A solid block across a way, drawn as wall: the base of the barrier (the dissolve verb opens it) and the hidden door (the reveal verb shows it).
## Its origin is the middle of the block (a verb measures from there); the feature's `pos` is the base, the middle of its foot.

var id := ""
var size := Vector2(24.0, 64.0)
var _body: StaticBody2D

func setup(f: Dictionary, _ctx: Dictionary) -> void:
	id = f.get("id", "")
	size = f.get("size", size)
	position = (f["pos"] as Vector2) - Vector2(0.0, size.y / 2.0)

func _ready() -> void:
	_body = RoomBuilder.add_solid(self, Rect2(-size / 2.0, size), "wall")
	_body.position = Vector2.ZERO
