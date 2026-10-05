extends GutTest
## Where the nine deeds can be earned: the features, tags and rooms the area modules place for them, in rooms the world reaches.

## room -> [kind, id] for each feature the modules place for a deed.
const PLACED := {"SW5": [["barrier", "SW5_barrier"]], "VO4": [["barrier", "VO4_barrier"]], "CA3": [["hidden", "CA3_hidden"], ["vigil", "CA3_vigil"]],
	"DM7": [["hidden", "DM7_hidden"]], "FO6": [["gap", "FO6_gap_a"], ["gap", "FO6_gap_b"]], "SW2": [["gap", "SW2_gap_a"], ["gap", "SW2_gap_b"]],
	"CA1": [["lamp", "CA1_lamp"]], "VI3": [["lamp", "VI3_lamp"]], "CR2": [["lamp", "CR2_lamp"]], "CM2": [["vigil", "CM2_vigil"]], "DM1": [["vigil", "DM1_vigil"]]}
const HOLD_ROOMS := ["FO8", "CA1", "CR3", "VO4"]

var world: Dictionary

func before_all() -> void:
	world = World.load_rooms(AreaBuilder.ROOMS_DIR)

func _feature(room: String, id: String) -> Dictionary:
	for f in (world[room] as RoomDef).features:
		if f["id"] == id:
			return f
	return {}

func test_every_placement_is_there_with_its_kind_in_its_room() -> void:
	for room in PLACED:
		for pair in PLACED[room]:
			var f := _feature(room, pair[1])
			assert_false(f.is_empty(), "%s has %s" % [room, pair[1]])
			assert_eq(f.get("kind", ""), pair[0], pair[1])

func test_the_hold_rooms_are_tagged_hold_and_no_other_room_is() -> void:
	for id in world:
		assert_eq((world[id] as RoomDef).tags.has("hold"), HOLD_ROOMS.has(id), id)

func test_the_world_with_them_has_no_problems() -> void:
	assert_eq(Array(AreaBuilder.problems(world)), [])

func test_what_a_barrier_or_a_hidden_door_stands_in_front_of_is_a_dead_end_with_one_way_in() -> void:
	for id in ["SW5", "VO6", "CA3", "DM7"]:
		assert_eq((world[id] as RoomDef).exits.size(), 1, "%s is a dead end" % id)

func test_a_barrier_or_a_hidden_door_fills_the_whole_way_it_stands_in() -> void:
	for pair in [["SW5", "SW5_barrier"], ["CA3", "CA3_hidden"], ["DM7", "DM7_hidden"]]:
		var r := world[pair[0]] as RoomDef
		var f := _feature(pair[0], pair[1])
		var e: Dictionary = r.exits[0]
		assert_eq(e["edge"], "left", pair[0])
		var size: Vector2 = f["size"]
		assert_lte((f["pos"] as Vector2).y - size.y, float(e["from"]), "%s covers the door's top" % pair[1])
		assert_gte((f["pos"] as Vector2).y, float(e["to"]), "%s covers the door's sill" % pair[1])
		assert_gte((f["pos"] as Vector2).x - size.x / 2.0, RoomDef.WALL, "%s stands inside the room, not in the wall" % pair[1])
	var forge := world["VO4"] as RoomDef
	var hole: Dictionary = forge.exits.filter(func(e: Dictionary) -> bool: return e["edge"] == "bottom")[0]
	var plug := _feature("VO4", "VO4_barrier")
	assert_lte((plug["pos"] as Vector2).x - (plug["size"] as Vector2).x / 2.0, float(hole["from"]))
	assert_gte((plug["pos"] as Vector2).x + (plug["size"] as Vector2).x / 2.0, float(hole["to"]))
	assert_eq((plug["pos"] as Vector2).y, forge.pixel_size().y, "it stands in the floor's gap, its foot at the room's bottom")

func test_each_gap_is_the_real_space_between_two_ledges_of_its_room() -> void:
	for room in ["FO6", "SW2"]:
		for pair in PLACED[room]:
			var f := _feature(room, pair[1])
			var centre: float = (f["pos"] as Vector2).x
			var half: float = float(f["width"]) / 2.0
			var r := world[room] as RoomDef
			var left := r.solids.filter(func(s: Rect2) -> bool: return is_equal_approx(s.end.x, centre - half))
			var right := r.solids.filter(func(s: Rect2) -> bool: return is_equal_approx(s.position.x, centre + half))
			assert_eq(left.size(), 1, "%s: a ledge ends where the gap starts" % pair[1])
			assert_eq(right.size(), 1, "%s: a ledge starts where it ends" % pair[1])
			var lower := maxf((left[0] as Rect2).position.y, (right[0] as Rect2).position.y)
			assert_eq((f["pos"] as Vector2).y, lower, "%s: at the lower ledge's height, so a jump up still crosses above it" % pair[1])

func test_every_deed_has_a_place_to_be_earned() -> void:
	assert_true(world.values().any(func(r: RoomDef) -> bool: return r.tags.has("moonlit")), "moonlit")
	assert_true(world.values().any(func(r: RoomDef) -> bool: return r.tags.has("hold")), "room_held")
	for kind in ["barrier", "hidden", "gap", "lamp", "vigil"]:
		assert_true(world.values().any(func(r: RoomDef) -> bool: return r.features.any(func(f: Dictionary) -> bool: return f["kind"] == kind)), kind)
	for id in VillageWatch.ROOMS:
		assert_eq((world[id] as RoomDef).area, "village", id)
	assert_true(VillageWatch.ROOMS.has(VillageWatch.YARD))

func test_the_built_rooms_hold_the_nodes_that_earn_the_deeds() -> void:
	var classes := {"barrier": RoomBarrier, "hidden": RoomHidden, "gap": RoomGap, "lamp": RoomLamp, "vigil": RoomVigil}
	for room in PLACED:
		var node := RoomBuilder.build_room(world[room], {})
		add_child_autofree(node)
		for pair in PLACED[room]:
			var found := node.get_children().filter(func(n: Node) -> bool: return is_instance_of(n, classes[pair[0]]) and n.id == pair[1])
			assert_eq(found.size(), 1, "%s builds %s" % [room, pair[1]])
	for room in HOLD_ROOMS:
		var node := RoomBuilder.build_room(world[room], {})
		add_child_autofree(node)
		assert_eq(node.get_children().filter(func(n: Node) -> bool: return n is RoomHold).size(), 1, room)

func test_the_checked_in_rooms_are_what_the_builder_writes() -> void:
	assert_eq(AreaBuilder.stale(AreaBuilder.build()), [])
