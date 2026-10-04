extends GutTest
## The places a rebirth can start at: the pools in the room data, the default first (the goddess's menu lists the attuned ones).

func test_pools_come_from_the_room_data_with_the_default_first() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var pools := RebirthChoice.pools(rooms)
	assert_eq(pools[0]["id"], WorldProgress.DEFAULT_POOL)
	assert_eq(pools[0]["name"], "Cave mouth")
	assert_eq(pools[0]["room"], "C1")
	assert_true(pools[0]["pos"] is Vector2)

func test_pools_are_ordered_stably_default_first_then_by_id() -> void:
	var a := RoomDef.new()
	a.id = "Z9"
	a.features = [{"kind": "rebirth_pool", "id": "Z9", "area": "zed", "kit": {}, "pos": Vector2(1, 1)}]
	var b := RoomDef.new()
	b.id = "A1"
	b.features = [{"kind": "rebirth_pool", "id": "A1", "area": "alpha", "kit": {}, "pos": Vector2(1, 1)}]
	var c := RoomDef.new()
	c.id = "C1"
	c.features = [{"kind": "rebirth_pool", "id": "C1", "area": "cave", "kit": {}, "pos": Vector2(1, 1)}]
	var ids := RebirthChoice.pools({"Z9": a, "A1": b, "C1": c}).map(func(p): return p["id"])
	assert_eq(ids, ["C1", "A1", "Z9"])
