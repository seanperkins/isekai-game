extends GutTest
## RoomLint: the suite's level-design rules as one module. Shipped rooms are clean; each rule goes red on a synthetic room.

func _room(id := "T1", extra := {}) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.area = "cave"
	for k in extra:
		r.set(k, extra[k])
	return r

func _rules(r: RoomDef, rooms := {}) -> Array:
	var world := rooms if not rooms.is_empty() else {r.id: r}
	return RoomLint.check_room(r, world).map(func(f): return f["rule"])

func test_the_shipped_world_has_no_findings() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	assert_eq(RoomLint.text(RoomLint.check(rooms), RoomLint.RULES), "")

func test_a_finding_names_its_room_rule_text_and_pick() -> void:
	var r := _room("T1", {"spawns": [{"id": "toad", "pos": Vector2(5, 5)}]})  # inside the boundary wall
	var f: Dictionary = RoomLint.check_room(r, {"T1": r})[0]
	assert_eq([f["room"], f["rule"]], ["T1", "in_rock"])
	assert_eq(f["pick"], {"room": "T1", "kind": "spawn", "index": 0})
	assert_string_contains(f["text"], "toad")

func test_text_joins_only_the_named_rules() -> void:
	var r := _room("T1", {"spawns": [{"id": "toad", "pos": Vector2(5, 5)}], "solids": [Rect2(600, 100, 100, 20)]})
	var findings := RoomLint.check_room(r, {"T1": r})
	assert_ne(RoomLint.text(findings, ["in_rock"]), "")
	assert_ne(RoomLint.text(findings, ["solid_outside"]), "")
	assert_eq(RoomLint.text(findings, ["exit_narrow"]), "")

func test_solid_outside() -> void:
	assert_true(_rules(_room("T1", {"solids": [Rect2(600, 100, 100, 20)]})).has("solid_outside"))
	assert_false(_rules(_room("T1", {"solids": [Rect2(100, 100, 100, 20)]})).has("solid_outside"))

func test_outside_covers_spawns_and_the_start() -> void:
	assert_true(_rules(_room("T1", {"spawns": [{"id": "toad", "pos": Vector2(900, 100)}]})).has("outside"))
	assert_true(_rules(_room("T1", {"start": Vector2(-5, 308)})).has("outside"))
	assert_false(_rules(_room("T1", {"spawns": [{"id": "toad", "pos": Vector2(300, 100)}]})).has("outside"))

func test_in_rock_for_spawns_and_the_start_includes_the_boundary_walls() -> void:
	assert_true(_rules(_room("T1", {"spawns": [{"id": "toad", "pos": Vector2(5, 100)}]})).has("in_rock"), "the left wall")
	assert_true(_rules(_room("T1", {"solids": [Rect2(100, 100, 100, 40)], "spawns": [{"id": "toad", "pos": Vector2(150, 120)}]})).has("in_rock"))
	assert_false(_rules(_room("T1", {"spawns": [{"id": "toad", "pos": Vector2(300, 100)}]})).has("in_rock"))

func test_a_feature_is_embedded_only_when_it_is_stuck() -> void:
	var r := _room("T1", {"solids": [Rect2(200, 200, 100, 12)]})
	assert_false(RoomLint.embedded(r, Vector2(250, 200)), "standing on top of a ledge")
	assert_false(RoomLint.embedded(r, Vector2(100, 320)), "standing on the floor")
	assert_true(RoomLint.embedded(r, Vector2(250, 204)), "four pixels into the ledge")
	assert_true(RoomLint.embedded(r, Vector2(12, 320)), "in the wall column")
	assert_true(RoomLint.embedded(r, Vector2(630, 320)), "in the right wall column")
	assert_true(RoomLint.embedded(r, Vector2(30, 320), "rebirth_pool"), "the pool's 38 px box reaches into the wall")
	assert_false(RoomLint.embedded(r, Vector2(40, 320), "rebirth_pool"))
	assert_true(RoomLint.embedded(r, Vector2(25, 320), "tablet"), "a 12 px tablet's box starts at x 19")
	assert_false(RoomLint.embedded(r, Vector2(26, 320), "tablet"), "half-open: its box starts exactly at the wall face")

func test_in_rock_flags_an_embedded_feature_and_not_one_on_a_ledge() -> void:
	var on_ledge := _room("T1", {"solids": [Rect2(200, 200, 100, 12)], "features": [{"kind": "tablet", "id": "t1_tablet_1", "pos": Vector2(250, 200), "title": "T"}]})
	assert_false(_rules(on_ledge).has("in_rock"))
	var sunk := _room("T1", {"solids": [Rect2(200, 200, 100, 12)], "features": [{"kind": "tablet", "id": "t1_tablet_1", "pos": Vector2(250, 204), "title": "T"}]})
	assert_true(_rules(sunk).has("in_rock"))

func test_exit_blocked_by_mass_but_not_by_a_ledge() -> void:
	var exit := {"edge": "right", "from": 200.0, "to": 320.0, "room": "T2"}
	var mass := _room("T1", {"exits": [exit], "solids": [Rect2(520, 200, 60, 100)]})
	assert_true(_rules(mass).has("exit_blocked"))
	var ledge := _room("T1", {"exits": [exit], "solids": [Rect2(520, 250, 60, 12)]})
	assert_false(_rules(ledge).has("exit_blocked"))

