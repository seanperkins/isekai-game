extends GutTest
## The cut Style D sprites exist, load, are keyed cleanly and have the expected sizes.

var names: Array = []
var tile_names: Array = []

func before_all() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/manifest.json"))
	for sheet in manifest["sheets"]:
		for sprite in manifest["sheets"][sheet]:
			names.append(sprite)
			if manifest["sheets"][sheet][sprite].has("size"):
				tile_names.append(sprite)

func test_manifest_lists_every_sprite() -> void:
	assert_eq(names.size(), 44)

func test_every_sprite_loads_through_art() -> void:
	for n in names:
		var tex := Art.texture(n)
		assert_not_null(tex, n)

func test_no_magenta_fringe_survives_keying() -> void:
	for n in names:
		var img := Art.texture(n).get_image()
		var fringe := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and c.r > 0.75 and c.b > 0.75 and c.g < 0.35:
					fringe += 1
		assert_eq(fringe, 0, n)

func test_character_sprites_have_transparent_corners() -> void:
	for n in ["slime_idle", "bat_1", "toad_idle", "lizard_1", "spider_crawl", "serpent"]:
		var img := Art.texture(n).get_image()
		assert_eq(img.get_pixel(0, 0).a, 0.0, n)

func test_tiles_are_exactly_32_px() -> void:
	for n in tile_names:
		assert_eq(Art.texture(n).get_size(), Vector2(32, 32), n)

func test_slime_idle_is_game_sized() -> void:
	var size := Art.texture("slime_idle").get_size()
	assert_between(size.y, 14.0, 22.0)

func test_every_player_skill_has_an_icon() -> void:
	for d in DefLoader.load_dir("res://data/skills"):
		if d.source != "enemy_only":
			assert_not_null(Art.texture("icon_" + d.id), d.id)
	assert_not_null(Art.texture("icon_locked"))
