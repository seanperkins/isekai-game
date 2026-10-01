class_name RoomEditModel
extends RefCounted
## The room editor's data: working copies of the rooms, the selection, every edit (each one undo step), the dirty set and the
## save. Pure data, no nodes. It is the one place that knows the shape of a RoomDef's arrays.

const GRID := 4.0
const UNDO_CAP := 200
const FEATURE_KINDS := ["glow_pool", "tablet", "switch", "rebirth_pool"]
const MIN_SOLID := 4.0

static var _prop_names: Array = []

var rooms := {}     # id -> RoomDef (working copies)
var dirty := {}     # id -> true: rooms edited since the last successful save
var creature_ids: Array = []
## {} or {"room", "kind": "solid" | "spawn" | "exit" | "feature", "index"}
var selection := {}
var _undo: Array = []   # each: {id: RoomDef or null}, the state before a step
var _redo: Array = []
var _drag := {}         # a move in progress
var _source_ids := {}   # the rooms that were on disk when the editor opened: never deleted from disk
var _baseline := {}     # id -> RoomDef: what is on disk (the loaded rooms, then whatever the last Save wrote); dirty = differs
var _written := {}      # ids Save has written this session
var _removed_on_save := {}  # rooms created and saved this session, then undone: their file goes on the next Save
## Counts every recorded edit, undo and redo, so a view can tell that the rooms changed without diffing them.
var serial := 0
var _problems_serial := -1  # the serial the cached problems() list was computed at
var _problems_cache: Array = []

func _init(source: Dictionary, p_creature_ids: Array = []) -> void:
	creature_ids = p_creature_ids
	for id in source:
		rooms[id] = copy_room(source[id])
		_baseline[id] = copy_room(source[id])
		_source_ids[id] = true

