extends GutTest
## The placement on the real world: every one of the 169 new creatures has a place, in a room of one of its areas.

## No room may hold more than this many creatures per screen of it, or this much weighted (a common 1, an elite 2, a rare 3, an old one 1). The
## Deep, where 40 creatures live in five rooms, is the fullest.
const COUNT_BOUND := 7.0
const LOAD_BOUND := 14.0

var plan: Dictionary
var world: Dictionary
var before: Dictionary  # the world with no placement
var defs := {}

func before_all() -> void:
	plan = JSON.parse_string(FileAccess.get_file_as_string("res://tools/creature_areas.json"))
	world = World.load_rooms(AreaBuilder.ROOMS_DIR)
	before = AreaWorlds.upto("DM")
	for c in DefLoader.load_dir("res://data/creatures"):
		defs[c.id] = c

func _placed() -> Array:
	var out: Array = []
	for id in world:
		for s in (world[id] as RoomDef).spawns:
			if s.get("by", "") == "PL":
				out.append([id, s])
	return out

func test_every_creature_of_the_plan_is_placed_exactly_once() -> void:
	var seen := {}
	for pair in _placed():
		seen[pair[1]["id"]] = int(seen.get(pair[1]["id"], 0)) + 1
	assert_eq(plan["creatures"].size(), 169)
	for id in plan["creatures"]:
		assert_eq(int(seen.get(id, 0)), 1, id)
	assert_eq(seen.size(), 169)

func test_each_stands_in_a_room_of_one_of_its_areas() -> void:
	for pair in _placed():
		var areas: Array = plan["creatures"][pair[1]["id"]]["areas"]
		assert_true(areas.has((world[pair[0]] as RoomDef).area), "%s in %s" % [pair[1]["id"], pair[0]])

func test_no_quiet_room_the_start_room_or_a_boss_arena_holds_one() -> void:
	for pair in _placed():
		var r := world[pair[0]] as RoomDef
		assert_false(plan["quiet"].has(r.id), "%s in the quiet room %s" % [pair[1]["id"], r.id])
		assert_false(r.is_start(), r.id)
		assert_true(r.boss.is_empty(), r.id)
	for id in plan["quiet"]:
		assert_eq((world[id] as RoomDef).spawns.filter(func(s: Dictionary) -> bool: return s.get("by", "") == "PL"), [], id)

func test_the_world_with_them_has_no_problems() -> void:
	assert_eq(Array(AreaBuilder.problems(world)), [])

func test_what_was_there_before_is_untouched_in_every_room() -> void:
	for id in before:
		var unmarked := (world[id] as RoomDef).spawns.filter(func(s: Dictionary) -> bool: return not s.has("by"))
		assert_eq(unmarked, (before[id] as RoomDef).spawns, "%s keeps its own spawns" % id)

func test_no_two_creatures_overlap_on_a_level_and_a_door_is_clear() -> void:
	for id in world:
		var r := world[id] as RoomDef
		var placed := r.spawns.filter(func(s: Dictionary) -> bool: return s.get("by", "") == "PL")
		for s: Dictionary in placed:
			var mine := AreaPlacement.size_of(defs[s["id"]]).x
			for o: Dictionary in r.spawns:
				if o == s or absf((o["pos"] as Vector2).y - (s["pos"] as Vector2).y) >= AreaPlacement.LEVEL:
					continue
				if RoomLint.creature_kind(s["id"]) == "flier" or RoomLint.creature_kind(o["id"]) == "flier":
					continue
				var theirs := AreaPlacement.size_of(defs[o["id"]]).x if defs.has(o["id"]) else maxf(32.0, RoomLint.creature_extent(o["id"]).x)
				var gap := absf((o["pos"] as Vector2).x - (s["pos"] as Vector2).x) - (mine + theirs) / 2.0
				assert_gte(gap, AreaPlacement.GAP - 0.5, "%s and %s in %s" % [s["id"], o["id"], id])
			for e: Dictionary in r.exits:
				if e["edge"] == "left" or e["edge"] == "right":
					var top: float = (s["pos"] as Vector2).y + Enemy.BODY_BOTTOM
					if top >= float(e["from"]) - 40.0 and top <= float(e["to"]) + 60.0 and RoomLint.creature_kind(s["id"]) != "flier":
						var from_wall := (s["pos"] as Vector2).x - RoomDef.WALL if e["edge"] == "left" else r.pixel_size().x - RoomDef.WALL - (s["pos"] as Vector2).x
						assert_gte(from_wall - mine / 2.0, RoomLint.CLEAR - 0.5, "%s blocks the %s door of %s" % [s["id"], e["edge"], id])

func test_no_walking_creature_has_its_drawn_body_in_a_side_wall() -> void:
	for pair in _placed():
		if RoomLint.creature_kind(pair[1]["id"]) == "flier":
			continue
		var half := AreaPlacement.size_of(defs[pair[1]["id"]]).x / 2.0
		var width := (world[pair[0]] as RoomDef).pixel_size().x
		var x: float = (pair[1]["pos"] as Vector2).x
		assert_gte(x - half, RoomDef.WALL - 0.01, "%s in %s: west wall" % [pair[1]["id"], pair[0]])
		assert_lte(x + half, width - RoomDef.WALL + 0.01, "%s in %s: east wall" % [pair[1]["id"], pair[0]])

func test_no_room_is_over_the_bounds_per_screen() -> void:
	for id in world:
		var r := world[id] as RoomDef
		var load_sum := 0.0
		for s: Dictionary in r.spawns:
			var cls: String = plan["creatures"][s["id"]]["class"] if plan["creatures"].has(s["id"]) and s.get("by", "") == "PL" else "common"
			load_sum += float(AreaPlacement.WEIGHT[cls])
		var screens := float(r.size.x * r.size.y)
		assert_lte(load_sum / screens, LOAD_BOUND, "%s: %s weighted per screen" % [id, load_sum / screens])
		assert_lte(float(r.spawns.size()) / screens, COUNT_BOUND, "%s: %s creatures per screen" % [id, float(r.spawns.size()) / screens])

func test_the_rares_of_an_area_with_a_lair_stand_in_its_lairs_first() -> void:
	var rare_areas := {}
	for id in plan["creatures"]:
		if plan["creatures"][id]["class"] == "rare":
			for a in plan["creatures"][id]["areas"]:
				rare_areas[a] = true
	for a in rare_areas:
		var lairs: Array = plan["lairs"].filter(func(l: String) -> bool: return world.has(l) and (world[l] as RoomDef).area == a)
		if lairs.is_empty():
			continue
		var in_lair: Array = _placed().filter(func(p: Array) -> bool: return lairs.has(p[0]) and plan["creatures"][p[1]["id"]]["class"] == "rare")
		assert_gt(in_lair.size(), 0, "a rare of %s stands in one of %s" % [a, lairs])

func test_every_placed_creature_builds_as_a_live_enemy_in_its_room() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	var was := RoomBuilder.simple_layers
	RoomBuilder.simple_layers = true  # the painted terrain is not what this looks at
	var built := 0
	for id in world:
		var r := world[id] as RoomDef
		if not r.spawns.any(func(s: Dictionary) -> bool: return s.get("by", "") == "PL"):
			continue
		var node := RoomBuilder.build_room(r, {"spawn": game._spawn})
		add_child_autofree(node)
		var enemies := node.get_children().filter(func(n: Node) -> bool: return n is Enemy or n is WaterPool)
		assert_eq(enemies.size(), r.spawns.size(), "%s builds every one of its spawns" % id)
		built += enemies.size()
	RoomBuilder.simple_layers = was
	assert_gte(built, 169)
