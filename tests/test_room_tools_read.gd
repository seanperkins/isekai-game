extends GutTest
## The room MCP's read tools, over the shipped rooms. Nothing here edits.

var session: RoomSession
var tools: RoomTools

func before_all() -> void:
	session = RoomSession.new()
	tools = RoomTools.new(session)

func _call(tool_name: String, args := {}) -> Dictionary:
	return tools.call_tool(tool_name, args)

func _data(result: Dictionary) -> Variant:
	assert_false(result["isError"], str(result))
	return JSON.parse_string(result["content"][0]["text"])

func _error(result: Dictionary) -> String:
	assert_true(result["isError"], "expected an error: %s" % str(result))
	return result["content"][0]["text"]

func test_the_tools_are_listed_with_schemas() -> void:
	var names: Array = tools.tool_list().map(func(t: Dictionary) -> String: return t["name"])
	for n in ["list_rooms", "get_room", "catalog", "problems", "world_size", "state"]:
		assert_true(names.has(n), n)
	for t: Dictionary in tools.tool_list():
		assert_eq(t["inputSchema"]["type"], "object", t["name"])
		assert_true(t["description"] != "", t["name"])

func test_list_rooms() -> void:
	var all: Array = _data(_call("list_rooms"))["rooms"]
	assert_eq(all.size(), 23)
	var c1: Dictionary = all.filter(func(r: Dictionary) -> bool: return r["id"] == "C1")[0]
	var def: RoomDef = session.model.rooms["C1"]
	assert_eq(c1["area"], "cave")
	assert_eq(int(c1["counts"]["solids"]), def.solids.size())
	assert_eq(int(c1["counts"]["exits"]), def.exits.size())
	assert_eq(c1["dirty"], false)
	assert_eq(_data(_call("list_rooms", {"area": "cave"}))["rooms"].size(), 6)

func test_get_room() -> void:
	var spec: Dictionary = _data(_call("get_room", {"room": "C1"}))["spec"]
	assert_eq(spec["id"], "C1")
	assert_eq(int(spec["solids"][0]["index"]), 0)
	assert_true(spec["exits"].size() > 0)
	assert_true(spec["exits"][0].has("partner"))
	assert_eq(_error(_call("get_room", {"room": "Z9"})), "no room 'Z9'")

func test_catalog() -> void:
	var all: Dictionary = _data(_call("catalog"))
	assert_eq(all["features"], ["glow_pool", "tablet", "switch", "altar"])
	assert_eq(all["gates"], ["wall_cling", "swim"])
	assert_eq(int(all["limits"]["grid"]), 4)
	assert_eq(int(all["limits"]["max_screens"]), 6)
	assert_eq(int(all["prefabs"]["library"]["mound"]["width"]), 160)
	assert_true(all["decor"]["cave"].size() > 0)
	assert_eq(all["creatures"], session.model.creature_ids)
	assert_eq(all["areas"], TerrainArt.biomes())
	assert_true(all["perks"].size() > 0)
	assert_eq(_data(_call("catalog", {"section": "gates"})), ["wall_cling", "swim"])

func test_problems() -> void:
	var all: Dictionary = _data(_call("problems"))
	assert_eq(int(all["count"]), session.model.problems().size())
	assert_eq(all["items"].size(), int(all["count"]))
	var one: Dictionary = _data(_call("problems", {"room": "C1"}))
	for item: Dictionary in one["items"]:
		assert_eq(item["room"], "C1")
	assert_eq(_error(_call("problems", {"room": "Z9"})), "no room 'Z9'")

func test_world_size() -> void:
	var d: Dictionary = _data(_call("world_size"))
	assert_eq(int(d["measure"]["rooms"]), 23)
	assert_eq(int(d["measure"]["screens"]), 45)
	assert_eq(d["yardsticks"].size(), 3)
	assert_true(d["areas"].size() > 0)

func test_state() -> void:
	assert_eq(_data(_call("state"))["rooms"], 23.0)

func test_bad_arguments_are_refused_and_change_nothing() -> void:
	assert_eq(_error(_call("get_room", {})), "room: required")
	assert_eq(_error(_call("get_room", {"room": 5})), "room: expected a string")
	assert_eq(_error(_call("get_room", {"room": "C1", "rooom": "C1"})), "rooom: unknown argument")
	assert_eq(_error(_call("catalog", {"section": "nope"})), "section: expected one of creatures, features, decor, prefabs, perks, gates, areas, limits")
	assert_true(_error(_call("nope")).contains("unknown tool"))
	assert_eq(session.model.dirty.size(), 0)

func test_check_args_covers_the_schema_subset() -> void:
	var schema := {"type": "object", "properties": {
		"pos": {"type": "array", "items": {"type": "number"}, "minItems": 2, "maxItems": 2},
		"n": {"type": "integer", "minimum": 1, "maximum": 6},
		"ref": {"type": "object", "properties": {"index": {"type": "integer", "minimum": 0}}, "required": ["index"]},
		"on": {"type": "boolean"},
	}, "required": ["pos"]}
	assert_eq(RoomTools.check_args(schema, {"pos": [1, 2]}), "")
	assert_eq(RoomTools.check_args(schema, {"pos": [1]}), "pos: expected an array of 2 numbers")
	assert_eq(RoomTools.check_args(schema, {"pos": "5,5"}), "pos: expected an array of 2 numbers")
	assert_eq(RoomTools.check_args(schema, {"pos": [1, "a"]}), "pos: expected an array of 2 numbers")
	assert_eq(RoomTools.check_args(schema, {"pos": [1, 2], "n": 7}), "n: expected at most 6")
	assert_eq(RoomTools.check_args(schema, {"pos": [1, 2], "n": 2.5}), "n: expected an integer")
	assert_eq(RoomTools.check_args(schema, {"pos": [1, 2], "n": 3.0}), "")
	assert_eq(RoomTools.check_args(schema, {"pos": [1, 2], "ref": {}}), "ref.index: required")
	assert_eq(RoomTools.check_args(schema, {"pos": [1, 2], "ref": {"index": -1}}), "ref.index: expected at least 0")
	assert_eq(RoomTools.check_args(schema, {"pos": [1, 2], "on": "yes"}), "on: expected true or false")
