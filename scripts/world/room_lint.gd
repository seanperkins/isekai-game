class_name RoomLint
extends RefCounted
## The level-design rules the suite enforces, as one module: the suite's rule tests call it and the room editor's problems list
## shows the same findings, so "Validate clean" and "the suite's rule tests pass" are one set. Pure statics, no nodes. The
## validator (WorldValidator) is what the game needs to load and run; this is design.
##
## A finding is {room, rule, text, pick}: pick is a room-editor selection ({room, kind, index}) of an element that is a selection
## kind (solid, water, spawn, exit, feature, decor), else {}.

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
## How far above a water rect's top edge a swimmer's surface jump can put its feet: the jump's apex less the body's reach below
## its centre, less 4 px of margin. A literal (Player is not safe to read from a static initializer in every load order);
## test_room_lint_water derives it: floor(JUMP_VELOCITY^2 / (2 GRAVITY) - BodyConfig.BOTTOM - 4).
const SURFACE_LIFT := 44.0
## The smallest water rect either way (the largest swimmer's body fits), and how close a shore must lie to the rect's x-span.
const WATER_MIN := 32.0
const SHORE_REACH := 24.0
## The drawn box of each feature kind relative to its base point: the one source for lint, hit-testing, the selection outline and
## the marker. The pools are the 37x23 water_pool sprite, whose bottom sits 4 px below the base.
const FEATURE_BOX := {
	"tablet": Rect2(-6, -18, 12, 18),
	"switch": Rect2(-9, -22, 18, 22),
	"glow_pool": Rect2(-19, -20, 38, 24),
	"rebirth_pool": Rect2(-19, -20, 38, 24),
}

const RULES := ["solid_outside", "outside", "in_rock", "exit_blocked", "exit_narrow", "start_floor", "ledge_reach", "over_hole",
	"pool_clearance", "feature_id", "shortcut_pair", "hint_unknown", "decor_unknown", "water_rect", "swimmer_dry", "water_exit"]

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
	out.append_array(_decor_unknown(r))
	out.append_array(_feature_id(r, rooms))
	out.append_array(_shortcut_pair(r, rooms))
	out.append_array(_hint_unknown(r))
	out.append_array(_water_rect(r))
	out.append_array(_swimmer_dry(r))
	out.append_array(_water_exit(r))
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

## test_grotto_rooms: nothing spawns or stands over a bottom exit that has no shortcut. Only a shortcut closes a hole in play
## (RoomBuilder.is_exit_open reads only the shortcut), so a gated hole counts for creatures and decor; dressing keeps the skip for a
## gated hole (C3's stone arch). A decor piece is measured by its sprite's width.
static func _over_hole(r: RoomDef) -> Array:
	var out: Array = []
	var floor_y := r.pixel_size().y - RoomDef.FLOOR
	for e in r.exits:
		if e["edge"] != "bottom" or e.has("shortcut"):
			continue
		var span := Vector2(e["from"], e["to"])
		for i in r.spawns.size():
			if _over(span, floor_y, r.spawns[i]["pos"], Vector2(16, 12)):
				out.append(_f(r, "over_hole", "spawn %s is over its floor hole" % r.spawns[i]["id"], "spawn", i))
		for i in r.decor.size():
			var d: Dictionary = r.decor[i]
			var width := DecorLib.texture_box(str(d.get("id", ""))).size.x
			if _over(span, floor_y, d["pos"], Vector2(width, 24)):
				out.append(_f(r, "over_hole", "decor %s is over its floor hole" % d["id"], "decor", i))
		if e.has("gate"):
			continue
		for p in r.dressing:
			if _over(span, floor_y, p["pos"], DressingLib.size(r.area, p["piece"])):
				out.append(_f(r, "over_hole", "dressing %s is over its floor hole" % p["piece"]))
	return out

