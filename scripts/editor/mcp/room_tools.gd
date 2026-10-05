class_name RoomTools
extends RefCounted
## The room MCP's tools: a table of name, description, JSON schema and handler over one RoomSession. McpProtocol calls tool_list() and
## call_tool(); a tool that fails returns a normal MCP result with isError set and the reason as text, so the agent reads the same
## message an editor user would. Arguments are checked against the tool's schema before its handler runs, and an argument the schema
## does not name is refused (a typo such as `rooom` must not silently mean "everything").

const CATALOG_SECTIONS := ["creatures", "features", "decor", "prefabs", "perks", "gates", "areas", "limits"]

var _session: RoomSession
var _table := {}  # name -> {description, schema, handler}

func _init(p_session: RoomSession = null) -> void:
	_session = p_session
	_register_read()
	_register_add()

func tool_list() -> Array:
	var out: Array = []
	for name in _table:
		out.append({"name": name, "description": _table[name]["description"], "inputSchema": _table[name]["schema"]})
	return out

func call_tool(name: String, args: Dictionary) -> Dictionary:
	if not _table.has(name):
		return fail("unknown tool '%s'" % name)
	var err := check_args(_table[name]["schema"], args)
	if err != "":
		return fail(err)
	return _table[name]["handler"].call(args)

func _add(name: String, description: String, schema: Dictionary, handler: Callable) -> void:
	_table[name] = {"description": description, "schema": schema, "handler": handler}

static func result(content: Array, is_error := false) -> Dictionary:
	return {"content": content, "isError": is_error}

## A successful result: `data` as one JSON text item.
static func ok(data: Variant) -> Dictionary:
	return result([{"type": "text", "text": JSON.stringify(data)}])

static func fail(message: String) -> Dictionary:
	return result([{"type": "text", "text": message}], true)

# --- schemas ---

## An object schema: `properties` is name -> schema, `required` the names that must be present.
static func obj(properties := {}, required: Array = []) -> Dictionary:
	return {"type": "object", "properties": properties, "required": required, "additionalProperties": false}

static func vec2(description := "") -> Dictionary:
	return {"type": "array", "items": {"type": "number"}, "minItems": 2, "maxItems": 2, "description": description}

## "" when `args` fits `schema`, else the first reason, prefixed with the argument's path (`ref.index: required`). Understands type
## (object, array, string, number, integer, boolean), properties, required, enum, items, minItems, maxItems, minimum and maximum, and
## refuses any property an object schema does not list.
static func check_args(schema: Dictionary, args: Dictionary) -> String:
	return _check_object("", schema, args)

static func _check_object(path: String, schema: Dictionary, v: Dictionary) -> String:
	var props: Dictionary = schema.get("properties", {})
	for key: String in schema.get("required", []):
		if not v.has(key):
			return "%s: required" % _join(path, key)
	for key: String in v:
		if not props.has(key):
			return "%s: unknown argument" % _join(path, key)
		var err := _check_value(_join(path, key), props[key], v[key])
		if err != "":
			return err
	return ""

static func _join(path: String, key: String) -> String:
	return key if path == "" else "%s.%s" % [path, key]