func test_exit_zone_starts_at_the_wall_face() -> void:
	var size := Vector2(640, 360)
	assert_eq(RoomLint.exit_zone(size, {"edge": "right", "from": 200.0, "to": 320.0}), Rect2(556, 200, 64, 120))
	assert_eq(RoomLint.exit_zone(size, {"edge": "left", "from": 200.0, "to": 320.0}), Rect2(20, 200, 64, 120))
	assert_eq(RoomLint.exit_zone(size, {"edge": "top", "from": 100.0, "to": 200.0}), Rect2(100, 20, 100, 64))
	assert_eq(RoomLint.exit_zone(size, {"edge": "bottom", "from": 100.0, "to": 200.0}), Rect2(100, 256, 100, 64))

func test_exit_narrow() -> void:
	assert_true(_rules(_room("T1", {"exits": [{"edge": "right", "from": 200.0, "to": 230.0, "room": "T2"}]})).has("exit_narrow"))
	assert_false(_rules(_room("T1", {"exits": [{"edge": "right", "from": 200.0, "to": 236.0, "room": "T2"}]})).has("exit_narrow"))

func test_min_exit_is_at_least_what_the_rigged_body_needs_on_every_edge() -> void:
	var body := BodyConfig.COLLISION * float(BodyConfig.SCALE)
	assert_gte(RoomLint.MIN_EXIT, body.y + 8.0, "a left or right exit")
	assert_gte(RoomLint.MIN_EXIT, body.x + 8.0, "a top or bottom exit")

func test_start_floor() -> void:
	var good := _room("T1", {"start": Vector2(60, 360.0 - RoomDef.FLOOR - BodyConfig.BOTTOM)})
	assert_false(_rules(good).has("start_floor"))
	assert_true(_rules(_room("T1", {"start": Vector2(60, 200)})).has("start_floor"))
	assert_false(_rules(_room("T1")).has("start_floor"), "a room that is not the start has nothing to check")

func test_ledge_reach_from_the_floor_by_base_jumps() -> void:
	# floor top 320; a ledge 50 up is reachable, one 130 up with nothing between is not
	var reachable := _room("T1", {"solids": [Rect2(200, 270, 100, 12)]})
	assert_false(_rules(reachable).has("ledge_reach"))
	var too_high := _room("T1", {"solids": [Rect2(200, 190, 100, 12)]})
	assert_true(_rules(too_high).has("ledge_reach"))
	var stepped := _room("T1", {"solids": [Rect2(200, 270, 100, 12), Rect2(320, 220, 100, 12)]})
	assert_false(_rules(stepped).has("ledge_reach"), "each hop within the budget")

func test_the_reach_budget_constants_are_the_suites_numbers() -> void:
	assert_eq([RoomLint.REACH_RISE, RoomLint.REACH_GAP, RoomLint.REACH_HOP], [55.0, 60.0, 80.0])

func _hole_room(extra := {}) -> RoomDef:
	var e := {"edge": "bottom", "from": 200.0, "to": 300.0, "room": "T2"}
	var base := {"exits": [e]}
	for k in extra:
		base[k] = extra[k]
	return _room("T1", base)

func test_over_hole_flags_a_spawn_or_decor_above_an_open_bottom_exit() -> void:
	assert_true(_rules(_hole_room({"spawns": [{"id": "bat", "pos": Vector2(250, 280)}]})).has("over_hole"))
	assert_true(_rules(_hole_room({"decor": [{"id": "crystal_teal", "pos": Vector2(250, 300)}]})).has("over_hole"))
	assert_false(_rules(_hole_room({"spawns": [{"id": "bat", "pos": Vector2(500, 280)}]})).has("over_hole"), "beside it")

func test_over_hole_checks_dressing_too() -> void:
	var piece: String = DressingLib.piece_names("cave")[0]
	assert_true(DressingLib.has_piece("cave", piece), "the test needs a real cave piece")
	var over := _hole_room({"dressing": [{"piece": piece, "pos": Vector2(250, 300), "factor": 0.5}]})
	assert_true(_rules(over).has("over_hole"))

func test_over_hole_skips_an_exit_with_a_gate_or_a_shortcut() -> void:
	for opts in [{"gate": "wall_cling"}, {"shortcut": "s1"}]:
		var e := {"edge": "bottom", "from": 200.0, "to": 300.0, "room": "T2"}
		e.merge(opts)
		var r := _room("T1", {"exits": [e], "spawns": [{"id": "bat", "pos": Vector2(250, 280)}]})
		assert_false(_rules(r).has("over_hole"), str(opts))

func _pool(id: String, area: String, pos: Vector2) -> Dictionary:
	return {"kind": "rebirth_pool", "id": id, "area": area, "pos": pos, "kit": {}}

func test_pool_clearance_applies_to_every_pool_but_the_default() -> void:
	var near := _room("T1", {"features": [_pool("t1_pool_1", "cave", Vector2(300, 320))], "spawns": [{"id": "toad", "pos": Vector2(400, 300)}]})
	assert_true(_rules(near).has("pool_clearance"), "a new cave pool is held to it too")
	var far := _room("T1", {"features": [_pool("t1_pool_1", "cave", Vector2(100, 320))], "spawns": [{"id": "toad", "pos": Vector2(400, 300)}]})
	assert_false(_rules(far).has("pool_clearance"))
	var default := _room("T1", {"features": [_pool(WorldProgress.DEFAULT_POOL, "cave", Vector2(300, 320))], "spawns": [{"id": "toad", "pos": Vector2(400, 300)}]})
	assert_false(_rules(default).has("pool_clearance"), "the default pool is older than the rule")
