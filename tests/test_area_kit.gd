extends GutTest
## The kit area modules build rooms with: ledges, stairs, spawns and exits written from one world span.

func _world(rooms: Array) -> Dictionary:
	var out := {}
	for r in rooms:
		out[r.id] = r
	return out

func _problems(rooms: Array) -> Array:
	return Array(WorldValidator.validate(_world(rooms)))

func test_a_room_has_its_id_area_cell_and_size() -> void:
	var r := AreaKit.room("T1", "forest", Vector2i(3, -2), Vector2i(2, 1))
	assert_eq(r.id, "T1")
	assert_eq(r.area, "forest")
	assert_eq(r.cell, Vector2i(3, -2))
	assert_eq(r.size, Vector2i(2, 1))
	assert_eq(AreaKit.room("T2", "forest", Vector2i.ZERO).size, Vector2i.ONE)

func test_the_floor_is_the_room_height_less_the_floor_slab() -> void:
	assert_eq(AreaKit.floor_y(AreaKit.room("T", "forest", Vector2i.ZERO)), 320.0)
	assert_eq(AreaKit.floor_y(AreaKit.room("T", "forest", Vector2i.ZERO, Vector2i(1, 3))), 1040.0)

func test_a_creature_stands_its_body_bottom_above_the_surface() -> void:
	assert_eq(AreaKit.stand(320.0), 320.0 - Enemy.BODY_BOTTOM)

func test_a_ledge_is_twelve_thick_with_its_top_at_y() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	var l := AreaKit.ledge(r, 60.0, 268.0, 100.0)
	assert_eq(l, Rect2(60, 268, 100, 12))
	assert_eq(r.solids, [l])

func test_stairs_climb_a_rise_and_a_step_each_ledge() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	var made := AreaKit.stairs(r, 60.0, 268.0, 90.0, 52.0, 3, 100.0)
	assert_eq(made, [Rect2(60, 268, 100, 12), Rect2(150, 216, 100, 12), Rect2(240, 164, 100, 12)])
	assert_eq(r.solids, made)

func test_stairs_refuse_a_rise_the_base_jump_cannot_make() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	assert_eq(AreaKit.stairs(r, 60.0, 268.0, 90.0, RoomLint.REACH_RISE + 1.0, 3, 100.0), [])
	assert_eq(r.solids, [])

func test_stairs_from_the_floor_pass_the_ledge_reach_rule() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	AreaKit.stairs(r, 60.0, 268.0, 90.0, 52.0, 4, 100.0)
	var findings := RoomLint.check_room(r, _world([r])).filter(func(f: Dictionary) -> bool: return f["rule"] == "ledge_reach")
	assert_eq(findings, [])

func test_a_ledge_too_high_to_reach_fails_the_rule_the_kit_is_built_to_keep() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	AreaKit.ledge(r, 60.0, 150.0, 100.0)
	var findings := RoomLint.check_room(r, _world([r])).filter(func(f: Dictionary) -> bool: return f["rule"] == "ledge_reach")
	assert_eq(findings.size(), 1)

# --- links ---

func test_link_writes_both_ends_of_an_exit_from_one_world_span() -> void:
	var a := AreaKit.room("A", "forest", Vector2i(0, 0))
	var b := AreaKit.room("B", "forest", Vector2i(1, 0))
	AreaKit.start(a, 60.0)
	assert_true(AreaKit.link(a, b, "right", 100.0, 180.0))
	assert_eq(a.exits, [{"edge": "right", "from": 100.0, "to": 180.0, "room": "B"}])
	assert_eq(b.exits, [{"edge": "left", "from": 100.0, "to": 180.0, "room": "A"}])
	assert_eq(_problems([a, b]), [])

