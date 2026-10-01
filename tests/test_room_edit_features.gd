extends GutTest
## Features: placement on the surface below the click, ids, hit boxes, drag and delete; P1's floor_spot rule is unchanged.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func _features(room: String, kind := "") -> Array:
	return model.rooms[room].features.filter(func(f): return kind == "" or f["kind"] == kind)

# --- surface_below and floor_spot ---

func test_surface_below_finds_floor_ledge_and_refuses_rock_holes_and_outside() -> void:
	var r: RoomDef = model.rooms["C1"]
	r.solids = [Rect2(200, 250, 100, 12)]
	var floor_y: float = r.pixel_size().y - RoomDef.FLOOR
	assert_eq(model.surface_below("C1", Vector2(250, 100)), 250.0, "a ledge")
	assert_eq(model.surface_below("C1", Vector2(120, 100)), floor_y, "the floor")
	assert_null(model.surface_below("C1", Vector2(250, 255)), "inside rock")
	assert_null(model.surface_below("C1", Vector2(-10, 100)), "outside the room")

func test_surface_below_counts_a_closed_gate_only_when_asked() -> void:
	var r: RoomDef = model.rooms["C6"]
	var gate := Rect2(0, 0, 0, 0)
	for e in r.exits:
		if e.has("shortcut"):
			gate = RoomBuilder.gate_rect(r.pixel_size(), e)
	assert_ne(gate.size, Vector2.ZERO, "C6 has a shortcut exit in its floor")
	var p := Vector2(gate.get_center().x, 100)
	assert_null(model.surface_below("C6", p), "to a feature the gate is not rock: it vanishes when opened")
	assert_eq(model.surface_below("C6", p, true), gate.position.y)

func test_floor_spot_keeps_its_p1_behaviour_and_counts_gates_by_default() -> void:
	var r: RoomDef = model.rooms["C1"]
	r.solids = [Rect2(200, 250, 100, 12)]
	assert_eq(model.floor_spot("C1", Vector2(250, 100)), Vector2(250, 250 - BodyConfig.BOTTOM))
	assert_null(model.floor_spot("C1", Vector2(250, 255)), "inside rock")
	var c6: RoomDef = model.rooms["C6"]
	var gate: Rect2 = RoomBuilder.gate_rect(c6.pixel_size(), c6.exits.filter(func(e): return e.has("shortcut"))[0])
	var over := Vector2(gate.get_center().x, 100)
	assert_eq(model.floor_spot("C6", over), Vector2(over.x, gate.position.y - BodyConfig.BOTTOM), "a closed gate is a surface for Play")
	assert_null(model.floor_spot("C6", over, false), "with shortcuts open there is a hole")

# --- placing ---

func test_each_kind_is_placed_on_the_surface_with_its_defaults_and_selected() -> void:
	assert_eq(model.add_feature("C2", "tablet", Vector2(404, 100)), "")
	var t: Dictionary = _features("C2", "tablet").back()
	assert_eq(t["pos"].x, 404.0)
	assert_eq([t["title"], t["text"]], ["Tablet", ""])
	assert_eq(model.selection["kind"], "feature")
	assert_eq(model.add_feature("C2", "switch", Vector2(600, 100)), "")
	var s: Dictionary = _features("C2", "switch").back()
	assert_eq(s["shortcut"], s["id"], "a switch starts with its own id as its shortcut")
	assert_eq(model.add_feature("C2", "rebirth_pool", Vector2(700, 100)), "")
	var p: Dictionary = _features("C2", "rebirth_pool").back()
	assert_eq([p["area"], p["kit"]], ["cave", {}])
	assert_eq(model.add_feature("C2", "glow_pool", Vector2(800, 100)), "")
	assert_eq(model.undo_depth(), 4)

func test_a_feature_on_a_ledge_stands_on_top_of_it() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 100, 12)]
	assert_eq(model.add_feature("C2", "tablet", Vector2(240, 120)), "")
	assert_eq(_features("C2", "tablet").back()["pos"], Vector2(240, 200))
	assert_eq(RoomLint.text(RoomLint.check_room(r, model.rooms), ["in_rock"]), "", "a feature on a ledge is clean")

