extends GutTest
## problems(): lint findings and validator strings as one list, routed to rooms.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func test_the_shipped_world_has_no_problems() -> void:
	assert_eq(model.problems(), [])

func test_a_lint_finding_carries_its_room_and_pick() -> void:
	model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	model.serial += 1
	var p := model.problems()
	assert_eq(p.size(), 1)
	assert_eq(p[0]["room"], "C2")
	assert_eq(p[0]["pick"]["kind"], "spawn")

func test_a_validator_string_is_routed_by_its_head_and_has_no_pick() -> void:
	model.rooms["C1"].exits.append({"edge": "top", "from": 100.0, "to": 200.0, "room": "Z"})
	model.serial += 1
	var routed := model.problems().filter(func(p): return p["text"].contains("unknown room 'Z'"))
	assert_eq(routed.size(), 1)
	assert_eq(routed[0]["room"], "C1")
	assert_eq(routed[0]["pick"], {})

func test_the_problems_list_names_an_altar_with_an_unknown_perk() -> void:
	var f: Dictionary = model.rooms["C1"].features.filter(func(x): return x["kind"] == "altar")[0]
	f["perk"] = "nope"
	model.serial += 1
	var named := model.problems().filter(func(p): return p["text"].contains("names perk 'nope'"))
	assert_eq(named.size(), 1)
	assert_eq(named[0]["room"], "C1")

func test_overlap_strings_route_to_the_first_room_and_world_strings_to_none() -> void:
	var a: RoomDef = model.rooms["C1"]
	var dup := RoomEditModel.copy_room(a)
	dup.id = "ZZ"
	dup.start = RoomDef.NO_START
	model.rooms["ZZ"] = dup
	model.serial += 1
	var texts := model.problems().filter(func(p): return p["text"].contains("overlaps"))
	assert_gt(texts.size(), 0)
	assert_true(model.rooms.has(texts[0]["room"]))
	a.start = RoomDef.NO_START
	model.serial += 1
	var world := model.problems().filter(func(p): return p["text"].begins_with("world:"))
	assert_gt(world.size(), 0)
	assert_eq(world[0]["room"], "", "a world-level string opens no room")

func test_problems_are_recomputed_only_when_serial_changes() -> void:
	var first := model.problems()
	model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})  # a change that does not touch serial
	assert_eq(model.problems().size(), first.size(), "cached until an edit, undo or redo bumps serial")
	model.add_solid("C1", Vector2(100, 100), Vector2(160, 116))
	assert_gt(model.problems().size(), first.size())

func test_validate_is_unchanged_and_validator_only() -> void:
	assert_eq("\n".join(model.validate()), "")
	model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	assert_eq("\n".join(model.validate()), "", "lint findings are not in validate()")

func test_the_id_world_is_reserved_case_insensitively_for_rooms_but_not_for_shortcuts() -> void:
	assert_ne(model.id_error("world"), "")
	assert_ne(model.id_error("World"), "")
	assert_true(RoomEditModel.valid_id("world"), "valid_id also gates shortcut ids, so it stays permissive")
