extends GutTest
## The Deep's rooms: the world is valid, the doorway from the marsh sits at floor height, nothing stands in a door zone, the climb in
## the Sinkhole works, and the Flooded and the Deep together fill stage 2.

const ROOMS := ["D1", "D2", "D3", "D4", "D5"]

var rooms: Dictionary
var creatures := {}

func before_all() -> void:
	rooms = World.load_rooms("res://data/rooms")
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func test_the_world_validates_and_lints_clean() -> void:
	var ids: Array = creatures.keys()
	assert_eq(WorldValidator.validate(rooms, ids), PackedStringArray())
	assert_eq(RoomLint.check(rooms), [], RoomLint.text(RoomLint.check(rooms), RoomLint.RULES))

func test_the_rooms_sit_where_the_spec_puts_them() -> void:
	var want := {"D1": [Vector2i(17, 6), Vector2i(1, 1)], "D2": [Vector2i(18, 6), Vector2i(2, 1)], "D3": [Vector2i(20, 6), Vector2i(1, 2)],
		"D4": [Vector2i(21, 7), Vector2i(2, 1)], "D5": [Vector2i(23, 7), Vector2i(1, 1)]}
	for id in want:
		assert_eq((rooms[id] as RoomDef).cell, want[id][0], id)
		assert_eq((rooms[id] as RoomDef).size, want[id][1], id)
		assert_eq((rooms[id] as RoomDef).area, "deep", id)

func test_the_deep_is_behind_the_swim_door_and_its_only_gate_is_d2s_top_exit() -> void:
	var reach := WorldValidator.reachable(rooms, true)
	for id in ROOMS:
		assert_false(reach.has(id), "%s hangs off F4, behind the Swim door" % id)
		for e in (rooms[id] as RoomDef).exits:
			assert_true(not e.has("gate") or (id == "D2" and e["edge"] == "top" and e["gate"] == "wall_cling"), "%s: no gate but D2's top exit (the slice)" % id)

func test_the_doorway_from_the_marsh_ends_at_the_floor_on_both_halves() -> void:
	# new_room_beside rejects a door whose zone holds any solid, a ledge included, and would pick a span 60 px above the floor
	var east: Dictionary = (rooms["F4"] as RoomDef).exits.filter(func(e): return e["edge"] == "right")[0]
	var west: Dictionary = (rooms["D1"] as RoomDef).exits.filter(func(e): return e["edge"] == "left")[0]
	assert_eq(east["room"], "D1")
	assert_eq(west["room"], "F4")
	var floor_top := 360.0 - RoomDef.FLOOR
	assert_eq(float(east["to"]), floor_top, "F4's half")
	assert_eq(float(west["to"]), floor_top, "D1's half")

## Closed on both axes: Rect2.has_point's far edges are open, so a decor base on a zone's bottom edge would slip through it.
func _in_zone(zone: Rect2, p: Vector2) -> bool:
	return p.x >= zone.position.x and p.x <= zone.end.x and p.y >= zone.position.y and p.y <= zone.end.y

func test_nothing_spawns_or_stands_in_a_door_zone() -> void:
	# RoomLint checks solids only. F4's other doors are the Flooded's business (a puddle sits on its west zone's edge): only its new one.
	var checks: Array = []
	for e in (rooms["F4"] as RoomDef).exits:
		if e["edge"] == "right":
			checks.append(["F4", e])
	for id in ROOMS:
		for e in (rooms[id] as RoomDef).exits:
			checks.append([id, e])
	for c in checks:
		var r: RoomDef = rooms[c[0]]
		var zone := RoomLint.exit_zone(r.pixel_size(), c[1])
		for s in r.spawns:
			assert_false(_in_zone(zone, s["pos"]), "%s spawn %s is in the %s door zone" % [c[0], s["id"], c[1]["edge"]])
		for d in r.decor:
			assert_false(_in_zone(zone, d["pos"]), "%s decor %s is in the %s door zone" % [c[0], d["id"], c[1]["edge"]])

## The Sinkhole is climbed in both directions: a ledge flush with the west wall at D2's door's floor height, then a chain of hops of at most
## 55 px down to the floor. RoomLint._ledge_reach and WorldValidator.reachable cannot see an exit's sill.
func test_d3_has_a_chain_from_its_floor_to_the_sill_of_d2s_door() -> void:
	var d3: RoomDef = rooms["D3"]
	var door: Dictionary = d3.exits.filter(func(e): return e["edge"] == "left")[0]
	var sill := float(door["to"])
	var ledges: Array = d3.solids.filter(func(s): return (s as Rect2).size.y <= 12.0 and (s as Rect2).position.x < 300.0)
	ledges.sort_custom(func(a, b): return (a as Rect2).position.y < (b as Rect2).position.y)
	assert_gt(ledges.size(), 2)
	var top: Rect2 = ledges[0]
	assert_eq(top.position.y, sill, "the top ledge stands at the door's floor height")
	assert_eq(top.position.x, RoomDef.WALL, "flush with the west wall")
	for i in range(1, ledges.size()):
		assert_lte((ledges[i] as Rect2).position.y - (ledges[i - 1] as Rect2).position.y, 55.0, "hop %d" % i)
	var floor_top := d3.pixel_size().y - RoomDef.FLOOR
	assert_lte(floor_top - (ledges[ledges.size() - 1] as Rect2).position.y, 55.0, "the lowest ledge is within a hop of the floor")

func test_the_flooded_and_the_deep_together_fill_stage_2() -> void:
	var flooded := ShippedRooms.first_time(rooms, creatures, ["F1", "F2", "F3", "F4", "F5"])
	var deep := ShippedRooms.first_time(rooms, creatures, ROOMS)
	assert_gte(flooded + deep, Progression.stage_total(2), "a tuning pin: one drake or two wolves fewer breaks it")

func test_the_census() -> void:
	var count := {}
	for id in ROOMS:
		for s in (rooms[id] as RoomDef).spawns:
			count[s["id"]] = int(count.get(s["id"], 0)) + 1
	assert_eq(count, {"armed_ant": 9, "gloom_wolf": 9, "stone_drake": 3})

func test_d1_holds_the_rebirth_pool_and_d5_the_glow_pool_and_the_tablet() -> void:
	var d1_kinds: Array = (rooms["D1"] as RoomDef).features.map(func(f): return f["kind"])
	assert_true(d1_kinds.has("rebirth_pool"))
	var d5_kinds: Array = (rooms["D5"] as RoomDef).features.map(func(f): return f["kind"])
	assert_true(d5_kinds.has("glow_pool"))
	assert_true(d5_kinds.has("tablet"))
