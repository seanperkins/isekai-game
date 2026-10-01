class_name RoomLint
extends RefCounted
## The level-design rules the suite enforces, as one module: the suite's rule tests call it and the room editor's problems list
## shows the same findings, so "Validate clean" and "the suite's rule tests pass" are one set. Pure statics, no nodes. The
## validator (WorldValidator) is what the game needs to load and run; this is design.
##
## A finding is {room, rule, text, pick}: pick is a room-editor selection ({room, kind, index}) of an element that is a selection
## kind (solid, spawn, exit, feature), else {}.

## The smallest exit span: the rigged body plus 8 on either axis (test_room_lint pins MIN_EXIT >= both).
const MIN_EXIT := 36.0
## Nothing may stand this close in front of an exit (measured from the wall face).
const CLEAR := 64.0
## A solid thicker than this on both axes is mass; thinner is a ledge.
const MASS := 24.0
const START_TOLERANCE := 0.6
const REACH_RISE := 55.0
const REACH_GAP := 60.0
const REACH_HOP := 80.0
const POOL_CLEARANCE := 200.0
## The drawn box of each feature kind relative to its base point: the one source for lint, hit-testing, the selection outline and
## the marker. The pools are the 37x23 water_pool sprite, whose bottom sits 4 px below the base.
const FEATURE_BOX := {
	"tablet": Rect2(-6, -18, 12, 18),
	"switch": Rect2(-9, -22, 18, 22),
	"glow_pool": Rect2(-19, -20, 38, 24),
	"rebirth_pool": Rect2(-19, -20, 38, 24),
}

const RULES := ["solid_outside", "outside", "in_rock", "exit_blocked", "exit_narrow", "start_floor", "ledge_reach", "over_hole",
	"pool_clearance", "feature_id", "shortcut_pair", "hint_unknown"]

static func check(rooms: Dictionary) -> Array:
	var out: Array = []
	var ids := rooms.keys()
	ids.sort()
	for id in ids:
		out.append_array(check_room(rooms[id], rooms))
	return out

## Every finding for one room; `rooms` is the whole world (exit partners, shortcuts and feature ids need it).
static func check_room(r: RoomDef, _rooms: Dictionary) -> Array:
	var out: Array = []
	out.append_array(_solid_outside(r))
	out.append_array(_outside(r))
	out.append_array(_in_rock(r))
	out.append_array(_exit_blocked(r))
	out.append_array(_exit_narrow(r))
	out.append_array(_start_floor(r))
	return out

## The findings of the named rules, one per line; "" when there are none.
static func text(findings: Array, rules: Array) -> String:
	var lines: Array = []
	for f in findings:
		if rules.has(f["rule"]):
			lines.append("%s [%s] %s" % [f["room"], f["rule"], f["text"]])
	return "\n".join(lines)

static func _f(r: RoomDef, rule: String, msg: String, kind := "", index := -1) -> Dictionary:
	var pick := {} if kind == "" else {"room": r.id, "kind": kind, "index": index}
	return {"room": r.id, "rule": rule, "text": msg, "pick": pick}

## Interior solids plus the generated boundary walls and floor: what nothing may stand inside.
static func rock(r: RoomDef) -> Array:
	var out: Array = r.solids.duplicate()
	for w in RoomBuilder.edge_walls(r.pixel_size(), r.exits):
		out.append(w["rect"])
	return out

## A feature's `pos` is its base. It is stuck when its drawn box reaches into a side wall column (a wall or a side doorway), or
## the point one pixel above the base is inside rock: Rect2.has_point includes the top edge, so testing the base itself would
## flag every feature standing on a ledge and refuse every horizontal drag.
static func embedded(r: RoomDef, base: Vector2, kind := "") -> bool:
	var width := r.pixel_size().x
	var box: Rect2 = FEATURE_BOX.get(kind, Rect2(0, 0, 0, 0))
	if base.x + box.position.x < RoomDef.WALL or base.x + box.end.x > width - RoomDef.WALL:
		return true
	var above := base - Vector2(0.0, 1.0)
	for rect in rock(r):
		if (rect as Rect2).has_point(above):
			return true
	return false

