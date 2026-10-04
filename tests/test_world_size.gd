extends GutTest
## WorldSize: how big the world is next to Super Metroid and the room budget. Pure functions over the shipped rooms; informational, so
## nothing here asserts that the world reaches a target, only that the numbers are counted right.

func _rooms() -> Dictionary:
	return ShippedRooms.load_all()

func _room(id: String, area: String, w: int, h: int, cell := Vector2i.ZERO) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.area = area
	r.size = Vector2i(w, h)
	r.cell = cell
	return r

func test_the_shipped_world_is_23_rooms_and_45_screens() -> void:
	var m := WorldSize.measure(_rooms())
	assert_eq(m["rooms"], 23)
	assert_eq(m["screens"], 45)
	assert_almost_eq(m["avg"], 45.0 / 23.0, 0.001)

func test_rooms_and_screens_per_area_are_counted() -> void:
	var per: Dictionary = WorldSize.measure(_rooms())["per_area"]
	assert_eq(per["cave"], {"rooms": 6, "screens": 11})
	assert_eq(per["grotto"], {"rooms": 5, "screens": 14})
	assert_eq(per["flooded"], {"rooms": 6, "screens": 11})
	assert_eq(per["deep"], {"rooms": 6, "screens": 9})

func test_the_shape_of_a_room_is_summarised() -> void:
	var m := WorldSize.measure({
		"A": _room("A", "cave", 1, 1), "B": _room("B", "cave", 2, 1, Vector2i(1, 0)), "C": _room("C", "cave", 1, 3, Vector2i(3, 0))})
	assert_eq(m["rooms"], 3)
	assert_eq(m["screens"], 6)
	assert_eq(m["median"], 2)
	assert_eq(m["largest"], 3)
	assert_eq(m["single"], 1)
	assert_eq(m["bounds"], Vector2(4, 3))

func test_no_rooms_measure_as_zero_without_dividing_by_zero() -> void:
	var m := WorldSize.measure({})
	assert_eq(m["rooms"], 0)
	assert_eq(m["screens"], 0)
	assert_eq(m["avg"], 0.0)
	assert_eq(m["median"], 0)
	assert_eq(m["largest"], 0)
	assert_eq(WorldSize.yardsticks(m)[0]["frac"], 0.0)

func test_the_three_yardsticks_read_rooms_and_screens() -> void:
	var ys := WorldSize.yardsticks(WorldSize.measure(_rooms()))
	assert_eq(ys.size(), 3)
	assert_eq([ys[0]["now"], ys[0]["target"]], [23, WorldSize.SM_ROOMS])
	assert_eq([ys[1]["now"], ys[1]["target"]], [45, WorldSize.BODY_SCALED_SCREENS])
	assert_eq([ys[2]["now"], ys[2]["target"]], [45, WorldSize.SM_SCREENS])
	assert_almost_eq(ys[0]["frac"], 23.0 / 255.0, 0.0001)
	assert_lt(ys[2]["frac"], ys[1]["frac"], "the strict bar is the harder one")

func test_a_world_past_a_target_reports_a_fraction_over_one() -> void:
	var rooms := {}
	for i in 300:
		rooms["R%d" % i] = _room("R%d" % i, "cave", 1, 1, Vector2i(i, 0))
	var ys := WorldSize.yardsticks(WorldSize.measure(rooms))
	assert_gt(ys[0]["frac"], 1.0)

func test_the_budget_sums_to_256_and_lists_every_planned_area() -> void:
	assert_eq(WorldSize.target_total(), 256)
	var rows := WorldSize.area_rows(WorldSize.measure(_rooms()))
	assert_eq(rows.size(), WorldSize.TARGETS.size())
	assert_eq(rows[0]["area"], "cave")
	assert_eq([rows[0]["rooms"], rows[0]["target"]], [6, 18])
	var forest: Dictionary = rows.filter(func(r): return r["area"] == "forest")[0]
	assert_eq(forest["rooms"], 0, "an area with no rooms yet still shows, at 0")
	assert_eq(forest["frac"], 0.0)

func test_an_area_outside_the_budget_is_listed_after_it_with_no_target() -> void:
	var m := WorldSize.measure({"X": _room("X", "mystery", 2, 2)})
	var rows := WorldSize.area_rows(m)
	var last: Dictionary = rows[rows.size() - 1]
	assert_eq(last["area"], "mystery")
	assert_eq([last["rooms"], last["target"], last["screens"]], [1, 1, 4])