static func _check_value(path: String, schema: Dictionary, v) -> String:
	if schema.has("enum") and not (schema["enum"] as Array).has(v):
		return "%s: expected one of %s" % [path, ", ".join((schema["enum"] as Array).map(func(x): return str(x)))]
	match schema.get("type", ""):
		"string":
			if not v is String:
				return "%s: expected a string" % path
		"boolean":
			if not v is bool:
				return "%s: expected true or false" % path
		"number", "integer":
			if not (v is float or v is int) or not is_finite(float(v)):
				return "%s: expected a number" % path
			if schema["type"] == "integer" and float(v) != floorf(float(v)):
				return "%s: expected an integer" % path
			if schema.has("minimum") and float(v) < float(schema["minimum"]):
				return "%s: expected at least %s" % [path, str(schema["minimum"])]
			if schema.has("maximum") and float(v) > float(schema["maximum"]):
				return "%s: expected at most %s" % [path, str(schema["maximum"])]
		"array":
			var min_n: int = schema.get("minItems", 0)
			var max_n: int = schema.get("maxItems", 1 << 30)
			var item_type: String = schema.get("items", {}).get("type", "")
			var shape := "an array"
			if min_n == max_n and item_type != "":
				shape = "an array of %d %ss" % [min_n, item_type]
			if not v is Array or v.size() < min_n or v.size() > max_n:
				return "%s: expected %s" % [path, shape]
			for i in v.size():
				var err := _check_value("%s[%d]" % [path, i], schema.get("items", {}), v[i])
				if err != "":
					return shape_error(path, shape, err, item_type)
		"object":
			if not v is Dictionary:
				return "%s: expected an object" % path
			return _check_object(path, schema, v)
	return ""

## An element of a fixed-size array that is the wrong type is reported as the array being the wrong shape ("pos: expected an array of
## 2 numbers"); a range error ("size[0]: expected at least 1") keeps its own path.
static func shape_error(path: String, shape: String, err: String, item_type: String) -> String:
	var range_error := err.contains(": expected at ") or err.contains(": expected one of")
	if item_type in ["number", "integer", "string", "boolean"] and err.begins_with("%s[" % path) and not range_error:
		return "%s: expected %s" % [path, shape]
	return err

# --- the read tools ---

func _register_read() -> void:
	_add("list_rooms", "List the rooms: id, area, grid cell, size in screens, element counts and whether each has unsaved edits.",
		obj({"area": {"type": "string", "description": "Only rooms of this area."}}), _list_rooms)
	_add("get_room", "One room as a spec: solids, water, spawns, features, decor and exits, each with its index (the index in a ref). "
		+ "Each exit also names its partner exit in the room across.",
		obj({"room": {"type": "string"}}, ["room"]), _get_room)
	_add("catalog", "What can be placed: creatures, feature kinds, decor ids per biome, prefabs, perks, gates, areas and the editor's limits.",
		obj({"section": {"type": "string", "enum": CATALOG_SECTIONS}}), _catalog)
	_add("problems", "Everything the room linter and the world validator object to, as the editor's Problems panel shows it.",
		obj({"room": {"type": "string", "description": "Only problems in this room."}}), _problems)
	_add("world_size", "How big the world is: rooms and screens, the three Super Metroid yardsticks and rooms per area against the budget. Informational.",
		obj(), _world_size)
	_add("state", "The working set: room count, rooms with unsaved edits, undo and redo depth, and rooms whose file changed on disk.",
		obj(), func(_a: Dictionary) -> Dictionary: return ok(_session.state()))

func _room(id: String) -> RoomDef:
	return _session.model.rooms.get(id)

func _no_room(id: String) -> Dictionary:
	return fail("no room '%s'" % id)

func _list_rooms(args: Dictionary) -> Dictionary:
	var ids := _session.model.rooms.keys()
	ids.sort()
	var out: Array = []
	for id: String in ids:
		var r := _room(id)
		if args.has("area") and r.area != args["area"]:
			continue
		out.append({
			"id": id, "area": r.area, "cell": [r.cell.x, r.cell.y], "size": [r.size.x, r.size.y],
			"counts": {"solids": r.solids.size(), "water": r.water.size(), "spawns": r.spawns.size(), "features": r.features.size(),
				"decor": r.decor.size(), "exits": r.exits.size()},
			"dirty": _session.model.dirty.has(id),
		})
	return ok({"rooms": out})

func _get_room(args: Dictionary) -> Dictionary:
	var r := _room(args["room"])
	if r == null:
		return _no_room(args["room"])
	var spec := RoomSpec.to_json(r, true)
	for i in r.exits.size():
		spec["exits"][i]["partner"] = _session.model.partner_of(r.id, i)
	return ok({"spec": spec})

