extends GutTest
## Prefabs expand to plain room data, and the rooms they dress stay walkable.


var rooms := {}

func before_all() -> void:
	rooms = World.load_rooms("res://data/rooms")

func test_stamp_offsets_and_flips_solids_and_decor() -> void:
	var room := {}
	var box := Prefabs.stamp(room, "mound", Vector2(100, 320))
	assert_eq(room["solids"][0], Rect2(100, 288, 160, 32))
	assert_eq(box, Rect2(100, 224, 160, 96))
	var flipped := {}
	Prefabs.stamp(flipped, "mound", Vector2(100, 320), true)
	# Mirrored inside its own width: the 112-wide second step starts 24 from the right edge.
	assert_eq(flipped["solids"][1], Rect2(100 + 160 - 24 - 112, 256, 112, 32))
	assert_eq(flipped["decor"][0]["pos"], Vector2(100 + 160 - 20, 288))

func test_ceiling_prefabs_hang_down() -> void:
	var room := {}
	var box := Prefabs.stamp(room, "stalactites", Vector2(300, 20))
	assert_eq(box.position.y, 20.0)
	assert_eq(box.end.y, 116.0)

func test_steps_never_exceed_the_ledge_limit() -> void:
	for id in Prefabs.library():
		var p: Dictionary = Prefabs.library()[id]
		if not p.get("walkable", false):
			continue
		var tops: Array = p["solids"].map(func(r: Rect2) -> float: return r.position.y)
		tops.sort()
		tops.reverse()  # lowest tops (highest steps) first
		var prev := 0.0
		for t: float in tops:
			assert_lte(absf(t - prev), 54.0 + 0.1, "%s step" % id)
			prev = t

func test_every_solid_is_inside_its_room() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), ["solid_outside"]), "")

func test_nothing_stands_in_front_of_an_exit() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), ["exit_blocked"]), "")

func test_exits_fit_the_body() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), ["exit_narrow"]), "")

func test_spawns_and_features_are_not_inside_solids() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), ["in_rock"]), "")

func test_start_stands_on_the_floor() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), ["start_floor"]), "")

func test_every_biome_set_names_real_prefabs() -> void:
	for biome in Prefabs.SETS:
		for id in Prefabs.ids_for(biome):
			assert_true(Prefabs.library().has(id), "%s uses %s" % [biome, id])

func test_each_biome_has_signature_shapes_of_its_own() -> void:
	var cave: Array = Prefabs.ids_for("cave")
	for biome in ["grotto", "flooded"]:
		var own: Array = Prefabs.ids_for(biome).filter(func(id): return not cave.has(id))
		assert_gte(own.size(), 1, "%s has a prefab the Cave does not" % biome)

func test_decor_ids_are_prefixed_for_other_biomes() -> void:
	assert_eq(Prefabs.decor_id("glow_fungus", "cave"), "glow_fungus")
	assert_eq(Prefabs.decor_id("glow_fungus", "grotto"), "grotto_glow_fungus")
	var room := {}
	Prefabs.stamp(room, "hummock", Vector2(100, 320), false, "grotto")
	for d in room["decor"]:
		assert_true(str(d["id"]).begins_with("grotto_"), str(d["id"]))

func test_shelf_stairs_leave_room_to_climb() -> void:
	# Each shelf is 48 px above the last and 12 px thick: 36 px of headroom for the 24 px body.
	var room := {}
	Prefabs.stamp(room, "cap_stairs", Vector2(0, 320))
	var s: Array = room["solids"]
	for i in range(1, s.size()):
		assert_gte(s[i - 1].position.y - s[i].end.y, 36.0, "gap between shelf %d and %d" % [i - 1, i])
