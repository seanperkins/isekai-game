class_name RoomEditModel
extends RefCounted
## The room editor's data: working copies of the rooms, the selection, every edit (each one undo step), the dirty set and the
## save. Pure data, no nodes. It is the one place that knows the shape of a RoomDef's arrays.

const GRID := 4.0
const MIN_EXIT := 36.0
const UNDO_CAP := 200
## Depth of the rock-free strip kept in front of a new room's default door, in the neighbour.
const KEEP_CLEAR := 64.0
const MIN_SOLID := 4.0

static var _prop_names: Array = []

var rooms := {}     # id -> RoomDef (working copies)
var dirty := {}     # id -> true: rooms edited since the last successful save
var creature_ids: Array = []
## {} or {"room", "kind": "solid" | "spawn" | "exit", "index"}
var selection := {}
var _undo: Array = []   # each: {id: RoomDef or null}, the state before a step
var _redo: Array = []
var _drag := {}         # a move in progress

func _init(source: Dictionary, p_creature_ids: Array = []) -> void:
	creature_ids = p_creature_ids
	for id in source:
		rooms[id] = copy_room(source[id])

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
			dirty[id] = true
	if not changed:
		return
	_undo.append(before)
	if _undo.size() > UNDO_CAP:
		_undo.pop_front()
	_redo.clear()

## Puts `snap` back and returns the state it replaced (the other stack's step).
func _swap(snap: Dictionary) -> Dictionary:
	var now := _snap(snap.keys())
	for id in snap:
		if snap[id] == null:
			rooms.erase(id)
			dirty.erase(id)
		else:
			rooms[id] = snap[id]
			dirty[id] = true
	selection = {}
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
	var out: Array = r.solids.duplicate()
	for w in RoomBuilder.edge_walls(r.pixel_size(), r.exits):
		out.append(w["rect"])
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

## The element under a room-local point: the nearest creature within `pick`, else an exit's gap, else the smallest solid.
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
		_:
			return _begin_move_exit(sel)
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
		_:
			_move_exit_to(d)

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
		_:
			return _delete_exit()
	selection = {}
	return ""

# --- where Play starts ---

## Where Play puts the slime for a click at `p`: the point straight down to the first rock below, a ledge included; null when
## `p` is outside the room or in rock, or nothing is below it. The returned point is the player's origin (feet on the rock).
func floor_spot(room_id: String, p: Vector2) -> Variant:
	if not bounds(rooms[room_id]).has_point(p):
		return null
	var best := INF
	for rect in rock(room_id, true):
		var q: Rect2 = rect
		if q.has_point(p):
			return null
		if p.x >= q.position.x and p.x < q.end.x and q.position.y >= p.y and q.position.y < best:
			best = q.position.y
	if best == INF:
		return null
	return Vector2(p.x, best - BodyConfig.BOTTOM)

# The exit halves of begin_move / move_to / delete are written with the exits.
func _begin_move_exit(_sel: Dictionary) -> bool:
	return false

func _move_exit_to(_d: Vector2) -> void:
	pass

func _delete_exit() -> String:
	return "nothing selected"
