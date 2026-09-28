class_name RoomBuilder
extends RefCounted
## Builds static solids from a layout. Geometry lives in data, not in .tscn files.

static func build(parent: Node, layout: Dictionary) -> void:
	var width: float = layout.get("size", Vector2(1600, 360)).x
	for r in layout["solids"]:
		var body := StaticBody2D.new()
		body.position = r.position + r.size / 2.0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		body.add_child(shape)
		var kind := visual_kind(r, width)
		var visual := TextureRect.new()
		visual.texture = Art.texture(kind)
		visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visual.stretch_mode = TextureRect.STRETCH_SCALE if kind == "column" else TextureRect.STRETCH_TILE
		visual.size = r.size
		visual.position = -r.size / 2.0
		body.add_child(visual)
		parent.add_child(body)

## Which tile a solid is drawn with: mossy ground for floors and platforms, a stone column
## for tall narrow pillars, plain wall for the room's outer walls and ceiling.
static func visual_kind(r: Rect2, room_width: float = 1600.0) -> String:
	if r.position.x < 0.0 or r.position.x >= room_width or r.position.y < 0.0:
		return "wall"
	if r.size.x <= 20.0 and r.size.y > 60.0:
		return "column"
	if r.size.y <= 40.0:
		return "ground"
	return "wall"

## Decorative sprites (crystals, torches, vines, stalactites), each with an optional light.
## "top" anchors hang from the ceiling; the default stands on the given point.
static func build_decor(parent: Node, layout: Dictionary) -> void:
	for d in layout.get("decor", []):
		var holder := Node2D.new()
		holder.position = d["pos"]
		var tex := Art.texture(d["id"])
		var s := Art.sprite(d["id"], tex.get_height() if d.get("anchor", "bottom") == "top" else 0.0)
		holder.add_child(s)
		if d.has("light"):
			var l := Art.light(d["light"], 1.0, 1.6)
			l.position.y = s.position.y
			holder.add_child(l)
		parent.add_child(holder)
