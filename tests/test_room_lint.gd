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

func test_over_hole_skips_a_shortcut_exit_for_everything() -> void:
	var e := {"edge": "bottom", "from": 200.0, "to": 300.0, "room": "T2", "shortcut": "s1"}
	var piece: String = DressingLib.piece_names("cave")[0]
	var r := _room("T1", {"exits": [e], "spawns": [{"id": "bat", "pos": Vector2(250, 280)}],
		"decor": [DecorLib.entry("crystal_teal", Vector2(250, 300))],
		"dressing": [{"piece": piece, "pos": Vector2(250, 300), "factor": 0.5}]})
	assert_false(_rules(r).has("over_hole"))

func test_over_hole_counts_a_gated_hole_for_creatures_and_decor_but_not_dressing() -> void:
	var e := {"edge": "bottom", "from": 200.0, "to": 300.0, "room": "T2", "gate": "wall_cling"}
	var spawn := _room("T1", {"exits": [e], "spawns": [{"id": "bat", "pos": Vector2(250, 280)}]})
	assert_true(_rules(spawn).has("over_hole"), "only a shortcut closes a hole in play")
	var decor := _room("T1", {"exits": [e], "decor": [DecorLib.entry("crystal_teal", Vector2(250, 300))]})
	assert_true(_rules(decor).has("over_hole"))
	var piece: String = DressingLib.piece_names("cave")[0]
	var dressing := _room("T1", {"exits": [e], "dressing": [{"piece": piece, "pos": Vector2(250, 300), "factor": 0.5}]})
	assert_false(_rules(dressing).has("over_hole"), "C3's stone arch: dressing over a gated hole stays allowed")

func test_over_hole_measures_decor_by_its_texture_width() -> void:
	var wide := DecorLib.texture_box("deep_bones").size.x
	assert_gt(wide, 40.0, "the test needs a decor piece wider than the old fixed 24")
	var r := _hole_room({"area": "deep", "decor": [DecorLib.entry("deep_bones", Vector2(300.0 + 20.0, 320))]})
	assert_true(_rules(r).has("over_hole"), "its edge hangs over the hole although its centre is beside it")
	var far := _hole_room({"area": "deep", "decor": [DecorLib.entry("deep_bones", Vector2(300.0 + wide, 320))]})
	assert_false(_rules(far).has("over_hole"))

func test_decor_unknown_flags_an_id_outside_the_catalog_with_a_decor_pick() -> void:
	var bad := _room("T1", {"decor": [{"id": "no_such_sprite", "pos": Vector2(100, 320)}]})
	var f: Dictionary = RoomLint.check_room(bad, {"T1": bad}).filter(func(x): return x["rule"] == "decor_unknown")[0]
	assert_eq(f["pick"], {"room": "T1", "kind": "decor", "index": 0})
	var ok := _room("T1", {"decor": [DecorLib.entry("crystal_teal", Vector2(100, 320))]})
	assert_false(_rules(ok).has("decor_unknown"))

func test_the_rule_list_has_thirteen_rules() -> void:
	assert_eq(RoomLint.RULES.size(), 13)

func _pool(id: String, area: String, pos: Vector2) -> Dictionary:
	return {"kind": "rebirth_pool", "id": id, "area": area, "pos": pos, "kit": {}}

func test_pool_clearance_applies_to_every_pool_but_the_default() -> void:
	var near := _room("T1", {"features": [_pool("t1_pool_1", "cave", Vector2(300, 320))], "spawns": [{"id": "toad", "pos": Vector2(400, 300)}]})
	assert_true(_rules(near).has("pool_clearance"), "a new cave pool is held to it too")
	var far := _room("T1", {"features": [_pool("t1_pool_1", "cave", Vector2(100, 320))], "spawns": [{"id": "toad", "pos": Vector2(400, 300)}]})
	assert_false(_rules(far).has("pool_clearance"))
	var default := _room("T1", {"features": [_pool(WorldProgress.DEFAULT_POOL, "cave", Vector2(300, 320))], "spawns": [{"id": "toad", "pos": Vector2(400, 300)}]})
	assert_false(_rules(default).has("pool_clearance"), "the default pool is older than the rule")

