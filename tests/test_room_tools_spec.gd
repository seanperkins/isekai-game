extends GutTest
## The apply_room_spec tool: a room spec in, the room's content replaced in one undo step, or every refusal listed and nothing changed.

var session: RoomSession
var tools: RoomTools

func before_each() -> void:
	session = RoomSession.new()
	tools = RoomTools.new(session)

func _call(args: Dictionary) -> Dictionary:
	return tools.call_tool("apply_room_spec", args)

func _json(result: Dictionary) -> Dictionary:
	return JSON.parse_string(result["content"][0]["text"])

func test_a_rooms_own_spec_applies_unchanged() -> void:
	var spec := RoomSpec.to_json(session.model.rooms["C1"])
	var res := _call({"room": "C1", "spec": JSON.parse_string(JSON.stringify(spec))})
	assert_false(res["isError"], str(res))
	assert_eq(session.model.undo_depth(), 0)
	assert_eq(session.model.dirty.size(), 0)

func test_a_new_spec_replaces_the_content_and_reports_counts() -> void:
	var res := _call({"room": "C1", "spec": {"solids": [{"rect": [100, 100, 40, 12]}, {"rect": [300, 100, 40, 12], "hard": true}]}})
	var d := _json(res)
	assert_false(res["isError"], str(res))
	assert_eq(int(d["counts"]["solids"]), 2)
	assert_eq(int(d["counts"]["spawns"]), 0)
	assert_eq(session.model.undo_depth(), 1)
	assert_eq(session.model.rooms["C1"].hard_ledges, [Rect2(300, 100, 40, 12)])

func test_shape_errors_and_model_errors_are_listed_with_indexes_into_the_spec() -> void:
	var shape := _call({"room": "C1", "spec": {"solids": [{"rect": [1, 2, 3]}, {"rect": [0, 0, 8, 8]}]}})
	assert_true(shape["isError"])
	assert_eq(_json(shape)["errors"][0]["kind"], "solid")
	assert_eq(int(_json(shape)["errors"][0]["index"]), 0)
	var model_errors := _call({"room": "C1", "spec": {"water": [{"rect": [100, 200, 8, 8]}]}})
	assert_true(model_errors["isError"])
	assert_eq(_json(model_errors)["errors"][0]["error"], "too small: water is at least 32 px each way")
	assert_eq(session.model.dirty.size(), 0, "nothing was applied")

func test_unknown_room_and_wrong_shapes_are_refused() -> void:
	assert_eq(_call({"room": "Z9", "spec": {}})["content"][0]["text"], "no room 'Z9'")
	assert_eq(_call({"room": "C1", "spec": []})["content"][0]["text"], "spec: expected an object")
	assert_eq(_call({"room": "C1"})["content"][0]["text"], "spec: required")

func test_a_large_spec_applies_and_answers() -> void:
	var big := RoomDef.new()
	big.id = "Big"
	big.area = "cave"
	big.size = Vector2i(6, 6)
	big.cell = Vector2i(60, 60)
	session.model.rooms["Big"] = big
	var solids: Array = []
	for i in 3000:
		solids.append({"rect": [30 + (i % 100) * 36, 60 + (i / 100) * 40 - 20 * (i / 100 % 2) + 30, 24, 12]})
	var spec := {"solids": solids}
	assert_gt(JSON.stringify(spec).length(), 50000)
	var res := _call({"room": "Big", "spec": spec})
	assert_false(res["isError"], str(res).left(300))
	assert_eq(int(_json(res)["counts"]["solids"]), 3000)
