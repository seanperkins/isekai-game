extends GutTest
## Growing a room: whole screens, left, right or top; local positions shift so world positions never move.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

## A room with room on every side and no neighbours: a lone 1x1 room far from the shipped ones.
func _lone() -> RoomDef:
	var r := RoomDef.new()
	r.id = "L1"
	r.area = "cave"
	r.cell = Vector2i(20, 20)
	r.solids = [Rect2(100, 200, 80, 12)]
	r.spawns = [{"id": "toad", "pos": Vector2(300, 300)}]
	r.features = [{"kind": "glow_pool", "id": "l1_glow_pool_1", "pos": Vector2(400, 320)}]
	r.decor = [{"id": "crystal_teal", "pos": Vector2(110, 320)}]
	r.dressing = [{"piece": "stalagmite", "pos": Vector2(500, 320), "factor": 0.5}]
	r.exits = []
	return r

func _with_lone() -> void:
	model.rooms["L1"] = _lone()
	model._baseline["L1"] = RoomEditModel.copy_room(model.rooms["L1"])

func _world_pos(r: RoomDef, local: Vector2) -> Vector2:
	return r.world_rect().position + local

func test_growing_right_adds_a_screen_and_moves_nothing() -> void:
	_with_lone()
	var before := RoomEditModel.copy_room(model.rooms["L1"])
	assert_eq(model.grow_room("L1", "right"), "")
	var r: RoomDef = model.rooms["L1"]
	assert_eq(r.size, Vector2i(2, 1))
	assert_eq(r.cell, before.cell)
	assert_eq(r.solids, before.solids)
	assert_eq(model.undo_depth(), 1)

func test_growing_left_shifts_every_local_position_and_keeps_world_positions() -> void:
	_with_lone()
	var before := RoomEditModel.copy_room(model.rooms["L1"])
	assert_eq(model.grow_room("L1", "left"), "")
	var r: RoomDef = model.rooms["L1"]
	assert_eq(r.cell, Vector2i(19, 20))
	assert_eq(r.size, Vector2i(2, 1))
	assert_eq(_world_pos(r, r.spawns[0]["pos"]), _world_pos(before, before.spawns[0]["pos"]))
	assert_eq(_world_pos(r, r.features[0]["pos"]), _world_pos(before, before.features[0]["pos"]))
	assert_eq(_world_pos(r, r.decor[0]["pos"]), _world_pos(before, before.decor[0]["pos"]))
	assert_eq(_world_pos(r, r.dressing[0]["pos"]), _world_pos(before, before.dressing[0]["pos"]))
	assert_eq(r.solids[0].position + r.world_rect().position, before.solids[0].position + before.world_rect().position)
	assert_eq(r.solids[0].size, before.solids[0].size)

func test_growing_the_top_shifts_down_and_the_floor_stays_where_it_was_in_the_world() -> void:
	_with_lone()
	var before := RoomEditModel.copy_room(model.rooms["L1"])
	assert_eq(model.grow_room("L1", "top"), "")
	var r: RoomDef = model.rooms["L1"]
	assert_eq(r.cell, Vector2i(20, 19))
	assert_eq(r.world_rect().end, before.world_rect().end, "the bottom is anchored")
	assert_eq(_world_pos(r, r.features[0]["pos"]), _world_pos(before, before.features[0]["pos"]))

func test_a_hard_ledge_moves_with_its_solid() -> void:
	_with_lone()
	var ledge := Rect2(220, 200, 80, 8)
	model.rooms["L1"].solids.append(ledge)
	model.rooms["L1"].hard_ledges.append(ledge)
	model.grow_room("L1", "left")
	var r: RoomDef = model.rooms["L1"]
	assert_eq(r.hard_ledges[0], r.solids[1], "still the same rect in both lists")
	assert_eq(r.hard_ledges[0].position, Vector2(860, 200))

func test_the_bottom_is_not_offered() -> void:
	_with_lone()
	assert_ne(model.grow_room("L1", "bottom"), "")
	assert_eq(model.undo_depth(), 0)

func test_a_non_start_room_stays_a_non_start_and_the_start_room_keeps_its_start_in_the_world() -> void:
	_with_lone()
	model.grow_room("L1", "left")
	model.grow_room("L1", "top")
	assert_false(model.rooms["L1"].is_start(), "NO_START (-1, -1) must not move")
	model.undo()
	model.undo()
	model.rooms["L1"].start = Vector2(60, 308)
	var before := RoomEditModel.copy_room(model.rooms["L1"])
	assert_eq(model.grow_room("L1", "left"), "")
	assert_eq(model.grow_room("L1", "top"), "")
	var r: RoomDef = model.rooms["L1"]
	assert_true(r.is_start())
	assert_eq(_world_pos(r, r.start), _world_pos(before, before.start), "the start stays in place in the world")

