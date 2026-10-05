class_name RoomSpec
extends RefCounted
## A room as the JSON an agent reads and writes (the "Room spec" section of the room MCP design), and back. This only converts and
## checks the shape of what it is given; the editor model's rules (grid, sizes, rock, surfaces) are applied when the content is
## applied to a room.
##
## Vectors and rects are arrays of numbers, a colour is [r, g, b, a], a spawn's `creature` is the stored `id` and a decor entry's
## `piece` is its `id`. Every other key of a feature or decor entry passes through under its own name.

## No coordinate or size in a spec is beyond this (a room is at most 6 x 640 by 6 x 360 px): it keeps NaN-like and runaway numbers out.
const LIMIT := 1000000.0

## The spec of room `r`: id, area, cell, size, start (null when there is none) and the six lists. With `indexed`, every element also
## carries `index`, its position in the room's array, which an edit tool's `ref` uses.
static func to_json(r: RoomDef, indexed := false) -> Dictionary:
	var out := {
		"id": r.id, "area": r.area, "cell": [r.cell.x, r.cell.y], "size": [r.size.x, r.size.y],
		"start": [r.start.x, r.start.y] if r.is_start() else null,
		"solids": [], "water": [], "spawns": [], "features": [], "decor": [], "exits": [],
	}
	for i in r.solids.size():
		out["solids"].append(_tag({"rect": plain(r.solids[i]), "hard": r.hard_ledges.has(r.solids[i])}, i, indexed))
	for i in r.water.size():
		out["water"].append(_tag({"rect": plain(r.water[i])}, i, indexed))
	for i in r.spawns.size():
		out["spawns"].append(_tag({"creature": r.spawns[i]["id"], "pos": plain(r.spawns[i]["pos"])}, i, indexed))
	for i in r.features.size():
		out["features"].append(_tag(plain(r.features[i]), i, indexed))
	for i in r.decor.size():
		var d: Dictionary = plain(r.decor[i])
		d["piece"] = d["id"]
		d.erase("id")
		out["decor"].append(_tag(d, i, indexed))
	for i in r.exits.size():
		out["exits"].append(_tag(plain(r.exits[i]), i, indexed))
	return out

## The content of room `r` in the runtime types content_from_json produces and the model applies:
## {solids: [{rect: Rect2, hard: bool}], water: [Rect2], spawns: [{id, pos: Vector2}], features: [Dictionary], decor: [Dictionary]}.
static func content_of(r: RoomDef) -> Dictionary:
	var solids: Array = []
	for s: Rect2 in r.solids:
		solids.append({"rect": s, "hard": r.hard_ledges.has(s)})
	return {
		"solids": solids, "water": r.water.duplicate(), "spawns": r.spawns.duplicate(true),
		"features": r.features.duplicate(true), "decor": r.decor.duplicate(true),
	}

## {content, errors} from a spec. `content` has the shape content_of returns, holding every element that was well formed (a key the
## spec leaves out is an empty list); `errors` is [{kind, index, error}] for each element that was not (index -1: the whole list).
static func content_from_json(spec: Dictionary) -> Dictionary:
	var content := {"solids": [], "water": [], "spawns": [], "features": [], "decor": []}
	var errors: Array = []
	for section in [["solids", "solid"], ["water", "water"], ["spawns", "spawn"], ["features", "feature"], ["decor", "decor"]]:
		var key: String = section[0]
		var kind: String = section[1]
		var list = spec.get(key, [])
		if not list is Array:
			errors.append({"kind": kind, "index": -1, "error": "%s: expected a list" % key})
			continue
		for i in list.size():
			var parsed = _element(kind, list[i])
			if parsed is String:
				errors.append({"kind": kind, "index": i, "error": parsed})
			else:
				content[key].append(parsed)
	return {"content": content, "errors": errors}

## One element in runtime types, or the reason it is malformed (a String).
static func _element(kind: String, e) -> Variant:
	if not e is Dictionary:
		return "expected an object"
	match kind:
		"solid", "water":
			var rect = _nums(e.get("rect"), 4)
			if rect == null:
				return "rect: expected 4 finite numbers within +-%d" % int(LIMIT)
			var box := Rect2(rect[0], rect[1], rect[2], rect[3])
			if kind == "water":
				return box
			var hard = e.get("hard", false)
			return {"rect": box, "hard": hard} if hard is bool else "hard: expected true or false"
		"spawn":
			if not e.get("creature") is String or e["creature"] == "":
				return "creature: expected a creature id"
			var p = _nums(e.get("pos"), 2)
			return {"id": e["creature"], "pos": Vector2(p[0], p[1])} if p != null else "pos: expected an array of 2 numbers"
		"feature", "decor":
			var out: Dictionary = e.duplicate(true)
			out.erase("index")  # get_room's own metadata (an element's position in its list), never part of the room
			var p = _nums(e.get("pos"), 2)
			if p == null:
				return "pos: expected an array of 2 numbers"
			out["pos"] = Vector2(p[0], p[1])
			if kind == "feature":
				return out if e.get("kind") is String else "kind: expected a feature kind"
			if not e.get("piece") is String or e["piece"] == "":
				return "piece: expected a decor id"
			out["id"] = e["piece"]
			out.erase("piece")
			if out.has("light"):
				var c = _nums(out["light"], 4)
				if c == null:
					return "light: expected [r, g, b, a]"
				out["light"] = Color(c[0], c[1], c[2], c[3])
			return out
	return "unknown element kind"

## `v` as an array of exactly `n` floats, or null when it is not one: not an array, the wrong length, a non-number, a non-finite or
## runaway value.
static func _nums(v, n: int) -> Variant:
	if not v is Array or v.size() != n:
		return null
	var out: Array = []
	for x in v:
		if not (x is float or x is int) or not is_finite(float(x)) or absf(float(x)) > LIMIT:
			return null
		out.append(float(x))
	return out

## Runtime value to plain JSON types: Vector2, Rect2 and Color become number arrays, containers are converted inside.
static func plain(v) -> Variant:
	match typeof(v):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_RECT2:
			return [v.position.x, v.position.y, v.size.x, v.size.y]
		TYPE_COLOR:
			return [v.r, v.g, v.b, v.a]
		TYPE_ARRAY:
			return v.map(func(x): return plain(x))
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = plain(v[k])
			return out
	return v

static func _tag(e: Dictionary, i: int, indexed: bool) -> Dictionary:
	if indexed:
		e["index"] = i
	return e
