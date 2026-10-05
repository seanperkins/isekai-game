extends GutTest
## A new room in every biome the art supports builds and validates, so a biome's art needs no code change to be offered.

func test_a_new_room_in_every_biome_builds_and_the_world_stays_valid() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	for biome in TerrainArt.biomes():
		var model := RoomEditModel.new(ShippedRooms.load_all(), ids)
		assert_eq(model.new_room_beside("C6", "left", "NB", biome, Vector2i(1, 1)), "", biome)
		var built := RoomBuilder.build_room(model.rooms["NB"], {"progress": null})
		assert_not_null(built, biome)
		add_child_autofree(built)
		assert_eq("\n".join(model.validate()), "", biome)

func test_a_new_room_in_every_area_builds_and_the_world_stays_valid() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	for area: String in TerrainArt.areas():
		var model := RoomEditModel.new(ShippedRooms.load_all(), ids)
		assert_eq(model.new_room_beside("C6", "left", "NB", area, Vector2i(1, 1)), "", area)
		add_child_autofree(RoomBuilder.build_room(model.rooms["NB"], {"progress": null}))
		assert_eq("\n".join(model.validate()), "", area)

func test_the_new_room_dialog_offers_every_biome_and_every_borrowing_area() -> void:
	assert_eq(EditorPanels.areas(), TerrainArt.areas())
	for biome: String in TerrainArt.biomes():
		assert_true(EditorPanels.areas().has(biome), biome)
