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

static var _hintable: Array = []

## Skill ids a tablet hint can name: CompendiumModel keeps no slot for an enemy_only skill, so raise() on one does nothing.
static func hintable_skill_ids() -> Array:
	if _hintable.is_empty():
		for d in RebirthKit.skill_defs():
			if d.source != "enemy_only":
				_hintable.append(d.id)
	return _hintable

static func check(rooms: Dictionary) -> Array:
	var out: Array = []
	var ids := rooms.keys()
	ids.sort()
	for id in ids:
		out.append_array(check_room(rooms[id], rooms))
	return out

## Every finding for one room; `rooms` is the whole world (exit partners, shortcuts and feature ids need it).
static func check_room(r: RoomDef, rooms: Dictionary) -> Array:
	var out: Array = []
	out.append_array(_solid_outside(r))
	out.append_array(_outside(r))
	out.append_array(_in_rock(r))
	out.append_array(_exit_blocked(r))
	out.append_array(_exit_narrow(r))
	out.append_array(_start_floor(r))
	out.append_array(_ledge_reach(r))
	out.append_array(_over_hole(r))
	out.append_array(_pool_clearance(r))
	out.append_array(_feature_id(r, rooms))
	out.append_array(_shortcut_pair(r, rooms))
	out.append_array(_hint_unknown(r))
	return out

## The findings of the named rules, one per line; "" when there are none.
static func text(findings: Array, rules: Array) -> String:
	var lines: Array = []
	for f in findings:
		if rules.has(f["rule"]):
			lines.append("%s [%s] %s" % [f["room"], f["rule"], f["text"]])
	return "\n".join(lines)

## A rectangle as a person reads it: "x 100..160, y 60..76" (Godot's own Rect2 text is "[P: (100.0, 60.0), S: (60.0, 16.0)]").
static func _rect_text(rect: Rect2) -> String:
	return "x %d..%d, y %d..%d" % [rect.position.x, rect.end.x, rect.position.y, rect.end.y]

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
			out.append(_f(r, "solid_outside", "the solid at %s is outside the room" % _rect_text(r.solids[i]), "solid", i))
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
				out.append(_f(r, "in_rock", "%s at %s is inside rock at %s" % [r.spawns[i]["id"], r.spawns[i]["pos"], _rect_text(rect)], "spawn", i))
				break
	if r.is_start():
		for rect in rocks:
			if (rect as Rect2).has_point(r.start):
				out.append(_f(r, "in_rock", "the start at %s is inside rock at %s" % [r.start, _rect_text(rect)]))
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
				out.append(_f(r, "exit_blocked", "the solid at %s blocks the %s exit" % [_rect_text(s), r.exits[i]["edge"]], "exit", i))
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

## test_rooms: every ledge (thin, wider than 20) reachable from the floor by hops within the base-jump budget.
static func _ledge_reach(r: RoomDef) -> Array:
	var out: Array = []
	var ledges: Array = r.solids.filter(func(s: Rect2) -> bool: return s.size.y <= MASS and s.size.x > 20.0)
	var reached: Array = []
	for w in RoomBuilder.edge_walls(r.pixel_size(), r.exits):
		if w["kind"] == "ground":
			reached.append(w["rect"])
	var frontier: Array = reached.duplicate()
	while not frontier.is_empty():
		var p: Rect2 = frontier.pop_back()
		for q in ledges:
			if reached.has(q):
				continue
			var rise: float = p.position.y - q.position.y
			var gap: float = maxf(0.0, maxf(p.position.x - q.end.x, q.position.x - p.end.x))
			if (rise > 0.0 and rise <= REACH_RISE and gap <= REACH_GAP) or (rise <= 0.0 and gap <= REACH_HOP):
				reached.append(q)
				frontier.append(q)
	for i in r.solids.size():
		var s: Rect2 = r.solids[i]
		if ledges.has(s) and not reached.has(s):
			out.append(_f(r, "ledge_reach", "the ledge at %s cannot be reached from the floor by the base jump" % _rect_text(s), "solid", i))
	return out

## `pos` with `extent` (centred in x) overlaps the span horizontally and sits within 120 px above the floor line or below it.
static func _over(span: Vector2, floor_y: float, pos: Vector2, extent: Vector2) -> bool:
	var x_overlap := pos.x + extent.x / 2.0 > span.x and pos.x - extent.x / 2.0 < span.y
	return x_overlap and pos.y >= floor_y - 120.0

