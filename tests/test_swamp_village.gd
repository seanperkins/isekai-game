extends GutTest
## The swamp and the goblin village east of the forest: their rooms at their cells, the exits that join them to the world, and nothing else
## of the world changed.

const SWAMP := {"SW1": [Vector2i(11, 0), Vector2i(1, 1)], "SW2": [Vector2i(12, 0), Vector2i(2, 1)], "SW3": [Vector2i(14, 0), Vector2i(2, 1)],
	"SW4": [Vector2i(15, -1), Vector2i(1, 1)], "SW5": [Vector2i(16, 0), Vector2i(1, 1)]}
## The creatures the design table gives the swamp that exist as data before F2f places the twins.
const SWAMP_SUPPORT := ["blood_leech", "bog_wisp", "firefly_swarm"]
## The village: the Gate Shrine, the Palisade Roofs, the Yard and the Chieftain Hall, and the Sump below (the swamp's, in flooded art).
const VILLAGE := {"VI1": [Vector2i(15, 1), Vector2i(1, 1), "village"], "VI2": [Vector2i(13, 1), Vector2i(2, 1), "village"],
	"VI3": [Vector2i(14, 2), Vector2i(2, 1), "village"], "VI4": [Vector2i(13, 2), Vector2i(1, 1), "village"],
	"VI5": [Vector2i(15, 3), Vector2i(1, 2), "swamp"]}
const VILLAGE_SUPPORT := ["village_goblin", "cave_rat", "junk", "goblin_shaman"]

var world: Dictionary  # the swamp built, the village not yet
var before: Dictionary  # the forest's world
var full: Dictionary  # everything checked in

func before_all() -> void:
	world = AreaWorlds.without(["VI"])
	before = AreaWorlds.without(["SW", "VI"])
	full = World.load_rooms(AreaBuilder.ROOMS_DIR)

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

# --- the village ---

func test_the_village_is_four_rooms_and_the_sump_at_their_cells_sizes_and_areas() -> void:
	for id in VILLAGE:
		assert_true(full.has(id), id)
		var r: RoomDef = full[id]
		assert_eq(r.cell, VILLAGE[id][0], id)
		assert_eq(r.size, VILLAGE[id][1], id)
		assert_eq(r.area, VILLAGE[id][2], id)

func test_the_whole_world_has_no_problems() -> void:
	assert_eq(Array(AreaBuilder.problems(full)), [])

func test_every_village_room_is_reachable_from_the_start() -> void:
	var reached := WorldValidator.reachable(full)
	for id in VILLAGE:
		assert_true(reached.has(id), "%s: no way in from the start room" % id)

func test_the_gate_shrine_is_neutral_ground_a_pool_and_no_creatures_and_no_altar() -> void:
	var shrine := full["VI1"] as RoomDef
	assert_eq(shrine.spawns, [], "a non-goblin must never wake in a hostile palisade")
	assert_eq(shrine.features.filter(func(f: Dictionary) -> bool: return f["kind"] == "glow_pool").size(), 1)
	for id in VILLAGE:
		for f in (full[id] as RoomDef).features:
			assert_ne(f["kind"], "altar", id)

func test_the_sump_joins_f6_by_a_shortcut_that_is_closed_until_a_swimmer_opens_it_from_f6() -> void:
	var down: Dictionary = (full["VI5"] as RoomDef).exits.filter(func(e: Dictionary) -> bool: return e["room"] == "F6")[0]
	var up: Dictionary = (full["F6"] as RoomDef).exits.filter(func(e: Dictionary) -> bool: return e["room"] == "VI5")[0]
	assert_eq([down["edge"], up["edge"]], ["bottom", "top"])
	for e in [down, up]:
		assert_eq(e["shortcut"], "sump_drop")
		assert_false(e.has("gate"), "a drop cannot be gated by a label: a walker sinks through it, so the hole is shut until the swim has opened it")
		assert_false(RoomBuilder.is_exit_open(e, null), "closed in play until the shortcut is opened")
	assert_eq((full["VI5"] as RoomDef).water.size(), 1, "a flooded shaft")

func test_the_switch_that_opens_it_stands_on_f6s_highest_ledge_where_only_a_swimmer_comes() -> void:
	var f6 := full["F6"] as RoomDef
	var switches := f6.features.filter(func(f: Dictionary) -> bool: return f["kind"] == "switch")
	assert_eq(switches.size(), 1)
	assert_eq(switches[0]["shortcut"], "sump_drop")
	var top: Rect2 = f6.solids[0]
	for l: Rect2 in f6.solids:
		if l.position.y < top.position.y:
			top = l
	assert_eq((switches[0]["pos"] as Vector2).y, top.position.y, "on the highest ledge")
	assert_true(top.position.x <= (switches[0]["pos"] as Vector2).x - 9.0 and top.end.x >= (switches[0]["pos"] as Vector2).x + 9.0, "wholly on it")

func test_f6_gains_exactly_one_exit_and_one_switch_and_nothing_else_of_it_changes() -> void:
	var was: RoomDef = world["F6"]
	var now: RoomDef = full["F6"]
	assert_eq(now.exits.size(), was.exits.size() + 1)
	assert_eq(now.features.size(), was.features.size() + 1)
	for p in now.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) != 0 and p["name"] != "script" and p["name"] != "exits" and p["name"] != "features":
			assert_eq(now.get(p["name"]), was.get(p["name"]), "F6.%s is as shipped" % p["name"])

func test_the_village_adds_no_ungated_way_into_the_flooded_tunnels() -> void:
	var flooded := func(rooms: Dictionary) -> Array:
		var out: Array = WorldValidator.reachable(rooms, true).filter(func(id: String) -> bool: return (rooms[id] as RoomDef).area == "flooded")
		out.sort()
		return out
	assert_eq(flooded.call(full), flooded.call(before), "swim is still what opens the Sump and F6")

func test_every_village_spawn_is_a_creature_the_village_holds() -> void:
	var seen := {}
	for id in VILLAGE:
		for s in (full[id] as RoomDef).spawns:
			assert_true(VILLAGE_SUPPORT.has(s["id"]), "%s: %s" % [id, s["id"]])
			seen[s["id"]] = true
	for c in VILLAGE_SUPPORT:
		assert_true(seen.has(c), "%s lives in the village" % c)

func test_every_climb_in_the_village_ends_in_its_opening() -> void:
	for id in ["VI1", "VI3", "VI5"]:
		var r := full[id] as RoomDef
		var holes := r.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "top")
		for h: Dictionary in holes:
			var in_hole := r.solids.filter(func(l: Rect2) -> bool: return l.position.y == 14.0 and l.position.x >= float(h["from"]) and l.end.x <= float(h["to"]))
			assert_eq(in_hole.size(), 1, "%s: a ledge stands in the opening %s..%s" % [id, h["from"], h["to"]])

func test_the_checked_in_rooms_are_what_the_builder_writes() -> void:
	assert_eq(AreaBuilder.stale(AreaBuilder.build()), [])
