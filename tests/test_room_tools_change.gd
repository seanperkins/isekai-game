extends GutTest
## The room MCP's tools that change an existing element (set_field, move, delete) and undo and redo. A ref is {room, kind, index}; an
## index is a position in the room's array, so it goes stale when an earlier element is deleted, and that must be refused.

var session: RoomSession
var tools: RoomTools

func before_each() -> void:
	session = RoomSession.new()
	tools = RoomTools.new(session)

func _call(tool_name: String, args := {}) -> Dictionary:
	return tools.call_tool(tool_name, args)

func _data(result: Dictionary) -> Dictionary:
	assert_false(result["isError"], str(result))
	return JSON.parse_string(result["content"][0]["text"])

func _error(result: Dictionary) -> String:
	assert_true(result["isError"], "expected an error: %s" % str(result))
	return result["content"][0]["text"]

## Adds a solid to C1 and returns its ref.
func _solid(a: Array, b: Array) -> Dictionary:
	return _data(_call("add_solid", {"room": "C1", "a": a, "b": b}))["ref"]

func _c1() -> RoomDef:
	return session.model.rooms["C1"]

func test_a_stale_ref_after_a_delete_is_refused() -> void:
	var first := _solid([100, 100], [200, 116])
	var second := _solid([300, 100], [400, 116])
	_data(_call("delete", {"ref": first}))
	var snapshot := RoomEditModel.copy_room(_c1())
	assert_eq(_error(_call("set_field", {"ref": second, "key": "x", "value": 320})), "no such element: C1 solid %d" % int(second["index"]))
	assert_eq(_error(_call("delete", {"ref": second})), "no such element: C1 solid %d" % int(second["index"]))
	assert_eq(_error(_call("move", {"ref": second, "delta": [8, 0]})), "no such element: C1 solid %d" % int(second["index"]))
	assert_true(RoomEditModel.same_room(_c1(), snapshot), "a refused ref changes nothing")

func test_unknown_room_is_refused() -> void:
	var ref := {"room": "Z9", "kind": "solid", "index": 0}
	assert_eq(_error(_call("set_field", {"ref": ref, "key": "x", "value": 1})), "no room 'Z9'")
	assert_eq(_error(_call("move", {"ref": ref, "delta": [4, 0]})), "no room 'Z9'")
	assert_eq(_error(_call("delete", {"ref": ref})), "no room 'Z9'")

func test_set_field_and_move() -> void:
	var ref := _solid([100, 100], [200, 116])
	var sel := {"room": "C1", "kind": "solid", "index": int(ref["index"])}
	var d := _data(_call("set_field", {"ref": ref, "key": "x", "value": 120}))
	assert_eq(d["ref"], ref)
	assert_eq(session.model.get_field(sel, "x"), 120.0)
	_data(_call("move", {"ref": ref, "delta": [8, 0]}))
	assert_eq(session.model.get_field(sel, "x"), 128.0)

func test_delete_then_undo_restores_the_room() -> void:
	var ref := _solid([100, 100], [200, 116])
	var with_solid := RoomEditModel.copy_room(_c1())
	assert_eq(_data(_call("delete", {"ref": ref}))["deleted"], ref)
	assert_eq(_c1().solids.size(), with_solid.solids.size() - 1)
	var u := _data(_call("undo"))
	assert_true(RoomEditModel.same_room(_c1(), with_solid))
	assert_eq([int(u["undo_depth"]), int(u["redo_depth"])], [1, 1])
	_data(_call("redo"))
	assert_eq(_c1().solids.size(), with_solid.solids.size() - 1)

func test_undo_and_redo_with_nothing_to_do() -> void:
	assert_eq(_error(_call("undo")), "nothing to undo")
	assert_eq(_error(_call("redo")), "nothing to redo")

func test_the_models_refusal_comes_through() -> void:
	var ref := _solid([100, 100], [200, 116])
	assert_eq(_error(_call("set_field", {"ref": ref, "key": "w", "value": 2})), "too small: a solid is at least 4 px each way")
	assert_eq(_error(_call("set_field", {"ref": ref, "key": "nope", "value": 2})), "no such field")

func test_a_move_that_goes_nowhere_is_an_error() -> void:
	var ref := _solid([100, 100], [200, 116])
	assert_eq(_error(_call("move", {"ref": ref, "delta": [1, 1]})), "nothing moved: that spot is refused, or the move rounds to nothing on the 4 px grid")

func test_a_bad_ref_shape_is_refused() -> void:
	assert_eq(_error(_call("delete", {"ref": {"room": "C1", "kind": "wall", "index": 0}})), "ref.kind: expected one of solid, water, spawn, feature, decor, exit")
	assert_eq(_error(_call("delete", {"ref": {"room": "C1", "kind": "solid", "index": -1}})), "ref.index: expected at least 0")
	assert_eq(_error(_call("delete", {"ref": {"room": "C1", "kind": "solid"}})), "ref.index: required")
	assert_eq(session.model.dirty.size(), 0)
