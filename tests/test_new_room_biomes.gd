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

func test_the_new_room_dialog_offers_every_biome() -> void:
	assert_eq(EditorPanels.areas(), TerrainArt.biomes())
