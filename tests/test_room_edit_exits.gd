extends GutTest
## Exits are written in pairs, in one undo step, by the validator's own rules.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func _errors() -> String:
	return "\n".join(model.validate())

## The exit dict in `room` that points at `to_room`.
func _exit_to(room: String, to_room: String) -> Dictionary:
	for e in model.rooms[room].exits:
		if e["room"] == to_room:
			return e
	return {}

func _index_to(room: String, to_room: String) -> int:
	for i in model.rooms[room].exits.size():
		if model.rooms[room].exits[i]["room"] == to_room:
			return i
	return -1

## Removes both halves of a pair from the working rooms and returns copies of them, [a's, b's].
func _remove_pair(a: String, b: String) -> Array:
	var ea := _exit_to(a, b)
	var eb := _exit_to(b, a)
	var copies := [ea.duplicate(), eb.duplicate()]
	model.rooms[a].exits.erase(ea)
	model.rooms[b].exits.erase(eb)
	return copies

func test_the_shipped_world_validates_clean() -> void:
	assert_eq(_errors(), "")

func test_adding_an_exit_reproduces_the_shipped_c1_c2_pair_exactly() -> void:
	var pair := _remove_pair("C1", "C2")
	assert_eq(model.add_exit("C1", "right", pair[0]["from"], pair[0]["to"]), "")
	assert_eq(_exit_to("C1", "C2"), pair[0])
	assert_eq(_exit_to("C2", "C1"), pair[1], "the partner's local span is right")
	assert_eq(_errors(), "")

func test_adding_a_shortcut_exit_copies_the_shortcut_and_the_partner_is_offset_by_the_neighbours_origin() -> void:
	var pair := _remove_pair("C1", "C6")  # C1's top exit to C6 is a shortcut; C6 sits 640 px to the right in x
	assert_true(pair[0].has("shortcut"))
	assert_eq(model.add_exit("C1", "top", pair[0]["from"], pair[0]["to"], {"shortcut": pair[0]["shortcut"]}), "")
	assert_eq(_exit_to("C1", "C6"), pair[0])
	assert_eq(_exit_to("C6", "C1"), pair[1])
	assert_eq(_errors(), "")

func test_the_partner_is_right_for_a_vertical_pair_and_a_gate_is_copied() -> void:
	var pair := _remove_pair("C3", "C6")  # C3's left edge (local y 560..680) meets C6's right edge (local y 200..320)
	assert_eq(model.add_exit("C3", "left", pair[0]["from"], pair[0]["to"]), "")
	assert_eq(_exit_to("C6", "C3"), pair[1])
	pair = _remove_pair("C2", "C3")
	assert_true(pair[0].has("gate"))
	assert_eq(model.add_exit("C2", "top", pair[0]["from"], pair[0]["to"], {"gate": pair[0]["gate"]}), "")
	assert_eq(_exit_to("C2", "C3"), pair[0])
	assert_eq(_exit_to("C3", "C2"), pair[1], "the gate is on both halves")
	assert_eq(_errors(), "")

func test_one_add_is_one_undo_step_across_two_rooms() -> void:
	_remove_pair("C1", "C2")
	model.add_exit("C1", "right", 200.0, 320.0)
	assert_eq(model.undo_depth(), 1)
	assert_eq(model.dirty.keys().size(), 2)
	model.undo()
	assert_true(_exit_to("C1", "C2").is_empty())
	assert_true(_exit_to("C2", "C1").is_empty())

func test_the_span_rules_are_the_validators_own() -> void:
	_remove_pair("C1", "C2")
	var h: float = model.rooms["C1"].pixel_size().y
	assert_eq(model.add_exit("C1", "right", h - 120.0, h - RoomDef.FLOOR), "", "a side door flush with the floor: to = height - 40")
	model.undo()
	assert_ne(model.add_exit("C1", "right", h - 120.0, h - 36.0), "", "height - 36 is into the floor")
	assert_ne(model.add_exit("C1", "right", 200.0, 230.0), "", "shorter than 36")
	assert_ne(model.add_exit("C1", "right", 4.0, 100.0), "", "starts inside the corner")
	assert_ne(model.add_exit("C2", "bottom", 60.0, 120.0), "", "no room across that edge covers the span")
	assert_eq(model.undo_depth(), 0)