## The floor space in front of an exit that must stay open: CLEAR deep, the exit's span wide, from the wall face.
static func exit_zone(size: Vector2, e: Dictionary) -> Rect2:
	var a := float(e["from"])
	var b := float(e["to"])
	match e["edge"]:
		"left": return Rect2(RoomDef.WALL, a, CLEAR, b - a)
		"right": return Rect2(size.x - RoomDef.WALL - CLEAR, a, CLEAR, b - a)
		"top": return Rect2(a, RoomDef.WALL, b - a, CLEAR)
	return Rect2(a, size.y - RoomDef.FLOOR - CLEAR, b - a, CLEAR)

static func _solid_outside(r: RoomDef) -> Array:
	var out: Array = []
	var bounds := Rect2(Vector2.ZERO, r.pixel_size())
	for i in r.solids.size():
		if not bounds.encloses(r.solids[i]):
			out.append(_f(r, "solid_outside", "solid %s is outside the room" % r.solids[i], "solid", i))
	return out

static func _outside(r: RoomDef) -> Array:
	var out: Array = []
	var local := Rect2(Vector2.ZERO, r.pixel_size())
	for i in r.spawns.size():
		if not local.has_point(r.spawns[i]["pos"]):
			out.append(_f(r, "outside", "%s at %s is outside the room" % [r.spawns[i]["id"], r.spawns[i]["pos"]], "spawn", i))
	if r.is_start() and not local.has_point(r.start):
		out.append(_f(r, "outside", "the start at %s is outside the room" % r.start))
	return out

static func _in_rock(r: RoomDef) -> Array:
	var out: Array = []
	var rocks := rock(r)
	for i in r.spawns.size():
		for rect in rocks:
			if (rect as Rect2).has_point(r.spawns[i]["pos"]):
				out.append(_f(r, "in_rock", "%s at %s is inside %s" % [r.spawns[i]["id"], r.spawns[i]["pos"], rect], "spawn", i))
				break
	if r.is_start():
		for rect in rocks:
			if (rect as Rect2).has_point(r.start):
				out.append(_f(r, "in_rock", "the start at %s is inside %s" % [r.start, rect]))
				break
	for i in r.features.size():
		var f: Dictionary = r.features[i]
		if embedded(r, f["pos"], f.get("kind", "")):
			out.append(_f(r, "in_rock", "feature %s at %s is stuck in rock or a wall" % [f.get("id", "?"), f["pos"]], "feature", i))
	return out

static func _exit_blocked(r: RoomDef) -> Array:
	var out: Array = []
	var size := r.pixel_size()
	for i in r.exits.size():
		var zone := exit_zone(size, r.exits[i])
		for s: Rect2 in r.solids:
			if s.size.y > MASS and s.size.x > MASS and zone.intersects(s):
				out.append(_f(r, "exit_blocked", "solid %s blocks the %s exit" % [s, r.exits[i]["edge"]], "exit", i))
				break
	return out

static func _exit_narrow(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.exits.size():
		var e: Dictionary = r.exits[i]
		if float(e["to"]) - float(e["from"]) < MIN_EXIT:
			out.append(_f(r, "exit_narrow", "the %s exit %s..%s is narrower than %d px" % [e["edge"], e["from"], e["to"], int(MIN_EXIT)], "exit", i))
	return out

static func _start_floor(r: RoomDef) -> Array:
	if not r.is_start():
		return []
	var want := r.pixel_size().y - RoomDef.FLOOR - BodyConfig.BOTTOM
	if absf(r.start.y - want) > START_TOLERANCE:
		return [_f(r, "start_floor", "the start's y is %s, the floor stand is %s" % [r.start.y, want])]
	return []
