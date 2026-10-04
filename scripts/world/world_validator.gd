class_name WorldValidator
extends RefCounted
## Checks the room graph. Every exit must be matched by an exit on the neighbour's opposite
## edge covering the same world span, with the same shortcut id and the same gate. Rooms must not overlap,
## spans must fit their edge (clear of the corners and the floor), and exactly one room
## must be the start.

const OPPOSITE := {"left": "right", "right": "left", "top": "bottom", "bottom": "top"}

const FEATURE_KINDS := ["glow_pool", "rebirth_pool", "tablet", "switch"]

## The labels an exit's `gate` may carry (a label for the validator and lint, not an obstacle in play); P4 gives them teeth.
const GATES := ["wall_cling", "swim"]

## `creature_ids`, when given, is every creature id the game defines: spawns naming another are errors (a typo
## must not silently drop a creature and its XP).
static func validate(rooms: Dictionary, creature_ids: Array = []) -> PackedStringArray:
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
		errors.append_array(_check_dressing(a))
		errors.append_array(_check_hard_ledges(a))
		errors.append_array(_check_content(a, creature_ids))
	errors.append_array(_check_rebirth_pools(rooms))
	if starts == 1:
		var reached := reachable(rooms)
		for id in ids:
			if not reached.has(id):
				errors.append("%s: no way in from the start room" % id)
	return errors

## An exit's span in world pixels: x = from, y = to.
static func world_span(r: RoomDef, e: Dictionary) -> Vector2:
	var base := edge_origin(r, e.get("edge", ""))
	return Vector2(base + float(e["from"]), base + float(e["to"]))

## The rooms the start room reaches by following exits, start first. Exits to unknown rooms are skipped (validate reports
## them). `skip_gated` leaves out exits that carry a `gate` or a `shortcut`. Empty unless exactly one room is the start.
static func reachable(rooms: Dictionary, skip_gated := false) -> Array:
	var start := ""
	var starts := 0
	for id in rooms:
		if (rooms[id] as RoomDef).is_start():
			start = id
			starts += 1
	if starts != 1:
		return []
	var seen := [start]
	var frontier := [start]
	while not frontier.is_empty():
		var id: String = frontier.pop_back()
		for e in (rooms[id] as RoomDef).exits:
			if skip_gated and (e.has("gate") or e.has("shortcut")):
				continue
			var to: String = e.get("room", "")
			if rooms.has(to) and not seen.has(to):
				seen.append(to)
				frontier.append(to)
	return seen

## The span an exit on `edge` may cover, in the room's own pixels: clear of the corners and, on a side edge, of the floor.
static func edge_range(r: RoomDef, edge: String) -> Vector2:
	var size := r.pixel_size()
	return Vector2(RoomDef.WALL, size.y - RoomDef.FLOOR if _vertical_edge(edge) else size.x - RoomDef.WALL)

## The room's world position along the axis an exit on `edge` runs (y for a left or right edge, x for a top or bottom one).
static func edge_origin(r: RoomDef, edge: String) -> float:
	var origin := r.world_rect().position
	return origin.y if _vertical_edge(edge) else origin.x

static func _vertical_edge(edge: String) -> bool:
	return edge == "left" or edge == "right"

