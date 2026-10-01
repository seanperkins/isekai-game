extends GutTest

var model: RoomEditModel

func before_each() -> void:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = "flooded"
	r.size = Vector2i(2, 1)
	r.start = Vector2(60, 308)
	model = RoomEditModel.new({"T1": r}, [])

func test_add_water_draws_a_snapped_rect_and_selects_it_in_one_undo_step() -> void:
	assert_eq(model.add_water("T1", Vector2(203, 103), Vector2(405, 251)), "")
	var w: Rect2 = model.rooms["T1"].water[0]
	assert_eq(w.position, Vector2(model.snap(203), model.snap(103)))
	assert_eq(model.selection["kind"], "water")
	assert_eq(model.undo_depth(), 1)
	model.undo()
	assert_eq(model.rooms["T1"].water, [])

func test_add_water_refuses_small_and_overlapping_rects_and_clips_a_drag_that_leaves_the_room() -> void:
	assert_ne(model.add_water("T1", Vector2(100, 100), Vector2(120, 120)), "", "under 32 px")
	assert_ne(model.add_water("T1", Vector2(-50, 100), Vector2(10, 200)), "", "clipped to the room it is under the minimum")
	assert_eq(model.undo_depth(), 0, "refusals leave no history")
	assert_eq(model.add_water("T1", Vector2(-50, 100), Vector2(100, 200)), "", "a drag that starts outside is clipped, as for a solid")
	assert_eq((model.rooms["T1"].water[0] as Rect2), Rect2(0, 100, 100, 100))
	assert_eq(model.add_water("T1", Vector2(200, 100), Vector2(400, 250)), "")
	assert_ne(model.add_water("T1", Vector2(300, 150), Vector2(500, 300)), "", "overlaps the second")
	assert_ne(model.add_water("T1", Vector2(400, 100), Vector2(600, 250)), "", "touches the second")
	assert_eq(model.undo_depth(), 2, "only the two accepted rects")

func test_water_is_hit_last_so_anything_in_it_wins() -> void:
	model.add_water("T1", Vector2(200, 100), Vector2(400, 250))
	assert_eq(model.hit("T1", Vector2(300, 180), 4.0)["kind"], "water")
	model.add_spawn("T1", "glass_eel", Vector2(300, 180))
	assert_eq(model.hit("T1", Vector2(300, 180), 4.0)["kind"], "spawn")

func test_water_moves_deletes_and_edits_by_field() -> void:
	model.add_water("T1", Vector2(200, 100), Vector2(400, 250))
	var sel := model.selection.duplicate()
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(40, 20))
	model.end_move()
	assert_eq((model.rooms["T1"].water[0] as Rect2).position, Vector2(model.snap(240), model.snap(120)))
	assert_eq(model.get_field(sel, "w"), 200.0)
	assert_eq(model.set_field(sel, "w", 240.0), "")
	assert_eq((model.rooms["T1"].water[0] as Rect2).size.x, 240.0)
	assert_ne(model.set_field(sel, "w", 10.0), "", "under the minimum")
	assert_eq(model.delete_selection(), "")
	assert_eq(model.rooms["T1"].water, [])

func test_a_lint_finding_for_water_selects_it() -> void:
	var r: RoomDef = model.rooms["T1"]
	r.water = [Rect2(200, 240, 160, 80)]  # no shore: water_exit
	var f: Dictionary = RoomLint.check_room(r, {"T1": r}).filter(func(x): return x["rule"] == "water_exit")[0]
	assert_eq(f["pick"], {"room": "T1", "kind": "water", "index": 0})
