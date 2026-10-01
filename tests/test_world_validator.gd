extends GutTest
## Rooms on a shared grid of screens: exits pair with the neighbour's opposite edge over the
## same world span, rooms never overlap, spans fit their edge, and one room is the start.

func _room(id: String, cell: Vector2i, exits: Array, extra: Dictionary = {}) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.cell = cell
	r.exits = exits
	for k in extra:
		r.set(k, extra[k])
	return r

func _pair() -> Dictionary:
	return {
		"A": _room("A", Vector2i(0, 0), [{"edge": "right", "from": 200.0, "to": 320.0, "room": "B"}], {"start": Vector2(100, 310)}),
		"B": _room("B", Vector2i(1, 0), [{"edge": "left", "from": 200.0, "to": 320.0, "room": "A"}]),
	}

func _errors(rooms: Dictionary) -> String:
	return "\n".join(WorldValidator.validate(rooms))

func test_a_matching_pair_is_valid() -> void:
	assert_eq(_errors(_pair()), "")

func test_world_rects_follow_the_grid() -> void:
	var r := _room("T", Vector2i(2, 1), [], {"size": Vector2i(2, 1)})
	assert_eq(r.world_rect(), Rect2(1280, 360, 1280, 360))

func test_a_missing_partner_fails() -> void:
	var rooms := _pair()
	rooms["B"].exits = []
	assert_string_contains(_errors(rooms), "A: right exit to B has no matching exit back")

func test_mismatched_spans_fail() -> void:
	var rooms := _pair()
	rooms["B"].exits[0]["to"] = 300.0
	assert_string_contains(_errors(rooms), "no matching exit back")

func test_non_adjacent_rooms_fail() -> void:
	var rooms := _pair()
	rooms["B"].cell = Vector2i(2, 0)
	assert_string_contains(_errors(rooms), "A: right edge does not touch B")

func test_overlapping_rooms_fail() -> void:
	var rooms := _pair()
	rooms["C"] = _room("C", Vector2i(0, 0), [])
	assert_string_contains(_errors(rooms), "overlaps")

func test_a_span_outside_its_edge_fails() -> void:
	var rooms := _pair()
	rooms["A"].exits[0]["to"] = 340.0  # into the floor
	assert_string_contains(_errors(rooms), "span")

func test_unknown_rooms_and_starts_fail() -> void:
	var rooms := _pair()
	rooms["A"].exits.append({"edge": "top", "from": 100.0, "to": 200.0, "room": "Z"})
	rooms["A"].start = RoomDef.NO_START
	var errors := _errors(rooms)
	assert_string_contains(errors, "unknown room 'Z'")
	assert_string_contains(errors, "exactly one start room")

func test_shortcut_ids_must_match_on_both_sides() -> void:
	var rooms := _pair()
	rooms["A"].exits[0]["shortcut"] = "s1"
	assert_string_contains(_errors(rooms), "shortcut")

func test_edge_walls_leave_gaps_at_exits() -> void:
	var walls := RoomBuilder.edge_walls(Vector2(640, 360), [{"edge": "right", "from": 200.0, "to": 320.0, "room": "B"}])
	var right := walls.filter(func(w: Dictionary) -> bool: return w["rect"].position.x == 620.0).map(func(w: Dictionary) -> Rect2: return w["rect"])
	assert_eq(right, [Rect2(620, 0, 20, 200), Rect2(620, 320, 20, 40)])
	var floors := walls.filter(func(w: Dictionary) -> bool: return w["kind"] == "ground")
	assert_eq(floors.size(), 1)
	assert_eq(floors[0]["rect"], Rect2(0, 320, 640, 40))

func test_a_gate_covers_its_exit_span() -> void:
	assert_eq(RoomBuilder.gate_rect(Vector2(640, 360), {"edge": "bottom", "from": 200.0, "to": 260.0}), Rect2(200, 320, 60, 40))
	assert_eq(RoomBuilder.gate_rect(Vector2(640, 360), {"edge": "left", "from": 200.0, "to": 320.0}), Rect2(0, 200, 20, 120))

func test_a_spawn_with_an_unknown_creature_is_an_error_when_ids_are_given() -> void:
	var rooms := _pair()
	rooms["A"].spawns = [{"id": "spore_mothh", "pos": Vector2(10, 10)}]
	assert_eq(_errors(rooms), "", "no ids given: spawns are not checked")
	var errs := "\n".join(WorldValidator.validate(rooms, ["spore_moth"]))
	assert_string_contains(errs, "spore_mothh")
	assert_eq("\n".join(WorldValidator.validate(rooms, ["spore_mothh"])), "")

func test_an_unknown_feature_kind_is_an_error() -> void:
	var rooms := _pair()
	rooms["A"].features = [{"kind": "glow_poool", "id": "x", "pos": Vector2(1, 1)}]
	assert_string_contains(_errors(rooms), "glow_poool")

func test_the_shipped_world_has_only_known_creatures_and_feature_kinds() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c: CreatureDef) -> String: return c.id)
	var rooms := World.load_rooms("res://data/rooms")
	assert_eq(WorldValidator.validate(rooms, ids).size(), 0, str(WorldValidator.validate(rooms, ids)))

# --- hard ledges are a deliberate list: each names a real thin platform of the room ---

func test_a_hard_ledge_must_be_one_of_the_rooms_solids() -> void:
	var rooms := _pair()
	rooms["A"].solids = [Rect2(100, 200, 100, 12)]
	rooms["A"].hard_ledges = [Rect2(100, 100, 100, 12)]
	assert_string_contains(_errors(rooms), "A: hard ledge %s is not one of the room's solids" % Rect2(100, 100, 100, 12))

func test_a_hard_ledge_must_be_thin() -> void:
	var rooms := _pair()
	rooms["A"].solids = [Rect2(100, 200, 100, 32)]
	rooms["A"].hard_ledges = [Rect2(100, 200, 100, 32)]
	assert_string_contains(_errors(rooms), "A: hard ledge %s is already solid" % Rect2(100, 200, 100, 32))

func test_a_listed_thin_solid_is_valid() -> void:
	var rooms := _pair()
	rooms["A"].solids = [Rect2(100, 200, 100, 12)]
	rooms["A"].hard_ledges = [Rect2(100, 200, 100, 12)]
	assert_eq(_errors(rooms), "")

func test_a_known_gate_on_both_halves_is_valid() -> void:
	var rooms := _pair()
	rooms["A"].exits[0]["gate"] = "wall_cling"
	rooms["B"].exits[0]["gate"] = "wall_cling"
	assert_eq(_errors(rooms), "")

func test_a_gate_on_one_half_only_is_reported() -> void:
	var rooms := _pair()
	rooms["A"].exits[0]["gate"] = "wall_cling"
	assert_string_contains(_errors(rooms), "A: right exit to B has a different gate than its partner")

func test_an_unknown_gate_is_reported_even_when_both_halves_agree() -> void:
	var rooms := _pair()
	rooms["A"].exits[0]["gate"] = "wall_clinng"
	rooms["B"].exits[0]["gate"] = "wall_clinng"
	assert_string_contains(_errors(rooms), "unknown gate 'wall_clinng'")