func test_placing_is_refused_in_rock_in_a_wall_in_a_doorway_over_a_hole_and_outside() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 100, 40)]
	assert_ne(model.add_feature("C2", "tablet", Vector2(250, 220)), "", "inside a solid")
	assert_ne(model.add_feature("C2", "tablet", Vector2(12, 100)), "", "x 12 is in the wall column")
	assert_ne(model.add_feature("C2", "tablet", Vector2(-50, 100)), "", "outside")
	assert_ne(model.add_feature("C2", "teapot", Vector2(300, 100)), "", "an unknown kind")
	var left_exit_y: float = (r.exits.filter(func(e): return e["edge"] == "left")[0]["from"] + 20.0)
	assert_ne(model.add_feature("C2", "tablet", Vector2(10, left_exit_y)), "", "a side doorway")
	assert_eq(model.undo_depth(), 0)
	var c5: RoomDef = model.rooms["C5"]
	var hole: Dictionary = c5.exits.filter(func(e): return e["edge"] == "bottom")[0]
	var mid := (float(hole["from"]) + float(hole["to"])) / 2.0
	assert_ne(model.add_feature("C5", "tablet", Vector2(mid, c5.pixel_size().y - 60.0)), "", "nothing below it")

func test_ids_are_unique_across_the_world_and_never_reuse_a_taken_one() -> void:
	model.add_feature("C2", "tablet", Vector2(404, 100))
	model.add_feature("C2", "tablet", Vector2(500, 100))
	var ids := _features("C2", "tablet").map(func(f): return f["id"])
	assert_eq(ids, ["c2_tablet_1", "c2_tablet_2"])
	model.select({"room": "C2", "kind": "feature", "index": 0})
	model.delete_selection()
	model.add_feature("C2", "tablet", Vector2(600, 100))
	assert_eq(_features("C2", "tablet").map(func(f): return f["id"]), ["c2_tablet_2", "c2_tablet_1"], "the first unused n")

# --- selection, drag, delete ---

func test_hit_finds_a_feature_by_its_drawn_box_and_a_pools_upper_half() -> void:
	model.add_feature("C2", "tablet", Vector2(404, 100))
	var base: Vector2 = _features("C2", "tablet").back()["pos"]
	assert_eq(model.hit("C2", base + Vector2(0, -12), 0.0).get("kind", ""), "feature", "the tablet's body above its base")
	assert_ne(model.hit("C2", base + Vector2(0, 30), 0.0).get("kind", ""), "feature")
	model.add_feature("C2", "glow_pool", Vector2(600, 100))
	var pool: Vector2 = _features("C2", "glow_pool").back()["pos"]
	assert_eq(model.hit("C2", pool + Vector2(0, -15), 0.0).get("kind", ""), "feature", "the pool's upper half")
	assert_eq(model.hit("C2", pool + Vector2(17, 2), 0.0).get("kind", ""), "feature", "near its edge")

func test_spawns_beat_features_which_beat_exits_and_solids() -> void:
	model.add_feature("C2", "tablet", Vector2(404, 100))
	var base: Vector2 = _features("C2", "tablet").back()["pos"]
	model.rooms["C2"].spawns.append({"id": "toad", "pos": base + Vector2(0, -8)})
	assert_eq(model.hit("C2", base + Vector2(0, -8), 0.0).get("kind", ""), "spawn")

func test_a_feature_drags_along_the_floor_and_between_coplanar_ledges() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 60, 12), Rect2(300, 200, 60, 12)]
	model.add_feature("C2", "tablet", Vector2(220, 100))
	var sel := {"room": "C2", "kind": "feature", "index": r.features.size() - 1}
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(100, 0))
	assert_eq(r.features[sel["index"]]["pos"], Vector2(320, 200), "onto the next ledge at the same height")
	model.end_move()
	assert_eq(model.undo_depth(), 2, "the placement and the drag are one step each")
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(0, 0))
	model.end_move()
	assert_eq(model.undo_depth(), 2, "a click, or a drag that ends where it began, pushes none")
	var floor_y: float = r.pixel_size().y - RoomDef.FLOOR
	model.begin_move(sel)
	model.move_to(Vector2(-60, 100))
	assert_eq(r.features[sel["index"]]["pos"], Vector2(260, floor_y), "left of the ledges and below them: dropped to the floor")
	model.end_move()

func test_a_feature_on_a_ledge_whose_top_is_off_the_grid_still_drags() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 266, 120, 12)]  # 266 is not a multiple of GRID: C1's ledges are like this
	assert_eq(model.add_feature("C2", "tablet", Vector2(220, 100)), "")
	var sel := {"room": "C2", "kind": "feature", "index": r.features.size() - 1}
	assert_eq(r.features[sel["index"]]["pos"], Vector2(220, 266))
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(60, 0))
	assert_eq(r.features[sel["index"]]["pos"], Vector2(280, 266), "the base y is a surface top, never snapped into the ledge")
	model.end_move()

