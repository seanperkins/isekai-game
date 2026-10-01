extends GutTest
## The Cave rooms as data: a valid graph, food for every Plan 2 skill, no skills needed on
## the main route, and every ledge reachable from its floor by base jumps.

var rooms := {}

func before_all() -> void:
	for r in DefLoader.load_dir("res://data/rooms", "RoomDef"):
		rooms[r.id] = r

func test_the_world_has_the_cave_and_the_grotto_and_validates() -> void:
	for id in ShippedRooms.IDS:
		assert_true(rooms.has(id), id)
	assert_eq("\n".join(WorldValidator.validate(rooms)), "")
	assert_true(rooms["C1"].is_start())

func test_the_shipped_list_names_rooms_that_exist() -> void:
	assert_eq(ShippedRooms.load_all().size(), ShippedRooms.IDS.size())

func test_cave_meets_the_food_minimums() -> void:
	var counts := {}
	for r in rooms.values():
		for s in r.spawns:
			counts[s["id"]] = int(counts.get(s["id"], 0)) + 1
	var minimums := {"bat": 3, "toad": 4, "lizard": 3, "spider": 3, "water_pool": 2}
	for id in minimums:
		assert_gte(int(counts.get(id, 0)), minimums[id], id)

func test_spawns_and_the_start_sit_inside_their_room_and_outside_rock() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), ["outside", "in_rock"]), "")

func test_every_ledge_is_reachable_from_its_floor_by_base_jumps() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), ["ledge_reach"]), "")

func test_the_main_route_needs_no_skills() -> void:
	var open := WorldValidator.reachable(rooms, true)
	for id in ["C1", "C2", "C4", "C5", "G1", "G2", "G3", "G4"]:
		assert_true(open.has(id), id)
	assert_false(open.has("C3"), "C3 is behind the wall-cling chimney")

func test_every_room_is_reachable_through_its_gates() -> void:
	assert_eq(WorldValidator.reachable(rooms).size(), rooms.size())

func test_the_nook_holds_a_tablet_and_the_shortcut_switch() -> void:
	var kinds: Array = rooms["C6"].features.map(func(f: Dictionary) -> String: return f["kind"])
	assert_true(kinds.has("tablet"))
	assert_true(kinds.has("switch"))
	assert_true(rooms["C4"].features.any(func(f: Dictionary) -> bool: return f["kind"] == "glow_pool"))

func test_the_world_has_no_lint_findings() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), RoomLint.RULES), "", "Validate clean is the same set as the suite's rules")
