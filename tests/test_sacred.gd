extends GutTest
## The sacred cluster above and east of the Deep: a cemetery, a cathedral and a crypt, their rooms at their cells, the exits that join them to
## the world, and nothing else of the world changed.

const CEMETERY := {"CM1": [Vector2i(18, 4), Vector2i(1, 1)], "CM2": [Vector2i(19, 4), Vector2i(2, 1)], "CM3": [Vector2i(21, 4), Vector2i(1, 1)],
	"CM4": [Vector2i(17, 4), Vector2i(1, 2)]}
## The creatures the design table gives the cemetery's open rooms (the churchyard itself is a truce).
const CEMETERY_SUPPORT := ["skeleton", "ghost", "carrion_crow"]

## The cathedral: the Nave, the Transept, the Font Chapel, the Bell Shaft and the Loft.
const CATHEDRAL := {"CA1": [Vector2i(19, 3), Vector2i(3, 1)], "CA2": [Vector2i(22, 3), Vector2i(1, 1)], "CA3": [Vector2i(23, 3), Vector2i(1, 1)],
	"CA4": [Vector2i(22, 0), Vector2i(1, 3)], "CA5": [Vector2i(20, 0), Vector2i(2, 1)]}
const SACRED_SUPPORT := ["candle_wisp", "chapel_priest", "stained_glass_moth", "shield_guard", "gargoyle", "ghost"]

## The crypt: the Stair, the Ossuary, the Niche Gallery, the Vault and the Coffin Slide down to D5.
const CRYPT := {"CR1": [Vector2i(22, 4), Vector2i(1, 2)], "CR2": [Vector2i(23, 5), Vector2i(2, 1)], "CR3": [Vector2i(25, 5), Vector2i(3, 1)],
	"CR4": [Vector2i(28, 5), Vector2i(1, 1)], "CR5": [Vector2i(23, 6), Vector2i(2, 1)]}
const CRYPT_SUPPORT := ["skeleton", "junk", "vampire_bat", "bone_hound"]

var graveyard: Dictionary  # the cemetery built, the rest of the cluster not yet
var nave: Dictionary  # the cathedral built, the crypt not yet
var crypt: Dictionary  # the whole cluster
var before: Dictionary  # the world before the cluster: the forest, the swamp and the village

func before_all() -> void:
	graveyard = AreaWorlds.upto("CM")
	before = AreaWorlds.upto("VI")
	nave = AreaWorlds.upto("CA")
	crypt = AreaWorlds.upto("CR")

func test_the_cemetery_is_four_rooms_at_their_cells_and_sizes() -> void:
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
	var e: Dictionary = now.exits.filter(func(x: Dictionary) -> bool: return x["room"] == "CM4")[0]
	assert_eq(e["edge"], "left", "a door in D7's west wall: the antechamber has no ledge to climb to a hole in its ceiling")
	assert_false(e.has("gate") or e.has("shortcut"), "the way in is D7's own, which is behind the wall cling")
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

func test_the_gate_stair_climbs_from_d7s_door_to_the_tunnels_door_on_ledges_a_hop_apart() -> void:
	var stair := graveyard["CM4"] as RoomDef
	var low: Dictionary = stair.exits.filter(func(e: Dictionary) -> bool: return e["room"] == "D7")[0]
	var high: Dictionary = stair.exits.filter(func(e: Dictionary) -> bool: return e["room"] == "CM1")[0]
	assert_eq([low["edge"], high["edge"]], ["right", "right"])
	assert_gt(float(low["from"]), float(high["to"]), "D7's door is at the floor, the tunnel's a screen above")
	var ledges := stair.solids.duplicate()
	ledges.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y > b.position.y)
	assert_lte(AreaKit.floor_y(stair) - (ledges[0] as Rect2).position.y, RoomLint.REACH_RISE, "the lowest ledge is a hop above the floor")
	assert_lte((ledges[-1] as Rect2).position.y - float(high["to"]), RoomLint.REACH_RISE, "the highest is a hop below the upper door's sill")
	assert_gte((ledges[-1] as Rect2).end.x, 600.0, "and reaches the door's wall")
	for i in range(1, ledges.size()):
		assert_lte((ledges[i - 1] as Rect2).position.y - (ledges[i] as Rect2).position.y, 52.0 + 0.001)
	assert_eq(stair.spawns, [], "a threshold: no creatures")

