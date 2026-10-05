class_name RoomBlock
extends RoomDeed
## A solid block across a way, drawn as wall: the base of the barrier (blows or the dissolve verb open it) and the hidden door (a search or the
## reveal verb shows it). Its origin is the middle of the block (a verb measures from there); the feature's `pos` is the base, the middle of its
## foot, and its `w` and `h` are plain numbers (a spec round trip keeps numbers, not vectors).

var size := Vector2(24.0, 64.0)
var _body: StaticBody2D

func setup(f: Dictionary, ctx: Dictionary) -> void:
	super.setup(f, ctx)
	size = Vector2(float(f.get("w", size.x)), float(f.get("h", size.y)))
	position = (f["pos"] as Vector2) - Vector2(0.0, size.y / 2.0)

func _ready() -> void:
	_body = RoomBuilder.add_solid(self, Rect2(-size / 2.0, size), "wall")
	_body.position = Vector2.ZERO