func test_an_overlapping_span_is_refused_on_either_side() -> void:
	assert_ne(model.add_exit("C1", "right", 240.0, 300.0), "", "overlaps C1's existing exit to C2")
	assert_eq(model.undo_depth(), 0)
	var ea := _exit_to("C1", "C2")
	model.rooms["C1"].exits.erase(ea)  # only C1's half: C2 still has its exit toward C1
	assert_string_contains(model.add_exit("C1", "right", 240.0, 300.0), "overlaps an exit in C2")

func test_a_span_the_neighbour_does_not_cover_is_refused_even_when_the_edge_lines_coincide() -> void:
	_remove_pair("C4", "C5")
	# C5 is three screens tall, C4 one: C5's left span 280..360 (world y 1000..1080) is inside C5's own range but runs past
	# the bottom of what C4's right edge allows (world y 1040)
	assert_ne(model.add_exit("C5", "left", 280.0, 360.0), "", "C4 does not cover it")
	assert_ne(model.add_exit("C5", "left", 600.0, 680.0), "", "no room at all across there")
	assert_eq(model.undo_depth(), 0)
	assert_eq(model.add_exit("C5", "left", 200.0, 320.0), "")
	assert_eq(_errors(), "")

func test_moving_an_exit_moves_its_partner_in_one_step() -> void:
	var idx := _index_to("C1", "C2")
	var before_a: Dictionary = model.rooms["C1"].exits[idx].duplicate()
	assert_true(model.begin_move({"room": "C1", "kind": "exit", "index": idx}))
	model.move_to(Vector2(0, -40))
	model.end_move()
	assert_eq(model.rooms["C1"].exits[idx]["from"], before_a["from"] - 40.0)
	assert_eq(_errors(), "", "the partner moved with it")
	assert_eq(model.undo_depth(), 1)
	model.undo()
	assert_eq(model.rooms["C1"].exits[idx], before_a)
	assert_eq(_errors(), "")

func test_a_move_past_the_edge_stops_at_the_last_valid_spot() -> void:
	var idx := _index_to("C1", "C2")
	var start: Dictionary = model.rooms["C1"].exits[idx].duplicate()
	model.begin_move({"room": "C1", "kind": "exit", "index": idx})
	model.move_to(Vector2(0, -20))
	model.move_to(Vector2(0, 5000))
	model.end_move()
	assert_eq(model.rooms["C1"].exits[idx]["from"], start["from"] - 20.0, "the invalid pointer position left the last valid one")
	assert_eq(_errors(), "")

func test_a_move_that_would_leave_the_neighbours_range_is_refused_too() -> void:
	# C5's left exit (local y 200..320) meets C4's right edge, whose allowed range ends at world y 1040 (C5 local 320)
	var idx := _index_to("C5", "C4")
	var start: Dictionary = model.rooms["C5"].exits[idx].duplicate()
	model.begin_move({"room": "C5", "kind": "exit", "index": idx})
	model.move_to(Vector2(0, 40))
	model.end_move()
	assert_eq(model.rooms["C5"].exits[idx], start, "C5 would allow it, C4 does not")
	assert_eq(model.undo_depth(), 0)

func test_deleting_an_exit_deletes_its_partner_in_one_step() -> void:
	var idx := _index_to("C1", "C2")
	model.select({"room": "C1", "kind": "exit", "index": idx})
	assert_eq(model.delete_selection(), "")
	assert_true(_exit_to("C1", "C2").is_empty())
	assert_true(_exit_to("C2", "C1").is_empty())
	assert_eq(model.undo_depth(), 1)
	model.undo()
	assert_false(_exit_to("C2", "C1").is_empty())
	assert_eq(_errors(), "")

func test_partner_of_uses_the_validators_rule() -> void:
	var idx := _index_to("C1", "C2")
	var p := model.partner_of("C1", idx)
	assert_eq(p["room"], "C2")
	assert_eq(model.rooms["C2"].exits[p["index"]]["room"], "C1")
	model.rooms["C2"].exits[p["index"]]["to"] += 8.0
	assert_true(model.partner_of("C1", idx).is_empty(), "a span that no longer matches is not a partner")