## Rebirth pools: each has an id, area and kit; ids are unique; kits are valid; and a world that has any
## must hold the default pool (the Cave mouth's), so there is always somewhere to start.
static func _check_rebirth_pools(rooms: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	var ids := rooms.keys()
	ids.sort()
	for room_id in ids:
		for f in (rooms[room_id] as RoomDef).features:
			if f.get("kind", "") != "rebirth_pool":
				continue
			if typeof(f.get("id")) != TYPE_STRING or typeof(f.get("area")) != TYPE_STRING \
					or typeof(f.get("kit")) != TYPE_DICTIONARY or typeof(f.get("pos")) != TYPE_VECTOR2 or f.get("id") == "":
				out.append("%s: a rebirth pool needs a string id and area, a kit dictionary and a Vector2 pos" % room_id)
				continue
			var pid: String = f["id"]
			if seen.has(pid):
				out.append("%s: duplicate rebirth pool '%s'" % [room_id, pid])
			seen[pid] = room_id
			if pid == WorldProgress.DEFAULT_ALTAR and not (rooms[room_id] as RoomDef).is_start():
				out.append("%s: the default rebirth pool '%s' must be in the start room" % [room_id, pid])
			for e in RebirthKit.validate(f["kit"]):
				out.append("%s: rebirth pool '%s': %s" % [room_id, pid, e])
	if not seen.is_empty() and not seen.has(WorldProgress.DEFAULT_ALTAR):
		out.append("world: the default rebirth pool '%s' is missing" % WorldProgress.DEFAULT_ALTAR)
	return out

## Spawns name known creatures (when the ids are given) and features are kinds the builder makes.
static func _check_content(r: RoomDef, creature_ids: Array) -> PackedStringArray:
	var out := PackedStringArray()
	if not creature_ids.is_empty():
		for s in r.spawns:
			if not creature_ids.has(s.get("id", "")):
				out.append("%s: spawn names unknown creature '%s'" % [r.id, s.get("id", "")])
	for f in r.features:
		if not FEATURE_KINDS.has(f.get("kind", "")):
			out.append("%s: unknown feature kind '%s'" % [r.id, f.get("kind", "")])
	return out

## Hard ledges are a deliberate list: each is one of the room's solids and thin enough to be one-way otherwise
## (a thick rect is solid already, so listing it would be noise that hides a real choice).
static func _check_hard_ledges(r: RoomDef) -> PackedStringArray:
	var out := PackedStringArray()
	for h: Rect2 in r.hard_ledges:
		if not r.solids.has(h):
			out.append("%s: hard ledge %s is not one of the room's solids" % [r.id, h])
		elif not RoomBuilder.is_one_way(h):
			out.append("%s: hard ledge %s is already solid" % [r.id, h])
	return out

## Set dressing: a known piece, a depth factor in range, a position in or near the room, and no more
## than SetDressing.MAX_PROPS entries.
static func _check_dressing(r: RoomDef) -> PackedStringArray:
	var out := PackedStringArray()
	if r.dressing.is_empty():
		return out
	if not DressingLib.has_biome(r.area):
		out.append("%s: dressing needs a piece library for biome '%s'" % [r.id, r.area])
		return out
	if r.dressing.size() > SetDressing.MAX_PROPS:
		out.append("%s: %d dressing entries, at most %d" % [r.id, r.dressing.size(), SetDressing.MAX_PROPS])
	var bounds := Rect2(Vector2.ZERO, r.pixel_size()).grow(200.0)
	for i in r.dressing.size():
		var e = r.dressing[i]
		if typeof(e) != TYPE_DICTIONARY or not e.has("piece") or not e.has("pos") or not e.has("factor"):
			out.append("%s: dressing[%d] needs piece, pos and factor" % [r.id, i])
			continue
		if not DressingLib.has_piece(r.area, str(e["piece"])):
			out.append("%s: dressing[%d] unknown piece '%s'" % [r.id, i, e["piece"]])
		var f := float(e["factor"])
		if f < SetDressing.FACTOR_MIN or f > SetDressing.FACTOR_MAX:
			out.append("%s: dressing[%d] factor %.2f outside %.1f..%.1f" % [r.id, i, f, SetDressing.FACTOR_MIN, SetDressing.FACTOR_MAX])
		if not bounds.has_point(e["pos"] as Vector2):
			out.append("%s: dressing[%d] at %s is outside the room" % [r.id, i, e["pos"]])
	return out

static func _check_exit(a: RoomDef, e: Dictionary, rooms: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var edge: String = e.get("edge", "")
	if not OPPOSITE.has(edge):
		out.append("%s: bad exit edge '%s'" % [a.id, edge])
		return out
	var limits := edge_range(a, edge)
	var lo := limits.x
	var hi := limits.y
	var from := float(e.get("from", 0.0))
	var to := float(e.get("to", 0.0))
	if from < lo or to > hi or from >= to:
		out.append("%s: %s exit span %d..%d outside %d..%d" % [a.id, edge, from, to, lo, hi])
	if e.has("gate") and not GATES.has(str(e["gate"])):
		out.append("%s: %s exit to %s has an unknown gate '%s'" % [a.id, edge, e.get("room", ""), e["gate"]])
	var b: RoomDef = rooms.get(e.get("room", ""))
	if b == null:
		out.append("%s: exit to unknown room '%s'" % [a.id, e.get("room", "")])
		return out
	if not touches(a.world_rect(), b.world_rect(), edge):
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
	elif partner.get("gate", "") != e.get("gate", ""):
		out.append("%s: %s exit to %s has a different gate than its partner" % [a.id, edge, b.id])
	return out

static func touches(a: Rect2, b: Rect2, edge: String) -> bool:
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