func _feat(kind: String, id: String, extra := {}) -> Dictionary:
	var f := {"kind": kind, "id": id, "pos": Vector2(300, 320)}
	for k in extra:
		f[k] = extra[k]
	return f

func test_feature_id_flags_an_empty_or_duplicated_id_across_the_world() -> void:
	var a := _room("T1", {"features": [_feat("tablet", "dup", {"title": "T"})]})
	var b := _room("T2", {"cell": Vector2i(1, 0), "features": [_feat("glow_pool", "dup")]})
	var world := {"T1": a, "T2": b}
	assert_true(_rules(a, world).has("feature_id"))
	assert_true(_rules(b, world).has("feature_id"))
	var empty := _room("T1", {"features": [_feat("glow_pool", "")]})
	assert_true(_rules(empty).has("feature_id"))
	var ok := _room("T1", {"features": [_feat("glow_pool", "t1_glow_pool_1")]})
	assert_false(_rules(ok).has("feature_id"))

func test_shortcut_pair_in_both_directions() -> void:
	var exit_s := {"edge": "right", "from": 200.0, "to": 320.0, "room": "T2", "shortcut": "s1"}
	var lonely_exit := _room("T1", {"exits": [exit_s]})
	assert_true(_rules(lonely_exit).has("shortcut_pair"), "an exit with a shortcut and no switch can never open")
	var lonely_switch := _room("T1", {"features": [_feat("switch", "t1_switch_1", {"shortcut": "s1"})]})
	assert_true(_rules(lonely_switch).has("shortcut_pair"), "a switch whose shortcut no exit uses opens nothing")
	var paired := _room("T1", {"exits": [exit_s], "features": [_feat("switch", "t1_switch_1", {"shortcut": "s1"})]})
	assert_false(_rules(paired).has("shortcut_pair"))
	var across := {"T1": _room("T1", {"exits": [exit_s]}), "T2": _room("T2", {"cell": Vector2i(1, 0), "features": [_feat("switch", "t2_switch_1", {"shortcut": "s1"})]})}
	assert_false(_rules(across["T1"], across).has("shortcut_pair"), "the pair is world-wide")
	assert_false(_rules(across["T2"], across).has("shortcut_pair"))

func test_hint_unknown_accepts_only_skills_the_compendium_has_a_slot_for() -> void:
	var ok := _room("T1", {"features": [_feat("tablet", "t1_tablet_1", {"title": "T", "hint": "echolocation"})]})
	assert_false(_rules(ok).has("hint_unknown"))
	var none := _room("T1", {"features": [_feat("tablet", "t1_tablet_1", {"title": "T"})]})
	assert_false(_rules(none).has("hint_unknown"), "a hint is optional")
	var made_up := _room("T1", {"features": [_feat("tablet", "t1_tablet_1", {"title": "T", "hint": "spore shell"})]})
	assert_true(_rules(made_up).has("hint_unknown"))
	var enemy_only := _room("T1", {"features": [_feat("tablet", "t1_tablet_1", {"title": "T", "hint": "flight"})]})
	assert_true(_rules(enemy_only).has("hint_unknown"), "flight is an enemy-only skill: the Compendium has no slot for it")

func test_hintable_skill_ids_exclude_enemy_only_skills() -> void:
	var ids := RoomLint.hintable_skill_ids()
	assert_true(ids.has("echolocation"))
	assert_true(ids.has("spore_cloud"))
	assert_false(ids.has("flight"))
	assert_false(ids.has("poison_spit"))

func test_the_g4_tablet_hints_a_real_skill() -> void:
	var g4: RoomDef = load("res://data/rooms/G4.tres")
	var tablet: Dictionary = g4.features.filter(func(f): return f["kind"] == "tablet")[0]
	assert_true(RoomLint.hintable_skill_ids().has(tablet["hint"]), "was 'spore shell', which hinted nothing")
