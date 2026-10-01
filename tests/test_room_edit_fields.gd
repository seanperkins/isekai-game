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

func test_a_pools_level_and_skills_merge_into_the_kit_and_keep_the_rest() -> void:
	var sel := _feature_sel("G1", "rebirth_pool")
	var affinity: Dictionary = model.rooms["G1"].features[sel["index"]]["kit"]["affinity"].duplicate()
	assert_false(affinity.is_empty(), "G1 ships an affinity")
	assert_eq(model.set_field(sel, "kit_level", 5), "")
	assert_eq(model.get_field(sel, "kit_level"), 5)
	assert_eq(model.set_field(sel, "kit_skills", ["leap"]), "")
	assert_eq(model.get_field(sel, "kit_skills"), ["leap"])
	assert_eq(model.rooms["G1"].features[sel["index"]]["kit"].get("affinity", {}), affinity, "G1's affinity survives every edit")
	assert_eq(model.set_field(sel, "kit_level", 0), "", "0 unsets the level")
	assert_false(model.rooms["G1"].features[sel["index"]]["kit"].has("level"))

func test_a_kit_the_validator_rejects_is_refused_and_changes_nothing() -> void:
	var sel := _feature_sel("G1", "rebirth_pool")
	var before := RoomEditModel.copy_room(model.rooms["G1"])
	assert_ne(model.set_field(sel, "kit_skills", ["not_a_skill"]), "")
	assert_ne(model.set_field(sel, "kit_skills", ["poison_spit"]), "", "enemy-only")
	assert_ne(model.set_field(sel, "kit_level", 11), "")
	assert_true(RoomEditModel.same_room(before, model.rooms["G1"]))
	assert_eq(model.undo_depth(), 0)

func test_the_pool_area_and_kit_are_required_keys() -> void:
	var sel := _feature_sel("G1", "rebirth_pool")
	assert_eq(model.rooms["G1"].features[sel["index"]].has("area"), true)
	assert_eq(model.rooms["G1"].features[sel["index"]].has("kit"), true)
	model.set_field(sel, "kit_skills", [])
	assert_true(model.rooms["G1"].features[sel["index"]].has("kit"), "an empty list unsets skills but the kit stays a Dictionary")
