extends GutTest
## The three water rules: water_rect, swimmer_dry and water_exit, and the authored-world shore check.

func _room(water: Array, solids: Array = [], spawns: Array = [], exits: Array = []) -> RoomDef:
	var r := RoomDef.new()
	r.id = "W1"
	r.area = "flooded"
	r.size = Vector2i(1, 1)
	r.start = Vector2(60, 308)
	r.water = water
	r.solids = solids
	r.spawns = spawns
	r.exits = exits
	return r

func _rules(r: RoomDef) -> Array:
	return RoomLint.check_room(r, {"W1": r}).map(func(f): return f["rule"])

func test_surface_lift_is_derived_from_the_jump_and_the_body() -> void:
	assert_eq(RoomLint.SURFACE_LIFT, floorf(pow(Player.JUMP_VELOCITY, 2.0) / (2.0 * Player.GRAVITY) - BodyConfig.BOTTOM - 4.0))
	assert_eq(RoomLint.SURFACE_LIFT, 44.0)

func test_the_rules_are_registered() -> void:
	for rule in ["water_rect", "swimmer_dry", "water_exit"]:
		assert_true(RoomLint.RULES.has(rule), rule)
	assert_eq(RoomLint.RULES.size(), 16)

# --- water_rect ---

func test_a_water_rect_outside_the_room_is_reported() -> void:
	assert_true(_rules(_room([Rect2(600, 200, 100, 60)])).has("water_rect"))

func test_a_water_rect_under_32_px_either_way_is_reported() -> void:
	assert_true(_rules(_room([Rect2(100, 200, 31, 60)])).has("water_rect"))
	assert_true(_rules(_room([Rect2(100, 200, 60, 31)])).has("water_rect"))

func test_overlapping_and_touching_rects_are_reported() -> void:
	assert_true(_rules(_room([Rect2(100, 200, 80, 80), Rect2(150, 220, 80, 80)])).has("water_rect"), "overlap")
	assert_true(_rules(_room([Rect2(100, 200, 80, 80), Rect2(180, 200, 80, 80)])).has("water_rect"), "touching edge to edge")

func test_a_clean_pool_with_a_shore_has_no_water_findings() -> void:
	var shore := Rect2(150, 245, 50, 12)  # a ledge just at the rect's left; its top (245) is inside the band around the surface (240)
	var r := _room([Rect2(200, 240, 160, 80)], [shore])
	var rules := _rules(r).filter(func(x): return x.begins_with("water"))
	assert_eq(rules, [])

# --- swimmer_dry ---

func test_a_swimmer_outside_every_water_rect_is_reported_and_a_walker_never_is() -> void:
	var dry := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 245, 50, 12)], [{"id": "glass_eel", "pos": Vector2(60, 100)}])
	assert_true(_rules(dry).has("swimmer_dry"))
	var wet := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 245, 50, 12)], [{"id": "glass_eel", "pos": Vector2(260, 280)}])
	assert_false(_rules(wet).has("swimmer_dry"))
	var walker := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 245, 50, 12)], [{"id": "toad", "pos": Vector2(60, 100)}])
	assert_false(_rules(walker).has("swimmer_dry"), "a ground creature in or out of water is nothing")

func test_swimmer_dry_picks_the_spawn() -> void:
	var dry := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 245, 50, 12)], [{"id": "glass_eel", "pos": Vector2(60, 100)}])
	var f: Dictionary = RoomLint.check_room(dry, {"W1": dry}).filter(func(x): return x["rule"] == "swimmer_dry")[0]
	assert_eq(f["pick"], {"room": "W1", "kind": "spawn", "index": 0})

# --- water_exit ---

func test_a_pit_with_no_shore_and_no_exit_traps_a_swimmer() -> void:
	var r := _room([Rect2(200, 240, 160, 80)])
	assert_true(_rules(r).has("water_exit"))

func test_a_ledge_inside_the_band_is_a_shore() -> void:
	var r := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 236, 50, 12)])  # top 236 is 4 above the surface
	assert_false(_rules(r).has("water_exit"))

func test_a_ledge_too_high_above_or_too_deep_inside_is_no_shore() -> void:
	var high := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 190, 50, 12)])  # 50 above the surface: past SURFACE_LIFT
	assert_true(_rules(high).has("water_exit"), "out of the surface jump's reach")
	var deep := _room([Rect2(200, 240, 160, 80)], [Rect2(250, 270, 60, 12)])  # a ledge inside the water, 30 below the surface
	assert_true(_rules(deep).has("water_exit"), "a body standing on it is still in water")

func test_a_ledge_more_than_24_px_from_the_rect_is_no_shore() -> void:
	var far := _room([Rect2(200, 240, 160, 80)], [Rect2(100, 236, 50, 12)])  # ends at x 150, 50 from the rect
	assert_true(_rules(far).has("water_exit"))

