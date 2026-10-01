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
	assert_eq(gated, ["F2:swim", "F3:swim"], "F2's top exit and F3's floor hole")

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
	# G4 -> F1 and F4 -> F5: the top ledge sits at local y 12-15 flush with the span's west edge, every hop at most 55 up
	for pair in [["G4", "F1"], ["F4", "F5"]]:
		var upper: RoomDef = rooms[pair[0]]
		var lower: RoomDef = rooms[pair[1]]
		var hole: Dictionary = upper.exits.filter(func(e): return e["edge"] == "bottom" and e["room"] == pair[1])[0]
		var span := WorldValidator.world_span(upper, hole)
		var west := span.x - WorldValidator.edge_origin(lower, "top")
		var tops: Array = lower.solids.map(func(s): return (s as Rect2).position.y)
		tops.sort()
		assert_between(tops[0], 12.0, 15.0, "%s: the top ledge" % pair[1])
		var top_ledge: Rect2 = lower.solids.filter(func(s): return (s as Rect2).position.y == tops[0])[0]
		assert_almost_eq(top_ledge.position.x, west, 1.0, "%s: flush with the span's west edge" % pair[1])
		for i in range(1, tops.size()):
			if tops[i] - tops[i - 1] > 55.0:
				break
			assert_lte(tops[i] - tops[i - 1], 55.0)
		for w in lower.water:
			for s in lower.solids:
				if (s as Rect2).position.y > 100.0:
					continue
				assert_false((s as Rect2).intersects(w), "%s: the chain stands outside every water rect" % pair[1])

## The Swim door of a room's top exit, in the three parts the Grotto's G5 test has.
func _assert_door(room_id: String) -> void:
	var r: RoomDef = rooms[room_id]
	var top: Dictionary = r.exits.filter(func(e): return e["edge"] == "top" and e.get("gate", "") == "swim")[0]
	var column: Rect2 = r.water.filter(func(w): return (w as Rect2).position.y <= RoomDef.WALL + 0.5 and (w as Rect2).end.x > float(top["from"]) and (w as Rect2).position.x < float(top["to"]))[0]
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

func test_the_swim_door_is_structural() -> void:
	_assert_door("F2")

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