func _catalog(args: Dictionary) -> Dictionary:
	var decor := {}
	for biome: String in TerrainArt.biomes():
		decor[biome] = DecorLib.ids_for_biome(biome)
	var prefabs := {}
	for id: String in Prefabs.library():
		var p: Dictionary = Prefabs.library()[id]
		prefabs[id] = {"width": p["width"], "ceiling": p.get("ceiling", false), "walkable": p.get("walkable", false)}
	var all := {
		"creatures": _session.model.creature_ids,
		"features": RoomEditModel.FEATURE_KINDS,
		"decor": decor,
		"prefabs": {"library": prefabs, "sets": Prefabs.SETS},
		"perks": DefLoader.load_dir("res://data/perks", "PerkDef").map(func(p: PerkDef) -> String: return p.id),
		"gates": WorldValidator.GATES,
		"areas": TerrainArt.biomes(),
		"limits": {
			"screen": RoomSpec.plain(RoomDef.SCREEN), "wall": RoomDef.WALL, "floor": RoomDef.FLOOR, "grid": RoomEditModel.GRID,
			"door": RoomEditModel.DOOR, "max_screens": RoomEditModel.MAX_SCREENS, "min_solid": RoomEditModel.MIN_SOLID,
			"min_water": RoomEditModel.MIN_WATER, "min_exit": RoomLint.MIN_EXIT,
		},
	}
	return ok(all[args["section"]] if args.has("section") else all)

func _problems(args: Dictionary) -> Dictionary:
	if args.has("room") and _room(args["room"]) == null:
		return _no_room(args["room"])
	var items: Array = []
	for p: Dictionary in _session.model.problems():
		if not args.has("room") or p["room"] == args["room"]:
			items.append(RoomSpec.plain(p))
	return ok({"count": items.size(), "items": items})

func _world_size(_args: Dictionary) -> Dictionary:
	var m := WorldSize.measure(_session.model.rooms)
	return ok({"measure": RoomSpec.plain(m), "yardsticks": WorldSize.yardsticks(m), "areas": WorldSize.area_rows(m)})

# --- the add tools ---
# Each is a thin wrapper over one RoomEditModel call and returns the model's own refusal text. No schema here lists the valid edges,
# sides, kinds or ids as an enum: the model's message ("not an edge", "unknown creature 'x'") says what is wrong, and catalog lists them.