func test_the_ceiling_and_walls_are_not_a_shore() -> void:
	var r := _room([Rect2(200, 0, 160, 320)])  # reaches the room top but has no exit, and the ceiling is not standable
	assert_true(_rules(r).has("water_exit"), "the ceiling's top (y 0) is inside the band but nothing stands on it")

func test_the_floor_is_a_shore_when_the_surface_is_at_the_floor() -> void:
	var r := _room([Rect2(200, 310, 160, 50)])  # a shallow film at the floor top (320): the floor's top is 10 below the surface
	assert_false(_rules(r).has("water_exit"))

func test_an_open_exit_span_the_rect_reaches_is_a_way_out() -> void:
	var top := {"edge": "top", "from": 200.0, "to": 360.0, "room": "W2"}
	var r := _room([Rect2(200, 0, 160, 320)], [], [], [top])
	assert_false(_rules(r).has("water_exit"))

func test_a_shortcut_or_wall_cling_gated_exit_is_not_a_way_out_but_swim_is() -> void:
	var water := [Rect2(200, 0, 160, 320)]
	var base := {"edge": "top", "from": 200.0, "to": 360.0, "room": "W2"}
	var shortcut := base.duplicate()
	shortcut["shortcut"] = "s1"
	assert_true(_rules(_room(water, [], [], [shortcut])).has("water_exit"))
	var cling := base.duplicate()
	cling["gate"] = "wall_cling"
	assert_true(_rules(_room(water, [], [], [cling])).has("water_exit"))
	var swim := base.duplicate()
	swim["gate"] = "swim"
	assert_false(_rules(_room(water, [], [], [swim])).has("water_exit"))

# --- the authored-world check ---

func _pair(with_shore: bool) -> Dictionary:
	var a := _room([Rect2(200, 0, 160, 320)], [], [], [{"edge": "top", "from": 200.0, "to": 360.0, "room": "W2"}])
	a.cell = Vector2i(0, 1)
	var b := RoomDef.new()
	b.id = "W2"
	b.area = "flooded"
	b.cell = Vector2i(0, 0)
	b.size = Vector2i(1, 1)
	b.water = [Rect2(200, 100, 160, 260)]  # reaches the bottom edge over the span
	b.exits = [{"edge": "bottom", "from": 200.0, "to": 360.0, "room": "W1"}]
	if with_shore:
		b.solids = [Rect2(150, 90, 50, 12)]  # a shore beside W2's rect: its top (90) is 10 above W2's surface (100), inside the lift band
	return {"W1": a, "W2": b}

func test_adjacent_rects_that_each_reach_a_shared_exit_still_need_a_shore_somewhere() -> void:
	assert_eq(RoomLint.water_groups(_pair(false)).size(), 1, "no shore in either: one trapped group")
	assert_eq(RoomLint.water_groups(_pair(true)).size(), 0)

func test_a_rect_that_leaves_through_an_open_exit_into_dry_land_is_not_trapped() -> void:
	var a := _room([Rect2(200, 0, 160, 320)], [], [], [{"edge": "top", "from": 200.0, "to": 360.0, "room": "W2"}])
	a.cell = Vector2i(0, 1)
	var b := RoomDef.new()
	b.id = "W2"
	b.area = "flooded"
	b.cell = Vector2i(0, 0)
	b.size = Vector2i(1, 1)
	b.exits = [{"edge": "bottom", "from": 200.0, "to": 360.0, "room": "W1"}]  # a dry room above
	assert_eq(RoomLint.water_groups({"W1": a, "W2": b}), [])

func test_a_gated_wall_cling_exit_does_not_join_or_free_a_group() -> void:
	var rooms := _pair(false)
	rooms["W1"].exits[0]["gate"] = "wall_cling"
	rooms["W2"].exits[0]["gate"] = "wall_cling"
	var groups := RoomLint.water_groups(rooms)
	assert_eq(groups.size(), 2, "two separate groups, neither of which has a shore or an open exit")

func test_a_rect_that_stops_short_of_the_edge_does_not_reach_the_exit() -> void:
	# a swimmer leaving at the top would cross a dry band of the ceiling's thickness and fall back: the rect must reach the edge
	var top := {"edge": "top", "from": 200.0, "to": 360.0, "room": "W2"}
	var short := _room([Rect2(200, 20, 160, 300)], [], [], [top])
	assert_true(_rules(short).has("water_exit"), "20 px short of the room top")
	var side := {"edge": "right", "from": 200.0, "to": 320.0, "room": "W2"}
	assert_true(_rules(_room([Rect2(400, 200, 220, 120)], [], [], [side])).has("water_exit"), "20 px short of the right wall")
	assert_false(_rules(_room([Rect2(400, 200, 240, 120)], [], [], [side])).has("water_exit"), "to the room's own edge")
