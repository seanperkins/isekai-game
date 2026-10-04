extends GutTest
## Inspector fields: flat keys through get_field and set_field, one undo step each, required keys never removed.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func _feature_sel(room: String, kind: String) -> Dictionary:
	for i in model.rooms[room].features.size():
		if model.rooms[room].features[i]["kind"] == kind:
			return {"room": room, "kind": "feature", "index": i}
	return {}

func _exit_sel(room: String, to_room: String) -> Dictionary:
	for i in model.rooms[room].exits.size():
		if model.rooms[room].exits[i]["room"] == to_room:
			return {"room": room, "kind": "exit", "index": i}
	return {}

func test_a_tablets_title_and_text_round_trip_in_one_step_each() -> void:
	var sel := _feature_sel("C6", "tablet")
	assert_eq(model.get_field(sel, "title"), "Worn tablet")
	assert_eq(model.set_field(sel, "title", "Moss"), "")
	assert_eq(model.get_field(sel, "title"), "Moss")
	assert_eq(model.set_field(sel, "text", "A new line."), "")
	assert_eq(model.undo_depth(), 2)
	model.undo()
	assert_eq(model.get_field(sel, "text"), "Eat what hunts by sound in the dark, and you will hear as it does.")

func test_an_equal_value_is_a_no_op() -> void:
	var sel := _feature_sel("C6", "tablet")
	assert_eq(model.set_field(sel, "title", "Worn tablet"), "")
	assert_eq(model.undo_depth(), 0)
	assert_false(model.dirty.has("C6"))

func test_required_keys_are_never_removed_and_optional_ones_are() -> void:
	var sel := _feature_sel("C6", "tablet")
	assert_ne(model.set_field(sel, "title", ""), "", "a tablet needs a title")
	assert_eq(model.get_field(sel, "title"), "Worn tablet")
	assert_eq(model.set_field(sel, "text", ""), "", "text is optional")
	assert_eq(model.get_field(sel, "text"), "")
	var sw := _feature_sel("C6", "switch")
	assert_ne(model.set_field(sw, "shortcut", ""), "", "a switch needs its shortcut")
	assert_eq(model.get_field(sw, "shortcut"), "c6_drop")

func test_an_unknown_field_or_kind_is_refused() -> void:
	assert_ne(model.set_field(_feature_sel("C6", "tablet"), "colour", "red"), "")
	assert_ne(model.set_field(_feature_sel("C4", "glow_pool"), "title", "x"), "", "a glow pool has no title")

func test_a_shortcut_id_must_be_a_valid_id() -> void:
	var sw := _feature_sel("C6", "switch")
	assert_ne(model.set_field(sw, "shortcut", "has space"), "")
	assert_ne(model.set_field(sw, "shortcut", "../x"), "")
	assert_eq(model.set_field(sw, "shortcut", "new_path"), "")
	assert_eq(model.get_field(sw, "shortcut"), "new_path")

func test_an_exits_shortcut_lands_on_both_halves_in_one_step() -> void:
	var sel := _exit_sel("C1", "C2")
	assert_eq(model.get_field(sel, "shortcut"), "")
	assert_eq(model.set_field(sel, "shortcut", "front_door"), "")
	var partner := model.partner_of("C1", sel["index"])
	assert_eq(model.rooms["C2"].exits[partner["index"]].get("shortcut", ""), "front_door")
	assert_eq(model.undo_depth(), 1)
	assert_eq(model.set_field(sel, "shortcut", ""), "", "an empty value removes it from both")
	assert_false(model.rooms["C1"].exits[sel["index"]].has("shortcut"))
	assert_false(model.rooms["C2"].exits[partner["index"]].has("shortcut"))
	assert_eq("\n".join(model.validate()), "", "the validator still pairs them")

func test_the_perk_field_accepts_a_known_perk_and_clears_with_empty() -> void:
	var sel := _feature_sel("C1", "altar")
	assert_eq(model.get_field(sel, "perk"), "stats")
	assert_eq(model.set_field(sel, "perk", ""), "")
	assert_eq(model.get_field(sel, "perk"), "")
	assert_true(model.rooms["C1"].features[sel["index"]].has("perk"), "an altar always carries its perk key, even empty")
	assert_eq(model.undo_depth(), 1)
	assert_eq(model.set_field(sel, "perk", "stats"), "")
	assert_eq(model.get_field(sel, "perk"), "stats")
	assert_eq(model.undo_depth(), 2)
	assert_eq(model.set_field(sel, "perk", "stats"), "", "the stored value again")
	assert_eq(model.undo_depth(), 2, "an unchanged value pushes nothing")

func test_the_perk_field_refuses_an_unknown_perk_and_a_non_altar() -> void:
	var sel := _feature_sel("G1", "altar")
	var before := RoomEditModel.copy_room(model.rooms["G1"])
	assert_eq(model.set_field(sel, "perk", "nope"), "'nope' is not a perk")
	assert_true(RoomEditModel.same_room(before, model.rooms["G1"]))
	assert_eq(model.set_field(_feature_sel("C6", "tablet"), "perk", "stats"), "a tablet has no perk")
	assert_null(model.get_field(_feature_sel("C6", "switch"), "perk"), "a switch has no perk to read")
	assert_eq(model.undo_depth(), 0, "a refusal pushes nothing")

