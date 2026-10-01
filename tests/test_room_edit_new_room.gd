extends GutTest
## A new room is created beside an existing one, level with it, and connected at once.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func _errors() -> String:
	return "\n".join(model.validate())

func test_ids_are_letters_digits_and_underscore_and_unique_case_insensitively() -> void:
	assert_true(RoomEditModel.valid_id("D1"))
	assert_true(RoomEditModel.valid_id("my_room_2"))
	assert_false(RoomEditModel.valid_id(""))
	assert_false(RoomEditModel.valid_id("a b"))
	assert_false(RoomEditModel.valid_id("../x"))
	assert_ne(model.id_error("c1"), "", "c1 collides with C1 on a case-insensitive file system")
	assert_ne(model.id_error("C1"), "")
	assert_eq(model.id_error("Fresh"), "")

func test_a_room_beside_a_side_edge_is_bottom_aligned_and_connected() -> void:
	assert_eq(model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(2, 2)), "")
	var r: RoomDef = model.rooms["Fresh"]
	assert_eq(r.world_rect().end.y, model.rooms["C6"].world_rect().end.y, "the floors are level")
	assert_eq(r.world_rect().end.x, model.rooms["C6"].world_rect().position.x, "it sits against C6's left edge")
	assert_eq(r.area, "cave")
	assert_false(r.is_start())
	assert_eq(r.exits.size(), 1)
	assert_eq(_errors(), "", "connected, paired, no overlap")
	assert_true(WorldValidator.reachable(model.rooms).has("Fresh"))

func test_a_room_above_or_below_is_left_aligned() -> void:
	assert_eq(model.new_room_beside("C6", "top", "Above", "cave", Vector2i(1, 1)), "")
	assert_eq(model.rooms["Above"].world_rect().position.x, model.rooms["C6"].world_rect().position.x)
	assert_eq(model.rooms["Above"].world_rect().end.y, model.rooms["C6"].world_rect().position.y)
	assert_eq(model.new_room_beside("C2", "bottom", "Below", "cave", Vector2i(1, 1)), "")
	assert_eq(model.rooms["Below"].world_rect().position.x, model.rooms["C2"].world_rect().position.x)
	assert_eq(model.rooms["Below"].world_rect().position.y, model.rooms["C2"].world_rect().end.y)
	assert_eq(_errors(), "")

func test_one_new_room_is_one_undo_step_and_undo_removes_it() -> void:
	model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 1))
	assert_eq(model.undo_depth(), 1)
	assert_true(model.dirty.has("Fresh"))
	assert_true(model.dirty.has("C6"), "the neighbour got the partner exit")
	model.undo()
	assert_false(model.rooms.has("Fresh"))
	assert_false(model.dirty.has("Fresh"))
	assert_eq(_errors(), "")
	model.redo()
	assert_true(model.rooms.has("Fresh"))
	assert_eq(_errors(), "")

func test_a_room_that_would_overlap_another_is_refused() -> void:
	assert_string_contains(model.new_room_beside("C1", "right", "Fresh", "cave", Vector2i(1, 1)), "overlap")
	assert_string_contains(model.new_room_beside("C3", "left", "Beside", "cave", Vector2i(1, 1)), "overlap")
	assert_eq(model.undo_depth(), 0)
	assert_false(model.rooms.has("Fresh"))

func test_a_bad_id_a_bad_area_or_a_bad_size_is_refused_and_writes_nothing() -> void:
	assert_ne(model.new_room_beside("C6", "left", "c1", "cave", Vector2i(1, 1)), "")
	assert_ne(model.new_room_beside("C6", "left", "Fresh", "nowhere", Vector2i(1, 1)), "")
	assert_ne(model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(0, 1)), "")
	assert_ne(model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 9)), "")
	assert_eq(model.undo_depth(), 0)

func test_a_room_on_a_bottom_edge_is_connected_but_the_hole_has_no_floor_below() -> void:
	assert_eq(model.new_room_beside("C2", "bottom", "Below", "cave", Vector2i(1, 1)), "")
	assert_eq(_errors(), "")
	var e: Dictionary = model.rooms["C2"].exits.filter(func(x): return x["room"] == "Below")[0]
	var mid: float = (float(e["from"]) + float(e["to"])) / 2.0
	var h: float = model.rooms["C2"].pixel_size().y
	assert_null(model.floor_spot("C2", Vector2(mid, h - 60.0)), "nothing below the hole: Play refuses")

func test_the_default_door_keeps_the_lint_zone_clear_of_rock_in_the_neighbour() -> void:
	var checked := 0
	for host in ["C1", "C2", "C3", "C6"]:
		for edge in ["right", "left", "top", "bottom"]:
			var m := RoomEditModel.new(ShippedRooms.load_all(), [])
			if m.new_room_beside(host, edge, "Fresh", "cave", Vector2i(1, 1)) != "":
				continue
			checked += 1
			var a: RoomDef = m.rooms[host]
			var e: Dictionary = a.exits.filter(func(x): return x["room"] == "Fresh")[0]
			var strip := RoomLint.exit_zone(a.pixel_size(), e)
			for s in a.solids:
				assert_false((s as Rect2).intersects(strip), "%s %s: solid %s in the strip %s" % [host, edge, s, strip])
	assert_gte(checked, 4, "several shipped edges take a new room")

func test_a_blocked_default_door_slides_to_a_free_span() -> void:
	# put a rock right in front of the floor-level door of C6's left edge; the door must move up
	var c6: RoomDef = model.rooms["C6"]
	var floor_y: float = c6.pixel_size().y - RoomDef.FLOOR
	c6.solids.append(Rect2(20, floor_y - 80.0, 40, 80))
	assert_eq(model.new_room_beside("C6", "left", "Fresh", "cave", Vector2i(1, 1)), "")
	var e: Dictionary = c6.exits.filter(func(x): return x["room"] == "Fresh")[0]
	assert_lt(float(e["to"]), floor_y - 0.0, "the door is above the rock, not at the floor")
	assert_eq(_errors(), "")

func test_every_shipped_room_opens_in_the_model_and_round_trips_its_data() -> void:
	var fresh := ShippedRooms.load_all()
	for id in ShippedRooms.IDS:
		assert_true(RoomEditModel.same_room(fresh[id], model.rooms[id]), id)

func test_every_door_the_editor_makes_passes_exit_blocked() -> void:
	var made := 0
	for host in ["C1", "C2", "C3", "C6"]:
		for edge in ["right", "left", "top", "bottom"]:
			var m := RoomEditModel.new(ShippedRooms.load_all(), [])
			if m.new_room_beside(host, edge, "Fresh", "cave", Vector2i(1, 1)) != "":
				continue
			made += 1
			assert_eq(RoomLint.text(RoomLint.check_room(m.rooms[host], m.rooms), ["exit_blocked", "exit_narrow"]), "", "%s %s" % [host, edge])
	assert_gte(made, 4)
