extends GutTest
## The placement: a spot for each creature in a room of one of its areas, on a made-up world and plan.

var defs: Dictionary

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		defs[c.id] = c

## A room of `area` at a cell far from everything, a screen wide unless `size` says.
func _room(id: String, area: String, cell: Vector2i, size := Vector2i.ONE) -> RoomDef:
	return AreaKit.room(id, area, cell, size)

func _plan(creatures: Dictionary, lairs := [], quiet := []) -> Dictionary:
	return {"creatures": creatures, "lairs": lairs, "quiet": quiet}

func _world(rooms: Array) -> Dictionary:
	var w := {}
	for r in rooms:
		w[r.id] = r
	return w

func _placed(world: Dictionary, room: String) -> Array:
	return (world[room] as RoomDef).spawns.filter(func(s: Dictionary) -> bool: return s.get("by", "") == "PL")

func _all_placed(world: Dictionary) -> Array:
	var out: Array = []
	for id in world:
		for s in _placed(world, id):
			out.append([id, s])
	return out

func _run(world: Dictionary, plan: Dictionary, custom := {}) -> AreaPlacement:
	var pl := AreaPlacement.new(plan, defs.merged(custom))
	pl.build(world)
	return pl

# --- the size of a creature ---

func test_size_of_a_creature_is_its_sheets_frame_or_the_creature_it_wears_times_its_size() -> void:
	var rat: CreatureDef = defs["cave_rat"]  # wears the lizard
	assert_eq(AreaPlacement.size_of(rat), RoomLint.creature_extent(rat.wears) * rat.sprite_size)
	var fenrir: CreatureDef = defs["twin_wolf_fenrir"]
	var sheet := SpriteSheet.load_set(fenrir.sprite_set)
	assert_eq(AreaPlacement.size_of(fenrir), sheet.frame_size(fenrir.sprite_frame) * fenrir.sprite_size)

# --- where a creature goes ---

func test_a_creature_lands_in_a_room_of_its_area_on_a_surface_marked_pl() -> void:
	var world := _world([_room("PA", "forest", Vector2i(60, 60)), _room("PB", "swamp", Vector2i(61, 60))])
	var pl := _run(world, _plan({"village_goblin": {"areas": ["forest"], "class": "common"}}))
	assert_eq(pl.unplaced, [])
	assert_eq(_placed(world, "PA").size(), 1)
	assert_eq(_placed(world, "PB").size(), 0, "not its area")
	var s: Dictionary = _placed(world, "PA")[0]
	assert_eq(s["id"], "village_goblin")
	assert_eq(RoomLint.spawn_findings(world["PA"]), [])

func test_a_quiet_room_the_start_room_and_a_boss_arena_get_nothing() -> void:
	var quiet := _room("PQ", "forest", Vector2i(60, 60))
	var start := _room("PS", "forest", Vector2i(61, 60))
	AreaKit.start(start, 100.0)
	var boss := _room("PX", "forest", Vector2i(62, 60), Vector2i(2, 1))
	boss.boss = {"creature": "village_goblin", "threshold": Rect2(300, 200, 40, 100)}
	var open := _room("PO", "forest", Vector2i(64, 60))
	var world := _world([quiet, start, boss, open])
	_run(world, _plan({"village_goblin": {"areas": ["forest"], "class": "common"}, "cave_rat": {"areas": ["forest"], "class": "common"}}, [], ["PQ"]))
	assert_eq(_placed(world, "PQ").size() + _placed(world, "PS").size() + _placed(world, "PX").size(), 0)
	assert_eq(_placed(world, "PO").size(), 2)

func test_a_rare_goes_to_a_lair_and_to_another_room_when_the_area_has_none_with_room() -> void:
	var lair := _room("PL1", "forest", Vector2i(60, 60))
	var other := _room("PL2", "forest", Vector2i(61, 60))
	var world := _world([lair, other])
	_run(world, _plan({"gargoyle": {"areas": ["forest"], "class": "rare"}}, ["PL1"]))
	assert_eq(_placed(world, "PL1").size(), 1, "the lair, though the other room is emptier")
	var no_lair := _world([_room("PL3", "forest", Vector2i(60, 60))])
	var pl := _run(no_lair, _plan({"gargoyle": {"areas": ["forest"], "class": "rare"}}, ["PZ9"]))
	assert_eq(pl.unplaced, [])
	assert_eq(_placed(no_lair, "PL3").size(), 1, "a rare with no lair in its area stands in an ordinary room")

func test_a_creature_too_big_for_any_surface_is_unplaced_and_named() -> void:
	var giant := CreatureDef.new()
	giant.id = "giant"
	giant.display_name = "Giant"
	giant.sprite_set = "forms_wolf"
	giant.sprite_frame = "fenrir"
	giant.sprite_size = 30.0
	var world := _world([_room("PA", "forest", Vector2i(60, 60))])
	var pl := _run(world, _plan({"giant": {"areas": ["forest"], "class": "common"}}), {"giant": giant})
	assert_push_error("giant")
	assert_eq(pl.unplaced, ["giant"])
	assert_eq(_placed(world, "PA").size(), 0)