func test_exits_on_perpendicular_edges_shift_along_the_grown_axis() -> void:
	_with_lone()
	var r: RoomDef = model.rooms["L1"]
	r.exits = [{"edge": "bottom", "from": 100.0, "to": 200.0, "room": "L9"}, {"edge": "right", "from": 200.0, "to": 320.0, "room": "L8"}]
	model.grow_room("L1", "left")
	assert_eq([r.exits[0]["from"], r.exits[0]["to"]], [740.0, 840.0], "a bottom exit moves along x by one screen width")
	assert_eq([r.exits[1]["from"], r.exits[1]["to"]], [200.0, 320.0], "a right exit does not move in y when growing left")
	model.grow_room("L1", "top")
	assert_eq([r.exits[1]["from"], r.exits[1]["to"]], [560.0, 680.0], "a right exit moves along y by one screen height")
	assert_eq([r.exits[0]["from"], r.exits[0]["to"]], [740.0, 840.0])

func test_a_side_that_touches_a_neighbour_is_refused_as_an_overlap() -> void:
	var err := model.grow_room("C1", "right")  # C2 is there
	assert_string_contains(err, "overlap")
	assert_eq(model.undo_depth(), 0)

func test_the_screen_cap_is_six() -> void:
	_with_lone()
	for i in 5:
		assert_eq(model.grow_room("L1", "right"), "")
	assert_eq(model.rooms["L1"].size.x, 6)
	assert_ne(model.grow_room("L1", "right"), "")

func test_undo_restores_the_exact_previous_room() -> void:
	_with_lone()
	var before := RoomEditModel.copy_room(model.rooms["L1"])
	model.grow_room("L1", "left")
	model.undo()
	assert_true(RoomEditModel.same_room(before, model.rooms["L1"]))

func test_ceiling_attached_content_ends_up_mid_air_as_documented() -> void:
	_with_lone()
	model.rooms["L1"].solids.append(Rect2(300, 20, 120, 32))  # hangs from the ceiling
	model.grow_room("L1", "top")
	assert_eq(model.rooms["L1"].solids[1].position.y, 380.0, "20 + one screen: now far below the new ceiling")

func test_a_grown_room_keeps_the_world_valid() -> void:
	_with_lone()
	model.grow_room("L1", "left")
	model.grow_room("L1", "top")
	assert_false("\n".join(model.validate()).contains("L1: overlaps"))

func test_growing_shifts_the_boss_threshold_and_the_glimpse_with_the_room() -> void:
	_with_lone()
	var lone: RoomDef = model.rooms["L1"]
	lone.boss = {"creature": "toad", "threshold": Rect2(200, 100, 40, 80)}
	lone.glimpse = {"creature": "taratect", "pos": Vector2(320, 150), "scale": 2.0}
	model._baseline["L1"] = RoomEditModel.copy_room(lone)
	var before := RoomEditModel.copy_room(lone)
	assert_eq(model.grow_room("L1", "left"), "")
	assert_eq(model.grow_room("L1", "top"), "")
	var grown: RoomDef = model.rooms["L1"]
	assert_eq(_world_pos(grown, (grown.boss["threshold"] as Rect2).position), _world_pos(before, (before.boss["threshold"] as Rect2).position), "the threshold stays where it was in the world")
	assert_eq(_world_pos(grown, grown.glimpse["pos"]), _world_pos(before, before.glimpse["pos"]), "and so does the glimpse")
	assert_eq((grown.boss["threshold"] as Rect2).size, Rect2(200, 100, 40, 80).size)
	assert_true(model.undo())
	assert_true(model.undo())
	var undone: RoomDef = model.rooms["L1"]
	assert_eq(undone.boss["threshold"], Rect2(200, 100, 40, 80))
	assert_eq(undone.glimpse["pos"], Vector2(320, 150))
	assert_true(model.redo())
	assert_true(model.redo())
	var redone: RoomDef = model.rooms["L1"]
	assert_eq(_world_pos(redone, (redone.boss["threshold"] as Rect2).position), _world_pos(before, (before.boss["threshold"] as Rect2).position))
