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

func test_serial_counts_edits_undo_and_redo_but_not_clicks() -> void:
	var s0 := model.serial
	model._push(model._snap(["C1"]))
	assert_eq(model.serial, s0, "a step that changed nothing")
	_add()
	assert_eq(model.serial, s0 + 1)
	model.undo()
	assert_eq(model.serial, s0 + 2)
	model.redo()
	assert_eq(model.serial, s0 + 3)

func test_editing_marks_only_the_touched_room_dirty() -> void:
	_add()
	assert_eq(model.dirty.keys(), ["C1"])

# --- solids ---

func test_a_solid_is_dragged_between_snapped_corners_and_clipped_to_the_room() -> void:
	assert_eq(RoomEditModel.drag_rect(Vector2(101, 99), Vector2(203, 143)), Rect2(100, 100, 104, 44))
	assert_eq(RoomEditModel.drag_rect(Vector2(200, 140), Vector2(100, 100)), Rect2(100, 100, 100, 40), "backwards drags normalise")
	var size: Vector2 = model.rooms["C1"].pixel_size()
	assert_eq(model.add_solid("C1", Vector2(size.x - 40, 100), Vector2(size.x + 200, 140)), "")
	var s: Rect2 = model.rooms["C1"].solids.back()
	assert_eq(s.end.x, size.x, "clipped to the room")

func test_a_tiny_or_outside_solid_is_refused_and_pushes_no_step() -> void:
	assert_ne(model.add_solid("C1", Vector2(100, 100), Vector2(101, 140)), "", "101 snaps back to 100: no width")
	assert_ne(model.add_solid("C1", Vector2(-300, -300), Vector2(-100, -100)), "")
	assert_eq(model.undo_depth(), 0)

func test_the_live_label_matches_the_builders_one_way_rule() -> void:
	for r in [Rect2(0, 0, 100, 24), Rect2(0, 0, 100, 28), Rect2(0, 0, 24, 24), Rect2(0, 0, 28, 24), Rect2(0, 0, 200, 8)]:
		var one_way := RoomBuilder.is_one_way(r)
		assert_eq(RoomEditModel.label_for(r), "one-way ledge" if one_way else "rock", str(r))
	var hard := Rect2(0, 0, 100, 24)
	assert_eq(RoomEditModel.label_for(hard, [hard]), "rock", "a hard ledge is rock")

# --- creatures ---

func test_a_creature_is_placed_at_a_snapped_point_and_selected() -> void:
	assert_eq(model.add_spawn("C1", "toad", Vector2(303, 299)), "")
	var s: Dictionary = model.rooms["C1"].spawns.back()
	assert_eq([s["id"], s["pos"]], ["toad", Vector2(304, 300)])
	assert_eq(model.selection["kind"], "spawn")

func test_a_creature_is_refused_in_rock_a_ledge_a_wall_outside_and_for_an_unknown_id() -> void:
	var solid: Rect2 = model.rooms["C1"].solids[0]
	assert_ne(model.add_spawn("C1", "toad", solid.get_center()), "", "inside a solid")
	assert_ne(model.add_spawn("C1", "toad", Vector2(4, 100)), "", "inside the wall")
	assert_ne(model.add_spawn("C1", "toad", Vector2(-50, 100)), "", "outside")
	assert_ne(model.add_spawn("C1", "gorgon", Vector2(300, 100)), "", "unknown id")
	assert_eq(model.undo_depth(), 0)
	var thin := Rect2(400, 200, 80, 12)
	model.rooms["C1"].solids.append(thin)
	assert_ne(model.add_spawn("C1", "toad", Vector2(420, 206)), "", "a ledge counts as rock for placement")

# --- hit-testing ---

func test_hit_prefers_creatures_then_exits_then_the_smallest_solid_and_uses_the_pick_radius() -> void:
	model.rooms["C1"].solids = [Rect2(100, 200, 300, 60), Rect2(150, 200, 40, 20)]
	model.rooms["C1"].spawns = [{"id": "toad", "pos": Vector2(170, 210)}]
	assert_eq(model.hit("C1", Vector2(172, 212), 6.0)["kind"], "spawn")
	model.rooms["C1"].spawns = []
	var h := model.hit("C1", Vector2(170, 210), 0.0)
	assert_eq([h["kind"], h["index"]], ["solid", 1], "the smaller solid wins where they overlap")
	assert_eq(model.hit("C1", Vector2(96, 230), 6.0)["index"], 0, "a click a few pixels outside still picks with a radius")
	assert_eq(model.hit("C1", Vector2(96, 230), 0.0), {}, "and misses without one")
	var edge: Dictionary = model.rooms["C1"].exits[0]
	var band := RoomBuilder.gate_rect(model.rooms["C1"].pixel_size(), edge)
	assert_eq(model.hit("C1", band.get_center(), 0.0)["kind"], "exit")