func test_a_pointer_that_dips_into_the_surface_keeps_the_feature_sliding_along_it() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = []
	var floor_y: float = r.pixel_size().y - RoomDef.FLOOR
	assert_eq(model.add_feature("C2", "tablet", Vector2(220, 100)), "")
	var sel := {"room": "C2", "kind": "feature", "index": r.features.size() - 1}
	assert_eq(r.features[sel["index"]]["pos"], Vector2(220, floor_y))
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(40, 4))  # a hand never drags dead level: the pointer is a pixel or two below the floor line
	assert_eq(r.features[sel["index"]]["pos"], Vector2(260, floor_y), "it follows along the floor")
	model.move_to(Vector2(80, 2))
	assert_eq(r.features[sel["index"]]["pos"], Vector2(300, floor_y))
	model.end_move()

func test_a_pointer_that_dips_into_a_ledge_keeps_the_feature_on_it() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 160, 12)]
	assert_eq(model.add_feature("C2", "tablet", Vector2(220, 100)), "")
	var sel := {"room": "C2", "kind": "feature", "index": r.features.size() - 1}
	model.begin_move(sel)
	model.move_to(Vector2(60, 6))
	assert_eq(r.features[sel["index"]]["pos"], Vector2(280, 200), "still on the ledge, not stuck at 220")
	model.end_move()

func test_a_drag_into_rock_stays_at_the_last_valid_spot() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(400, 100, 100, 220)]  # down to the floor
	model.add_feature("C2", "tablet", Vector2(300, 100))
	var sel := {"room": "C2", "kind": "feature", "index": r.features.size() - 1}
	var start: Vector2 = r.features[sel["index"]]["pos"]
	model.begin_move(sel)
	model.move_to(Vector2(120, 0))
	assert_eq(r.features[sel["index"]]["pos"], start, "x 420 is inside the solid")
	model.end_move()

func test_delete_removes_a_feature_and_never_an_exit() -> void:
	model.add_feature("C2", "tablet", Vector2(404, 100))
	var exits_before: Array = model.rooms["C2"].exits.duplicate(true)
	var n := _features("C2").size()
	assert_eq(model.delete_selection(), "")
	assert_eq(_features("C2").size(), n - 1)
	assert_eq(model.rooms["C2"].exits, exits_before, "Delete on a feature leaves the exits alone")
	model.select({"room": "C2", "kind": "teapot", "index": 0})  # not a kind (decor became one in P3)
	assert_ne(model.delete_selection(), "", "an unknown kind is refused, never routed to an exit")
	assert_eq(model.rooms["C2"].exits, exits_before)
	model.select({"room": "C2", "kind": "teapot", "index": 0})
	assert_false(model.begin_move(model.selection))

func test_a_new_feature_is_lint_clean_and_undo_restores_the_room() -> void:
	var before := RoomEditModel.copy_room(model.rooms["C2"])
	model.add_feature("C2", "glow_pool", Vector2(404, 100))
	assert_eq(RoomLint.text(RoomLint.check(model.rooms), RoomLint.RULES), "")
	model.undo()
	assert_true(RoomEditModel.same_room(before, model.rooms["C2"]))

# --- decor ---

func _decor(room: String) -> Array:
	return model.rooms[room].decor

func test_surface_above_is_the_underside_of_the_first_rock_and_null_in_rock_or_under_a_top_exit() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 100, 100, 12)]
	assert_eq(model.surface_above("C2", Vector2(250, 200)), 112.0, "the ledge's underside")
	assert_eq(model.surface_above("C2", Vector2(50, 200)), 20.0, "the generated ceiling")
	assert_null(model.surface_above("C2", Vector2(250, 105)), "inside rock")
	var top: Dictionary = r.exits.filter(func(e): return e["edge"] == "top")[0]
	var mid := (float(top["from"]) + float(top["to"])) / 2.0
	assert_null(model.surface_above("C2", Vector2(mid, 200)), "under a top exit the ceiling is cut: nothing to hang from")

func test_a_standing_piece_stands_on_the_surface_below_and_a_hanging_one_hangs_from_the_rock_above() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 100, 12)]
	assert_eq(model.add_decor("C2", "crystal_teal", Vector2(240, 120)), "")
	assert_eq(_decor("C2").back(), DecorLib.entry("crystal_teal", Vector2(240, 200)))
	assert_eq(model.selection["kind"], "decor")
	assert_eq(model.add_decor("C2", "vine", Vector2(240, 300)), "")
	assert_eq(_decor("C2").back(), DecorLib.entry("vine", Vector2(240, 212)), "hangs from the ledge's underside")
	assert_eq(model.undo_depth(), 2)

