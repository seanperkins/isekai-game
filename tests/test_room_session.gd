extends GutTest
## RoomSession: the working set behind the room MCP. It loads a directory of rooms into a RoomEditModel and remembers what the files
## held, so a file changed behind its back is noticed. Tests use a copy of the shipped rooms under res://.tmp, never data/rooms.

const TMP := "res://.tmp/room_session_test"

var session: RoomSession

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	var rooms := ShippedRooms.load_all()
	for id in rooms:
		ResourceSaver.save(rooms[id], "%s/%s.tres" % [TMP, id])
	session = RoomSession.new(TMP)

func after_each() -> void:
	var d := DirAccess.open(TMP)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))

func _rewrite_c1_on_disk() -> void:
	var r := RoomEditModel.copy_room(session.model.rooms["C1"])
	r.solids.append(Rect2(100, 100, 40, 12))
	ResourceSaver.save(r, "%s/C1.tres" % TMP)

func test_a_session_loads_the_rooms_and_nothing_is_dirty() -> void:
	assert_eq(session.model.rooms.size(), 23)
	assert_eq(session.model.dirty.size(), 0)
	assert_eq(session.changed_on_disk(), [])
	assert_true(session.model.creature_ids.size() > 0)
	var s := session.state()
	assert_eq(s["rooms"], 23)
	assert_eq(s["dirty"], [])
	assert_eq([s["undo_depth"], s["redo_depth"]], [0, 0])
	assert_eq(s["changed_on_disk"], [])

func test_a_file_that_changes_on_disk_is_reported() -> void:
	_rewrite_c1_on_disk()
	assert_eq(session.changed_on_disk(), ["C1"])
	assert_eq(session.state()["changed_on_disk"], ["C1"])

func test_reload_clears_dirty_history_and_reads_the_disk_again() -> void:
	session.model.add_solid("C2", Vector2(100, 100), Vector2(200, 116))
	assert_eq(session.state()["dirty"], ["C2"])
	_rewrite_c1_on_disk()
	session.reload()
	assert_eq(session.state()["dirty"], [])
	assert_eq(session.model.undo_depth(), 0)
	assert_eq(session.changed_on_disk(), [])
	assert_true((session.model.rooms["C1"] as RoomDef).solids.has(Rect2(100, 100, 40, 12)), "the rewritten C1 was read, not the cache")
