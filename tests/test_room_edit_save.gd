extends GutTest
## Save writes each edited room with ResourceSaver and reads back equal.

const TMP := "res://.tmp/room_edit_save_test"

var model: RoomEditModel

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func after_each() -> void:
	var d := DirAccess.open(TMP)
	if d != null:
		for f in d.get_files():
			d.remove(f)
		for sub in d.get_directories():
			d.remove(sub)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))

func _load(id: String) -> RoomDef:
	return ResourceLoader.load("%s/%s.tres" % [TMP, id], "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef

func test_an_edited_room_saves_and_reloads_equal_and_only_it_is_written() -> void:
	model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	model.add_spawn("C1", "toad", Vector2(300, 100))
	var result := model.save_dirty(TMP)
	assert_eq(result["saved"], ["C1"])
	assert_eq(result["errors"], {})
	assert_true(RoomEditModel.same_room(model.rooms["C1"], _load("C1")))
	assert_false(FileAccess.file_exists("%s/C2.tres" % TMP), "an untouched room is not written")
	assert_true(model.dirty.is_empty())

func test_rooms_with_features_dressing_and_a_nested_kit_round_trip() -> void:
	for id in ShippedRooms.IDS:
		model.dirty[id] = true
	var result := model.save_dirty(TMP)
	assert_eq(result["errors"], {})
	for id in ShippedRooms.IDS:
		assert_true(RoomEditModel.same_room(model.rooms[id], _load(id)), id)

func test_a_failed_save_names_the_room_and_leaves_it_dirty() -> void:
	model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	var result := model.save_dirty("res://.tmp/does/not/exist/anywhere")
	assert_eq(result["saved"], [])
	assert_true(result["errors"].has("C1"))
	assert_true(model.dirty.has("C1"))

func test_a_write_failure_leaves_that_room_dirty_and_the_others_written() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/C1.tres" % TMP))  # a directory where C1's file goes
	model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	model.add_solid("C2", Vector2(100, 100), Vector2(200, 116))
	var result := model.save_dirty(TMP)
	assert_engine_error("Cannot save file")
	assert_eq(result["saved"], ["C2"])
	assert_true(result["errors"].has("C1"))
	assert_true(model.dirty.has("C1"), "the failed room stays dirty")
	assert_false(model.dirty.has("C2"))

func test_a_new_room_saves_and_so_does_its_neighbours_partner_exit() -> void:
	assert_eq(model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 1)), "")
	var result := model.save_dirty(TMP)
	result["saved"].sort()
	assert_eq(result["saved"], ["C6", "Fresh"])
	var reloaded := {}
	for id in ShippedRooms.IDS:
		reloaded[id] = _load(id) if id == "C6" else ResourceLoader.load("res://data/rooms/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE)
	reloaded["Fresh"] = _load("Fresh")
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	assert_eq("\n".join(WorldValidator.validate(reloaded, ids)), "")

## ResourceSaver gives the script reference a fresh random id on every save ("1_obhj1"); that pair of lines is the only
## difference a first Save makes to a room nobody edited.
func _without_script_ids(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("1_[a-z0-9]{5}")
	return rx.sub(text, "1_ID", true)

func test_an_unedited_room_saves_identical_to_the_shipped_file_but_for_the_script_id() -> void:
	for id in ["C1", "G3"]:
		model.dirty[id] = true
	model.save_dirty(TMP)
	for id in ["C1", "G3"]:
		assert_eq(_without_script_ids(FileAccess.get_file_as_string("%s/%s.tres" % [TMP, id])),
			_without_script_ids(FileAccess.get_file_as_string("res://data/rooms/%s.tres" % id)), id)

# --- undoing what a Save already wrote ---

func _reload_all(dir: String, ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		var path := "%s/%s.tres" % [dir, id]
		if not FileAccess.file_exists(path):
			path = "res://data/rooms/%s.tres" % id
		out[id] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return out

func test_undoing_a_saved_new_room_removes_its_file_on_the_next_save_and_redo_brings_it_back() -> void:
	var ids: Array = ShippedRooms.IDS.duplicate()
	assert_eq(model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 1)), "")
	model.save_dirty(TMP)
	assert_true(FileAccess.file_exists("%s/Fresh.tres" % TMP))
	model.undo()
	var result := model.save_dirty(TMP)
	assert_eq(result["removed"], ["Fresh"])
	assert_false(FileAccess.file_exists("%s/Fresh.tres" % TMP), "no orphan room left on disk")
	assert_true(FileAccess.file_exists("%s/C6.tres" % TMP), "C6 is rewritten without the exit")
	var dir_ids := ids.duplicate()
	var reloaded := _reload_all(TMP, dir_ids)
	var creature_ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	assert_eq("\n".join(WorldValidator.validate(reloaded, creature_ids)), "", "the saved directory is a valid world again")
	model.redo()
	model.save_dirty(TMP)
	assert_true(FileAccess.file_exists("%s/Fresh.tres" % TMP), "redo and Save write it again")

func test_undoing_a_new_room_that_was_never_saved_removes_nothing() -> void:
	model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 1))
	model.undo()
	var result := model.save_dirty(TMP)
	assert_eq(result["removed"], [])

func test_a_room_that_was_loaded_is_never_removed_from_disk() -> void:
	model.dirty["C1"] = true
	model.save_dirty(TMP)
	model._removed_on_save["C1"] = true  # even if the set were wrong, only rooms this session created may be deleted
	var result := model.save_dirty(TMP)
	assert_eq(result["removed"], [])
	assert_true(FileAccess.file_exists("%s/C1.tres" % TMP))

# --- dirty means differs from what is on disk ---

func test_undoing_back_to_the_saved_state_clears_the_dirty_mark() -> void:
	model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	assert_true(model.dirty.has("C1"))
	model.undo()
	assert_false(model.dirty.has("C1"), "back to what is on disk")
	assert_eq(model.save_dirty(TMP)["saved"], [], "nothing to write")

func test_after_a_save_the_saved_state_is_the_new_baseline() -> void:
	model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	model.save_dirty(TMP)
	model.add_solid("C1", Vector2(300, 100), Vector2(360, 116))
	model.undo()
	assert_false(model.dirty.has("C1"), "undoing to the saved state clears it")
	model.undo()
	assert_true(model.dirty.has("C1"), "undoing past the saved state marks it again")

func test_only_limits_the_write_to_the_named_rooms() -> void:
	model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	model.add_solid("C2", Vector2(100, 100), Vector2(200, 116))
	var result := model.save_dirty(TMP, ["C2"])
	assert_eq(result["saved"], ["C2"])
	assert_true(model.dirty.has("C1"), "C1 was not named, so it is still unsaved")
	assert_false(FileAccess.file_exists("%s/C1.tres" % TMP))
	assert_true(FileAccess.file_exists("%s/C2.tres" % TMP))
