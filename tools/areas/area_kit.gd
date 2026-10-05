class_name AreaKit
extends RefCounted
## What an area module builds rooms with. Positions are the room's own pixels; a "surface" is the top of what something stands on.
## The kit writes the things that must agree (the two ends of an exit) from one number, and refuses what the rules refuse.

const LEDGE_THICKNESS := 12.0
const OPPOSITE := {"left": "right", "right": "left", "top": "bottom", "bottom": "top"}

static func room(id: String, area: String, cell: Vector2i, size := Vector2i.ONE) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.area = area
	r.cell = cell
	r.size = size
	return r

## The top of the generated floor.
static func floor_y(r: RoomDef) -> float:
	return r.pixel_size().y - RoomDef.FLOOR

## Where a creature's spawn goes to stand on `surface_y`.
static func stand(surface_y: float) -> float:
	return surface_y - Enemy.BODY_BOTTOM

## A thin ledge whose top is at `y`; thin solids are one-way platforms (RoomBuilder.is_one_way).
static func ledge(r: RoomDef, x: float, y: float, w: float) -> Rect2:
	var rect := Rect2(x, y, w, LEDGE_THICKNESS)
	r.solids.append(rect)
	return rect

## `count` ledges climbing: the first has its top at `y`, each next is `rise` higher and `dx` further along. A rise the base jump cannot
## make (RoomLint.REACH_RISE) builds nothing.
static func stairs(r: RoomDef, x: float, y: float, dx: float, rise: float, count: int, w: float) -> Array:
	if rise > RoomLint.REACH_RISE:
		return []
	var made: Array = []
	for i in count:
		made.append(ledge(r, x + dx * i, y - rise * i, w))
	return made

## The start on the floor stand (a new run places the player here); only the starting room has one.
static func start(r: RoomDef, x: float) -> void:
	r.start = Vector2(x, floor_y(r) - BodyConfig.BOTTOM)

static func spawn(r: RoomDef, creature_id: String, x: float, surface_y: float) -> void:
	r.spawns.append({"id": creature_id, "pos": Vector2(x, stand(surface_y))})

static func decor(r: RoomDef, id: String, x: float, surface_y: float, extra := {}) -> void:
	var d := {"id": id, "pos": Vector2(x, surface_y)}
	d.merge(extra)
	r.decor.append(d)

static func feature(r: RoomDef, kind: String, id: String, x: float, surface_y: float, extra := {}) -> void:
	var f := {"kind": kind, "id": id, "pos": Vector2(x, surface_y)}
	f.merge(extra)
	r.features.append(f)

## The exit between two rooms that touch along `edge` of `a`, written to both: `from_world` to `to_world` along the edge's axis in world
## pixels (y for a left or right edge, x for a top or bottom one), converted to each room's own. `extra` ({"gate"} or {"shortcut"})
## goes on both ends. False, and nothing written, when the rooms do not touch along that edge, the span is empty, or it leaves either
## room's exit range (clear of the corners and the floor), which also keeps it to the stretch both rooms share.
static func link(a: RoomDef, b: RoomDef, edge: String, from_world: float, to_world: float, extra := {}) -> bool:
	if not OPPOSITE.has(edge) or to_world <= from_world:
		return false
	var ra := a.world_rect()
	var rb := b.world_rect()
	var vertical := edge == "left" or edge == "right"
	var touches := false
	match edge:
		"right":
			touches = is_equal_approx(ra.end.x, rb.position.x)
		"left":
			touches = is_equal_approx(ra.position.x, rb.end.x)
		"bottom":
			touches = is_equal_approx(ra.end.y, rb.position.y)
		"top":
			touches = is_equal_approx(ra.position.y, rb.end.y)
	if not touches:
		return false
	var lo_a := (ra.position.y if vertical else ra.position.x)
	var lo_b := (rb.position.y if vertical else rb.position.x)
	var from_a := from_world - lo_a
	var to_a := to_world - lo_a
	var from_b := from_world - lo_b
	var to_b := to_world - lo_b
	var range_a := WorldValidator.edge_range(a, edge)
	var range_b := WorldValidator.edge_range(b, OPPOSITE[edge])
	if from_a < range_a.x or to_a > range_a.y or from_b < range_b.x or to_b > range_b.y:
		return false
	var ea := {"edge": edge, "from": from_a, "to": to_a, "room": b.id}
	var eb := {"edge": OPPOSITE[edge], "from": from_b, "to": to_b, "room": a.id}
	ea.merge(extra)
	eb.merge(extra)
	a.exits.append(ea)
	b.exits.append(eb)
	return true