## test_grotto_rooms: nothing spawns or stands over a bottom exit that has neither a gate nor a shortcut. A gated hole is open in
## play (RoomBuilder.is_exit_open reads only the shortcut); counting it is P3's, with the gate field.
static func _over_hole(r: RoomDef) -> Array:
	var out: Array = []
	var floor_y := r.pixel_size().y - RoomDef.FLOOR
	for e in r.exits:
		if e["edge"] != "bottom" or e.has("gate") or e.has("shortcut"):
			continue
		var span := Vector2(e["from"], e["to"])
		for i in r.spawns.size():
			if _over(span, floor_y, r.spawns[i]["pos"], Vector2(16, 12)):
				out.append(_f(r, "over_hole", "spawn %s is over its floor hole" % r.spawns[i]["id"], "spawn", i))
		for d in r.decor:
			if _over(span, floor_y, d["pos"], Vector2(24, 24)):
				out.append(_f(r, "over_hole", "decor %s is over its floor hole" % d["id"]))
		for p in r.dressing:
			if _over(span, floor_y, p["pos"], DressingLib.size(r.area, p["piece"])):
				out.append(_f(r, "over_hole", "dressing %s is over its floor hole" % p["piece"]))
	return out

## test_grotto_rooms: nothing spawns within 200 px of a rebirth pool (a new life stands on it). The default pool is exempt.
static func _pool_clearance(r: RoomDef) -> Array:
	var out: Array = []
	for f in r.features:
		if f.get("kind", "") != "rebirth_pool" or f.get("id", "") == WorldProgress.DEFAULT_POOL:
			continue
		for i in r.spawns.size():
			var d: float = (r.spawns[i]["pos"] as Vector2).distance_to(f["pos"])
			if d <= POOL_CLEARANCE:
				out.append(_f(r, "pool_clearance", "%s spawns %d px from the rebirth pool %s" % [r.spawns[i]["id"], int(d), f.get("id", "?")], "spawn", i))
	return out

static func _feature_id(r: RoomDef, rooms: Dictionary) -> Array:
	var counts := {}
	for id in rooms:
		for f in (rooms[id] as RoomDef).features:
			counts[f.get("id", "")] = int(counts.get(f.get("id", ""), 0)) + 1
	var out: Array = []
	for i in r.features.size():
		var fid: String = r.features[i].get("id", "")
		if fid == "":
			out.append(_f(r, "feature_id", "a %s has no id" % r.features[i].get("kind", "feature"), "feature", i))
		elif int(counts[fid]) > 1:
			out.append(_f(r, "feature_id", "the feature id '%s' is used %d times in the world" % [fid, counts[fid]], "feature", i))
	return out

## The world's switch shortcuts must equal its exits' shortcuts.
static func _shortcut_pair(r: RoomDef, rooms: Dictionary) -> Array:
	var switches := {}
	var exits := {}
	for id in rooms:
		for f in (rooms[id] as RoomDef).features:
			if f.get("kind", "") == "switch":
				switches[f.get("shortcut", "")] = true
		for e in (rooms[id] as RoomDef).exits:
			if e.has("shortcut"):
				exits[e["shortcut"]] = true
	var out: Array = []
	for i in r.features.size():
		var f: Dictionary = r.features[i]
		if f.get("kind", "") == "switch" and not exits.has(f.get("shortcut", "")):
			out.append(_f(r, "shortcut_pair", "the switch %s opens '%s', which no exit uses" % [f.get("id", "?"), f.get("shortcut", "")], "feature", i))
	for i in r.exits.size():
		var e: Dictionary = r.exits[i]
		if e.has("shortcut") and not switches.has(e["shortcut"]):
			out.append(_f(r, "shortcut_pair", "the %s exit's shortcut '%s' has no switch: it can never open" % [e["edge"], e["shortcut"]], "exit", i))
	return out

static func _hint_unknown(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.features.size():
		var f: Dictionary = r.features[i]
		var hint: String = f.get("hint", "")
		if f.get("kind", "") == "tablet" and hint != "" and not hintable_skill_ids().has(hint):
			out.append(_f(r, "hint_unknown", "the tablet %s hints '%s', which is not a skill the Compendium holds" % [f.get("id", "?"), hint], "feature", i))
	return out
