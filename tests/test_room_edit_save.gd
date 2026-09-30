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
