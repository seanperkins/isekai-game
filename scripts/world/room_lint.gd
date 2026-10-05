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
	"altar": Rect2(-19, -20, 38, 24),
}

const RULES := ["solid_outside", "outside", "in_rock", "exit_blocked", "exit_narrow", "start_floor", "ledge_reach", "over_hole",
	"altar_clearance", "feature_id", "shortcut_pair", "hint_unknown", "decor_unknown", "water_rect", "swimmer_dry", "water_exit",
	"creature_fit", "boss_room", "tremor_range", "glimpse"]

## A standing creature needs this many times its tallest frame of clear height above its footing and this many times its widest
## frame of footing; a ceiling-anchored one the same height as a drop below its anchor and the same width at the anchor. The
## sheet's frames are the sizes as drawn in game, which already carry the creature size ladder.
const FIT_HEIGHT := 1.25
const FIT_FOOTING := 2.0
## A boss room's threshold is this far from every exit (the Jet Dash's 700 px/s over the 0.4 s before the doors slam, the 28 px body
## and a margin), the boss spawns at least BOSS_SPAWN_GAP from it, and the room is BOSS_MIN_SCREENS screens in one dimension.
const SEAL_CLEARANCE := 320.0
const BOSS_MIN_SCREENS := 2
const BOSS_SPAWN_GAP := 200.0

static var _hintable: Array = []

## Skill ids a tablet hint can name: CompendiumModel keeps no slot for an enemy_only skill, so raise() on one does nothing.
static func hintable_skill_ids() -> Array:
	if _hintable.is_empty():
		for d in DefLoader.load_dir("res://data/skills"):
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
	out.append_array(_altar_clearance(r))
	out.append_array(_decor_unknown(r))
	out.append_array(_creature_fit(r))
	out.append_array(_boss_room(r, rooms))
	out.append_array(_tremor_range(r))
	out.append_array(_glimpse(r))
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

## test_grotto_rooms: nothing spawns within 200 px of an altar (a new life stands on it). The default altar is exempt.
static func _altar_clearance(r: RoomDef) -> Array:
	var out: Array = []
	for f in r.features:
		if f.get("kind", "") != "altar" or f.get("id", "") == WorldProgress.DEFAULT_ALTAR:
			continue
		for i in r.spawns.size():
			var d: float = (r.spawns[i]["pos"] as Vector2).distance_to(f["pos"])
			if d <= POOL_CLEARANCE:
				out.append(_f(r, "altar_clearance", "%s spawns %d px from the altar %s" % [r.spawns[i]["id"], int(d), f.get("id", "?")], "spawn", i))
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

## True when `rect` reaches the room's own edge (not the inside face of the wall: a swimmer leaving through a band of dry wall would
## fall back) over exit `e`'s span.
static func reaches_edge(r: RoomDef, rect: Rect2, e: Dictionary) -> bool:
	var size := r.pixel_size()
	var a := float(e["from"])
	var b := float(e["to"])
	match e["edge"]:
		"top": return rect.position.y <= 0.5 and rect.end.x > a and rect.position.x < b
		"bottom": return rect.end.y >= size.y - 0.5 and rect.end.x > a and rect.position.x < b
		"left": return rect.position.x <= 0.5 and rect.end.y > a and rect.position.y < b
		"right": return rect.end.x >= size.x - 0.5 and rect.end.y > a and rect.position.y < b
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

# --- creature fit and boss rooms (plan: boss arenas) ---

static var _extents: Dictionary = {}
static var _kinds: Dictionary = {}

## The widest and tallest frame of a creature's sheet (px, as drawn in game), ZERO when it has no sheet.
static func creature_extent(id: String) -> Vector2:
	if not _extents.has(id):
		var e := Vector2.ZERO
		if SpriteSheet.available(id):
			var sheet := SpriteSheet.load_set(id)
			for n in sheet.frame_names():
				var s: Vector2 = sheet.frame_size(n)
				e = Vector2(maxf(e.x, s.x), maxf(e.y, s.y))
		_extents[id] = e
	return _extents[id]

## "walker" (stands on a footing), "ceiling" (a `ceiling_walk` creature hangs from the ceiling), "flier" (a drifter or a `flight` creature)
## or "swimmer", from the shipped defs; "" for an id with no def.
static func creature_kind(id: String) -> String:
	if _kinds.is_empty():
		for c in DefLoader.load_dir("res://data/creatures"):
			var d := c as CreatureDef
			var skill_ids: Array = d.skills.map(func(s: Dictionary) -> String: return str(s.get("id", "")))
			if d.swimmer:
				_kinds[d.id] = "swimmer"
			elif skill_ids.has("ceiling_walk"):
				_kinds[d.id] = "ceiling"
			elif d.drifter or skill_ids.has("flight"):
				_kinds[d.id] = "flier"
			else:
				_kinds[d.id] = "walker"
	return _kinds.get(id, "")

