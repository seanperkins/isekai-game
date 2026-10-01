extends GutTest
## TerrainArt: which biomes the art supports.

func test_biomes_lists_the_directories_that_have_terrain_art_sorted() -> void:
	assert_eq(TerrainArt.biomes(), ["cave", "deep", "flooded", "grotto"])

func test_has_biome_is_false_for_a_name_with_no_art() -> void:
	assert_false(TerrainArt.has_biome("no_such_biome"))
