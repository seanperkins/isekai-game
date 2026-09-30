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

# --- solids (the rest of the edits arrive in the next tasks) ---

## A drag's rect: both corners snapped, normalised.
static func drag_rect(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(Vector2(snap(a.x), snap(a.y)), Vector2.ZERO).expand(Vector2(snap(b.x), snap(b.y)))

func _sel(room_id: String, kind: String, index: int) -> Dictionary:
	return {"room": room_id, "kind": kind, "index": index}

func select(sel: Dictionary) -> void:
	selection = sel

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
