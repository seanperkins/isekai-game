extends GutTest
## The save and revert tools. They take no path: a save goes to the session's directory (here a temp copy, in the game data/rooms).

const TMP := "res://.tmp/room_tools_save_test"

var session: RoomSession
var tools: RoomTools

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	var rooms := ShippedRooms.load_all()
	for id in rooms:
		ResourceSaver.save(rooms[id], "%s/%s.tres" % [TMP, id])
	session = RoomSession.new(TMP)
	tools = RoomTools.new(session)

func after_each() -> void:
	var d := DirAccess.open(TMP)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))

func _call(tool_name: String, args := {}) -> Dictionary:
	return tools.call_tool(tool_name, args)

func _data(result: Dictionary) -> Dictionary:
	assert_false(result["isError"], str(result))
	return JSON.parse_string(result["content"][0]["text"])

func test_save_and_revert_take_no_path() -> void:
	for t: Dictionary in tools.tool_list():
		if t["name"] == "save":
			assert_eq(t["inputSchema"]["properties"].keys(), ["rooms", "force"])
		if t["name"] == "revert":
			assert_eq(t["inputSchema"]["properties"].keys(), [])
	assert_true(_call("save", {"path": "res://data/rooms"})["isError"])

func test_save_through_the_tool() -> void:
	_data(_call("add_solid", {"room": "C1", "a": [100, 100], "b": [200, 116]}))
	var d := _data(_call("save"))
	assert_eq(d["saved"], ["C1"])
	assert_eq(session.state()["dirty"], [])
	assert_eq(_data(_call("save"))["saved"], [], "nothing left to save is not an error")

func test_a_save_that_saves_nothing_but_refuses_is_an_error() -> void:
	_data(_call("add_solid", {"room": "C1", "a": [100, 100], "b": [200, 116]}))
	var r := RoomEditModel.copy_room(session.model.rooms["C1"])
	r.solids.append(Rect2(300, 100, 40, 12))
	ResourceSaver.save(r, "%s/C1.tres" % TMP)
	var res := _call("save")
	assert_true(res["isError"])
	assert_true(JSON.parse_string(res["content"][0]["text"])["errors"].has("C1"))
	assert_eq(_data(_call("save", {"rooms": ["C1"], "force": true}))["saved"], ["C1"])

func test_revert_through_the_tool() -> void:
	_data(_call("add_solid", {"room": "C1", "a": [100, 100], "b": [200, 116]}))
	_data(_call("revert"))
	assert_eq(session.state()["dirty"], [])
	assert_eq(session.model.undo_depth(), 0)