func test_link_converts_the_span_into_each_rooms_own_pixels() -> void:
	var a := AreaKit.room("A", "forest", Vector2i(0, 0), Vector2i(1, 2))
	var b := AreaKit.room("B", "forest", Vector2i(1, 1))
	AreaKit.start(a, 60.0)
	assert_true(AreaKit.link(a, b, "right", 400.0, 480.0))
	assert_eq(a.exits[0]["from"], 400.0)
	assert_eq(b.exits[0]["from"], 40.0)
	assert_eq(b.exits[0]["to"], 120.0)
	assert_eq(_problems([a, b]), [])

func test_link_works_for_a_room_above_another() -> void:
	var a := AreaKit.room("A", "forest", Vector2i(0, 0))
	var b := AreaKit.room("B", "forest", Vector2i(0, 1))
	AreaKit.start(a, 60.0)
	assert_true(AreaKit.link(a, b, "bottom", 200.0, 280.0))
	assert_eq(a.exits[0], {"edge": "bottom", "from": 200.0, "to": 280.0, "room": "B"})
	assert_eq(b.exits[0], {"edge": "top", "from": 200.0, "to": 280.0, "room": "A"})
	assert_eq(_problems([a, b]), [])

func test_link_carries_a_gate_or_shortcut_to_both_ends() -> void:
	var a := AreaKit.room("A", "forest", Vector2i(0, 0))
	var b := AreaKit.room("B", "forest", Vector2i(1, 0))
	AreaKit.link(a, b, "right", 100.0, 180.0, {"gate": "swim"})
	assert_eq(a.exits[0]["gate"], "swim")
	assert_eq(b.exits[0]["gate"], "swim")

func test_link_refuses_rooms_that_do_not_touch_and_adds_nothing() -> void:
	var a := AreaKit.room("A", "forest", Vector2i(0, 0))
	var b := AreaKit.room("B", "forest", Vector2i(2, 0))
	assert_false(AreaKit.link(a, b, "right", 100.0, 180.0))
	assert_eq(a.exits, [])
	assert_eq(b.exits, [])

func test_link_refuses_a_span_outside_either_rooms_edge() -> void:
	var a := AreaKit.room("A", "forest", Vector2i(0, 0))
	var b := AreaKit.room("B", "forest", Vector2i(1, 0))
	assert_false(AreaKit.link(a, b, "right", 10.0, 80.0), "inside the corner")
	assert_false(AreaKit.link(a, b, "right", 100.0, 330.0), "into the floor")
	assert_eq(a.exits, [])

func test_link_refuses_an_empty_or_backwards_span() -> void:
	var a := AreaKit.room("A", "forest", Vector2i(0, 0))
	var b := AreaKit.room("B", "forest", Vector2i(1, 0))
	assert_false(AreaKit.link(a, b, "right", 180.0, 100.0))
	assert_false(AreaKit.link(a, b, "right", 100.0, 100.0))
	assert_eq(a.exits, [])

func test_link_refuses_an_edge_that_is_not_one() -> void:
	var a := AreaKit.room("A", "forest", Vector2i(0, 0))
	var b := AreaKit.room("B", "forest", Vector2i(1, 0))
	assert_false(AreaKit.link(a, b, "middle", 100.0, 180.0))

func test_link_refuses_a_span_that_only_one_room_has() -> void:
	var a := AreaKit.room("A", "forest", Vector2i(0, 0), Vector2i(1, 2))
	var b := AreaKit.room("B", "forest", Vector2i(1, 1))
	assert_false(AreaKit.link(a, b, "right", 100.0, 180.0), "B starts a screen lower")
	assert_eq(a.exits, [])

# --- the small writers ---

func test_spawn_decor_and_feature_stand_on_the_surface_given() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	AreaKit.spawn(r, "bat", 100.0, 320.0)
	AreaKit.decor(r, "glow_fungus", 200.0, 320.0, {"light": Color(0.5, 1, 0.6, 1)})
	AreaKit.feature(r, "glow_pool", "FOREST_POOL", 300.0, 320.0)
	assert_eq(r.spawns, [{"id": "bat", "pos": Vector2(100, 320.0 - Enemy.BODY_BOTTOM)}])
	assert_eq(r.decor, [{"id": "glow_fungus", "pos": Vector2(200, 320), "light": Color(0.5, 1, 0.6, 1)}], "an extra overrides the catalog's")
	assert_eq(r.features, [{"kind": "glow_pool", "id": "FOREST_POOL", "pos": Vector2(300, 320)}])