## Every decor piece names a sprite the editor's catalog knows (and the art exists): a hand-edited id otherwise draws nothing.
static func _decor_unknown(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.decor.size():
		var id := str(r.decor[i].get("id", ""))
		if not DecorLib.CATALOG.has(id) or Art.texture(id) == null:
			out.append(_f(r, "decor_unknown", "decor '%s' is not a known decor sprite" % id, "decor", i))
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

# --- water ---

static var _swimmers: Dictionary = {}

## creature id -> whether its def is a `swimmer`, from the shipped defs (cached, like _hintable).
static func swimmer_ids() -> Dictionary:
	if _swimmers.is_empty():
		for c in DefLoader.load_dir("res://data/creatures"):
			_swimmers[c.id] = (c as CreatureDef).swimmer
	return _swimmers

## Every water rect lies inside the room, is at least WATER_MIN either way, and neither overlaps nor touches another (so a rect's
## top edge is always a real surface).
static func _water_rect(r: RoomDef) -> Array:
	var out: Array = []
	var bounds := Rect2(Vector2.ZERO, r.pixel_size())
	for i in r.water.size():
		var w: Rect2 = r.water[i]
		if not bounds.encloses(w):
			out.append(_f(r, "water_rect", "the water at %s is outside the room" % _rect_text(w), "water", i))
		elif w.size.x < WATER_MIN or w.size.y < WATER_MIN:
			out.append(_f(r, "water_rect", "the water at %s is under %d px either way" % [_rect_text(w), int(WATER_MIN)], "water", i))
		for j in range(i + 1, r.water.size()):
			if w.intersects(r.water[j], true):
				out.append(_f(r, "water_rect", "the water at %s overlaps or touches the water at %s" % [_rect_text(w), _rect_text(r.water[j])], "water", i))
	return out

## A swimmer spawn must be inside some water rect (outside, it idles: Enemy has no home water for it).
static func _swimmer_dry(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.spawns.size():
		var s: Dictionary = r.spawns[i]
		if not bool(swimmer_ids().get(s["id"], false)):
			continue
		var wet := false
		for w in r.water:
			if (w as Rect2).has_point(s["pos"]):
				wet = true
		if not wet:
			out.append(_f(r, "swimmer_dry", "%s at %s is not in any water" % [s["id"], s["pos"]], "spawn", i))
	return out

## True when exit `e` is a way out of the room for a swimmer: no shortcut (closed until opened) and no gate but swim.
static func _open_for_swimmer(e: Dictionary) -> bool:
	return not e.has("shortcut") and (not e.has("gate") or e["gate"] == "swim")

## True when `rect` reaches the room edge of exit `e` over the exit's span.
static func reaches_edge(r: RoomDef, rect: Rect2, e: Dictionary) -> bool:
	var size := r.pixel_size()
	var a := float(e["from"])
	var b := float(e["to"])
	match e["edge"]:
		"top": return rect.position.y <= RoomDef.WALL + 0.5 and rect.end.x > a and rect.position.x < b
		"bottom": return rect.end.y >= size.y - 0.5 and rect.end.x > a and rect.position.x < b
		"left": return rect.position.x <= RoomDef.WALL + 0.5 and rect.end.y > a and rect.position.y < b
		"right": return rect.end.x >= size.x - RoomDef.WALL - 0.5 and rect.end.y > a and rect.position.y < b
	return false

## The standable tops of a room: its interior solids and its floor pieces (the generated floor, cut at every exit gap). The
## ceiling and the side walls are not standable.
static func standable(r: RoomDef) -> Array:
	var out: Array = r.solids.duplicate()
	for w in RoomBuilder.edge_walls(r.pixel_size(), r.exits):
		if w["kind"] == "ground":
			out.append(w["rect"])
	return out

## True when a standable top lies near `rect`: within SHORE_REACH of its x-span, its top between SURFACE_LIFT above the rect's
## top edge and the body's reach (BodyConfig.BOTTOM) below it, so a body standing on it has its centre out of the water.
static func has_shore(r: RoomDef, rect: Rect2) -> bool:
	for s in standable(r):
		var rr: Rect2 = s
		if rr.end.x < rect.position.x - SHORE_REACH or rr.position.x > rect.end.x + SHORE_REACH:
			continue
		if rr.position.y >= rect.position.y - SURFACE_LIFT and rr.position.y <= rect.position.y + BodyConfig.BOTTOM:
			return true
	return false

## A swimmer must be able to leave each water rect of the room: it crosses an open exit span, or it has a shore.
static func _water_exit(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.water.size():
		var rect: Rect2 = r.water[i]
		var escapes := false
		for e in r.exits:
			if _open_for_swimmer(e) and reaches_edge(r, rect, e):
				escapes = true
		if not escapes and not has_shore(r, rect):
			out.append(_f(r, "water_exit", "a swimmer in the water at %s cannot get out: no shore within reach of its surface and no open exit" % _rect_text(rect), "water", i))
	return out

## The authored-world check: water rects joined across open exit spans (a rect that reaches an exit's edge, and the partner
## room's rect that reaches the opposite edge over the same world span). A connected group is trapped when no member has a shore
## and no member leaves the water through an open exit that leads somewhere with no water at that span. One entry per trapped
## group: {rooms: [ids], text}.
static func water_groups(rooms: Dictionary) -> Array:
	var nodes: Array = []  # {room, i}
	var index := {}
	for id in rooms:
		var r: RoomDef = rooms[id]
		for i in r.water.size():
			index["%s:%d" % [id, i]] = nodes.size()
			nodes.append({"room": id, "i": i})
	var parent: Array = range(nodes.size())
	var leaves: Array = []
	leaves.resize(nodes.size())
	leaves.fill(false)
	var find := func(x: int) -> int:
		while parent[x] != x:
			parent[x] = parent[parent[x]]
			x = parent[x]
		return x
	for id in rooms:
		var r: RoomDef = rooms[id]
		for e in r.exits:
			if not _open_for_swimmer(e) or not rooms.has(e.get("room", "")):
				continue
			var b: RoomDef = rooms[e["room"]]
			var span := WorldValidator.world_span(r, e)
			for i in r.water.size():
				if not reaches_edge(r, r.water[i], e):
					continue
				var joined := false
				for f in b.exits:
					if f.get("room", "") != id or f["edge"] != WorldValidator.OPPOSITE[e["edge"]]:
						continue
					if not WorldValidator.world_span(b, f).is_equal_approx(span):
						continue
					for j in b.water.size():
						if reaches_edge(b, b.water[j], f):
							joined = true
							var x: int = find.call(index["%s:%d" % [id, i]])
							var y: int = find.call(index["%s:%d" % [e["room"], j]])
							parent[x] = y
				if not joined:
					leaves[index["%s:%d" % [id, i]]] = true
	var groups := {}
	for k in nodes.size():
		var root: int = find.call(k)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(k)
	var out: Array = []
	for root in groups:
		var safe := false
		for k in groups[root]:
			var m: Dictionary = nodes[k]
			var rr: RoomDef = rooms[m["room"]]
			if leaves[k] or has_shore(rr, rr.water[m["i"]]):
				safe = true
		if not safe:
			out.append({"rooms": groups[root].map(func(k): return nodes[k]["room"]), "text": "a swimmer in this connected water has no shore and no way out"})
	return out