# --- moving and deleting ---

func _solid_selection(i: int) -> Dictionary:
	return {"room": "C1", "kind": "solid", "index": i}

func test_moving_a_solid_snaps_the_delta_and_never_an_untouched_origin() -> void:
	model.rooms["C1"].solids = [Rect2(101, 202, 54, 22)]
	assert_true(model.begin_move(_solid_selection(0)))
	model.move_to(Vector2(9, 5))
	assert_eq(model.rooms["C1"].solids[0], Rect2(109, 206, 54, 22), "origin 101 + snapped 8, 202 + snapped 4")
	model.end_move()
	assert_eq(model.undo_depth(), 1)
	model.undo()
	assert_eq(model.rooms["C1"].solids[0], Rect2(101, 202, 54, 22))

func test_a_drag_is_one_step_however_many_motions_and_a_click_pushes_none() -> void:
	model.rooms["C1"].solids = [Rect2(100, 200, 60, 20)]
	model.begin_move(_solid_selection(0))
	for i in 10:
		model.move_to(Vector2(i * 4, 0))
	model.end_move()
	assert_eq(model.undo_depth(), 1)
	model.begin_move(_solid_selection(0))
	model.end_move()
	assert_eq(model.undo_depth(), 1, "press and release without motion pushes nothing")

func test_a_moved_solid_stays_inside_the_room_and_keeps_hard_ledges_consistent() -> void:
	var r: RoomDef = model.rooms["C1"]
	var hard := Rect2(100, 200, 60, 20)
	r.solids = [hard]
	r.hard_ledges = [hard]
	model.begin_move(_solid_selection(0))
	model.move_to(Vector2(-5000, 8))
	model.end_move()
	assert_eq(r.solids[0].position.x, 0.0)
	assert_eq(r.hard_ledges[0], r.solids[0])
	var hard_errors := []
	for e in WorldValidator.validate({"C1": r}):
		if e.contains("hard ledge"):
			hard_errors.append(e)
	assert_eq(hard_errors, [], "the hard ledge is still one of the room's solids")

func test_a_creature_moves_but_never_into_rock() -> void:
	var r: RoomDef = model.rooms["C1"]
	r.solids = [Rect2(300, 200, 60, 60)]
	r.spawns = [{"id": "toad", "pos": Vector2(200, 150)}]
	model.begin_move({"room": "C1", "kind": "spawn", "index": 0})
	model.move_to(Vector2(20, 0))
	assert_eq(r.spawns[0]["pos"], Vector2(220, 150))
	model.move_to(Vector2(120, 60))
	assert_eq(r.spawns[0]["pos"], Vector2(220, 150), "the last valid spot stays while the pointer is over rock")
	model.end_move()

func test_deleting_a_solid_or_a_creature_is_one_undoable_step() -> void:
	var n_solids: int = model.rooms["C1"].solids.size()
	model.select(_solid_selection(0))
	assert_eq(model.delete_selection(), "")
	assert_eq(model.rooms["C1"].solids.size(), n_solids - 1)
	model.undo()
	assert_eq(model.rooms["C1"].solids.size(), n_solids)
	assert_ne(model.delete_selection(), "", "nothing selected after an undo")
	model.add_spawn("C1", "toad", Vector2(300, 100))
	var n_spawns: int = model.rooms["C1"].spawns.size()
	assert_eq(model.delete_selection(), "", "the new creature is selected")
	assert_eq(model.rooms["C1"].spawns.size(), n_spawns - 1)

# --- the spot Play starts from ---

func test_floor_spot_drops_to_the_first_rock_below_and_refuses_rock_and_no_floor() -> void:
	var r: RoomDef = model.rooms["C1"]
	r.solids = [Rect2(200, 250, 100, 12)]
	var floor_y: float = r.pixel_size().y - RoomDef.FLOOR
	assert_eq(model.floor_spot("C1", Vector2(250, 100)), Vector2(250, 250 - BodyConfig.BOTTOM), "lands on the ledge")
	assert_eq(model.floor_spot("C1", Vector2(120, 100)), Vector2(120, floor_y - BodyConfig.BOTTOM), "lands on the floor")
	assert_null(model.floor_spot("C1", Vector2(250, 255)), "inside rock")
	assert_null(model.floor_spot("C1", Vector2(-10, 100)), "outside the room")
