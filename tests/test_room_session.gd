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
	assert_eq(session.model.rooms.size(), ShippedRooms.IDS.size())
	assert_eq(session.model.dirty.size(), 0)
	assert_eq(session.changed_on_disk(), [])
	assert_true(session.model.creature_ids.size() > 0)
	var s := session.state()
	assert_eq(s["rooms"], ShippedRooms.IDS.size())
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

# --- saving and reverting ---

func _edit(id: String, at := 100) -> void:
	assert_eq(session.model.add_solid(id, Vector2(at, 100), Vector2(at + 100, 116)), "")

func _disk(id: String) -> RoomDef:
	return ResourceLoader.load("%s/%s.tres" % [TMP, id], "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef

func test_save_writes_only_dirty_rooms() -> void:
	var c2_before := session.file_hash("C2")
	_edit("C1")
	var result := session.save()
	assert_eq(result["saved"], ["C1"])
	assert_eq(result["errors"], {})
	assert_true(RoomEditModel.same_room(_disk("C1"), session.model.rooms["C1"]))
	assert_eq(session.file_hash("C2"), c2_before, "an untouched room's file is not rewritten")
	assert_eq(session.state()["dirty"], [])
	assert_eq(session.changed_on_disk(), [])

func test_a_file_changed_on_disk_is_refused_then_forced() -> void:
	_rewrite_c1_on_disk()
	var theirs := session.file_hash("C1")
	_edit("C1", 300)
	var refused := session.save()
	assert_eq(refused["saved"], [])
	assert_eq(refused["errors"]["C1"], "changed on disk since loaded")
	assert_eq(session.file_hash("C1"), theirs, "the file they wrote is untouched")
	assert_true(session.state()["dirty"].has("C1"))
	var forced := session.save([], true)
	assert_eq(forced["saved"], ["C1"])
	assert_ne(session.file_hash("C1"), theirs)
	_edit("C1", 450)
	assert_eq(session.save()["saved"], ["C1"], "after a save the recorded hash is current")

func test_a_new_room_whose_file_has_appeared_is_stale() -> void:
	assert_eq(session.model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 1)), "")
	var theirs := RoomDef.new()
	theirs.id = "Fresh"
	ResourceSaver.save(theirs, "%s/Fresh.tres" % TMP)
	var result := session.save()
	assert_eq(result["errors"]["Fresh"], "changed on disk since loaded")
	assert_eq(result["saved"], ["C6"], "the neighbour's exit is still saved")

func test_save_a_subset_and_report_problems_for_those_rooms() -> void:
	_edit("C1")
	_edit("C2")
	var result := session.save(["C2"])
	assert_eq(result["saved"], ["C2"])
	assert_eq(session.state()["dirty"], ["C1"])
	for p: Dictionary in result["problems"]:
		assert_eq(p["room"], "C2")

func test_save_names_what_it_was_asked_to_save_but_could_not() -> void:
	assert_eq(session.save(["C3"])["errors"], {"C3": "no unsaved changes"})
	assert_eq(session.save(["Z9"])["errors"], {"Z9": "no room 'Z9'"})

func test_revert_drops_everything_and_reads_the_disk() -> void:
	_edit("C1")
	_edit("C2")
	session.revert()
	assert_eq(session.state()["dirty"], [])
	assert_eq(session.model.undo_depth(), 0)
	assert_true(RoomEditModel.same_room(session.model.rooms["C1"], _disk("C1")))

func test_a_pending_deletion_of_a_file_changed_on_disk_is_refused_then_forced() -> void:
	assert_eq(session.model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 1)), "")
	assert_eq(session.save()["saved"].size(), 2, "Fresh and its neighbour")
	var theirs := RoomEditModel.copy_room(session.model.rooms["Fresh"])
	theirs.solids.append(Rect2(100, 100, 40, 12))
	ResourceSaver.save(theirs, "%s/Fresh.tres" % TMP)  # another process edits the room this session created
	session.model.undo()  # removes Fresh from the working set and queues its file for deletion
	var refused := session.save()
	assert_eq(refused["errors"]["Fresh"], "changed on disk since this session saved it: not deleted")
	assert_eq(refused["removed"], [])
	assert_true(FileAccess.file_exists("%s/Fresh.tres" % TMP), "their file survives")
	var forced := session.save([], true)
	assert_eq(forced["removed"], ["Fresh"])
	assert_false(FileAccess.file_exists("%s/Fresh.tres" % TMP))

func test_an_unchanged_pending_deletion_goes_through() -> void:
	assert_eq(session.model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 1)), "")
	session.save()
	session.model.undo()
	var result := session.save()
	assert_eq(result["removed"], ["Fresh"])
	assert_false(FileAccess.file_exists("%s/Fresh.tres" % TMP))

func test_a_room_id_that_is_not_an_id_is_not_saved() -> void:
	var r := RoomDef.new()
	r.id = "../escape"
	session.model.rooms["../escape"] = r
	session.model.dirty["../escape"] = true
	var result := session.save()
	assert_true(result["errors"].has("../escape"))
	assert_false(FileAccess.file_exists("res://.tmp/escape.tres"))
