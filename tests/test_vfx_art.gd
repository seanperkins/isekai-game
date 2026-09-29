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

func test_water_slash_is_the_generated_sprite() -> void:
	assert_eq(VfxArt.water_slash().get_size(), Vector2(56, 54))

func test_water_slash_is_blue_and_its_bulge_leads_to_the_right() -> void:
	var img := VfxArt.water_slash().get_image()
	var left := 0
	var right := 0
	var red := 0.0
	var blue := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			red += c.r
			blue += c.b
			if x < img.get_width() / 2:
				left += 1
			else:
				right += 1
	assert_gt(blue, red + 100.0, "water, not air: the sprite is blue")
	assert_gt(right, left, "the crescent's mass is on the right: it travels bulge first, toward +x")

func test_textures_are_cached() -> void:
	assert_same(VfxArt.silk(), VfxArt.silk())
	assert_same(VfxArt.water_slash(), VfxArt.water_slash())
	assert_same(VfxArt.web(80), VfxArt.web(80))
	assert_ne(VfxArt.web(80), VfxArt.web(40))

func _coverage(t: Texture2D, min_alpha: float, region := Rect2i()) -> float:
	var img := t.get_image()
	var r := region if region.size != Vector2i.ZERO else Rect2i(0, 0, img.get_width(), img.get_height())
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if img.get_pixel(x, y).a >= min_alpha:
				n += 1
	return float(n) / float(r.size.x * r.size.y)

func _centroid(t: Texture2D) -> Vector2:
	var img := t.get_image()
	var sum := Vector2.ZERO
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				sum += Vector2(float(x) / img.get_width(), float(y) / img.get_height())
				n += 1
	return sum / float(maxi(n, 1))

func test_web_cover_fits_over_the_frame_and_is_cached() -> void:
	for held in [false, true]:
		var t := VfxArt.web_cover(Vector2i(40, 32), held)
		assert_gte(t.get_size().x, 40.0)
		assert_gte(t.get_size().y, 32.0)
		assert_same(t, VfxArt.web_cover(Vector2i(40, 32), held))
	assert_ne(VfxArt.web_cover(Vector2i(40, 32), true), VfxArt.web_cover(Vector2i(40, 32), false))

func test_a_few_strands_leave_the_creature_showing() -> void:
	var c := _coverage(VfxArt.web_cover(Vector2i(40, 32), false), 0.5)
	assert_gt(c, 0.03, "there are strands")
	assert_lt(c, 0.4, "but only a few")

func test_the_cocoon_covers_the_frame_completely() -> void:
	var t := VfxArt.web_cover(Vector2i(40, 32), true)
	var frame := Rect2i((Vector2i(t.get_size()) - Vector2i(40, 32)) / 2, Vector2i(40, 32))
	assert_gt(_coverage(t, 0.5, frame), 0.7, "the wrap hides nearly all of the frame it sits over")

func test_the_strand_layout_does_not_change_with_the_animation_frame() -> void:
	# sheet frames are trimmed, so a walking toad is 46x22, 37x22, 46x21...: the strands must not jump between them
	var a := _centroid(VfxArt.web_cover(Vector2i(46, 22), false))
	for size in [Vector2i(37, 22), Vector2i(46, 21), Vector2i(40, 24)]:
		var b := _centroid(VfxArt.web_cover(size, false))
		assert_lt(a.distance_to(b), 0.05, "strands at %s" % size)

func test_a_wide_frame_gets_a_lying_cocoon_and_a_tall_one_an_upright_cocoon() -> void:
	var wide := VfxArt.web_cover(Vector2i(46, 22), true).get_size()
	var tall := VfxArt.web_cover(Vector2i(20, 40), true).get_size()
	assert_gt(wide.x, wide.y)
	assert_gt(tall.y, tall.x)
