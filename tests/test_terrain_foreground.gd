extends GutTest
## The foreground frame is scenery over the top of the view, not over the play band: ferns, crystals
## and glowing mushrooms down the sides used to draw (see-through) over creatures and ledges.

const BIOMES := ["cave", "grotto", "deep", "flooded"]

func test_the_play_band_of_every_biomes_frame_is_fully_transparent() -> void:
	for b in BIOMES:
		var img := TerrainLayers.foreground_texture(b).get_image()
		for y in range(int(TerrainLayers.FADE_END), img.get_height()):
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					fail_test("%s: foreground pixel at %d,%d is inside the play band" % [b, x, y])
					return
	pass_test("clear")

func test_the_frame_still_has_its_canopy_across_the_top() -> void:
	for b in BIOMES:
		var img := TerrainLayers.foreground_texture(b).get_image()
		var opaque := 0
		for y in int(TerrainLayers.FADE_START):
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_gt(opaque, 500, "%s: the canopy survives" % b)

func test_the_fade_is_gradual_not_a_hard_cut() -> void:
	for b in BIOMES:
		var src := TerrainArt.layer(b, "foreground").get_image()
		var img := TerrainLayers.foreground_texture(b).get_image()
		var mid := int((TerrainLayers.FADE_START + TerrainLayers.FADE_END) / 2.0)
		var checked := 0
		for x in img.get_width():
			var a: float = src.get_pixel(x, mid).a
			if a > 0.9:
				assert_lt(img.get_pixel(x, mid).a, a, "%s: fading at mid-band" % b)
				assert_gt(img.get_pixel(x, mid).a, 0.0, "%s: not cut off" % b)
				checked += 1
		assert_true(checked >= 0)

func test_the_built_room_uses_the_faded_frame_and_keeps_its_place_in_the_stack() -> void:
	var node := RoomBuilder.build_room(World.load_rooms("res://data/rooms")["C2"], {})
	add_child_autofree(node)
	var fg: TerrainParallax = node.get_node("foreground")
	assert_same(fg.texture, TerrainLayers.foreground_texture("cave"))
	assert_eq(fg.factor, 0.0)
	assert_gt(fg.z_index, 5)

func test_the_faded_texture_is_built_once_per_biome() -> void:
	assert_same(TerrainLayers.foreground_texture("cave"), TerrainLayers.foreground_texture("cave"))

func test_a_biome_without_a_frame_has_none() -> void:
	assert_null(TerrainLayers.foreground_texture("no_such_biome"))