# --- the cathedral ---

func test_the_cathedral_is_five_rooms_at_their_cells_sizes_and_area() -> void:
	for id in CATHEDRAL:
		assert_true(nave.has(id), id)
		var r: RoomDef = nave[id]
		assert_eq(r.area, "sacred", id)
		assert_eq(r.cell, CATHEDRAL[id][0], id)
		assert_eq(r.size, CATHEDRAL[id][1], id)

func test_the_world_with_the_cathedral_has_no_problems() -> void:
	assert_eq(Array(AreaBuilder.problems(nave)), [])

func test_every_cathedral_room_is_reachable_and_only_through_the_wall_cling() -> void:
	var reached := WorldValidator.reachable(nave)
	var ungated := WorldValidator.reachable(nave, true)
	for id in CATHEDRAL:
		assert_true(reached.has(id), "%s: no way in from the start room" % id)
		assert_false(ungated.has(id), "%s is behind the wall cling" % id)

func test_the_cathedral_holds_the_sacred_creatures_and_only_them() -> void:
	var seen := {}
	for id in CATHEDRAL:
		for s in (nave[id] as RoomDef).spawns:
			assert_true(SACRED_SUPPORT.has(s["id"]), "%s: %s" % [id, s["id"]])
			seen[s["id"]] = true
	for c in SACRED_SUPPORT:
		assert_true(seen.has(c), "%s lives in the cathedral" % c)

func test_the_churchyard_gains_one_exit_and_a_climb_and_is_still_a_truce() -> void:
	var was := graveyard["CM2"] as RoomDef
	var now := nave["CM2"] as RoomDef
	assert_eq(now.exits.size(), was.exits.size() + 1)
	assert_eq(now.spawns, [])
	var hole: Dictionary = now.exits.filter(func(e: Dictionary) -> bool: return e["room"] == "CA1")[0]
	assert_eq(hole["edge"], "top")
	var in_hole := now.solids.filter(func(l: Rect2) -> bool: return l.position.y == 14.0 and l.position.x >= float(hole["from"]) and l.end.x <= float(hole["to"]))
	assert_eq(in_hole.size(), 1, "the climb ends in the opening")

func test_the_transepts_climb_and_the_nave_and_bell_shaft_landings_stand_beside_their_holes() -> void:
	var transept := nave["CA2"] as RoomDef
	var up: Dictionary = transept.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "top")[0]
	assert_eq(transept.solids.filter(func(l: Rect2) -> bool: return l.position.y == 14.0 and l.position.x >= float(up["from"]) and l.end.x <= float(up["to"])).size(), 1)
	for id in ["CA1", "CA4"]:
		var r := nave[id] as RoomDef
		var hole: Dictionary = r.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "bottom")[0]
		var landings := r.solids.filter(func(l: Rect2) -> bool: return l.position.y == AreaKit.floor_y(r) - 52.0)
		assert_gte(landings.size(), 2, id)
		assert_true(landings.any(func(l: Rect2) -> bool: return l.end.x < float(hole["from"])), "%s: a landing left of the hole" % id)
		assert_true(landings.any(func(l: Rect2) -> bool: return l.position.x > float(hole["to"])), "%s: a landing right of the hole" % id)

func test_the_bell_shafts_last_ledge_is_a_hop_below_its_door() -> void:
	var bell := nave["CA4"] as RoomDef
	var door: Dictionary = bell.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "left")[0]
	var top := bell.solids.filter(func(l: Rect2) -> bool: return l.position.y > float(door["to"]))
	top.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y < b.position.y)
	assert_lte(float((top[0] as Rect2).position.y) - float(door["to"]), RoomLint.REACH_RISE, "the highest ledge below the door is within a hop of its sill")
	assert_lte((top[0] as Rect2).position.x, 40.0, "and it reaches the door's wall")

