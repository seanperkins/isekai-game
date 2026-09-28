class_name RoomBuilder
extends RefCounted
## Builds static solids from a layout. Geometry lives in data, not in .tscn files.

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

static func build(parent: Node, layout: Dictionary) -> void:
	var width: float = layout.get("size", Vector2(1600, 360)).x
	for r in layout["solids"]:
		add_solid(parent, r, visual_kind(r, width))

## A static solid drawn with the given tile ("ground", "wall" or "column").
static func add_solid(parent: Node, r: Rect2, kind: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.add_child(shape)
	var visual := TextureRect.new()
	visual.texture = Art.texture(kind)
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_SCALE if kind == "column" else TextureRect.STRETCH_TILE
	visual.size = r.size
	visual.position = -r.size / 2.0
	body.add_child(visual)
	parent.add_child(body)
	return body

## A room's boundary: ceiling and side walls (RoomDef.WALL thick) and the floor
## (RoomDef.FLOOR thick), all inside the room rect, with a gap at every exit span.
## Closed shortcut exits get a separate gate solid (see gate_rect).
static func edge_walls(size: Vector2, exits: Array) -> Array:
	var out: Array = []
	out.append_array(_cut("top", Rect2(0, 0, size.x, RoomDef.WALL), exits, "wall"))
	out.append_array(_cut("bottom", Rect2(0, size.y - RoomDef.FLOOR, size.x, RoomDef.FLOOR), exits, "ground"))
	out.append_array(_cut("left", Rect2(0, 0, RoomDef.WALL, size.y), exits, "wall"))
	out.append_array(_cut("right", Rect2(size.x - RoomDef.WALL, 0, RoomDef.WALL, size.y), exits, "wall"))
	return out

## The solid that fills an exit's gap while its shortcut is closed.
static func gate_rect(size: Vector2, e: Dictionary) -> Rect2:
	var from := float(e["from"])
	var length := float(e["to"]) - from
	match e["edge"]:
		"top":
			return Rect2(from, 0, length, RoomDef.WALL)
		"bottom":
			return Rect2(from, size.y - RoomDef.FLOOR, length, RoomDef.FLOOR)
		"left":
			return Rect2(0, from, RoomDef.WALL, length)
	return Rect2(size.x - RoomDef.WALL, from, RoomDef.WALL, length)

static func _cut(edge: String, band: Rect2, exits: Array, kind: String) -> Array:
	var along_x := edge == "top" or edge == "bottom"
	var lo: float = band.position.x if along_x else band.position.y
	var hi: float = band.end.x if along_x else band.end.y
	var spans: Array = []
	for e in exits:
		if e.get("edge", "") == edge:
			spans.append(Vector2(float(e["from"]), float(e["to"])))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array = []
	var cursor := lo
	for s in spans:
		if s.x > cursor:
			out.append({"rect": _piece(band, along_x, cursor, s.x), "kind": kind})
		cursor = maxf(cursor, s.y)
	if hi > cursor:
		out.append({"rect": _piece(band, along_x, cursor, hi), "kind": kind})
	return out

static func _piece(band: Rect2, along_x: bool, a: float, b: float) -> Rect2:
	if along_x:
		return Rect2(a, band.position.y, b - a, band.size.y)
	return Rect2(band.position.x, a, band.size.x, b - a)

const BACKDROP := Color(0.06, 0.06, 0.12)
const BACKDROP_TINT := Color(0.22, 0.21, 0.34)  # far cave wall, pushed back

## One room as a node at its world position: backdrop, boundary walls with exit gaps, gates for
## closed shortcuts, interior solids, decor, and fresh spawns (so enemies respawn on every
## entry). `ctx` may carry "spawn", "progress", "compendium" and "announce".
static func build_room(def: RoomDef, ctx: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.name = def.id
	node.position = def.world_rect().position
	var size := def.pixel_size()
	_backdrop(node, size)
	for w in edge_walls(size, def.exits):
		add_solid(node, w["rect"], w["kind"])
	var progress = ctx.get("progress")
	for e in def.exits:
		if not is_exit_open(e, progress):
			var gate := add_solid(node, gate_rect(size, e), "ground" if e["edge"] == "bottom" else "wall")
			gate.add_to_group("gate_" + str(e["shortcut"]))
	for r in def.solids:
		add_solid(node, r, visual_kind(r, size.x))
	build_decor(node, {"decor": def.decor})
	var spawn: Callable = ctx.get("spawn", Callable())
	if spawn.is_valid():
		for s in def.spawns:
			var n = spawn.call(s["id"], s["pos"])
			if n != null:
				node.add_child(n)
	return node

## Open unless it is a shortcut nobody has opened yet.
static func is_exit_open(e: Dictionary, progress) -> bool:
	return not e.has("shortcut") or (progress != null and progress.is_open(e["shortcut"]))

static func _backdrop(node: Node2D, size: Vector2) -> void:
	var back := ColorRect.new()
	back.color = BACKDROP
	back.size = size
	back.z_index = -10
	node.add_child(back)
	var wall := TextureRect.new()
	wall.texture = Art.texture("wall")
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_TILE
	wall.size = size
	wall.modulate = BACKDROP_TINT
	wall.z_index = -9
	node.add_child(wall)
