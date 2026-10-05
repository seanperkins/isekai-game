extends GutTest
## The stamp_prefab tool: a prefab becomes plain solids and decor in the room, in one undo step, with decor art from the room's biome.

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

## A new 1x1 room beside C6 in `area`.
func _fresh(area := "cave") -> RoomDef:
	_data(_call("new_room", {"beside": "C6", "edge": "left", "id": "Fresh", "area": area, "size": [1, 1]}))
	return session.model.rooms["Fresh"]

func test_stamp_mound() -> void:
	var r := _fresh()
	var depth := session.model.undo_depth()
	var d := _data(_call("stamp_prefab", {"room": "Fresh", "prefab": "mound", "origin": [200, 320]}))
	assert_eq(d["bounds"], [200.0, 224.0, 160.0, 96.0])
	assert_eq(d["added"], {"solids": 3.0, "decor": 2.0})
	assert_eq(r.solids.size(), 3)
	assert_eq(r.decor.size(), 2)
	assert_eq(session.model.undo_depth(), depth + 1)
	session.model.undo()
	assert_eq((session.model.rooms["Fresh"] as RoomDef).solids.size(), 0, "one undo removes the whole stamp")

func test_flip_matches_prefabs_stamp() -> void:
	var r := _fresh()
	_data(_call("stamp_prefab", {"room": "Fresh", "prefab": "mound", "origin": [200, 320], "flip": true}))
	var reference := {}
	Prefabs.stamp(reference, "mound", Vector2(200, 320), true)
	assert_eq(r.solids, reference["solids"])

func test_a_ceiling_prefab_hangs_from_the_ceiling() -> void:
	var r := _fresh()
	var d := _data(_call("stamp_prefab", {"room": "Fresh", "prefab": "stalactites", "origin": [300, 20]}))
	assert_gt(int(d["added"]["solids"]) + int(d["added"]["decor"]), 0)
	assert_gt(r.solids.size() + r.decor.size(), 0)

func test_decor_uses_the_aliased_biome() -> void:
	var r := _fresh("forest")
	_data(_call("stamp_prefab", {"room": "Fresh", "prefab": "cap_stairs", "origin": [100, 320]}))
	assert_gt(r.decor.size(), 0)
	for d: Dictionary in r.decor:
		assert_true(d["id"].begins_with("grotto_"), d["id"])
		assert_true(DecorLib.CATALOG.has(d["id"]), d["id"])

func test_a_refused_stamp_changes_nothing() -> void:
	var r := _fresh()
	_data(_call("stamp_prefab", {"room": "Fresh", "prefab": "mound", "origin": [200, 320]}))
	var depth := session.model.undo_depth()
	var said := _error(_call("stamp_prefab", {"room": "Fresh", "prefab": "mound", "origin": [200, 320]}))
	assert_true(said.begins_with("the prefab's solid 0: an identical solid is already there"), said)
	assert_true(said.contains("the prefab's solid 2:"), "every refusal is listed")
	assert_eq(session.model.undo_depth(), depth)
	assert_eq(r.solids.size(), 3)

func test_unknown_prefab_room_and_origin_are_refused() -> void:
	var r := _fresh()
	assert_true(_error(_call("stamp_prefab", {"room": "Fresh", "prefab": "castle", "origin": [200, 320]})).begins_with("prefab: expected one of"))
	assert_eq(_error(_call("stamp_prefab", {"room": "Fresh", "prefab": "mound", "origin": [1]})), "origin: expected an array of 2 numbers")
	assert_eq(_error(_call("stamp_prefab", {"room": "Z9", "prefab": "mound", "origin": [200, 320]})), "no room 'Z9'")
	assert_eq(r.solids.size(), 0)
