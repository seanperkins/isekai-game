extends GutTest
## WorldValidator.reachable: what the start room reaches by following exits, and the rule that every room must be reached.

func _room(id: String, cell: Vector2i, exits: Array, extra: Dictionary = {}) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.cell = cell
	r.exits = exits
	for k in extra:
		r.set(k, extra[k])
	return r

func _exit(edge: String, room: String, extra: Dictionary = {}) -> Dictionary:
	var e := {"edge": edge, "from": 200.0, "to": 320.0, "room": room}
	for k in extra:
		e[k] = extra[k]
	return e

func _line() -> Dictionary:  # A - B - C in a row, A is the start
	return {
		"A": _room("A", Vector2i(0, 0), [_exit("right", "B")], {"start": Vector2(100, 310)}),
		"B": _room("B", Vector2i(1, 0), [_exit("left", "A"), _exit("right", "C")]),
		"C": _room("C", Vector2i(2, 0), [_exit("left", "B")]),
	}

func test_the_start_reaches_a_chain_start_first() -> void:
	assert_eq(WorldValidator.reachable(_line()), ["A", "B", "C"])

func test_a_room_with_no_way_in_is_reported() -> void:
	var rooms := _line()
	rooms["B"].exits = [_exit("left", "A")]
	rooms["C"].exits = []
	var errors := "\n".join(WorldValidator.validate(rooms))
	assert_string_contains(errors, "C: no way in from the start room")
	assert_eq(WorldValidator.reachable(rooms), ["A", "B"])

func test_gated_and_shortcut_links_count_unless_skipped() -> void:
	var rooms := _line()
	rooms["A"].exits = [_exit("right", "B", {"shortcut": "s1"})]
	assert_eq(WorldValidator.reachable(rooms), ["A", "B", "C"], "a shortcut link is a link")
	assert_eq(WorldValidator.reachable(rooms, true), ["A"], "skipped when asked")
	rooms["A"].exits = [_exit("right", "B", {"gate": "wall_cling"})]
	assert_eq(WorldValidator.reachable(rooms, true), ["A"])

func test_an_exit_to_an_unknown_room_is_skipped_not_a_crash() -> void:
	var rooms := _line()
	rooms["A"].exits.append(_exit("top", "Z"))
	assert_eq(WorldValidator.reachable(rooms), ["A", "B", "C"])
	assert_string_contains("\n".join(WorldValidator.validate(rooms)), "unknown room 'Z'")

func test_with_no_start_or_two_starts_the_rule_is_skipped() -> void:
	var rooms := _line()
	rooms["A"].start = RoomDef.NO_START
	assert_eq(WorldValidator.reachable(rooms), [])
	assert_string_contains("\n".join(WorldValidator.validate(rooms)), "exactly one start")
	assert_false("\n".join(WorldValidator.validate(rooms)).contains("no way in"))
	rooms["A"].start = Vector2(100, 310)
	rooms["C"].start = Vector2(100, 310)
	assert_eq(WorldValidator.reachable(rooms), [])
	assert_false("\n".join(WorldValidator.validate(rooms)).contains("no way in"), "two starts: one error about the starts, not one per room")

func test_the_public_edge_helpers() -> void:
	var r := _room("A", Vector2i(2, 1), [], {"size": Vector2i(2, 1)})
	assert_eq(WorldValidator.edge_range(r, "right"), Vector2(20.0, 320.0), "a side edge ends at height - FLOOR")
	assert_eq(WorldValidator.edge_range(r, "top"), Vector2(20.0, 1260.0), "a top edge ends at width - WALL")
	assert_eq(WorldValidator.edge_origin(r, "left"), 360.0)
	assert_eq(WorldValidator.edge_origin(r, "bottom"), 1280.0)
	assert_true(WorldValidator.touches(Rect2(0, 0, 640, 360), Rect2(640, 0, 640, 360), "right"))
	assert_false(WorldValidator.touches(Rect2(0, 0, 640, 360), Rect2(700, 0, 640, 360), "right"))

func test_the_shipped_world_is_one_connected_graph() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	assert_eq(WorldValidator.reachable(rooms).size(), rooms.size())
	assert_eq("\n".join(WorldValidator.validate(rooms)), "")