func test_decor_placement_is_refused_with_no_surface_an_unknown_id_or_outside() -> void:
	var r: RoomDef = model.rooms["C2"]
	var top: Dictionary = r.exits.filter(func(e): return e["edge"] == "top")[0]
	var mid := (float(top["from"]) + float(top["to"])) / 2.0
	assert_ne(model.add_decor("C2", "vine", Vector2(mid, 200)), "", "a hanging piece under a top exit")
	assert_ne(model.add_decor("C2", "no_such_sprite", Vector2(300, 200)), "", "an id outside the catalog")
	assert_ne(model.add_decor("C2", "crystal_teal", Vector2(-50, 200)), "", "outside the room")
	assert_eq(model.undo_depth(), 0)

func test_decor_hits_its_ungrown_box_so_a_ledge_beside_it_is_still_the_first_hit() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.spawns = []
	r.features = []
	r.solids = [Rect2(200, 200, 100, 12)]
	r.decor = [DecorLib.entry("crystal_teal", Vector2(260, 200))]
	var box := DecorLib.texture_box("crystal_teal")
	var on_art := Vector2(260, 200) + box.position + box.size / 2.0
	assert_eq(model.hit("C2", on_art, 8.0)["kind"], "decor", "on the crystal's art")
	assert_eq(model.hit("C2", Vector2(210, 206), 8.0)["kind"], "solid", "on the ledge, away from the crystal")
	assert_eq(model.hit("C2", Vector2(260, 206), 8.0)["kind"], "solid", "on the ledge under the crystal's foot: the box ends at the ledge's top")

func test_decor_drags_along_a_ledge_keeps_sliding_when_the_pointer_dips_and_deletes() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 160, 12)]
	r.decor = [DecorLib.entry("crystal_teal", Vector2(220, 200))]
	var sel := {"room": "C2", "kind": "decor", "index": 0}
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(60, 4))   # the pointer dips below the ledge top
	assert_eq(r.decor[0]["pos"], Vector2(280, 200))
	model.end_move()
	model.select(sel)
	assert_eq(model.delete_selection(), "")
	assert_eq(r.decor.size(), 0)
	model.undo()
	assert_eq(model.rooms["C2"].decor.size(), 1, "undo swaps in a restored room object, so read it from the model")

func test_an_unknown_decor_id_can_be_selected_and_deleted() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.spawns = []
	r.features = []
	r.decor = [{"id": "no_such_sprite", "pos": Vector2(300, 300), "anchor": "top"}]
	var box := DecorLib.box_of(r.decor[0])
	var inside := Vector2(300, 300) + box.position + box.size / 2.0
	assert_eq(model.hit("C2", inside, 0.0), {"room": "C2", "kind": "decor", "index": 0})
	model.select(model.hit("C2", inside, 0.0))
	assert_eq(model.delete_selection(), "")
	assert_eq(r.decor, [])

func test_a_closed_shortcut_gate_is_not_rock_to_hang_from() -> void:
	var r: RoomDef = model.rooms["C1"]
	var top: Dictionary = r.exits.filter(func(e): return e["edge"] == "top" and e.has("shortcut"))[0]
	var mid := (float(top["from"]) + float(top["to"])) / 2.0
	assert_null(model.surface_above("C1", Vector2(mid, 200)), "the gate vanishes when the shortcut opens")
	assert_ne(model.add_decor("C1", "vine", Vector2(mid, 200)), "")

func test_a_hand_edited_top_anchored_piece_is_boxed_below_its_position_and_drags_along_the_rock_above() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.spawns = []
	r.features = []
	r.solids = [Rect2(200, 200, 160, 12)]
	r.decor = [{"id": "no_such_sprite", "pos": Vector2(240, 212), "anchor": "top"}]
	var below := Vector2(240, 212) + DecorLib.UNKNOWN_BOX.size / 2.0 * Vector2(0.0, 1.0)
	assert_eq(model.hit("C2", below, 0.0), {"room": "C2", "kind": "decor", "index": 0}, "a hanging piece's box is under its position")
	var sel := {"room": "C2", "kind": "decor", "index": 0}
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(40, 0))
	assert_eq(r.decor[0]["pos"], Vector2(280, 212), "it keeps hanging from the ledge's underside, not dropped onto a floor")

func test_a_hand_edited_piece_without_an_anchor_stands_even_when_the_catalog_says_it_hangs() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 160, 12)]
	r.decor = [{"id": "vine", "pos": Vector2(240, 200)}]   # RoomBuilder.build_decor reads the entry's anchor, default bottom
	assert_eq(DecorLib.box_of(r.decor[0]).position.y, -float(Art.texture("vine").get_height()), "the box ends at the position")