## The exported (stored) properties of RoomDef, so a property added later is copied and compared without an edit here.
static func _props() -> Array:
	if _prop_names.is_empty():
		for p in RoomDef.new().get_property_list():
			if (p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (p["usage"] & PROPERTY_USAGE_STORAGE) != 0:
				_prop_names.append(p["name"])
	return _prop_names

static func copy_room(r: RoomDef) -> RoomDef:
	var c := RoomDef.new()
	for name in _props():
		var v = r.get(name)
		c.set(name, v.duplicate(true) if (v is Array or v is Dictionary) else v)
	return c

## RoomDef == RoomDef compares identity, so two rooms are the same when every exported property is equal (null equals null).
static func same_room(a, b) -> bool:
	if a == null or b == null:
		return a == b
	for name in _props():
		if a.get(name) != b.get(name):
			return false
	return true

static func snap(v: float) -> float:
	return roundf(v / GRID) * GRID

static func snap_delta(d: Vector2) -> Vector2:
	return Vector2(snap(d.x), snap(d.y))

static func bounds(r: RoomDef) -> Rect2:
	return Rect2(Vector2.ZERO, r.pixel_size())

# --- snapshots ---

func _snap(ids: Array) -> Dictionary:
	var s := {}
	for id in ids:
		s[id] = copy_room(rooms[id]) if rooms.has(id) else null
	return s

## Records `before` as an undo step unless the rooms it covers are unchanged; marks the changed ones dirty.
func _push(before: Dictionary) -> void:
	var changed := false
	for id in before:
		if not same_room(before[id], rooms.get(id)):
			changed = true
			_mark(id)
	if not changed:
		return
	_undo.append(before)
	if _undo.size() > UNDO_CAP:
		_undo.pop_front()
	_redo.clear()
	serial += 1

## A room is dirty when it differs from what is on disk, so undoing back to the saved state clears the mark.
func _mark(id: String) -> void:
	if same_room(rooms.get(id), _baseline.get(id)):
		dirty.erase(id)
	else:
		dirty[id] = true

## Puts `snap` back and returns the state it replaced (the other stack's step).
func _swap(snap: Dictionary) -> Dictionary:
	var now := _snap(snap.keys())
	for id in snap:
		if snap[id] == null:
			rooms.erase(id)
			dirty.erase(id)
			if _written.has(id) and not _source_ids.has(id):
				_removed_on_save[id] = true  # a room this session created and saved: its file must not outlive the undo
		else:
			rooms[id] = snap[id]
			_removed_on_save.erase(id)
			_mark(id)
	selection = {}
	serial += 1
	return now

func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(_swap(_undo.pop_back()))
	return true

func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(_swap(_redo.pop_back()))
	return true

func undo_depth() -> int:
	return _undo.size()

func redo_depth() -> int:
	return _redo.size()

# --- geometry ---

## A drag's rect: both corners snapped, normalised.
static func drag_rect(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(Vector2(snap(a.x), snap(a.y)), Vector2.ZERO).expand(Vector2(snap(b.x), snap(b.y)))

## What the builder will make of a solid this size: a one-way ledge you jump up through, or rock.
static func label_for(rect: Rect2, hard: Array = []) -> String:
	return "one-way ledge" if RoomBuilder.is_one_way(rect, hard) else "rock"

## Rects nothing stands inside: interior solids and the boundary walls (the suite's spawn rule), and with `with_gates` the
## gates of closed shortcut exits (what the editor view and Play draw).
func rock(room_id: String, with_gates := false) -> Array:
	var r: RoomDef = rooms[room_id]
	var out: Array = RoomLint.rock(r)
	if with_gates:
		for e in r.exits:
			if e.has("shortcut"):
				out.append(RoomBuilder.gate_rect(r.pixel_size(), e))
	return out

func _in_rock(room_id: String, p: Vector2) -> bool:
	for rect in rock(room_id):
		if (rect as Rect2).has_point(p):
			return true
	return false

func _sel(room_id: String, kind: String, index: int) -> Dictionary:
	return {"room": room_id, "kind": kind, "index": index}

func select(sel: Dictionary) -> void:
	selection = sel

# --- solids and creatures ---

func add_solid(room_id: String, a: Vector2, b: Vector2) -> String:
	var r: RoomDef = rooms[room_id]
	var rect := drag_rect(a, b).intersection(bounds(r))
	if rect.size.x < MIN_SOLID or rect.size.y < MIN_SOLID:
		return "too small, or outside the room"
	var before := _snap([room_id])
	r.solids.append(rect)
	_push(before)
	selection = _sel(room_id, "solid", r.solids.size() - 1)
	return ""

func add_spawn(room_id: String, creature_id: String, pos: Vector2) -> String:
	var r: RoomDef = rooms[room_id]
	if not creature_ids.is_empty() and not creature_ids.has(creature_id):
		return "unknown creature '%s'" % creature_id
	var p := Vector2(snap(pos.x), snap(pos.y))
	if not bounds(r).has_point(p):
		return "outside the room"
	if _in_rock(room_id, p):
		return "inside rock: click open space"
	var before := _snap([room_id])
	r.spawns.append({"id": creature_id, "pos": p})
	_push(before)
	selection = _sel(room_id, "spawn", r.spawns.size() - 1)
	return ""

# --- hit-testing ---

## The element under a room-local point: the nearest creature within `pick`, else a feature's drawn box, else an exit's gap, else
## the smallest solid.
func hit(room_id: String, p: Vector2, pick: float) -> Dictionary:
	var r: RoomDef = rooms[room_id]
	var best := -1
	var best_d := INF
	for i in r.spawns.size():
		var d := (r.spawns[i]["pos"] as Vector2).distance_to(p)
		if d <= pick and d < best_d:
			best = i
			best_d = d
	if best >= 0:
		return _sel(room_id, "spawn", best)
	for i in r.features.size():
		var f: Dictionary = r.features[i]
		var box: Rect2 = RoomLint.FEATURE_BOX.get(f.get("kind", ""), Rect2(-6, -12, 12, 12))
		if Rect2(box.position + (f["pos"] as Vector2), box.size).grow(pick).has_point(p):
			return _sel(room_id, "feature", i)
	for i in r.exits.size():
		if RoomBuilder.gate_rect(r.pixel_size(), r.exits[i]).grow(pick).has_point(p):
			return _sel(room_id, "exit", i)
	var area := INF
	best = -1
	for i in r.solids.size():
		var s: Rect2 = r.solids[i]
		if s.grow(pick).has_point(p) and s.get_area() < area:
			area = s.get_area()
			best = i
	return _sel(room_id, "solid", best) if best >= 0 else {}

# --- moving ---

func begin_move(sel: Dictionary) -> bool:
	if sel.is_empty() or not rooms.has(sel["room"]):
		return false
	var r: RoomDef = rooms[sel["room"]]
	var i: int = sel["index"]
	match sel["kind"]:
		"solid":
			if i >= r.solids.size():
				return false
			_drag = {"sel": sel, "before": _snap([sel["room"]]), "orig": r.solids[i]}
		"spawn":
			if i >= r.spawns.size():
				return false
			_drag = {"sel": sel, "before": _snap([sel["room"]]), "orig": r.spawns[i]["pos"]}
		"feature":
			if i >= r.features.size():
				return false
			_drag = {"sel": sel, "before": _snap([sel["room"]]), "orig": r.features[i]["pos"]}
		"exit":
			return _begin_move_exit(sel)
		_:
			return false
	selection = sel
	return true

## Moves the dragged element to its original place plus `delta` (snapped). An invalid spot leaves the last valid one.
func move_to(delta: Vector2) -> void:
	if _drag.is_empty():
		return
	var sel: Dictionary = _drag["sel"]
	var r: RoomDef = rooms[sel["room"]]
	var d := snap_delta(delta)
	match sel["kind"]:
		"solid":
			var orig: Rect2 = _drag["orig"]
			var moved := Rect2(orig.position + d, orig.size)
			moved.position = moved.position.clamp(Vector2.ZERO, r.pixel_size() - moved.size)
			var i: int = sel["index"]
			var was: Rect2 = r.solids[i]
			r.solids[i] = moved
			var h := r.hard_ledges.find(was)
			if h >= 0:
				r.hard_ledges[h] = moved
		"spawn":
			var p: Vector2 = (_drag["orig"] as Vector2) + d
			if bounds(r).has_point(p) and not _in_rock(sel["room"], p):
				r.spawns[sel["index"]]["pos"] = p
		"feature":
			var base = _feature_base(sel["room"], (_drag["orig"] as Vector2) + d, r.features[sel["index"]]["kind"])
			if base is Vector2:
				r.features[sel["index"]]["pos"] = base
		"exit":
			_move_exit_to(d)
		_:
			pass

func end_move() -> void:
	if _drag.is_empty():
		return
	var before: Dictionary = _drag["before"]
	_drag = {}
	_push(before)

# --- deleting ---

func delete_selection() -> String:
	if selection.is_empty() or not rooms.has(selection["room"]):
		return "nothing selected"
	var r: RoomDef = rooms[selection["room"]]
	var i: int = selection["index"]
	match selection["kind"]:
		"solid":
			if i >= r.solids.size():
				return "nothing selected"
			var before := _snap([selection["room"]])
			var gone: Rect2 = r.solids[i]
			r.solids.remove_at(i)
			var h := r.hard_ledges.find(gone)
			if h >= 0:
				r.hard_ledges.remove_at(h)
			_push(before)
		"spawn":
			if i >= r.spawns.size():
				return "nothing selected"
			var before := _snap([selection["room"]])
			r.spawns.remove_at(i)
			_push(before)
		"feature":
			if i >= r.features.size():
				return "nothing selected"
			var before := _snap([selection["room"]])
			r.features.remove_at(i)
			_push(before)
		"exit":
			return _delete_exit()
		_:
			return "nothing selected"
	selection = {}
	return ""

# --- where Play starts ---

## The top of the first solid or boundary floor at or under `p`: null when `p` is outside the room, inside rock, or nothing is
## below it. `with_gates` adds the gates of closed shortcut exits as surfaces (Play stands on them; a feature does not, since
## they vanish when the shortcut opens).
func surface_below(room_id: String, p: Vector2, with_gates := false) -> Variant:
	if not bounds(rooms[room_id]).has_point(p):
		return null
	var best := INF
	for rect in rock(room_id, with_gates):
		var q: Rect2 = rect
		if q.has_point(p):
			return null
		if p.x >= q.position.x and p.x < q.end.x and q.position.y >= p.y and q.position.y < best:
			best = q.position.y
	return null if best == INF else best

## Where Play puts the slime for a click at `p` (the surface below it, a closed gate included by default; Play passes false when
## shortcuts are open). The player's origin: feet on the rock. The two defaults are opposite on purpose: Play stands on a closed
## gate, a feature never does.
func floor_spot(room_id: String, p: Vector2, with_gates := true) -> Variant:
	var y = surface_below(room_id, p, with_gates)
	return null if y == null else Vector2(p.x, float(y) - BodyConfig.BOTTOM)

# --- features ---

## A feature's base for a candidate point: x snapped, y the surface found from one pixel above the candidate (so a point exactly
## on a surface top, as every drag step is, finds that surface instead of being "inside" it). A Vector2, or the reason it is
## refused.
func _feature_base(room_id: String, p: Vector2, kind: String) -> Variant:
	var r: RoomDef = rooms[room_id]
	var q := Vector2(snap(p.x), snap(p.y))
	if not bounds(r).has_point(q):
		return "outside the room"
	var y = surface_below(room_id, q - Vector2(0.0, 1.0))
	if y == null:
		return "nothing to stand on there: click open space above a floor or a ledge"
	var base := Vector2(q.x, float(y))
	if RoomLint.embedded(r, base, kind):
		return "stuck in rock or a wall"
	return base

## The first n for which "<room>_<kind>_<n>" is not used by any feature in the world.
func _feature_id(room_id: String, kind: String) -> String:
	var taken := {}
	for id in rooms:
		for f in (rooms[id] as RoomDef).features:
			taken[f.get("id", "")] = true
	var n := 1
	while taken.has("%s_%s_%d" % [room_id.to_lower(), kind, n]):
		n += 1
	return "%s_%s_%d" % [room_id.to_lower(), kind, n]

func add_feature(room_id: String, kind: String, pos: Vector2) -> String:
	if not FEATURE_KINDS.has(kind):
		return "unknown feature '%s'" % kind
	var base = _feature_base(room_id, pos, kind)
	if base is String:
		return base
	var r: RoomDef = rooms[room_id]
	var id := _feature_id(room_id, kind)
	var f := {"kind": kind, "id": id, "pos": base}
	match kind:
		"tablet":
			f["title"] = "Tablet"
			f["text"] = ""
		"switch":
			f["shortcut"] = id
		"rebirth_pool":
			f["area"] = r.area
			f["kit"] = {}
	var before := _snap([room_id])
	r.features.append(f)
	_push(before)
	selection = _sel(room_id, "feature", r.features.size() - 1)
	return ""

# --- inspector fields ---

## The value of an inspector field for the selection (see set_field for the keys), or null for an unknown one.
func get_field(sel: Dictionary, key: String) -> Variant:
	if sel.is_empty() or not rooms.has(sel["room"]):
		return null
	var r: RoomDef = rooms[sel["room"]]
	var i: int = sel["index"]
	match sel["kind"]:
		"exit":
			if i < r.exits.size() and key == "shortcut":
				return r.exits[i].get("shortcut", "")
		"feature":
			if i >= r.features.size():
				return null
			var f: Dictionary = r.features[i]
			match key:
				"title", "text", "shortcut":
					return f.get(key, "")
				"kit_level":
					return int((f.get("kit", {}) as Dictionary).get("level", 0))
				"kit_skills":
					return ((f.get("kit", {}) as Dictionary).get("skills", []) as Array).duplicate()
	return null

## Sets one inspector field: exit "shortcut" (both halves); tablet "title" (required) and "text"; switch "shortcut" (required);
## rebirth pool "kit_level" (0 unsets) and "kit_skills" (a list), merged into the kit so every other key (G1's affinity) is kept.
## Optional keys are removed by "" or 0; required keys are never removed. A refusal returns the reason and changes nothing; a
## value equal to the stored one pushes nothing (_push declines an unchanged room).
func set_field(sel: Dictionary, key: String, value) -> String:
	if sel.is_empty() or not rooms.has(sel["room"]):
		return "nothing selected"
	var room_id: String = sel["room"]
	var r: RoomDef = rooms[room_id]
	var i: int = sel["index"]
	match sel["kind"]:
		"exit":
			if i >= r.exits.size() or key != "shortcut":
				return "no such field"
			return _set_exit_shortcut(room_id, i, str(value))
		"feature":
			if i >= r.features.size():
				return "nothing selected"
			return _set_feature_field(room_id, i, key, value)
	return "no such field"

func _set_exit_shortcut(room_id: String, i: int, value: String) -> String:
	if value != "" and not valid_id(value):
		return "a shortcut id is letters, digits and underscore"
	var r: RoomDef = rooms[room_id]
	var p := partner_of(room_id, i)
	var ids: Array = [room_id]
	if not p.is_empty():
		ids.append(p["room"])
	var before := _snap(ids)
	_write_exit_shortcut(r.exits[i], value)
	if not p.is_empty():
		_write_exit_shortcut((rooms[p["room"]] as RoomDef).exits[p["index"]], value)
	_push(before)
	return ""

static func _write_exit_shortcut(e: Dictionary, value: String) -> void:
	if value == "":
		e.erase("shortcut")
	else:
		e["shortcut"] = value

func _set_feature_field(room_id: String, i: int, key: String, value) -> String:
	var r: RoomDef = rooms[room_id]
	var f: Dictionary = r.features[i]
	var kind: String = f.get("kind", "")
	if (key == "title" or key == "text") and kind != "tablet":
		return "a %s has no %s" % [kind, key]
	if key == "shortcut" and kind != "switch":
		return "a %s has no shortcut" % kind
	if (key == "kit_level" or key == "kit_skills") and kind != "rebirth_pool":
		return "a %s has no kit" % kind
	var next: Dictionary = f.duplicate(true)
	match key:
		"title":
			if str(value) == "":
				return "a tablet needs a title"
			next["title"] = str(value)
		"text":
			if str(value) == "":
				next.erase("text")
			else:
				next["text"] = str(value)
		"shortcut":
			if not valid_id(str(value)):
				return "a shortcut id is letters, digits and underscore (and not empty)"
			next["shortcut"] = str(value)
		"kit_level":
			var kit: Dictionary = next.get("kit", {})
			if int(value) == 0:
				kit.erase("level")
			else:
				kit["level"] = int(value)
			next["kit"] = kit
		"kit_skills":
			var kit: Dictionary = next.get("kit", {})
			if (value as Array).is_empty():
				kit.erase("skills")
			else:
				kit["skills"] = (value as Array).duplicate()
			next["kit"] = kit
		_:
			return "no such field"
	if kind == "rebirth_pool":
		var errs := RebirthKit.validate(next["kit"])
		if not errs.is_empty():
			return errs[0]
	var before := _snap([room_id])
	r.features[i] = next
	_push(before)
	return ""

func validate() -> PackedStringArray:
	return WorldValidator.validate(rooms, creature_ids)

## Lint findings and validator strings as one list of {room, text, pick}. A validator string's room is the text before its first
## ": " or " overlaps ", kept only when that is a room id. Recomputed when `serial` changes, never per mouse motion.
func problems() -> Array:
	if _problems_serial == serial:
		return _problems_cache
	var out: Array = []
	for f in RoomLint.check(rooms):
		out.append({"room": f["room"], "text": f["text"], "pick": f["pick"]})
	for s in validate():
		out.append({"room": _room_of(s), "text": s, "pick": {}})
	_problems_cache = out
	_problems_serial = serial
	return out

func _room_of(text: String) -> String:
	var cut := text.length()
	for sep in [": ", " overlaps "]:
		var at := text.find(sep)
		if at >= 0:
			cut = mini(cut, at)
	var head := text.substr(0, cut)
	return head if rooms.has(head) else ""

# --- exits ---

static func _exit(edge: String, from: float, to: float, room: String, opts: Dictionary) -> Dictionary:
	var e := {"edge": edge, "from": from, "to": to, "room": room}
	if opts.has("gate"):
		e["gate"] = opts["gate"]
	if opts.has("shortcut"):
		e["shortcut"] = opts["shortcut"]
	return e

## Does an exit on `edge` of `r` covering [from, to] (r-local) overlap another exit on that edge? `skip` is an index to ignore.
static func _overlaps(r: RoomDef, edge: String, from: float, to: float, skip := -1) -> bool:
	for i in r.exits.size():
		var e: Dictionary = r.exits[i]
		if i != skip and e["edge"] == edge and from < float(e["to"]) and float(e["from"]) < to:
			return true
	return false

static func _within(r: RoomDef, edge: String, from: float, to: float) -> bool:
	var limits := WorldValidator.edge_range(r, edge)
	return from >= limits.x and to <= limits.y and from < to

## The room across `edge` of `a` whose facing edge line coincides with a's and whose allowed range holds the world span.
func _across(a: RoomDef, edge: String, w0: float, w1: float) -> RoomDef:
	var opp: String = WorldValidator.OPPOSITE[edge]
	for id in rooms:
		var b: RoomDef = rooms[id]
		if b == a or not WorldValidator.touches(a.world_rect(), b.world_rect(), edge):
			continue
		var o := WorldValidator.edge_origin(b, opp)
		var limits := WorldValidator.edge_range(b, opp)
		if w0 >= o + limits.x and w1 <= o + limits.y:
			return b
	return null

## Adds an exit on `edge` of room `a_id` over [from, to] (a-local pixels along the edge) and its partner in the room across,
## in one undo step. `opts` may carry "gate" and "shortcut", copied to both halves. Returns "" or the reason it was refused.
func add_exit(a_id: String, edge: String, from: float, to: float, opts := {}) -> String:
	if not WorldValidator.OPPOSITE.has(edge):
		return "not an edge"
	var a: RoomDef = rooms[a_id]
	var lo := snap(minf(from, to))
	var hi := snap(maxf(from, to))
	if hi - lo < RoomLint.MIN_EXIT:
		return "too short: an exit is at least %d px" % int(RoomLint.MIN_EXIT)
	if not _within(a, edge, lo, hi):
		return "outside what this edge allows"
	if _overlaps(a, edge, lo, hi):
		return "overlaps another exit"
	var oa := WorldValidator.edge_origin(a, edge)
	var b := _across(a, edge, oa + lo, oa + hi)
	if b == null:
		return "no room across this edge covers that span"
	var opp: String = WorldValidator.OPPOSITE[edge]
	var ob := WorldValidator.edge_origin(b, opp)
	if _overlaps(b, opp, oa + lo - ob, oa + hi - ob):
		return "overlaps an exit in %s" % b.id
	var before := _snap([a_id, b.id])
	a.exits.append(_exit(edge, lo, hi, b.id, opts))
	b.exits.append(_exit(opp, oa + lo - ob, oa + hi - ob, a_id, opts))
	_push(before)
	selection = _sel(a_id, "exit", a.exits.size() - 1)
	return ""

## The exit in the neighbour that answers exit `index` of `room_id`, by the validator's rule: opposite edge, pointing back,
## the same world span. {} when there is none.
func partner_of(room_id: String, index: int) -> Dictionary:
	var a: RoomDef = rooms[room_id]
	var e: Dictionary = a.exits[index]
	var b: RoomDef = rooms.get(e.get("room", ""))
	if b == null or not WorldValidator.OPPOSITE.has(e.get("edge", "")):
		return {}
	var span := WorldValidator.world_span(a, e)
	for i in b.exits.size():
		var f: Dictionary = b.exits[i]
		if f.get("edge", "") == WorldValidator.OPPOSITE[e["edge"]] and f.get("room", "") == room_id \
				and WorldValidator.world_span(b, f).is_equal_approx(span):
			return {"room": b.id, "index": i}
	return {}

func _begin_move_exit(sel: Dictionary) -> bool:
	var r: RoomDef = rooms[sel["room"]]
	var i: int = sel["index"]
	if sel["kind"] != "exit" or i >= r.exits.size():
		return false
	var p := partner_of(sel["room"], i)
	var ids: Array = [sel["room"]]
	if not p.is_empty():
		ids.append(p["room"])
	_drag = {"sel": sel, "before": _snap(ids), "orig": r.exits[i].duplicate(), "partner": p}
	selection = sel
	return true

func _move_exit_to(d: Vector2) -> void:
	var sel: Dictionary = _drag["sel"]
	var a: RoomDef = rooms[sel["room"]]
	var orig: Dictionary = _drag["orig"]
	var edge: String = orig["edge"]
	var axis := d.y if edge == "left" or edge == "right" else d.x
	var lo := float(orig["from"]) + axis
	var hi := float(orig["to"]) + axis
	var i: int = sel["index"]
	if not _within(a, edge, lo, hi) or _overlaps(a, edge, lo, hi, i):
		return
	var p: Dictionary = _drag["partner"]
	if not p.is_empty():
		var b: RoomDef = rooms[p["room"]]
		var opp: String = WorldValidator.OPPOSITE[edge]
		var shift := WorldValidator.edge_origin(a, edge) - WorldValidator.edge_origin(b, opp)
		if not _within(b, opp, lo + shift, hi + shift) or _overlaps(b, opp, lo + shift, hi + shift, p["index"]):
			return
		b.exits[p["index"]]["from"] = lo + shift
		b.exits[p["index"]]["to"] = hi + shift
	a.exits[i]["from"] = lo
	a.exits[i]["to"] = hi

func _delete_exit() -> String:
	var r: RoomDef = rooms[selection["room"]]
	var i: int = selection["index"]
	if i >= r.exits.size():
		return "nothing selected"
	var p := partner_of(selection["room"], i)
	var ids: Array = [selection["room"]]
	if not p.is_empty():
		ids.append(p["room"])
	var before := _snap(ids)
	if not p.is_empty():
		(rooms[p["room"]] as RoomDef).exits.remove_at(p["index"])
	r.exits.remove_at(i)
	_push(before)
	selection = {}
	return ""

# --- new rooms ---

## The length of the door a new room is created with.
const DOOR := 80.0
const MAX_SCREENS := 6
static var _id_rx: RegEx

static func valid_id(id: String) -> bool:
	if _id_rx == null:
		_id_rx = RegEx.new()
		_id_rx.compile("^[A-Za-z0-9_]+$")
	return _id_rx.search(id) != null

## "" when `id` may name a new room; else why not. Ids are unique case-insensitively (the file system is).
func id_error(id: String) -> String:
	if id.to_lower() == "world":
		return "'world' is reserved"
	if not valid_id(id):
		return "an id is letters, digits and underscore"
	for k in rooms:
		if String(k).to_lower() == id.to_lower():
			return "'%s' is already a room (ids differ by more than case)" % k
	return ""

## A new room across `edge` of `a_id`: bottom-aligned beside a side edge (so the floors are level), left-aligned above or
## below. Created with the paired exit toward its neighbour, in one undo step. Returns "" or the reason it was refused.
func new_room_beside(a_id: String, edge: String, new_id: String, area: String, size: Vector2i) -> String:
	if not WorldValidator.OPPOSITE.has(edge):
		return "not an edge"
	var err := id_error(new_id)
	if err != "":
		return err
	if not TerrainArt.has_biome(area):
		return "unknown area '%s'" % area
	if size.x < 1 or size.y < 1 or size.x > MAX_SCREENS or size.y > MAX_SCREENS:
		return "a room is 1 to %d screens each way" % MAX_SCREENS
	var a: RoomDef = rooms[a_id]
	var cell: Vector2i
	match edge:
		"right": cell = Vector2i(a.cell.x + a.size.x, a.cell.y + a.size.y - size.y)
		"left": cell = Vector2i(a.cell.x - size.x, a.cell.y + a.size.y - size.y)
		"bottom": cell = Vector2i(a.cell.x, a.cell.y + a.size.y)
		_: cell = Vector2i(a.cell.x, a.cell.y - size.y)
	var b := RoomDef.new()
	b.id = new_id
	b.area = area
	b.cell = cell
	b.size = size
	for id in rooms:
		if (rooms[id] as RoomDef).world_rect().intersects(b.world_rect()):
			return "would overlap %s" % id
	var door := _default_door(a, b, edge)
	if door.x < 0.0:
		return "no free span for a door on that edge"
	var opp: String = WorldValidator.OPPOSITE[edge]
	var oa := WorldValidator.edge_origin(a, edge)
	var ob := WorldValidator.edge_origin(b, opp)
	var before := _snap([a_id, new_id])
	a.exits.append(_exit(edge, door.x, door.y, new_id, {}))
	b.exits.append(_exit(opp, oa + door.x - ob, oa + door.y - ob, a_id, {}))
	rooms[new_id] = b
	_push(before)
	selection = {}
	return ""

## A door of DOOR px along the shared edge (a-local from and to, as a Vector2), inside both rooms' allowed range, clear of a's
## exits, with RoomLint.CLEAR px in front of it (RoomLint.exit_zone) free of a's interior solids. Side edges try from the floor upward; top and bottom
## edges from the middle outward. (-1, -1) when nothing fits.
func _default_door(a: RoomDef, b: RoomDef, edge: String) -> Vector2:
	var opp: String = WorldValidator.OPPOSITE[edge]
	var oa := WorldValidator.edge_origin(a, edge)
	var ob := WorldValidator.edge_origin(b, opp)
	var la := WorldValidator.edge_range(a, edge)
	var lb := WorldValidator.edge_range(b, opp)
	var lo := maxf(oa + la.x, ob + lb.x)
	var hi := minf(oa + la.y, ob + lb.y)
	var candidates: Array = []
	if edge == "left" or edge == "right":
		var w := hi - DOOR
		while w >= lo:
			candidates.append(w)
			w -= 20.0
	else:
		var mid := snap((lo + hi) / 2.0 - DOOR / 2.0)
		var step := 0.0
		while mid - step >= lo or mid + step + DOOR <= hi:
			if mid + step + DOOR <= hi:
				candidates.append(mid + step)
			if step > 0.0 and mid - step >= lo:
				candidates.append(mid - step)
			step += 20.0
	for w in candidates:
		var from: float = snap(w) - oa
		var to := from + DOOR
		if from < la.x or to > la.y or _overlaps(a, edge, from, to):
			continue
		if not _clear_in_front(a, edge, from, to):
			continue
		return Vector2(from, to)
	return Vector2(-1.0, -1.0)

func _clear_in_front(a: RoomDef, edge: String, from: float, to: float) -> bool:
	var zone := RoomLint.exit_zone(a.pixel_size(), {"edge": edge, "from": from, "to": to})
	for s in a.solids:
		if (s as Rect2).intersects(zone):  # any solid, ledges too: stricter than exit_blocked, which counts mass only
			return false
	return true

# --- growing a room ---

## Grows a room by whole screens on its left, right or top. The bottom is anchored (the floor stays under floor-standing content).
## Refused only when the result would overlap another room or exceed MAX_SCREENS. Growing left or top changes `cell` and shifts
## every local position of this room so world positions never move; the start shifts only when this room is the start.
func grow_room(room_id: String, side: String, screens := 1) -> String:
	if not ["left", "right", "top"].has(side):
		return "a room grows to the left, right or top: the bottom stays where the floor is"
	if screens < 1:
		return "grow by at least one screen"
	var r: RoomDef = rooms[room_id]
	var new_size := r.size
	var new_cell := r.cell
	var shift := Vector2.ZERO
	match side:
		"right":
			new_size.x += screens
		"left":
			new_size.x += screens
			new_cell.x -= screens
			shift.x = screens * RoomDef.SCREEN.x
		"top":
			new_size.y += screens
			new_cell.y -= screens
			shift.y = screens * RoomDef.SCREEN.y
	if new_size.x > MAX_SCREENS or new_size.y > MAX_SCREENS:
		return "a room is at most %d screens each way" % MAX_SCREENS
	var rect := Rect2(Vector2(new_cell) * RoomDef.SCREEN, Vector2(new_size) * RoomDef.SCREEN)
	for id in rooms:
		if id != room_id and (rooms[id] as RoomDef).world_rect().intersects(rect):
			return "would overlap %s" % id
	var before := _snap([room_id])
	r.size = new_size
	r.cell = new_cell
	if shift != Vector2.ZERO:
		_shift_content(r, shift)
	_push(before)
	return ""

func _shift_content(r: RoomDef, d: Vector2) -> void:
	for i in r.solids.size():
		r.solids[i] = Rect2((r.solids[i] as Rect2).position + d, (r.solids[i] as Rect2).size)
	for i in r.hard_ledges.size():
		r.hard_ledges[i] = Rect2((r.hard_ledges[i] as Rect2).position + d, (r.hard_ledges[i] as Rect2).size)
	for list in [r.spawns, r.features, r.decor, r.dressing]:
		for e in list:
			e["pos"] = (e["pos"] as Vector2) + d
	if r.is_start():
		r.start += d
	for e in r.exits:
		var along_x: bool = e["edge"] == "top" or e["edge"] == "bottom"
		var amount := d.x if along_x else d.y
		e["from"] = float(e["from"]) + amount
		e["to"] = float(e["to"]) + amount

# --- save ---

## Writes each dirty room to `<dir>/<id>.tres` with ResourceSaver (the call the generator used). Rooms save independently: a
## failure leaves that room dirty and the others written. A room this session created, saved and then undid has its file
## removed (never a room that was on disk when the editor opened). Returns {"saved": [ids], "errors": {id: message},
## "removed": [ids]}.
func save_dirty(dir: String) -> Dictionary:
	var saved: Array = []
	var removed: Array = []
	var errors := {}
	var dir_ok := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir))
	for id in dirty.keys():
		if not rooms.has(id):
			dirty.erase(id)
			continue
		if not dir_ok:
			errors[id] = "no such directory: %s" % dir
			continue
		var err := ResourceSaver.save(rooms[id], "%s/%s.tres" % [dir, id])
		if err == OK:
			saved.append(id)
			dirty.erase(id)
			_baseline[id] = copy_room(rooms[id])
			_written[id] = true
		else:
			errors[id] = error_string(err)
	for id in _removed_on_save.keys():
		if _source_ids.has(id) or rooms.has(id):
			_removed_on_save.erase(id)
			continue
		var path := ProjectSettings.globalize_path("%s/%s.tres" % [dir, id])
		if dir_ok and FileAccess.file_exists(path):
			if DirAccess.remove_absolute(path) != OK:
				errors[id] = "could not remove %s" % path
				continue
			if FileAccess.file_exists(path + ".uid"):
				DirAccess.remove_absolute(path + ".uid")
			removed.append(id)
		_removed_on_save.erase(id)
		_written.erase(id)
		_baseline.erase(id)
	return {"saved": saved, "errors": errors, "removed": removed}
