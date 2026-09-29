extends GutTest
## Procedural effect textures: white, tinted in the engine, cached, built headless.

func test_silk_is_a_tileable_32_by_4_strand() -> void:
	var t := VfxArt.silk()
	assert_eq(t.get_size(), Vector2(32, 4))
	var img := t.get_image()
	for y in 4:
		for x in 24:
			assert_eq(img.get_pixel(x, y), img.get_pixel(x + 8, y), "period 8 at %d,%d" % [x, y])
	assert_gt(img.get_pixel(0, 1).a, 0.5, "opaque centre")
	assert_lt(img.get_pixel(0, 0).a, 0.5, "faint edge")

func test_web_is_exactly_symmetric_under_a_quarter_turn_and_has_gaps() -> void:
	var img := VfxArt.web(80).get_image()
	assert_eq(img.get_size(), Vector2i(80, 80))
	var opaque := 0
	for y in 80:
		for x in 80:
			var a := img.get_pixel(x, y).a
			if a > 0.5:
				opaque += 1
			assert_eq(a, img.get_pixel(79 - y, x).a, "rotates onto itself at %d,%d" % [x, y])
	assert_gt(opaque, 200, "threads")
	assert_lt(opaque, 80 * 80 / 2, "gaps between them")

func test_crescent_is_a_96_by_48_with_a_soft_edge() -> void:
	var t := VfxArt.crescent()
	assert_eq(t.get_size(), Vector2(96, 48))
	var alphas := {}
	var img := t.get_image()
	for y in 48:
		for x in 96:
			alphas[snappedf(img.get_pixel(x, y).a, 0.05)] = true
	assert_gt(alphas.size(), 3, "more than opaque and clear: a soft edge")

func test_textures_are_cached() -> void:
	assert_same(VfxArt.silk(), VfxArt.silk())
	assert_same(VfxArt.crescent(), VfxArt.crescent())
	assert_same(VfxArt.web(80), VfxArt.web(80))
	assert_ne(VfxArt.web(80), VfxArt.web(40))

func _coverage(t: Texture2D, min_alpha: float) -> float:
	var img := t.get_image()
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= min_alpha:
				n += 1
	return float(n) / float(img.get_width() * img.get_height())

func test_web_cover_matches_the_frame_pixel_for_pixel_and_is_cached() -> void:
	assert_eq(VfxArt.web_cover(Vector2i(40, 32), false).get_size(), Vector2(40, 32))
	assert_eq(VfxArt.web_cover(Vector2i(40, 32), true).get_size(), Vector2(40, 32))
	assert_same(VfxArt.web_cover(Vector2i(40, 32), true), VfxArt.web_cover(Vector2i(40, 32), true))
	assert_ne(VfxArt.web_cover(Vector2i(40, 32), true), VfxArt.web_cover(Vector2i(40, 32), false))

func test_a_few_strands_leave_the_creature_showing() -> void:
	var c := _coverage(VfxArt.web_cover(Vector2i(40, 32), false), 0.5)
	assert_gt(c, 0.02, "there are strands")
	assert_lt(c, 0.25, "but only a few")

func test_the_cocoon_covers_it_completely() -> void:
	var t := VfxArt.web_cover(Vector2i(40, 32), true)
	assert_gt(_coverage(t, 0.4), 0.6, "most of the frame is wrapped")
	assert_gt(_coverage(t, 0.9), 0.15, "with bright strands over the wrap")
