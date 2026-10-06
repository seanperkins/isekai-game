extends GutTest
## The forest above the cave: nine rooms, joined to the shipped world by two exits, and nothing else of the shipped world changed.

const CELLS := {"FO1": [Vector2i(3, 0), Vector2i(1, 1)], "FO2": [Vector2i(4, 0), Vector2i(2, 1)], "FO3": [Vector2i(6, 0), Vector2i(1, 1)],
	"FO4": [Vector2i(4, 1), Vector2i(1, 1)], "FO5": [Vector2i(6, -3), Vector2i(1, 3)], "FO6": [Vector2i(7, -3), Vector2i(3, 1)],
	"FO7": [Vector2i(10, -3), Vector2i(1, 1)], "FO8": [Vector2i(7, 0), Vector2i(3, 1)], "FO9": [Vector2i(10, 0), Vector2i(1, 1)]}
## The creatures the design table says live in the forest and that exist as data before F2f places the twins.
const FOREST_SUPPORT := ["village_goblin", "firefly_swarm", "moon_hare", "tusker_boar"]

var world: Dictionary
var shipped: Dictionary

func before_all() -> void:
	world = AreaWorlds.upto("FO")  # the world as it was when the forest was built: the later areas are tests of their own
	shipped = AreaWorlds.upto("")  # the hand-authored world as it was before the builder

func test_the_forest_is_nine_rooms_at_their_cells_and_sizes() -> void:
	for id in CELLS:
		assert_true(world.has(id), id)
		var r: RoomDef = world[id]
		assert_eq(r.area, "forest", id)
		assert_eq(r.cell, CELLS[id][0], id)
		assert_eq(r.size, CELLS[id][1], id)
	assert_eq(world.keys().filter(func(k: String) -> bool: return (world[k] as RoomDef).area == "forest").size(), 9)

func test_the_whole_world_has_no_problems() -> void:
	assert_eq(Array(AreaBuilder.problems(world)), [])

func test_every_forest_room_is_reachable_from_the_start() -> void:
	var reached := WorldValidator.reachable(world)
	for id in CELLS:
		assert_true(reached.has(id), "%s: no way in from the start room" % id)

func test_the_cave_is_reachable_without_the_forest() -> void:
	var cave := {}
	for id in shipped:
		var r: RoomDef = (shipped[id] as RoomDef)
		var c := AreaBuilder.copy_room(r)
		c.exits = c.exits.filter(func(e: Dictionary) -> bool: return not CELLS.has(e["room"]))
		cave[id] = c
	assert_eq(shipped.size(), ShippedRooms.IDS.size())
	assert_eq(WorldValidator.reachable(cave).size(), shipped.size(), "every shipped room is still reached")

func test_the_forest_joins_the_cave_by_two_exits_and_changes_nothing_else_of_it() -> void:
	var before := shipped
	for id in ["C3", "C4"]:
		var was: RoomDef = before[id]
		var now: RoomDef = world[id]
		assert_eq(now.exits.size(), was.exits.size() + 1, id)
		for p in now.get_property_list():
			if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) != 0 and p["name"] != "script" and p["name"] != "exits":
				assert_eq(now.get(p["name"]), was.get(p["name"]), "%s.%s is as shipped" % [id, p["name"]])
	for id in ShippedRooms.IDS:
		if id != "C3" and id != "C4":
			assert_true(AreaBuilder.same(world[id], before[id]), "%s is untouched" % id)

func test_c3_opens_east_onto_the_cave_mouth_at_the_height_of_a_hop_up() -> void:
	var e: Dictionary = (world["C3"] as RoomDef).exits.filter(func(x: Dictionary) -> bool: return x["room"] == "FO1")[0]
	assert_eq(e["edge"], "right")
	assert_eq(e["from"], 200.0)
	assert_eq(e["to"], 320.0)

func test_c4_takes_the_drop_from_the_root_hollow() -> void:
	var e: Dictionary = (world["C4"] as RoomDef).exits.filter(func(x: Dictionary) -> bool: return x["room"] == "FO4")[0]
	assert_eq(e["edge"], "top")
	assert_eq([e["from"], e["to"]], [440.0, 560.0])
	assert_eq(e["gate"], "wall_cling", "the drop is one way down; going back up wants the wall cling, so the cave stays closed to the forest without it")

func test_the_first_surface_room_has_no_creatures_and_the_clearing_has_a_pool_and_no_altar() -> void:
	assert_eq((world["FO1"] as RoomDef).spawns, [])
	var pool: Array = (world["FO3"] as RoomDef).features.filter(func(f: Dictionary) -> bool: return f["kind"] == "glow_pool")
	assert_eq(pool.size(), 1)
	for id in CELLS:
		for f in (world[id] as RoomDef).features:
			assert_ne(f["kind"], "altar", id)

func test_every_forest_spawn_is_a_creature_the_forest_holds() -> void:
	var seen := {}
	for id in CELLS:
		for s in (world[id] as RoomDef).spawns:
			assert_true(FOREST_SUPPORT.has(s["id"]), "%s: %s" % [id, s["id"]])
			seen[s["id"]] = true
	for c in FOREST_SUPPORT:
		assert_true(seen.has(c), "%s lives in the forest" % c)

func test_the_clearings_climb_ends_in_the_opening_and_the_trunk_starts_beside_its_hole() -> void:
	var clearing := world["FO3"] as RoomDef
	var top: Rect2 = clearing.solids[clearing.solids.size() - 1]
	assert_eq(top.position.y, 14.0, "the last ledge stands in the opening, as G1's")
	assert_true(top.position.x >= 240.0 and top.end.x <= 400.0)
	var trunk := world["FO5"] as RoomDef
	var flanks := trunk.solids.filter(func(s: Rect2) -> bool: return s.position.y == 988.0)
	assert_eq(flanks.size(), 2, "a ledge either side of the hole in the floor")
	var last: Rect2 = trunk.solids[trunk.solids.size() - 1]
	assert_eq(last.position.y, 364.0)
	assert_eq(last.end.x, 610.0, "out to the door")

func test_the_hollows_drop_has_nothing_over_it() -> void:
	var hollow := world["FO4"] as RoomDef
	for s in hollow.spawns:
		assert_false(s["pos"].x > 440.0 and s["pos"].x < 560.0)
	var holes := hollow.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "bottom")
	assert_eq(holes.size(), 1)
