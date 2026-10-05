extends GutTest
## The volcano under the Deep and the demon area past the crypt: their rooms at their cells, the exits that join them to the world, and
## nothing else of the world changed.

const VOLCANO := {"VO1": [Vector2i(22, 8), Vector2i(1, 1)], "VO2": [Vector2i(23, 8), Vector2i(2, 1)], "VO3": [Vector2i(25, 8), Vector2i(1, 2)],
	"VO4": [Vector2i(24, 10), Vector2i(2, 1)], "VO5": [Vector2i(26, 10), Vector2i(1, 1)], "VO6": [Vector2i(24, 11), Vector2i(1, 1)],
	"VO7": [Vector2i(24, 9), Vector2i(1, 1)]}
const VOLCANO_SUPPORT := ["ember_beetle", "lava_salamander", "ash_moth"]

var hot: Dictionary  # the volcano built, the demon area not yet
var before: Dictionary  # the world before the volcano

func before_all() -> void:
	hot = AreaWorlds.upto("VO")
	before = AreaWorlds.upto("CR")

## True when a ledge stands in the opening of room `r`'s top exit `h` with its top at 14 (the end of a climb).
func _climb_ends_in(r: RoomDef, h: Dictionary) -> bool:
	return r.solids.any(func(l: Rect2) -> bool: return l.position.y == 14.0 and l.position.x >= float(h["from"]) and l.end.x <= float(h["to"]))

func test_the_volcano_is_seven_rooms_at_their_cells_sizes_and_area() -> void:
	for id in VOLCANO:
		assert_true(hot.has(id), id)
		var r: RoomDef = hot[id]
		assert_eq(r.area, "volcano", id)
		assert_eq(r.cell, VOLCANO[id][0], id)
		assert_eq(r.size, VOLCANO[id][1], id)

func test_the_world_with_the_volcano_has_no_problems() -> void:
	assert_eq(Array(AreaBuilder.problems(hot)), [])

func test_the_volcano_is_reachable_but_not_without_the_deeps_gates_and_opens_nothing_else() -> void:
	var reached := WorldValidator.reachable(hot)
	var ungated := WorldValidator.reachable(hot, true)
	for id in VOLCANO:
		assert_true(reached.has(id), "%s: no way in from the start room" % id)
		assert_false(ungated.has(id), "%s is behind the Deep's gates" % id)
	var rest := ungated.filter(func(id: String) -> bool: return not VOLCANO.has(id))
	rest.sort()
	var was := WorldValidator.reachable(before, true)
	was.sort()
	assert_eq(rest, was)

func test_d4_gains_one_exit_a_hole_in_its_floor_and_nothing_else() -> void:
	var was := before["D4"] as RoomDef
	var now := hot["D4"] as RoomDef
	assert_eq(now.exits.size(), was.exits.size() + 1)
	var e: Dictionary = now.exits.filter(func(x: Dictionary) -> bool: return x["room"] == "VO1")[0]
	assert_eq([e["edge"], e["from"], e["to"]], ["bottom", 1100.0, 1260.0])
	assert_false(e.has("gate") or e.has("shortcut"))
	for p in now.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) != 0 and p["name"] != "script" and p["name"] != "exits":
			assert_eq(now.get(p["name"]), was.get(p["name"]), "D4.%s is as shipped" % p["name"])
	for id in before:
		if id != "D4":
			assert_true(AreaBuilder.same(hot[id], before[id]), "%s is untouched" % id)

func test_ashfall_is_a_threshold_a_tablet_and_no_creatures_and_ember_hall_has_the_pool() -> void:
	var ash := hot["VO1"] as RoomDef
	assert_eq(ash.spawns, [])
	assert_eq(ash.features.filter(func(f: Dictionary) -> bool: return f["kind"] == "tablet").size(), 1)
	assert_eq((hot["VO2"] as RoomDef).features.filter(func(f: Dictionary) -> bool: return f["kind"] == "glow_pool").size(), 1)
	for id in VOLCANO:
		for f in (hot[id] as RoomDef).features:
			assert_ne(f["kind"], "altar", id)

func test_the_volcano_holds_the_fire_creatures_and_only_them() -> void:
	var seen := {}
	for id in VOLCANO:
		for s in (hot[id] as RoomDef).spawns:
			assert_true(VOLCANO_SUPPORT.has(s["id"]), "%s: %s" % [id, s["id"]])
			seen[s["id"]] = true
	for c in VOLCANO_SUPPORT:
		assert_true(seen.has(c), "%s lives in the volcano" % c)

func test_the_ash_cut_is_a_shortcut_up_to_ember_hall_that_its_own_switch_opens() -> void:
	var cut := hot["VO7"] as RoomDef
	var up: Dictionary = cut.exits.filter(func(e: Dictionary) -> bool: return e["room"] == "VO2")[0]
	var down: Dictionary = cut.exits.filter(func(e: Dictionary) -> bool: return e["room"] == "VO4")[0]
	var partner: Dictionary = (hot["VO2"] as RoomDef).exits.filter(func(e: Dictionary) -> bool: return e["room"] == "VO7")[0]
	assert_eq([up["edge"], down["edge"], partner["edge"]], ["top", "bottom", "bottom"])
	assert_eq(up["shortcut"], "ash_cut")
	assert_eq(partner["shortcut"], "ash_cut")
	assert_false(down.has("shortcut"), "the way into the Ash Cut from the Forge Row is open")
	assert_false(RoomBuilder.is_exit_open(up, null), "the ceiling hole is shut until the switch is pulled")
	var switches := cut.features.filter(func(f: Dictionary) -> bool: return f["kind"] == "switch")
	assert_eq(switches.size(), 1)
	assert_eq(switches[0]["shortcut"], "ash_cut")

func test_every_way_up_in_the_volcano_ends_in_its_opening() -> void:
	for id in ["VO1", "VO4", "VO6", "VO7"]:
		var r := hot[id] as RoomDef
		for h: Dictionary in r.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "top"):
			assert_true(_climb_ends_in(r, h), "%s: a ledge stands in the opening %s..%s" % [id, h["from"], h["to"]])

func test_the_chimney_is_a_stair_down_from_its_door_to_the_floor() -> void:
	var chimney := hot["VO3"] as RoomDef
	var door: Dictionary = chimney.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "left")[0]
	var ledges := chimney.solids.duplicate()
	ledges.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y > b.position.y)
	assert_lte(AreaKit.floor_y(chimney) - (ledges[0] as Rect2).position.y, RoomLint.REACH_RISE, "the lowest ledge is a hop above the floor")
	assert_lte((ledges[-1] as Rect2).position.y - float(door["to"]), RoomLint.REACH_RISE, "the highest is a hop below the door's sill")
	for i in range(1, ledges.size()):
		assert_lte((ledges[i - 1] as Rect2).position.y - (ledges[i] as Rect2).position.y, 52.0 + 0.001)

func test_the_cooled_vault_is_a_plain_side_room_until_heat_is_a_rule() -> void:
	for e in (hot["VO6"] as RoomDef).exits:
		assert_false(e.has("gate") or e.has("shortcut"))

func test_the_checked_in_rooms_are_what_the_builder_writes() -> void:
	assert_eq(AreaBuilder.stale(AreaBuilder.build()), [])