func test_decor_is_the_catalogs_entry_with_its_light_and_anchor() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	AreaKit.decor(r, "grotto_flowers", 280.0, 268.0)
	AreaKit.decor(r, "grotto_root_hang", 360.0, 20.0)
	AreaKit.decor(r, "grotto_rubble", 400.0, 320.0)
	assert_eq(r.decor[0], DecorLib.entry("grotto_flowers", Vector2(280, 268)))
	assert_eq(r.decor[0]["light"], DecorLib.CATALOG["grotto_flowers"]["light"])
	assert_eq(r.decor[1], DecorLib.entry("grotto_root_hang", Vector2(360, 20)))
	assert_eq(r.decor[1]["anchor"], "top")
	assert_eq(r.decor[2], DecorLib.entry("grotto_rubble", Vector2(400, 320)))
	assert_false(r.decor[2].has("light"))

func test_start_is_on_the_floor_stand_and_passes_the_start_rule() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	AreaKit.start(r, 80.0)
	assert_eq(r.start, Vector2(80.0, 320.0 - BodyConfig.BOTTOM))
	var findings := RoomLint.check_room(r, _world([r])).filter(func(f: Dictionary) -> bool: return f["rule"] == "start_floor")
	assert_eq(findings, [])

# --- the vertical-exit pattern: a climb up to a ceiling opening, a landing either side of a floor opening ---

func test_climb_ends_in_the_ceiling_opening() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	var made := AreaKit.climb(r, 240.0, 400.0)
	assert_eq(r.solids, made)
	var last: Rect2 = made[-1]
	assert_eq(last.position.y, 14.0, "the last ledge's top is in the opening")
	for l: Rect2 in made:
		assert_gte(l.position.x, 240.0)
		assert_lte(l.end.x, 400.0 + 0.001, "every ledge stands inside the opening's span")
		assert_gte(l.size.x, 60.0, "wide enough to stand on")

func test_climb_in_a_one_screen_room_matches_the_forests_clearing() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO)
	var made := AreaKit.climb(r, 240.0, 400.0)
	assert_eq(made.size(), 6)
	assert_eq((made[0] as Rect2).position.y, 274.0)
	assert_eq(made, [Rect2(240, 274, 90, 12), Rect2(310, 222, 90, 12), Rect2(240, 170, 90, 12), Rect2(310, 118, 90, 12),
		Rect2(240, 66, 90, 12), Rect2(310, 14, 90, 12)])

func test_climb_in_a_tall_room_keeps_every_rise_within_the_base_jump_and_passes_ledge_reach() -> void:
	var r := AreaKit.room("T", "swamp", Vector2i.ZERO, Vector2i(1, 2))
	var made := AreaKit.climb(r, 240.0, 400.0)
	for i in range(1, made.size()):
		assert_lte((made[i - 1] as Rect2).position.y - (made[i] as Rect2).position.y, 52.0 + 0.001)
	assert_eq((made[-1] as Rect2).position.y, 14.0)
	var findings := RoomLint.check_room(r, _world([r])).filter(func(f: Dictionary) -> bool: return f["rule"] == "ledge_reach")
	assert_eq(findings, [])

func test_flank_stands_either_side_of_the_opening_a_hop_above_the_floor() -> void:
	var r := AreaKit.room("T", "forest", Vector2i.ZERO, Vector2i(1, 3))
	var made := AreaKit.flank(r, 240.0, 400.0)
	assert_eq(made, [Rect2(100, 988, 100, 12), Rect2(420, 988, 100, 12)])
	assert_eq(r.solids, made)
