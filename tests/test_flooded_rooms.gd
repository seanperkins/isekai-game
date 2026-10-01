extends GutTest
## The Flooded Tunnels' rooms: the world is valid, the pacing rule holds, the chains and the doors work, and no swimmer is trapped.

const ROOMS := ["F1", "F2", "F3", "F4", "F5"]

var rooms: Dictionary
var creatures := {}

func before_all() -> void:
	rooms = World.load_rooms("res://data/rooms")
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func _first_time(ids: Array) -> int:
	var total := 0
	for id in ids:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			total += c.xp * (1 if c.id == "water_pool" else 2)
	return total

func test_the_world_validates_and_lints_clean() -> void:
	var ids: Array = creatures.keys()
	assert_eq(WorldValidator.validate(rooms, ids), PackedStringArray())
	assert_eq(RoomLint.check(rooms), [], RoomLint.text(RoomLint.check(rooms), RoomLint.RULES))

func test_the_rooms_sit_where_the_spec_puts_them() -> void:
	var want := {"F1": [Vector2i(10, 8), Vector2i(2, 1)], "F2": [Vector2i(12, 7), Vector2i(1, 2)], "F3": [Vector2i(12, 6), Vector2i(3, 1)],
		"F4": [Vector2i(15, 6), Vector2i(2, 1)], "F5": [Vector2i(15, 7), Vector2i(1, 1)]}
	for id in want:
		assert_eq((rooms[id] as RoomDef).cell, want[id][0], id)
		assert_eq((rooms[id] as RoomDef).size, want[id][1], id)
		assert_eq((rooms[id] as RoomDef).area, "flooded", id)

func test_every_gated_exit_is_the_swim_door() -> void:
	var gated := []
	for id in ROOMS:
		for e in (rooms[id] as RoomDef).exits:
			if e.has("gate"):
				gated.append("%s:%s" % [id, e["gate"]])
	gated.sort()
	assert_eq(gated, ["F2:swim", "F3:swim", "F4:swim"], "F2's top exit, F3's floor hole and F4's top exit (the slice)")

func test_the_pacing_rule() -> void:
	var total := _first_time(ROOMS)
	assert_gte(total, 150, "real payoff for a stage-1 life that just evolved")
	assert_lt(total, Progression.stage_total(2), "stage 2's cap needs more than this area")

func test_the_ungated_flooded_is_f1_and_f2_only() -> void:
	var reach := WorldValidator.reachable(rooms, true)
	for id in ["F1", "F2"]:
		assert_true(reach.has(id), id)
	for id in ["F3", "F4", "F5"]:
		assert_false(reach.has(id), "%s is behind the swim door" % id)

func test_the_two_floor_holes_have_chains_back_up_standing_on_dry_floor() -> void:
	# G4 -> F1 and F4 -> F5: the top ledge sits at local y 12-15 flush with the span's west edge, every hop at most 55 up,
	# the lowest ledge within 55 of the floor, and no ledge in water
	for pair in [["G4", "F1"], ["F4", "F5"]]:
		var upper: RoomDef = rooms[pair[0]]
		var lower: RoomDef = rooms[pair[1]]
		var hole: Dictionary = upper.exits.filter(func(e): return e["edge"] == "bottom" and e["room"] == pair[1])[0]
		var span := WorldValidator.world_span(upper, hole)
		var west := span.x - WorldValidator.edge_origin(lower, "top")
		var chain: Array = lower.solids.filter(func(s): return (s as Rect2).position.x >= west - 10.0 and (s as Rect2).end.x <= west + 250.0 and (s as Rect2).size.y <= 24.0)
		chain.sort_custom(func(a, b): return (a as Rect2).position.y < (b as Rect2).position.y)
		assert_gte(chain.size(), 5, "%s: a real climb" % pair[1])
		assert_between((chain[0] as Rect2).position.y, 12.0, 15.0, "%s: the top ledge" % pair[1])
		assert_almost_eq((chain[0] as Rect2).position.x, west, 1.0, "%s: flush with the span's west edge" % pair[1])
		for i in range(1, chain.size()):
			assert_lte((chain[i] as Rect2).position.y - (chain[i - 1] as Rect2).position.y, 55.0, "%s: hop %d" % [pair[1], i])
		var floor_y: float = lower.pixel_size().y - RoomDef.FLOOR
		assert_lte(floor_y - (chain.back() as Rect2).position.y, 55.0, "%s: the lowest ledge is a hop from the floor" % pair[1])
		for s in chain:
			for w in lower.water:
				assert_false((s as Rect2).intersects(w), "%s: the chain stands outside every water rect" % pair[1])

