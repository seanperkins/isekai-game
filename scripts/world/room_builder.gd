class_name RoomBuilder
extends RefCounted
## Builds static solids from a layout. Geometry lives in data, not in .tscn files.

static func build(parent: Node, layout: Dictionary) -> void:
	for r in layout["solids"]:
		var body := StaticBody2D.new()
		body.position = r.position + r.size / 2.0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		body.add_child(shape)
		var visual := ColorRect.new()
		visual.size = r.size
		visual.position = -r.size / 2.0
		visual.color = Color(0.25, 0.22, 0.2)
		body.add_child(visual)
		parent.add_child(body)
