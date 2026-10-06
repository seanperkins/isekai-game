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
	assert_true(RoomLint.RULES.has("water_contained"))
	assert_eq(RoomLint.RULES.size(), 22)

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
	var r := _room([Rect2(200, 240, 160, 80)], [shore, Rect2(180, 240, 20, 80), Rect2(360, 240, 20, 80)])
	var rules := _rules(r).filter(func(x): return x.begins_with("water"))
	assert_eq(rules, [])

# --- water_contained (Sean, 2026-10-06: water always has something keeping it in, unless the whole floor is water) ---

const LEFT_BANK := Rect2(180, 240, 20, 80)    # beside the pool's left edge (200), its whole depth (240 to 320)
const RIGHT_BANK := Rect2(360, 240, 20, 80)   # beside its right edge (360)

func _contained(r: RoomDef) -> Array:
	return RoomLint.check_room(r, {"W1": r}).filter(func(f): return f["rule"] == "water_contained")

func test_a_pool_with_a_bank_each_side_and_the_floor_under_it_is_contained() -> void:
	assert_eq(_contained(_room([Rect2(200, 240, 160, 80)], [LEFT_BANK, RIGHT_BANK, Rect2(150, 245, 50, 12)])), [])

func test_a_pool_with_no_bank_on_a_side_is_reported_and_says_which() -> void:
	var left := _contained(_room([Rect2(200, 240, 160, 80)], [RIGHT_BANK]))
	assert_eq(left.size(), 1)
	assert_string_contains(left[0]["text"], "left")
	assert_false((left[0]["text"] as String).contains("right"))
	var right := _contained(_room([Rect2(200, 240, 160, 80)], [LEFT_BANK]))
	assert_string_contains(right[0]["text"], "right")
	var both := _contained(_room([Rect2(200, 240, 160, 80)], []))
	assert_string_contains(both[0]["text"], "left")
	assert_string_contains(both[0]["text"], "right")

func test_a_bank_a_hand_lower_than_the_surface_is_a_lip_and_still_holds_it() -> void:
	var lip := Rect2(360, 244, 20, 76)   # its top is 4 px under the surface (240): a lip, not a gap
	assert_eq(_contained(_room([Rect2(200, 240, 160, 80)], [LEFT_BANK, lip])), [])
	var low := Rect2(360, 256, 20, 64)   # 16 px under it: the top of the water stands unheld
	assert_eq(_contained(_room([Rect2(200, 240, 160, 80)], [LEFT_BANK, low])).size(), 1)

func test_a_bank_that_stops_short_of_the_water_s_depth_does_not_keep_it_in() -> void:
	var half := Rect2(180, 240, 20, 40)   # holds the top half of the left side only
	assert_eq(_contained(_room([Rect2(200, 240, 160, 80)], [half, RIGHT_BANK])).size(), 1)

func test_water_over_nothing_is_reported_and_water_on_the_floor_is_not() -> void:
	var floating := _contained(_room([Rect2(200, 200, 160, 80)], [Rect2(180, 200, 20, 80), Rect2(360, 200, 20, 80)]))
	assert_eq(floating.size(), 1, "the room's floor is at 320: this pool hangs in the air")
	assert_string_contains(floating[0]["text"], "under")
	var on_a_ledge := _contained(_room([Rect2(200, 200, 160, 60)], [Rect2(180, 200, 20, 80), Rect2(360, 200, 20, 80), Rect2(200, 260, 160, 60)]))
	assert_eq(on_a_ledge, [], "a slab of rock under it holds it")

func test_a_ledge_you_can_jump_up_through_holds_no_water() -> void:
	assert_true(RoomBuilder.is_one_way(Rect2(200, 280, 160, 12)), "wide and low enough to be one-way: things pass through it")
	var r := _room([Rect2(200, 240, 160, 40)], [LEFT_BANK, RIGHT_BANK, Rect2(200, 280, 160, 12)])
	assert_eq(_contained(r).size(), 1, "a one-way ledge under the water is not a floor")

func test_water_that_runs_to_the_rooms_edge_or_all_across_it_is_kept_in_by_the_room() -> void:
	var size := Vector2(1.0, 1.0) * RoomDef.SCREEN
	var across := _room([Rect2(0, 240, size.x, 80)])
	assert_eq(_contained(across), [], "the whole width is water: the room's walls keep it in")
	var from_the_left := _room([Rect2(0, 240, 200, 80)], [Rect2(200, 240, 20, 80)])
	assert_eq(_contained(from_the_left), [], "it reaches the left edge (a wall, or a doorway into more water): only the right needs a bank")

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
