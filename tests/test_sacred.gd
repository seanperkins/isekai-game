extends GutTest
## The sacred cluster above and east of the Deep: a cemetery, a cathedral and a crypt, their rooms at their cells, the exits that join them to
## the world, and nothing else of the world changed.

const CEMETERY := {"CM1": [Vector2i(18, 4), Vector2i(1, 1)], "CM2": [Vector2i(19, 4), Vector2i(2, 1)], "CM3": [Vector2i(21, 4), Vector2i(1, 1)]}
## The creatures the design table gives the cemetery's open rooms (the churchyard itself is a truce).
const CEMETERY_SUPPORT := ["skeleton", "ghost", "carrion_crow"]

var graveyard: Dictionary  # the cemetery built, the rest of the cluster not yet
var before: Dictionary  # the world before the cluster: the forest, the swamp and the village

func before_all() -> void:
	graveyard = AreaWorlds.upto("CM")
	before = AreaWorlds.upto("VI")

func test_the_cemetery_is_three_rooms_at_their_cells_and_sizes() -> void:
	for id in CEMETERY:
		assert_true(graveyard.has(id), id)
		var r: RoomDef = graveyard[id]
		assert_eq(r.area, "cemetery", id)
		assert_eq(r.cell, CEMETERY[id][0], id)
		assert_eq(r.size, CEMETERY[id][1], id)

func test_the_world_with_the_cemetery_has_no_problems() -> void:
	assert_eq(Array(AreaBuilder.problems(graveyard)), [])

func test_the_cemetery_is_reached_only_through_the_wall_cling_the_deeps_antechamber_asks_for() -> void:
	var reached := WorldValidator.reachable(graveyard)
	var ungated := WorldValidator.reachable(graveyard, true)
	for id in CEMETERY:
		assert_true(reached.has(id), "%s: no way in from the start room" % id)
		assert_false(ungated.has(id), "%s is behind the wall cling" % id)
	var rest := ungated.filter(func(id: String) -> bool: return not CEMETERY.has(id))
	rest.sort()
	var was := WorldValidator.reachable(before, true)
	was.sort()
	assert_eq(rest, was, "the cemetery opens no way into anything else without the wall cling")

func test_d7_gains_one_exit_and_nothing_else_and_the_arena_is_untouched() -> void:
	var was: RoomDef = before["D7"]
	var now: RoomDef = graveyard["D7"]
	assert_eq(now.exits.size(), was.exits.size() + 1)
	var e: Dictionary = now.exits.filter(func(x: Dictionary) -> bool: return x["room"] == "CM1")[0]
	assert_eq([e["edge"], e["gate"]], ["top", "wall_cling"])
	for p in now.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) != 0 and p["name"] != "script" and p["name"] != "exits":
			assert_eq(now.get(p["name"]), was.get(p["name"]), "D7.%s is as shipped" % p["name"])
	assert_true(AreaBuilder.same(graveyard["D6"], before["D6"]), "a boss room has exactly one exit: the Taratect's arena gains none")
	for id in before:
		if id != "D7":
			assert_true(AreaBuilder.same(graveyard[id], before[id]), "%s is untouched" % id)

func test_the_churchyard_is_a_truce_a_pool_a_tablet_no_altar_and_no_creatures() -> void:
	var yard := graveyard["CM2"] as RoomDef
	assert_eq(yard.spawns, [])
	assert_eq(yard.features.filter(func(f: Dictionary) -> bool: return f["kind"] == "glow_pool").size(), 1)
	assert_eq(yard.features.filter(func(f: Dictionary) -> bool: return f["kind"] == "tablet").size(), 1)
	for id in CEMETERY:
		for f in (graveyard[id] as RoomDef).features:
			assert_ne(f["kind"], "altar", id)

func test_the_gate_tunnel_and_the_lych_gate_hold_the_cemeterys_creatures() -> void:
	var seen := {}
	for id in ["CM1", "CM3"]:
		for s in (graveyard[id] as RoomDef).spawns:
			assert_true(CEMETERY_SUPPORT.has(s["id"]), "%s: %s" % [id, s["id"]])
			seen[s["id"]] = true
	for c in CEMETERY_SUPPORT:
		assert_true(seen.has(c), "%s lives in the cemetery" % c)

func test_the_gate_tunnels_flanks_stand_either_side_of_its_floor_hole() -> void:
	var tunnel := graveyard["CM1"] as RoomDef
	var hole: Dictionary = tunnel.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "bottom")[0]
	var flanks := tunnel.solids.filter(func(s: Rect2) -> bool: return s.position.y == 268.0)
	assert_eq(flanks.size(), 2)
	flanks.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	assert_lt((flanks[0] as Rect2).end.x, float(hole["from"]))
	assert_gt((flanks[1] as Rect2).position.x, float(hole["to"]))

func test_the_checked_in_rooms_are_what_the_builder_writes() -> void:
	assert_eq(AreaBuilder.stale(AreaBuilder.build()), [])