## The Swim door of a room's top exit, in the three parts the Grotto's G5 test has.
func _assert_door(room_id: String) -> void:
	var r: RoomDef = rooms[room_id]
	var top: Dictionary = r.exits.filter(func(e): return e["edge"] == "top" and e.get("gate", "") == "swim")[0]
	var column: Rect2 = r.water.filter(func(w): return (w as Rect2).position.y <= 0.5 and (w as Rect2).end.x > float(top["from"]) and (w as Rect2).position.x < float(top["to"]))[0]
	# (a) the top exit's span lies inside the column's x-range and the column reaches the room's top edge
	assert_true(column.position.x <= float(top["from"]) and column.end.x >= float(top["to"]), "%s (a) the span is inside the column" % room_id)
	# (b) no solid inside the column, and the sill clears the true non-swimmer reach plus 3
	for s in r.solids:
		assert_false((s as Rect2).intersects(column), "%s (b) no solid inside the column" % room_id)
	var jh := 185.0
	var b := PlayerWater.bob_apex(jh)
	var b_entry := (pow(Player.JUMP_VELOCITY, 2.0) - pow(PlayerWater.BOB_VELOCITY, 2.0)) * jh / (2.0 * Player.GRAVITY * 100.0) + b
	assert_almost_eq(b_entry, 160.8, 0.3)
	var floor_top: float = r.pixel_size().y - RoomDef.FLOOR
	var sill_height := floor_top - RoomDef.WALL
	assert_gte(sill_height, b_entry + 3.0, "%s (b) the sill clears B_entry + 3" % room_id)
	# (c) no dry surface beside the column is high enough that a lateral dry jump from it enters the column within B_entry of the sill
	for s in r.solids:
		var rr: Rect2 = s
		var dry := true
		for w in r.water:
			if rr.intersects(w):
				dry = false
		if not dry or rr.end.x < column.position.x - 160.0 or rr.position.x > column.end.x + 160.0:
			continue
		assert_lte((floor_top - rr.position.y) + b_entry + 3.0, sill_height, "%s (c) a dry ledge beside the column reaches the sill" % room_id)

func test_the_swim_doors_are_structural() -> void:
	_assert_door("F2")
	_assert_door("F4")  # the slice's column up to F6

func test_no_swimmer_is_trapped_anywhere_in_the_world() -> void:
	assert_eq(RoomLint.water_groups(rooms), [])

func test_every_swimmer_spawn_is_in_water_and_no_walker_needs_it() -> void:
	for id in ROOMS:
		var r: RoomDef = rooms[id]
		for s in r.spawns:
			if (creatures[s["id"]] as CreatureDef).swimmer:
				var wet := false
				for w in r.water:
					if (w as Rect2).has_point(s["pos"]):
						wet = true
				assert_true(wet, "%s %s" % [id, s["pos"]])

func test_f1_holds_the_rebirth_pool_and_f5_the_tablet() -> void:
	var f1_kinds: Array = (rooms["F1"] as RoomDef).features.map(func(f): return f["kind"])
	assert_true(f1_kinds.has("rebirth_pool"))
	var f5_kinds: Array = (rooms["F5"] as RoomDef).features.map(func(f): return f["kind"])
	assert_true(f5_kinds.has("tablet"))
	assert_true(f5_kinds.has("glow_pool"))

func test_g4_is_no_longer_the_last_room_and_has_a_hole_with_nothing_over_it() -> void:
	var g4: RoomDef = rooms["G4"]
	assert_true(g4.exits.any(func(e): return e["edge"] == "bottom" and e["room"] == "F1"))

# --- the rare slice: F6 and the Storm Eel ---

func test_f6_sits_above_f4_behind_a_gated_floor_hole_and_holds_one_storm_eel_in_water() -> void:
	var f6: RoomDef = rooms["F6"]
	assert_eq(f6.cell, Vector2i(15, 5))
	assert_eq(f6.size, Vector2i(1, 1))
	assert_eq(f6.area, "flooded")
	assert_true(f6.exits.any(func(e): return e["edge"] == "bottom" and e["room"] == "F4" and e.get("gate", "") == "swim"))
	assert_eq(f6.spawns.size(), 1)
	assert_eq(f6.spawns[0]["id"], "storm_eel")
	var wet := false
	for w in f6.water:
		if (w as Rect2).has_point(f6.spawns[0]["pos"]):
			wet = true
	assert_true(wet)

func test_f6_never_counts_toward_the_pacing_rule() -> void:
	assert_eq(_first_time(["F1", "F2", "F3", "F4", "F5"]), 188)
	var with_f6 := _first_time(["F1", "F2", "F3", "F4", "F5", "F6"])
	assert_eq(with_f6, 188 + 20, "the Storm Eel's first-time value is 20, and it is outside the rule")

func test_f4s_column_does_not_overlap_its_platforms_or_hole() -> void:
	var f4: RoomDef = rooms["F4"]
	var column: Rect2 = f4.water[0]
	for s in f4.solids:
		assert_false((s as Rect2).intersects(column), "no platform stands in the column")
	var hole: Dictionary = f4.exits.filter(func(e): return e["edge"] == "bottom")[0]
	assert_lt(float(hole["to"]) + 40.0, column.position.x, "the column keeps clear of the floor hole")