func test_an_altars_area_and_perk_are_required_keys() -> void:
	var sel := _feature_sel("G1", "altar")
	var f: Dictionary = model.rooms["G1"].features[sel["index"]]
	assert_true(f.has("area") and f.has("perk"))
	assert_false(f.has("kit"), "an altar has no kit")

func test_the_perk_ids_are_the_shipped_perks() -> void:
	assert_true(RoomEditModel.perk_ids().has("stats"))

# --- a solid's numbers ---

func _solid_sel(room: String, i: int) -> Dictionary:
	return {"room": room, "kind": "solid", "index": i}

func test_a_solids_numbers_read_back() -> void:
	var sel := _solid_sel("C1", 1)   # Rect2(420, 214, 100, 12)
	assert_eq([model.get_field(sel, "x"), model.get_field(sel, "y"), model.get_field(sel, "w"), model.get_field(sel, "h")], [420.0, 214.0, 100.0, 12.0])
	assert_eq(model.get_field(sel, "hard"), false)

func test_a_typed_number_is_not_snapped_and_is_one_step() -> void:
	var sel := _solid_sel("C1", 0)   # Rect2(260, 266, 120, 12): y 266 is off the grid
	assert_eq(model.set_field(sel, "y", 267.0), "")
	assert_eq(model.rooms["C1"].solids[0], Rect2(260, 267, 120, 12))
	assert_eq(model.undo_depth(), 1)
	assert_eq(model.set_field(sel, "y", 267.0), "", "the stored value is a no-op")
	assert_eq(model.undo_depth(), 1)

func test_a_solid_typed_outside_the_room_or_onto_another_is_refused_and_changes_nothing() -> void:
	var sel := _solid_sel("C1", 0)
	assert_ne(model.set_field(sel, "x", 1200.0), "", "260..380 moved to 1200..1320 leaves a 1280 room")
	assert_ne(model.set_field(sel, "w", 2.0), "", "below MIN_SOLID")
	assert_eq(model.undo_depth(), 0, "a refusal changes nothing")
	model.rooms["C1"].solids.append(Rect2(500, 100, 120, 12))
	var other := _solid_sel("C1", model.rooms["C1"].solids.size() - 1)
	assert_eq(model.set_field(other, "x", 260.0), "", "x alone does not make it identical")
	var depth: int = model.undo_depth()
	assert_eq(model.set_field(other, "y", 266.0), "an identical solid is already there")
	assert_eq(model.rooms["C1"].solids[other["index"]], Rect2(260, 100, 120, 12))
	assert_eq(model.undo_depth(), depth, "the refused set pushed nothing")

func test_rock_from_below_adds_and_removes_the_mark_on_a_thin_solid_only() -> void:
	var thin := _solid_sel("C1", 1)
	assert_eq(model.set_field(thin, "hard", true), "")
	assert_true(model.rooms["C1"].hard_ledges.has(Rect2(420, 214, 100, 12)))
	assert_eq(model.get_field(thin, "hard"), true)
	assert_eq(model.set_field(thin, "hard", false), "")
	assert_false(model.rooms["C1"].hard_ledges.has(Rect2(420, 214, 100, 12)))
	var thick := _solid_sel("C1", 5)   # Rect2(480, 272, 96, 48): rock
	assert_ne(model.set_field(thick, "hard", true), "", "only a thin solid can be rock from below")

func test_a_solid_that_stops_being_thin_loses_its_mark_in_the_same_step() -> void:
	var sel := _solid_sel("C1", 1)
	model.set_field(sel, "hard", true)
	assert_eq(model.set_field(sel, "h", 30.0), "")
	assert_eq(model.rooms["C1"].hard_ledges, [])
	assert_eq("\n".join(model.validate()), "", "the validator would reject a mark on a thick solid")

# --- an exit's gate and a tablet's hint ---

func test_an_exits_gate_lands_on_both_halves_in_one_step_and_none_removes_it() -> void:
	var sel := _exit_sel("C1", "C2")
	assert_eq(model.get_field(sel, "gate"), "")
	assert_eq(model.set_field(sel, "gate", "wall_cling"), "")
	var partner := model.partner_of("C1", sel["index"])
	assert_eq(model.rooms["C2"].exits[partner["index"]].get("gate", ""), "wall_cling")
	assert_eq(model.undo_depth(), 1)
	assert_eq(model.set_field(sel, "gate", ""), "")
	assert_false(model.rooms["C1"].exits[sel["index"]].has("gate"))
	assert_false(model.rooms["C2"].exits[partner["index"]].has("gate"))
	assert_eq("\n".join(model.validate()), "")

func test_an_unknown_gate_is_refused() -> void:
	var sel := _exit_sel("C1", "C2")
	assert_ne(model.set_field(sel, "gate", "wall_clinng"), "")
	assert_eq(model.undo_depth(), 0)

func test_a_tablets_hint_is_set_removed_and_checked_against_the_compendium() -> void:
	var sel := _feature_sel("C6", "tablet")
	assert_eq(model.get_field(sel, "hint"), "echolocation")
	assert_eq(model.set_field(sel, "hint", "spore_cloud"), "")
	assert_eq(model.get_field(sel, "hint"), "spore_cloud")
	assert_ne(model.set_field(sel, "hint", "flight"), "", "an enemy-only skill has no Compendium slot")
	assert_eq(model.set_field(sel, "hint", ""), "")
	assert_false(model.rooms["C6"].features[sel["index"]].has("hint"))
	assert_ne(model.set_field(_feature_sel("C4", "glow_pool"), "hint", "leap"), "", "only a tablet has a hint")
