class_name WorldValidator
extends RefCounted
## Checks the room graph. Every exit must be matched by an exit on the neighbour's opposite
## edge covering the same world span, with the same shortcut id. Rooms must not overlap,
## spans must fit their edge (clear of the corners and the floor), and exactly one room
## must be the start.

const OPPOSITE := {"left": "right", "right": "left", "top": "bottom", "bottom": "top"}

static func validate(rooms: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var starts := rooms.values().filter(func(r: RoomDef) -> bool: return r.is_start()).size()
	if starts != 1:
		errors.append("world: need exactly one start room, found %d" % starts)
	var ids := rooms.keys()
	ids.sort()
	for i in ids.size():
		var a: RoomDef = rooms[ids[i]]
		for j in range(i + 1, ids.size()):
			var b: RoomDef = rooms[ids[j]]
			if a.world_rect().intersects(b.world_rect()):
				errors.append("%s overlaps %s" % [a.id, b.id])
		for e in a.exits:
			errors.append_array(_check_exit(a, e, rooms))
	return errors

## An exit's span in world pixels: x = from, y = to.
static func world_span(r: RoomDef, e: Dictionary) -> Vector2:
	var origin := r.world_rect().position
	var base := origin.y if _vertical_edge(e.get("edge", "")) else origin.x
	return Vector2(base + float(e["from"]), base + float(e["to"]))

static func _vertical_edge(edge: String) -> bool:
	return edge == "left" or edge == "right"

static func _check_exit(a: RoomDef, e: Dictionary, rooms: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var edge: String = e.get("edge", "")
	if not OPPOSITE.has(edge):
		out.append("%s: bad exit edge '%s'" % [a.id, edge])
		return out
	var size := a.pixel_size()
	var lo := RoomDef.WALL
	var hi := size.y - RoomDef.FLOOR if _vertical_edge(edge) else size.x - RoomDef.WALL
	var from := float(e.get("from", 0.0))
	var to := float(e.get("to", 0.0))
	if from < lo or to > hi or from >= to:
		out.append("%s: %s exit span %d..%d outside %d..%d" % [a.id, edge, from, to, lo, hi])
	var b: RoomDef = rooms.get(e.get("room", ""))
	if b == null:
		out.append("%s: exit to unknown room '%s'" % [a.id, e.get("room", "")])
		return out
	if not _touches(a.world_rect(), b.world_rect(), edge):
		out.append("%s: %s edge does not touch %s" % [a.id, edge, b.id])
		return out
	var span := world_span(a, e)
	var partner := {}
	for f in b.exits:
		if f.get("edge", "") == OPPOSITE[edge] and f.get("room", "") == a.id and world_span(b, f).is_equal_approx(span):
			partner = f
	if partner.is_empty():
		out.append("%s: %s exit to %s has no matching exit back" % [a.id, edge, b.id])
	elif partner.get("shortcut", "") != e.get("shortcut", ""):
		out.append("%s: %s exit to %s has a different shortcut than its partner" % [a.id, edge, b.id])
	return out

static func _touches(a: Rect2, b: Rect2, edge: String) -> bool:
	match edge:
		"right":
			return is_equal_approx(a.end.x, b.position.x)
		"left":
			return is_equal_approx(a.position.x, b.end.x)
		"bottom":
			return is_equal_approx(a.end.y, b.position.y)
		"top":
			return is_equal_approx(a.position.y, b.end.y)
	return false