func _register_add() -> void:
	var room := {"type": "string", "description": "Room id."}
	var corners := {"room": room, "a": vec2("One corner, room-local px."), "b": vec2("The opposite corner; both snap to the 4 px grid.")}
	_add("new_room", "Create a room beside an existing one, level with it, joined by a paired door. Area must have terrain art (see catalog areas).",
		obj({"beside": {"type": "string", "description": "The existing room."}, "edge": {"type": "string", "description": "left, right, top or bottom of `beside`."},
			"id": {"type": "string", "description": "Letters, digits and underscore."}, "area": {"type": "string"},
			"size": {"type": "array", "items": {"type": "integer", "minimum": 1, "maximum": RoomEditModel.MAX_SCREENS},
				"minItems": 2, "maxItems": 2, "description": "[width, height] in screens, 1 to 6."}},
			["beside", "edge", "id", "area", "size"]), _new_room)
	_add("grow_room", "Grow a room by whole screens on its left, right or top (the bottom stays where the floor is).",
		obj({"room": room, "side": {"type": "string", "description": "left, right or top."}, "screens": {"type": "integer", "minimum": 1}}, ["room", "side"]),
		_grow_room)
	_add("add_solid", "Add a solid (rock, or a one-way ledge when thin) from two corners. Returns its ref.", obj(corners, ["room", "a", "b"]),
		func(a: Dictionary) -> Dictionary: return _added(a["room"], func() -> String: return _session.model.add_solid(a["room"], _v(a["a"]), _v(a["b"]))))
	_add("add_water", "Add deep water from two corners (at least 32 px each way, inside the room, not touching other water). Returns its ref.",
		obj(corners, ["room", "a", "b"]),
		func(a: Dictionary) -> Dictionary: return _added(a["room"], func() -> String: return _session.model.add_water(a["room"], _v(a["a"]), _v(a["b"]))))
	_add("add_spawn", "Add a creature spawn in open space. Returns its ref.",
		obj({"room": room, "creature": {"type": "string", "description": "A creature id (see catalog creatures)."}, "pos": vec2()}, ["room", "creature", "pos"]),
		func(a: Dictionary) -> Dictionary: return _added(a["room"], func() -> String: return _session.model.add_spawn(a["room"], a["creature"], _v(a["pos"]))))
	_add("add_feature", "Add a feature (glow_pool, tablet, switch or altar) standing on the surface below `pos`. Returns its ref.",
		obj({"room": room, "kind": {"type": "string", "description": "glow_pool, tablet, switch or altar."}, "pos": vec2()}, ["room", "kind", "pos"]),
		func(a: Dictionary) -> Dictionary: return _added(a["room"], func() -> String: return _session.model.add_feature(a["room"], a["kind"], _v(a["pos"]))))
	_add("add_decor", "Add a decor piece standing on (or hanging from) the surface at `pos`. Returns its ref.",
		obj({"room": room, "piece": {"type": "string", "description": "A decor id (see catalog decor)."}, "pos": vec2()}, ["room", "piece", "pos"]),
		func(a: Dictionary) -> Dictionary: return _added(a["room"], func() -> String: return _session.model.add_decor(a["room"], a["piece"], _v(a["pos"]))))
	_add("add_exit", "Add an exit on an edge of a room over [from, to] (px along the edge) and its partner in the room across, in one step. Returns the ref of this half.",
		obj({"room": room, "edge": {"type": "string", "description": "left, right, top or bottom."}, "from": {"type": "number"}, "to": {"type": "number"},
			"gate": {"type": "string", "enum": WorldValidator.GATES, "description": "Optional: the movement needed to pass."},
			"shortcut": {"type": "string", "description": "Optional: a shortcut id (the exit is closed until a switch opens it)."}},
			["room", "edge", "from", "to"]), _add_exit)

func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

## Runs `edit` (a model call that returns "" or a refusal) on an existing room and answers with the new element's ref, read from the
## model's selection, which every successful add leaves on the element it made.
func _added(room_id: String, edit: Callable) -> Dictionary:
	if _room(room_id) == null:
		return _no_room(room_id)
	var err: String = edit.call()
	if err != "":
		return fail(err)
	var sel: Dictionary = _session.model.selection
	return ok({"ok": true, "ref": {"room": sel["room"], "kind": sel["kind"], "index": sel["index"]}})

func _new_room(args: Dictionary) -> Dictionary:
	if _room(args["beside"]) == null:
		return _no_room(args["beside"])
	var size: Array = args["size"]
	var err := _session.model.new_room_beside(args["beside"], args["edge"], args["id"], args["area"], Vector2i(int(size[0]), int(size[1])))
	return fail(err) if err != "" else ok({"ok": true, "room": args["id"]})

func _grow_room(args: Dictionary) -> Dictionary:
	if _room(args["room"]) == null:
		return _no_room(args["room"])
	var err := _session.model.grow_room(args["room"], args["side"], int(args.get("screens", 1)))
	if err != "":
		return fail(err)
	var r := _room(args["room"])
	return ok({"ok": true, "room": r.id, "cell": [r.cell.x, r.cell.y], "size": [r.size.x, r.size.y]})

func _add_exit(args: Dictionary) -> Dictionary:
	var opts := {}
	if args.has("gate"):
		opts["gate"] = args["gate"]
	if args.has("shortcut"):
		if args["shortcut"] != "" and not RoomEditModel.valid_id(args["shortcut"]):
			return fail("a shortcut id is letters, digits and underscore")
		opts["shortcut"] = args["shortcut"]
	return _added(args["room"], func() -> String:
		return _session.model.add_exit(args["room"], args["edge"], float(args["from"]), float(args["to"]), opts))
