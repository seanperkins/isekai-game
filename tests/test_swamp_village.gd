extends GutTest
## The swamp and the goblin village east of the forest: their rooms at their cells, the exits that join them to the world, and nothing else
## of the world changed.

const SWAMP := {"SW1": [Vector2i(11, 0), Vector2i(1, 1)], "SW2": [Vector2i(12, 0), Vector2i(2, 1)], "SW3": [Vector2i(14, 0), Vector2i(2, 1)],
	"SW4": [Vector2i(15, -1), Vector2i(1, 1)], "SW5": [Vector2i(16, 0), Vector2i(1, 1)]}
## The creatures the design table gives the swamp that exist as data before F2f places the twins.
const SWAMP_SUPPORT := ["blood_leech", "bog_wisp", "firefly_swarm"]

var world: Dictionary  # the swamp built, the village not yet
var before: Dictionary  # the forest's world

func before_all() -> void:
	world = AreaWorlds.without(["VI"])
	before = AreaWorlds.without(["SW", "VI"])

func test_the_swamp_is_five_rooms_at_their_cells_and_sizes() -> void:
	for id in SWAMP:
		assert_true(world.has(id), id)
		var r: RoomDef = world[id]
		assert_eq(r.area, "swamp", id)
		assert_eq(r.cell, SWAMP[id][0], id)
		assert_eq(r.size, SWAMP[id][1], id)

func test_the_world_with_the_swamp_has_no_problems() -> void:
	assert_eq(Array(AreaBuilder.problems(world)), [])

func test_every_swamp_room_is_reachable_from_the_start() -> void:
	var reached := WorldValidator.reachable(world)
	for id in SWAMP:
		assert_true(reached.has(id), "%s: no way in from the start room" % id)

func test_the_dens_east_door_is_the_only_way_in_and_nothing_else_of_the_forest_changed() -> void:
	var was: RoomDef = before["FO9"]
	var now: RoomDef = world["FO9"]
	assert_eq(now.exits.size(), was.exits.size() + 1)
	var e: Dictionary = now.exits.filter(func(x: Dictionary) -> bool: return x["room"] == "SW1")[0]
	assert_eq([e["edge"], e["from"], e["to"]], ["right", 200.0, 320.0])
	for id in before:
		if id != "FO9":
			assert_true(AreaBuilder.same(world[id], before[id]), "%s is untouched" % id)
	for p in now.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) != 0 and p["name"] != "script" and p["name"] != "exits":
			assert_eq(now.get(p["name"]), was.get(p["name"]), "FO9.%s is as built" % p["name"])

func test_every_swamp_spawn_is_a_creature_the_swamp_holds() -> void:
	var seen := {}
	for id in SWAMP:
		for s in (world[id] as RoomDef).spawns:
			assert_true(SWAMP_SUPPORT.has(s["id"]), "%s: %s" % [id, s["id"]])
			seen[s["id"]] = true
	for c in SWAMP_SUPPORT:
		assert_true(seen.has(c), "%s lives in the swamp" % c)

func test_the_seam_between_forest_and_swamp_has_no_creatures() -> void:
	assert_eq((world["SW1"] as RoomDef).spawns, [])

func test_the_bog_flats_climb_ends_in_the_opening_to_the_roost() -> void:
	var flat := world["SW3"] as RoomDef
	var up := flat.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "top")
	assert_eq(up.size(), 1)
	var top: Rect2 = flat.solids[flat.solids.size() - 1]
	assert_eq(top.position.y, 14.0, "the last ledge stands in the opening")
	assert_true(top.position.x >= float(up[0]["from"]) and top.end.x <= float(up[0]["to"]))

func test_the_checked_in_rooms_are_what_the_builder_writes() -> void:
	assert_eq(AreaBuilder.stale(AreaBuilder.build()), [])