func test_the_font_chapel_has_a_pool_and_no_altar() -> void:
	var feats := (nave["CA3"] as RoomDef).features
	assert_eq(feats.filter(func(f: Dictionary) -> bool: return f["kind"] == "glow_pool").size(), 1)
	assert_eq(feats.filter(func(f: Dictionary) -> bool: return f["kind"] == "altar").size(), 0)

# --- the crypt ---

func test_the_crypt_is_five_rooms_at_their_cells_sizes_and_area() -> void:
	for id in CRYPT:
		assert_true(crypt.has(id), id)
		var r: RoomDef = crypt[id]
		assert_eq(r.area, "crypt", id)
		assert_eq(r.cell, CRYPT[id][0], id)
		assert_eq(r.size, CRYPT[id][1], id)

func test_the_whole_world_with_the_cluster_has_no_problems() -> void:
	assert_eq(Array(AreaBuilder.problems(crypt)), [])

func test_every_crypt_room_is_reachable_and_only_through_the_wall_cling() -> void:
	var reached := WorldValidator.reachable(crypt)
	var ungated := WorldValidator.reachable(crypt, true)
	for id in CRYPT:
		assert_true(reached.has(id), "%s: no way in from the start room" % id)
		assert_false(ungated.has(id), "%s is behind the wall cling" % id)
	var rest := ungated.filter(func(id: String) -> bool: return not CRYPT.has(id) and not CATHEDRAL.has(id) and not CEMETERY.has(id))
	rest.sort()
	var was := WorldValidator.reachable(before, true)
	was.sort()
	assert_eq(rest, was, "the whole cluster opens no way into anything else without the wall cling")

func test_the_crypt_holds_the_crypts_creatures_and_only_them() -> void:
	var seen := {}
	for id in CRYPT:
		for s in (crypt[id] as RoomDef).spawns:
			assert_true(CRYPT_SUPPORT.has(s["id"]), "%s: %s" % [id, s["id"]])
			seen[s["id"]] = true
	for c in CRYPT_SUPPORT:
		assert_true(seen.has(c), "%s lives in the crypt" % c)

func test_d5_gains_a_top_exit_and_nothing_else_and_has_no_way_back_up() -> void:
	var was := nave["D5"] as RoomDef
	var now := crypt["D5"] as RoomDef
	assert_eq(now.exits.size(), was.exits.size() + 1)
	var e: Dictionary = now.exits.filter(func(x: Dictionary) -> bool: return x["room"] == "CR5")[0]
	assert_eq(e["edge"], "top")
	assert_false(e.has("gate") or e.has("shortcut"))
	for p in now.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) != 0 and p["name"] != "script" and p["name"] != "exits":
			assert_eq(now.get(p["name"]), was.get(p["name"]), "D5.%s is as shipped" % p["name"])
	assert_eq(now.solids, [], "no ledge in D5: the slide is a drop, and a hole in the ceiling is out of the base jump's reach")

func test_nothing_stands_over_the_ossuarys_hole_or_the_slides() -> void:
	for pair in [["CR2", "CR5"], ["CR5", "D5"]]:
		var upper := crypt[pair[0]] as RoomDef
		var hole: Dictionary = upper.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "bottom")[0]
		for s in upper.spawns:
			assert_false(s["pos"].x > float(hole["from"]) - 20.0 and s["pos"].x < float(hole["to"]) + 20.0, "%s: %s is over the hole" % [pair[0], s["id"]])
	assert_eq((crypt["CR5"] as RoomDef).spawns, [], "the slide is a chute")

func test_the_lych_gate_gains_one_exit_to_the_stair() -> void:
	var was := nave["CM3"] as RoomDef
	var now := crypt["CM3"] as RoomDef
	assert_eq(now.exits.size(), was.exits.size() + 1)
	assert_eq(now.exits.filter(func(x: Dictionary) -> bool: return x["room"] == "CR1")[0]["edge"], "right")

func test_the_checked_in_rooms_are_what_the_builder_writes() -> void:
	assert_eq(AreaBuilder.stale(AreaBuilder.build()), [])