## A creature that stands has FIT_HEIGHT x its tallest frame of clear height above its footing and FIT_FOOTING x its widest frame of
## footing; one that hangs has the same height of drop below its anchor and the same width at the anchor. Creatures with no sheet,
## fliers and swimmers are skipped.
static func _creature_fit(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.spawns.size():
		var id: String = r.spawns[i]["id"]
		var pos: Vector2 = r.spawns[i]["pos"]
		var ext := creature_extent(id)
		var kind := creature_kind(id)
		if ext == Vector2.ZERO or (kind != "walker" and kind != "ceiling"):
			continue
		var foot_l := pos.x - ext.x / 2.0
		var foot_r := pos.x + ext.x / 2.0
		if kind == "walker":
			var support = _support(r, pos)
			if support == null:
				continue
			var run := _footing(r, support)
			if run.y - run.x < FIT_FOOTING * ext.x:
				out.append(_f(r, "creature_fit", "%s at %s stands on %d px of footing, needs %d (%s x its %d px width)" % [id, pos, int(run.y - run.x), int(ceil(FIT_FOOTING * ext.x)), FIT_FOOTING, int(ext.x)], "spawn", i))
			var top: float = (support as Rect2).position.y
			var ceiling := 0.0
			for rect in rock(r):
				var rr: Rect2 = rect
				if rr.end.y < top - 0.5 and rr.position.x < foot_r and rr.end.x > foot_l and not RoomBuilder.is_one_way(rr, r.hard_ledges):  # strictly overhead: a block standing on the footing is beside it, not above
					ceiling = maxf(ceiling, rr.end.y)
			if top - ceiling < FIT_HEIGHT * ext.y:
				out.append(_f(r, "creature_fit", "%s at %s has %d px of clear height over its footing, needs %d (%s x its %d px height)" % [id, pos, int(top - ceiling), int(ceil(FIT_HEIGHT * ext.y)), FIT_HEIGHT, int(ext.y)], "spawn", i))
		else:
			var floor_y := r.pixel_size().y
			for rect in rock(r):
				var rr: Rect2 = rect
				if rr.position.y >= pos.y - 0.5 and rr.position.x < foot_r and rr.end.x > foot_l:
					floor_y = minf(floor_y, rr.position.y)
			if floor_y - pos.y < FIT_HEIGHT * ext.y:
				out.append(_f(r, "creature_fit", "%s at %s has %d px to drop below its anchor, needs %d (%s x its %d px height)" % [id, pos, int(floor_y - pos.y), int(ceil(FIT_HEIGHT * ext.y)), FIT_HEIGHT, int(ext.y)], "spawn", i))
			var left := 0.0
			var right := r.pixel_size().x
			for rect in rock(r):
				var rr: Rect2 = rect
				if rr.position.y <= pos.y and pos.y <= rr.end.y:
					if rr.end.x <= pos.x:
						left = maxf(left, rr.end.x)
					elif rr.position.x >= pos.x:
						right = minf(right, rr.position.x)
			if right - left < FIT_FOOTING * ext.x:
				out.append(_f(r, "creature_fit", "%s at %s has %d px of room at its anchor, needs %d (%s x its %d px width)" % [id, pos, int(right - left), int(ceil(FIT_FOOTING * ext.x)), FIT_FOOTING, int(ext.x)], "spawn", i))
	return out

## The standable top (a Rect2) nearest below `pos` that `pos.x` is over, or null.
static func _support(r: RoomDef, pos: Vector2):
	var best = null
	for rect in standable(r):
		var rr: Rect2 = rect
		if pos.x >= rr.position.x and pos.x <= rr.end.x and rr.position.y >= pos.y - 1.0:
			if best == null or rr.position.y < (best as Rect2).position.y:
				best = rr
	return best

## The contiguous run (x start, x end) of standable tops at the same height as `support`, touching or overlapping it.
static func _footing(r: RoomDef, support: Rect2) -> Vector2:
	var lo := support.position.x
	var hi := support.end.x
	var grew := true
	while grew:
		grew = false
		for rect in standable(r):
			var rr: Rect2 = rect
			if absf(rr.position.y - support.position.y) < 0.5 and rr.position.x <= hi + 0.5 and rr.end.x >= lo - 0.5 and (rr.position.x < lo - 0.01 or rr.end.x > hi + 0.01):
				lo = minf(lo, rr.position.x)
				hi = maxf(hi, rr.end.x)
				grew = true
	return Vector2(lo, hi)

static func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(dx * dx + dy * dy)

## The rules of a boss room: two screens in one dimension, one exit (no bottom door: nothing may fall out), no water, an exit that leads
## to a room with a glow pool and no spawns, the boss spawned in the room at least BOSS_SPAWN_GAP from the threshold, and the threshold
## inside the room at least SEAL_CLEARANCE from every exit.
static func _boss_room(r: RoomDef, rooms: Dictionary) -> Array:
	var out: Array = []
	if r.boss.is_empty():
		return out
	var creature: String = str(r.boss.get("creature", ""))
	var threshold = r.boss.get("threshold")
	if creature == "" or not (threshold is Rect2):
		out.append(_f(r, "boss_room", "boss needs a creature id and a threshold Rect2"))
		return out
	var size := r.pixel_size()
	if (threshold as Rect2).size.x <= 0.0 or (threshold as Rect2).size.y <= 0.0:
		out.append(_f(r, "boss_room", "the threshold %s needs a positive size, or nothing can cross it" % _rect_text(threshold)))
	if maxi(r.size.x, r.size.y) < BOSS_MIN_SCREENS:
		out.append(_f(r, "boss_room", "a boss room is at least %d screens in one dimension, this one is %dx%d" % [BOSS_MIN_SCREENS, r.size.x, r.size.y]))
	if r.exits.size() != 1:
		out.append(_f(r, "boss_room", "a boss room has exactly one exit, this one has %d" % r.exits.size()))
	else:
		var partner = rooms.get(r.exits[0].get("room", ""))
		if partner != null:
			var has_pool := false
			for f in (partner as RoomDef).features:
				if f.get("kind", "") == "glow_pool":
					has_pool = true
			if not has_pool:
				out.append(_f(r, "boss_room", "its exit leads to %s, which has no glow pool to rest at" % partner.id))
			if not (partner as RoomDef).spawns.is_empty():
				out.append(_f(r, "boss_room", "its exit leads to %s, which has spawns: the antechamber must be quiet" % partner.id))
	for e in r.exits:
		if e.get("edge", "") == "bottom":
			out.append(_f(r, "boss_room", "a bottom exit is a hole in the floor: nothing may fall out of an arena"))
	if not r.water.is_empty():
		out.append(_f(r, "boss_room", "a boss room has no water"))
	var matches: Array = []
	for i in r.spawns.size():
		if r.spawns[i]["id"] == creature:
			matches.append(i)
	var boss_at: int = matches[0] if matches.size() == 1 else -1
	if matches.size() != 1:
		out.append(_f(r, "boss_room", "the boss %s must be in this room's spawns exactly once, it is there %d times" % [creature, matches.size()]))
	elif _gap(Rect2(r.spawns[boss_at]["pos"], Vector2.ZERO), threshold) < BOSS_SPAWN_GAP:
		out.append(_f(r, "boss_room", "the boss spawns %d px from the threshold, at least %d" % [int(_gap(Rect2(r.spawns[boss_at]["pos"], Vector2.ZERO), threshold)), int(BOSS_SPAWN_GAP)], "spawn", boss_at))
	if not Rect2(Vector2.ZERO, size).encloses(threshold):
		out.append(_f(r, "boss_room", "the threshold %s is not inside the room" % _rect_text(threshold)))
	for e in r.exits:
		if _gap(threshold, RoomBuilder.gate_rect(size, e)) < SEAL_CLEARANCE - 0.01:
			out.append(_f(r, "boss_room", "the threshold is %d px from the %s exit, at least %d so the doors never close on the player" % [int(_gap(threshold, RoomBuilder.gate_rect(size, e))), e.get("edge", ""), int(SEAL_CLEARANCE)]))
	return out

static func _tremor_range(r: RoomDef) -> Array:
	if r.tremor < 0.0 or r.tremor > 1.0:
		return [_f(r, "tremor_range", "tremor %s is outside 0 to 1" % r.tremor)]
	return []

## A glimpse names a creature with a sheet, sits inside the room and has a scale above 0.
static func _glimpse(r: RoomDef) -> Array:
	if r.glimpse.is_empty():
		return []
	var creature: String = str(r.glimpse.get("creature", ""))
	if not SpriteSheet.available(creature):
		return [_f(r, "glimpse", "the glimpse creature '%s' has no sheet" % creature)]
	var pos = r.glimpse.get("pos")
	if not (pos is Vector2) or not Rect2(Vector2.ZERO, r.pixel_size()).has_point(pos):
		return [_f(r, "glimpse", "the glimpse is not inside the room")]
	if float(r.glimpse.get("scale", 0.0)) <= 0.0:
		return [_f(r, "glimpse", "the glimpse scale must be above 0")]
	return []
