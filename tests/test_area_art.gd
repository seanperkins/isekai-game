extends GutTest
## New areas (forest, swamp, village ...) have no terrain art yet, so each borrows an existing biome's through data/area_art.json. These
## tests hold the alias table together and check that the places which turn a room's area into an art key use it.

func _table() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/area_art.json"))

func _room(area: String) -> RoomDef:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = area
	r.solids = [Rect2(100, 200, 80, 12)]
	return r

func test_an_area_with_art_is_its_own_biome() -> void:
	for b: String in ["cave", "grotto", "flooded", "deep"]:
		assert_eq(TerrainArt.art_biome(b), b)
		assert_true(TerrainArt.known_area(b))

func test_a_new_area_borrows_its_alias_and_an_unknown_one_has_none() -> void:
	assert_eq(TerrainArt.art_biome("forest"), _table()["forest"])
	assert_true(TerrainArt.known_area("forest"))
	assert_eq(TerrainArt.art_biome("nowhere"), "")
	assert_false(TerrainArt.known_area("nowhere"))

func test_every_budgeted_area_has_art_and_a_map_colour() -> void:
	for area: String in WorldSize.TARGETS:
		assert_true(TerrainArt.known_area(area), area)
		assert_true(WorldView.AREA_FILL.has(area), "%s has a World view colour" % area)

func test_aliases_point_at_real_biomes_not_at_other_aliases() -> void:
	var t := _table()
	for area: String in t:
		assert_true(TerrainArt.has_biome(t[area]), "%s -> %s" % [area, t[area]])
		assert_false(t.has(t[area]), "%s points at an alias" % area)

func test_areas_lists_biomes_and_aliases_sorted() -> void:
	var areas := TerrainArt.areas()
	for a: String in ["cave", "deep", "forest", "crypt", "cemetery", "serpent"]:
		assert_true(areas.has(a), a)
	var sorted := areas.duplicate()
	sorted.sort()
	assert_eq(areas, sorted)
	assert_eq(EditorPanels.areas(), areas)

func test_a_room_in_a_new_area_builds_like_one_in_its_biome() -> void:
	var alias: String = _table()["forest"]
	var forest := RoomBuilder.build_room(_room("forest"), {})
	var twin := RoomBuilder.build_room(_room(alias), {})
	assert_eq(forest.get_child_count(), twin.get_child_count())
	var plain := RoomBuilder.build_room(_room("nowhere"), {})
	assert_ne(plain.get_child_count(), twin.get_child_count(), "an unknown area still gets the flat backdrop")
	for n in [forest, twin, plain]:
		n.free()

func test_the_editor_can_make_a_room_in_a_new_area() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	var model := RoomEditModel.new(ShippedRooms.load_all(), ids)
	assert_eq(model.new_room_beside("C6", "left", "Wood1", "forest", Vector2i(1, 1)), "")
	assert_eq(model.new_room_beside("C6", "top", "Bad1", "nowhere", Vector2i(1, 1)), "unknown area 'nowhere'")

func test_dressing_in_a_new_area_is_checked_against_the_aliased_biome() -> void:
	var alias: String = _table()["forest"]
	var piece: String = DressingLib.piece_names(alias)[0]
	var r := _room("forest")
	r.dressing = [{"piece": piece, "pos": Vector2(100, 100), "factor": 0.5}]
	assert_eq(WorldValidator._check_dressing(r), PackedStringArray())
	r.area = "nowhere"
	assert_eq(WorldValidator._check_dressing(r).size(), 1)

func test_ambient_and_decor_follow_the_alias() -> void:
	var alias: String = _table()["forest"]
	assert_eq(TerrainArt.ambient(TerrainArt.art_biome("forest"), Color.BLACK), TerrainArt.ambient(alias, Color.BLACK))
	assert_eq(DecorLib.ids_for_biome(TerrainArt.art_biome("forest")), DecorLib.ids_for_biome(alias))
