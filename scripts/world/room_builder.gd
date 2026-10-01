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
static func build_decor(parent: Node, layout: Dictionary, light_energy := 1.0) -> void:
	for d in layout.get("decor", []):
		var tex := Art.texture(d["id"])
		if tex == null:
			continue  # an id with no sprite (a hand edit): RoomLint's decor_unknown reports it
		var holder := Node2D.new()
		holder.position = d["pos"]
		var s := Art.sprite(d["id"], tex.get_height() if d.get("anchor", "bottom") == "top" else 0.0)
		holder.add_child(s)
		if d.has("light"):
			var l := Art.light(d["light"], light_energy, 1.6)
			l.position.y = s.position.y
			holder.add_child(l)
		parent.add_child(holder)

## A thin, wide rect is a ledge: you can jump up through it and land on top. Everything else is
## solid. Same test as TerrainPainter's THIN, so a ledge that is drawn thin also behaves thin.
## `hard` is the room's list of thin platforms the author made solid from below on purpose.
static func is_one_way(r: Rect2, hard: Array = []) -> bool:
	return r.size.y <= 24.0 and r.size.x > 24.0 and not hard.has(r)

## A static solid drawn with the given tile ("ground", "wall" or "column"). `visual` false leaves
## the drawing to TerrainPainter. `one_way` makes it passable from below and the sides.
static func add_solid(parent: Node, r: Rect2, kind: String, visual := true, one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	if one_way:
		shape.one_way_collision = true
		shape.one_way_collision_margin = 6.0
	body.add_child(shape)
	if visual:
		var tile := TextureRect.new()
		tile.texture = Art.texture(kind)
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_SCALE if kind == "column" else TextureRect.STRETCH_TILE
		tile.size = r.size
		tile.position = -r.size / 2.0
		body.add_child(tile)
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

## A painted room has two layers for now: the background and the foreground terrain. Off, it also builds the
## parallax stack, the foreground frame, the motes and the room's set dressing (all still in code, and tested).
static var simple_layers := true

const PAINTED_LIGHT := 0.55
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
	# A biome with terrain art gets a background and painted solids (and, with simple_layers off, the parallax
	# stack, motes and dressing too); any other room keeps the flat backdrop and stretched tiles.
	var painted := TerrainArt.has_biome(def.area)
	if painted:
		if simple_layers:
			TerrainLayers.simple_background(node, def.area, size)
		else:
			TerrainLayers.build(node, def.area, size)
			TerrainLayers.back_wall(node, def.area, size)
			TerrainMotes.build(node, size, def.area)
			SetDressing.build(node, def.area, def.dressing, size)
	else:
		_backdrop(node, size)
	for w in def.water:
		node.add_child(DeepWater.make(w))  # behind the solids and the creatures, over the background
	var solids: Array = []
	for w in edge_walls(size, def.exits):
		add_solid(node, w["rect"], w["kind"], not painted)
		solids.append(w)
	var gates: Array = []
	var progress = ctx.get("progress")
	for e in def.exits:
		if not is_exit_open(e, progress):
			var g := gate_rect(size, e)
			var gate := add_solid(node, g, "ground" if e["edge"] == "bottom" else "wall", not painted)
			gate.add_to_group("gate_" + str(e["shortcut"]))
			gates.append({"body": gate, "rect": g})
	for r in def.solids:
		add_solid(node, r, visual_kind(r, size.x), not painted, is_one_way(r, def.hard_ledges))
		solids.append({"rect": r, "kind": visual_kind(r, size.x), "hard": def.hard_ledges.has(r)})
	if painted:
		var bounds := Rect2(Vector2.ZERO, size)
		TerrainPainter.paint(node, solids, bounds, def.area)
		for g in gates:
			# Painted as a child of the gate body, so opening the shortcut removes the art with it.
			var art := TerrainPainter.paint(g["body"], solids, bounds, def.area, [g["rect"]])
			art.position = -g["body"].position
	# Painted stone is pale, so point lights are gentler there or they blow it out to white.
	build_decor(node, {"decor": def.decor}, PAINTED_LIGHT if painted else 1.0)
	var spawn: Callable = ctx.get("spawn", Callable())
	if spawn.is_valid():
		for i in def.spawns.size():
			var s: Dictionary = def.spawns[i]
			var n = spawn.call(s["id"], s["pos"])
			if n != null:
				if "spawn_key" in n:
					n.spawn_key = "%s:%d" % [def.id, i]
				node.add_child(n)
	for f in def.features:
		var feature := RoomFeatures.make(f, ctx)
		if feature != null:
			node.add_child(feature)
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
