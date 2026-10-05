extends GutTest
## RoomSpec: a room as the JSON an agent reads and writes, and back. Pure conversion; the model's rules are not applied here.

func _roundtrip(r: RoomDef) -> Dictionary:
	return RoomSpec.content_from_json(JSON.parse_string(JSON.stringify(RoomSpec.to_json(r))))

func test_every_shipped_room_round_trips() -> void:
	var rooms := ShippedRooms.load_all()
	assert_eq(rooms.size(), 23)
	for id in rooms:
		var back := _roundtrip(rooms[id])
		assert_eq(back["errors"], [], id)
		assert_eq(back["content"], RoomSpec.content_of(rooms[id]), id)

func test_malformed_elements_are_reported_by_kind_and_index() -> void:
	var back := RoomSpec.content_from_json({
		"solids": [{"rect": [1, 2, 3]}, {"rect": [0, 0, 8, 8]}],
		"spawns": [{"creature": "toad", "pos": "x"}],
	})
	var errs: Array = back["errors"]
	assert_eq(errs.size(), 2)
	assert_eq([errs[0]["kind"], errs[0]["index"]], ["solid", 0])
	assert_eq([errs[1]["kind"], errs[1]["index"]], ["spawn", 0])
	assert_eq(back["content"]["solids"], [{"rect": Rect2(0, 0, 8, 8), "hard": false}])
	assert_eq(back["content"]["spawns"], [])

## A 1e999 in the JSON parses to INF (with an engine warning), so the specs here carry INF and NAN directly.
func test_non_finite_and_huge_numbers_are_shape_errors() -> void:
	for w in [INF, -INF, NAN, 1e9]:
		var back := RoomSpec.content_from_json({"solids": [{"rect": [0, 0, w, 10]}]})
		assert_eq(back["errors"].size(), 1, str(w))
		assert_eq(back["errors"][0]["kind"], "solid", str(w))
		assert_eq(back["content"]["solids"], [], str(w))

func test_a_section_that_is_not_a_list_is_one_error() -> void:
	var back := RoomSpec.content_from_json({"decor": "rubble"})
	assert_eq(back["errors"].size(), 1)
	assert_eq(back["errors"][0]["kind"], "decor")

func test_indexed_and_start() -> void:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = "cave"
	r.solids = [Rect2(0, 0, 8, 8), Rect2(20, 0, 8, 8)]
	r.water = [Rect2(0, 100, 40, 40)]
	var plain := RoomSpec.to_json(r)
	assert_eq(plain["start"], null)
	assert_false(plain["solids"][0].has("index"))
	var indexed := RoomSpec.to_json(r, true)
	assert_eq([indexed["solids"][0]["index"], indexed["solids"][1]["index"]], [0, 1])
	assert_eq(indexed["water"][0]["index"], 0)
	r.start = Vector2(40, 300)
	assert_eq(RoomSpec.to_json(r)["start"], [40.0, 300.0])

func test_decor_keys_pass_through() -> void:
	var back := RoomSpec.content_from_json({
		"decor": [{"piece": "rubble", "pos": [1, 2], "light": [1, 0.5, 0.25, 1], "anchor": "top"}],
		"features": [{"kind": "altar", "pos": [4, 8], "perk": "x"}],
	})
	assert_eq(back["errors"], [])
	assert_eq(back["content"]["decor"], [{"id": "rubble", "pos": Vector2(1, 2), "light": Color(1, 0.5, 0.25, 1), "anchor": "top"}])
	assert_eq(back["content"]["features"], [{"kind": "altar", "pos": Vector2(4, 8), "perk": "x"}])
	assert_false(back["content"]["features"][0].has("id"))

func test_transport_only_keys_are_dropped() -> void:
	var back := RoomSpec.content_from_json({
		"decor": [{"piece": "rubble", "pos": [1, 2], "index": 3}],
		"features": [{"kind": "glow_pool", "pos": [4, 8], "id": "x", "index": 1}],
		"solids": [{"rect": [0, 0, 8, 8], "index": 0}],
	})
	assert_eq(back["errors"], [])
	assert_false(back["content"]["decor"][0].has("index"))
	assert_false(back["content"]["features"][0].has("index"))
	assert_eq(back["content"]["solids"], [{"rect": Rect2(0, 0, 8, 8), "hard": false}])
