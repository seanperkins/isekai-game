extends GutTest
## What happens after death: a direct start at the only unlocked pool, or a list to choose from.

func _pool(id: String, room: String, name := "") -> Dictionary:
	return {"id": id, "area": "x", "room": room, "pos": Vector2(60, 300), "kit": {}, "name": name if name != "" else id}

func _pools() -> Array:
	return [_pool("C1", "C1", "Cave mouth"), _pool("G1", "G1", "Grotto rebirth pool"), _pool("F1", "F1", "Flooded rebirth pool")]

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

func test_one_unlocked_pool_starts_directly() -> void:
	assert_eq(RebirthChoice.decide(_pools(), ["C1"], "C1"), {"direct": "C1"})

func test_two_or_more_return_the_list_unlocked_first_then_locked_as_question_marks() -> void:
	var d := RebirthChoice.decide(_pools(), ["C1", "F1"], "F1")
	assert_false(d.has("direct"))
	var names: Array = d["options"].map(func(o): return o["name"])
	assert_eq(names, ["Cave mouth", "Flooded rebirth pool", "???"])
	assert_eq(d["options"].map(func(o): return o["locked"]), [false, false, true])

func test_the_last_choice_is_preselected() -> void:
	var d := RebirthChoice.decide(_pools(), ["C1", "G1", "F1"], "G1")
	assert_eq(d["selected"], 1)
	assert_eq(d["options"][d["selected"]]["id"], "G1")

func test_a_vanished_or_locked_last_choice_falls_back_to_the_first_unlocked() -> void:
	assert_eq(RebirthChoice.decide(_pools(), ["C1", "G1"], "GONE")["selected"], 0)
	assert_eq(RebirthChoice.decide(_pools(), ["C1", "G1"], "F1")["selected"], 0, "F1 is not unlocked")

func test_only_an_unlocked_entry_can_be_accepted() -> void:
	var d := RebirthChoice.decide(_pools(), ["C1", "G1"], "C1")
	assert_eq(RebirthChoice.accept(d, 0), "C1")
	assert_eq(RebirthChoice.accept(d, 1), "G1")
	assert_eq(RebirthChoice.accept(d, 2), "", "a locked entry")
	assert_eq(RebirthChoice.accept(d, -1), "")
	assert_eq(RebirthChoice.accept(d, 99), "")

func test_a_direct_decision_accepts_its_pool_and_nothing_else() -> void:
	var d := RebirthChoice.decide(_pools(), ["C1"], "C1")
	assert_eq(RebirthChoice.accept(d, 0), "C1")
	assert_eq(RebirthChoice.accept(d, 1), "")

func test_no_unlocked_pool_at_all_still_starts_at_the_default() -> void:
	assert_eq(RebirthChoice.decide(_pools(), [], ""), {"direct": "C1"})
	assert_eq(RebirthChoice.decide([], ["C1"], "C1"), {"direct": "C1"}, "even a world with no pools starts at the default id")

func test_unattuned_pools_never_appear_as_real_choices() -> void:
	var d := RebirthChoice.decide(_pools(), ["C1", "G1"], "C1")
	for o in d["options"]:
		if o["locked"]:
			assert_eq(o["name"], "???")
			assert_false(o.has("pos"))
