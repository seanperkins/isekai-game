extends GutTest
## The places a rebirth can start at: the pools in the room data, the default first (the goddess's menu lists the attuned ones).

func test_pools_come_from_the_room_data_with_the_default_first() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var pools := RebirthChoice.altars(rooms)
	assert_eq(pools[0]["id"], WorldProgress.DEFAULT_ALTAR)
	assert_eq(pools[0]["name"], "Cave mouth")
	assert_eq(pools[0]["room"], "C1")
	assert_true(pools[0]["pos"] is Vector2)
	assert_eq(pools[0]["perk"], "stats", "the Cave's altar sells the stats perk")
	assert_false(pools[0].has("kit"), "an altar carries a perk, not a kit")
	assert_eq(pools.size(), 4)

func test_pools_are_ordered_stably_default_first_then_by_id() -> void:
	var a := RoomDef.new()
	a.id = "Z9"
	a.features = [{"kind": "altar", "id": "Z9", "area": "zed", "perk": "", "pos": Vector2(1, 1)}]
	var b := RoomDef.new()
	b.id = "A1"
	b.features = [{"kind": "altar", "id": "A1", "area": "alpha", "perk": "", "pos": Vector2(1, 1)}]
	var c := RoomDef.new()
	c.id = "C1"
	c.features = [{"kind": "altar", "id": "C1", "area": "cave", "perk": "", "pos": Vector2(1, 1)}]
	var ids := RebirthChoice.altars({"Z9": a, "A1": b, "C1": c}).map(func(p): return p["id"])
	assert_eq(ids, ["C1", "A1", "Z9"])

func test_an_altar_is_named_by_its_area_and_the_cave_mouth_by_its_place() -> void:
	assert_eq(RebirthChoice.altar_name({"id": "C1", "area": "cave"}), "Cave mouth")
	assert_eq(RebirthChoice.altar_name({"id": "G1", "area": "grotto"}), "Grotto altar")
	assert_eq(RebirthChoice.altar_name({"id": "X9", "area": ""}), "X9")
