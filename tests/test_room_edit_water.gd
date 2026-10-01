extends GutTest
## Water rides the editor like every other stored property: snapshots, undo, redo, save, and a Grow.

func _model() -> RoomEditModel:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = "flooded"
	r.cell = Vector2i(2, 2)
	r.size = Vector2i(1, 1)
	r.start = Vector2(60, 308)
	r.water = [Rect2(100, 200, 64, 64)]
	return RoomEditModel.new({"T1": r}, [])

func test_the_default_is_no_water() -> void:
	assert_eq(RoomDef.new().water, [])

func test_a_copy_keeps_water_and_is_independent() -> void:
	var m := _model()
	var a := RoomEditModel.copy_room(m.rooms["T1"])
	assert_eq(a.water, [Rect2(100, 200, 64, 64)])
	a.water.append(Rect2(0, 0, 40, 40))
	assert_eq((m.rooms["T1"] as RoomDef).water.size(), 1, "a deep copy")

func test_a_grow_to_the_left_shifts_water_with_the_room_and_undo_restores_it() -> void:
	var m := _model()
	assert_eq(m.grow_room("T1", "left"), "")
	assert_eq(m.rooms["T1"].water, [Rect2(740, 200, 64, 64)], "one screen (640) right of where it was")
	assert_true(m.undo())
	assert_eq(m.rooms["T1"].water, [Rect2(100, 200, 64, 64)])
	assert_true(m.redo())
	assert_eq(m.rooms["T1"].water, [Rect2(740, 200, 64, 64)])

func test_a_grow_to_the_right_leaves_water_where_it_is() -> void:
	var m := _model()
	assert_eq(m.grow_room("T1", "right"), "")
	assert_eq(m.rooms["T1"].water, [Rect2(100, 200, 64, 64)])

func test_a_grow_at_the_top_shifts_water_down_by_a_screen() -> void:
	var m := _model()
	assert_eq(m.grow_room("T1", "top"), "")
	assert_eq(m.rooms["T1"].water, [Rect2(100, 560, 64, 64)], "360 down")

func test_water_changes_make_a_room_dirty_and_survive_a_save_and_load() -> void:
	var m := _model()
	m.rooms["T1"].water = [Rect2(100, 200, 64, 64), Rect2(300, 220, 80, 60)]
	assert_eq(m.grow_room("T1", "right"), "", "an editor operation marks the room dirty (water itself is data until the Water tool exists)")
	var dir := "user://test_water_rooms"
	DirAccess.make_dir_recursive_absolute(dir)
	var result := m.save_dirty(dir)
	assert_eq(result["errors"], {})
	assert_eq(result["saved"], ["T1"])
	var loaded := ResourceLoader.load("%s/T1.tres" % dir, "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef
	assert_eq(loaded.water, [Rect2(100, 200, 64, 64), Rect2(300, 220, 80, 60)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/T1.tres" % dir))

func test_a_room_file_from_before_water_loads_with_none() -> void:
	var c1 := ResourceLoader.load("res://data/rooms/C1.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef
	assert_eq(c1.water, [], "the shipped Cave rooms never had a water property")
