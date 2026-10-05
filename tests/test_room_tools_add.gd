extends GutTest
## The room MCP's add tools: each wraps one RoomEditModel call, so every refusal is the model's own text. Edits stay in memory.

var session: RoomSession
var tools: RoomTools

func before_each() -> void:
	session = RoomSession.new()
	tools = RoomTools.new(session)

func _call(tool_name: String, args: Dictionary) -> Dictionary:
	return tools.call_tool(tool_name, args)

func _data(result: Dictionary) -> Dictionary:
	assert_false(result["isError"], str(result))
	return JSON.parse_string(result["content"][0]["text"])

func _error(result: Dictionary) -> String:
	assert_true(result["isError"], "expected an error: %s" % str(result))
	return result["content"][0]["text"]

func _fresh() -> void:
	_data(_call("new_room", {"beside": "C6", "edge": "left", "id": "Fresh", "area": "cave", "size": [2, 2]}))

func test_add_solid_succeeds() -> void:
	var before: int = (session.model.rooms["C1"] as RoomDef).solids.size()
	var d := _data(_call("add_solid", {"room": "C1", "a": [100, 100], "b": [200, 116]}))
	assert_eq(d["ref"]["kind"], "solid")
	assert_eq(int(d["ref"]["index"]), before)
	assert_true(session.model.dirty.has("C1"))

func test_each_add_tool_succeeds_on_a_fresh_room() -> void:
	_fresh()
	var r: RoomDef = session.model.rooms["Fresh"]
	assert_eq(r.area, "cave")
	assert_true(session.model.dirty.has("Fresh") and session.model.dirty.has("C6"))
	var cases := [
		["add_solid", {"room": "Fresh", "a": [100, 200], "b": [200, 216]}, "solid"],
		["add_water", {"room": "Fresh", "a": [400, 200], "b": [500, 300]}, "water"],
		["add_spawn", {"room": "Fresh", "creature": session.model.creature_ids[0], "pos": [300, 150]}, "spawn"],
		["add_feature", {"room": "Fresh", "kind": "glow_pool", "pos": [300, 300]}, "feature"],
		["add_decor", {"room": "Fresh", "piece": "rubble", "pos": [250, 300]}, "decor"],
	]
	for c in cases:
		var d := _data(_call(c[0], c[1]))
		assert_eq(d["ref"], {"room": "Fresh", "kind": c[2], "index": 0.0}, c[0])
	assert_eq([r.solids.size(), r.water.size(), r.spawns.size(), r.features.size(), r.decor.size()], [1, 1, 1, 1, 1])

func test_refusals_carry_the_models_own_text() -> void:
	assert_eq(_error(_call("add_solid", {"room": "C1", "a": [100, 100], "b": [101, 116]})), "too small, or outside the room")
	assert_eq(_error(_call("add_water", {"room": "C1", "a": [100, 100], "b": [108, 108]})), "too small: water is at least 32 px each way")
	assert_eq(_error(_call("add_spawn", {"room": "C1", "creature": "nope", "pos": [300, 100]})), "unknown creature 'nope'")
	assert_eq(_error(_call("add_feature", {"room": "C1", "kind": "banner", "pos": [300, 100]})), "unknown feature 'banner'")
	assert_eq(_error(_call("add_decor", {"room": "C1", "piece": "zzz", "pos": [300, 100]})), "unknown decor 'zzz'")
	assert_eq(_error(_call("add_exit", {"room": "C1", "edge": "up", "from": 100, "to": 180})), "not an edge")
	assert_eq(_error(_call("grow_room", {"room": "C1", "side": "bottom"})), "a room grows to the left, right or top: the bottom stays where the floor is")
	assert_eq(_error(_call("new_room", {"beside": "C6", "edge": "left", "id": "X1", "area": "nowhere", "size": [1, 1]})), "unknown area 'nowhere'")
	assert_eq(_error(_call("add_solid", {"room": "Z9", "a": [0, 0], "b": [8, 8]})), "no room 'Z9'")
	assert_eq(_error(_call("new_room", {"beside": "Z9", "edge": "left", "id": "X1", "area": "cave", "size": [1, 1]})), "no room 'Z9'")
	assert_eq(session.model.dirty.size(), 0, "a refusal changes nothing")

func test_new_room_beside_a_free_edge_creates_a_paired_room() -> void:
	_fresh()
	assert_true(session.model.rooms.has("Fresh"))
	assert_eq(session.model.rooms["Fresh"].exits.size(), 1)
	assert_eq(session.model.undo_depth(), 1)

func test_grow_room_reports_the_new_size() -> void:
	_fresh()
	var d := _data(_call("grow_room", {"room": "Fresh", "side": "top", "screens": 1}))
	assert_eq(d["size"], [2.0, 3.0])
	assert_eq(session.model.rooms["Fresh"].size, Vector2i(2, 3))

func test_add_exit_creates_the_partner() -> void:
	var m := session.model
	var ea: Dictionary = m.rooms["C1"].exits.filter(func(e: Dictionary) -> bool: return e["room"] == "C2")[0]
	var eb: Dictionary = m.rooms["C2"].exits.filter(func(e: Dictionary) -> bool: return e["room"] == "C1")[0]
	m.rooms["C1"].exits.erase(ea)
	m.rooms["C2"].exits.erase(eb)
	var d := _data(_call("add_exit", {"room": "C1", "edge": ea["edge"], "from": ea["from"], "to": ea["to"]}))
	assert_eq(d["ref"]["kind"], "exit")
	assert_false(m.partner_of("C1", int(d["ref"]["index"])).is_empty())

func test_an_exit_shortcut_must_be_an_id() -> void:
	assert_eq(_error(_call("add_exit", {"room": "C1", "edge": "right", "from": 100, "to": 180, "shortcut": "a b"})),
		"a shortcut id is letters, digits and underscore")

func test_wrong_typed_arguments_change_nothing() -> void:
	assert_eq(_error(_call("add_solid", {"room": "C1", "a": [1], "b": [8, 8]})), "a: expected an array of 2 numbers")
	assert_eq(_error(_call("add_spawn", {"room": "C1", "creature": "toad", "pos": "5,5"})), "pos: expected an array of 2 numbers")
	assert_eq(_error(_call("new_room", {"beside": "C6", "edge": "left", "id": "X1", "area": "cave", "size": [0, 1]})), "size[0]: expected at least 1")
	assert_eq(_error(_call("add_solid", {"room": "C1", "a": [0, 0]})), "b: required")
	assert_eq(session.model.dirty.size(), 0)
	assert_eq(session.model.undo_depth(), 0)
