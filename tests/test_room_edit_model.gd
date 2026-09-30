extends GutTest
## RoomEditModel: the working copy of the rooms and its snapshot undo.

var source := {}
var model: RoomEditModel

func before_each() -> void:
	source = ShippedRooms.load_all()
	model = RoomEditModel.new(source, ["bat", "toad", "spider", "water_pool"])

func test_the_model_edits_copies_never_the_loaded_rooms() -> void:
	assert_ne(model.rooms["C1"], source["C1"])
	model.rooms["C1"].solids.append(Rect2(1, 2, 3, 4))
	assert_false(source["C1"].solids.has(Rect2(1, 2, 3, 4)))

func _kit_pool(rooms: Dictionary) -> Dictionary:
	for id in rooms:
		for f in (rooms[id] as RoomDef).features:
			if f.get("kind", "") == "rebirth_pool" and (f["kit"] as Dictionary).has("affinity"):
				return {"room": id, "feature": f}
	return {}

func test_a_nested_value_is_copied_too() -> void:
	var original := _kit_pool(source)
	assert_false(original.is_empty(), "a shipped room has a rebirth pool with a kit affinity")
	var copy := _kit_pool(model.rooms)
	var before: Dictionary = original["feature"]["kit"]["affinity"].duplicate()
	copy["feature"]["kit"]["affinity"]["zzz"] = 9
	assert_eq(original["feature"]["kit"]["affinity"], before)

func test_a_copy_equals_its_source_by_exported_properties() -> void:
	for id in source:
		assert_true(RoomEditModel.same_room(source[id], model.rooms[id]), id)
	assert_false(RoomEditModel.same_room(source["C1"], source["C2"]))
	assert_true(RoomEditModel.same_room(null, null))
	assert_false(RoomEditModel.same_room(null, source["C1"]))

func test_snap_rounds_to_four_and_a_delta_is_snapped_per_axis() -> void:
	assert_eq(RoomEditModel.snap(5.9), 4.0)
	assert_eq(RoomEditModel.snap(6.1), 8.0)
	assert_eq(RoomEditModel.snap(-1.9), 0.0)
	assert_eq(RoomEditModel.snap_delta(Vector2(9.0, -5.0)), Vector2(8.0, -4.0))

# --- undo and redo (driven through a real edit, add_solid, tested fully in the next task) ---

func _add(a := Vector2(100, 100), b := Vector2(200, 140)) -> void:
	assert_eq(model.add_solid("C1", a, b), "")

func test_an_edit_is_one_undo_step_and_undo_restores_the_exact_data() -> void:
	var before := RoomEditModel.copy_room(model.rooms["C1"])
	_add()
	assert_eq(model.undo_depth(), 1)
	assert_true(model.undo())
	assert_true(RoomEditModel.same_room(before, model.rooms["C1"]))
	assert_eq(model.undo_depth(), 0)
	assert_false(model.undo(), "nothing left")

func test_redo_reapplies_and_a_new_edit_clears_it() -> void:
	_add()
	var after := RoomEditModel.copy_room(model.rooms["C1"])
	model.undo()
	assert_true(model.redo())
	assert_true(RoomEditModel.same_room(after, model.rooms["C1"]))
	model.undo()
	_add(Vector2(300, 100), Vector2(360, 140))
	assert_eq(model.redo_depth(), 0)
	assert_false(model.redo())

func test_a_step_that_changed_nothing_is_dropped() -> void:
	var before := model._snap(["C1"])
	model._push(before)
	assert_eq(model.undo_depth(), 0)

func test_the_undo_stack_is_capped() -> void:
	for i in RoomEditModel.UNDO_CAP + 20:
		model.add_solid("C1", Vector2(24 + (i % 40) * 4, 100), Vector2(28 + (i % 40) * 4, 140 + floori(i / 40.0) * 4))
	assert_eq(model.undo_depth(), RoomEditModel.UNDO_CAP)

func test_editing_marks_only_the_touched_room_dirty() -> void:
	_add()
	assert_eq(model.dirty.keys(), ["C1"])