func test_creatures_on_one_surface_do_not_overlap() -> void:
	var world := _world([_room("PA", "forest", Vector2i(60, 60))])
	var plan := {}
	for id in ["village_goblin", "cave_rat", "tusker_boar", "moon_hare", "firefly_swarm"]:
		plan[id] = {"areas": ["forest"], "class": "common"}
	_run(world, _plan(plan))
	var spawns: Array = (world["PA"] as RoomDef).spawns.filter(func(s: Dictionary) -> bool: return s.get("by", "") == "PL" and RoomLint.creature_kind(s["id"]) != "flier")
	for i in spawns.size():
		for j in range(i + 1, spawns.size()):
			var a: Dictionary = spawns[i]
			var b: Dictionary = spawns[j]
			if absf((a["pos"] as Vector2).y - (b["pos"] as Vector2).y) < 60.0:
				var need := (AreaPlacement.size_of(defs[a["id"]]).x + AreaPlacement.size_of(defs[b["id"]]).x) / 2.0
				assert_gte(absf((a["pos"] as Vector2).x - (b["pos"] as Vector2).x), need, "%s and %s" % [a["id"], b["id"]])

func test_nothing_stands_under_a_ledge_too_low_for_it_or_over_a_floor_hole_or_in_a_door() -> void:
	var r := _room("PA", "forest", Vector2i(60, 60))
	AreaKit.ledge(r, 20.0, 300.0, 300.0)  # a ledge 8 above the floor over the west half: no head room under it
	r.exits = [{"edge": "bottom", "from": 440.0, "to": 560.0, "room": "PZ"}, {"edge": "left", "from": 200.0, "to": 320.0, "room": "PY"}]
	var world := _world([r])
	var plan := {}
	for id in ["village_goblin", "cave_rat", "tusker_boar"]:
		plan[id] = {"areas": ["forest"], "class": "common"}
	_run(world, _plan(plan))
	for pair in _all_placed(world):
		var s: Dictionary = pair[1]
		var half := AreaPlacement.size_of(defs[s["id"]]).x / 2.0
		var x: float = (s["pos"] as Vector2).x
		var on_floor: bool = (s["pos"] as Vector2).y > 310.0 - Enemy.BODY_BOTTOM  # not standing on the ledge (top 300)
		if on_floor:
			assert_false(x + half > 20.0 and x - half < 320.0, "%s is under the low ledge" % s["id"])
			assert_false(x + half > 440.0 and x - half < 560.0, "%s is over the hole" % s["id"])
			assert_gte(x - half, RoomDef.WALL + RoomLint.CLEAR, "%s is in the doorway" % s["id"])

func test_the_emptier_room_gets_the_next_creature() -> void:
	var world := _world([_room("PA", "forest", Vector2i(60, 60)), _room("PB", "forest", Vector2i(61, 60))])
	var plan := {}
	for id in ["village_goblin", "cave_rat", "tusker_boar", "moon_hare"]:
		plan[id] = {"areas": ["forest"], "class": "common"}
	_run(world, _plan(plan))
	assert_eq(_placed(world, "PA").size(), 2)
	assert_eq(_placed(world, "PB").size(), 2)

func test_a_second_build_places_the_same_creatures_at_the_same_spots_and_hand_made_spawns_are_untouched() -> void:
	var make := func() -> Dictionary:
		var r := _room("PA", "forest", Vector2i(60, 60), Vector2i(2, 1))
		AreaKit.spawn(r, "bat", 300.0, AreaKit.floor_y(r))
		return _world([r, _room("PB", "forest", Vector2i(62, 60))])
	var plan := {}
	for id in ["village_goblin", "cave_rat", "tusker_boar", "moon_hare", "gargoyle"]:
		plan[id] = {"areas": ["forest"], "class": "rare" if id == "gargoyle" else "common"}
	var a: Dictionary = make.call()
	var b: Dictionary = make.call()
	_run(a, _plan(plan))
	_run(b, _plan(plan))
	for id in a:
		assert_eq((a[id] as RoomDef).spawns, (b[id] as RoomDef).spawns, id)
	var first: Dictionary = (a["PA"] as RoomDef).spawns[0]
	assert_eq(first["id"], "bat")
	assert_false(first.has("by"), "the hand-made spawn is first and unmarked")

func test_a_flier_hovers_clear_of_the_rock() -> void:
	var world := _world([_room("PA", "forest", Vector2i(60, 60))])
	assert_eq(RoomLint.creature_kind("ghost"), "flier")
	_run(world, _plan({"ghost": {"areas": ["forest"], "class": "common"}}))
	var s: Dictionary = _placed(world, "PA")[0]
	assert_eq(RoomLint.spawn_findings(world["PA"]), [])
	assert_lt((s["pos"] as Vector2).y, AreaKit.floor_y(world["PA"]) - 60.0, "in the air")
