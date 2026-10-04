extends GutTest

func _alpha(img: Image, x: int, y: int) -> bool:
	return img.get_pixel(x, y).a > 0.0

func _eye_pixels(img: Image) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for y in SlimeBall.SIZE:
		for x in SlimeBall.SIZE:
			if img.get_pixel(x, y).is_equal_approx(SlimeBall.EYE):
				out.append(Vector2(x + 0.5, y + 0.5))
	return out

## The eye pixels' centre relative to the ball's centre.
func _eye_centre(img: Image) -> Vector2:
	var sum := Vector2.ZERO
	var eyes := _eye_pixels(img)
	for p in eyes:
		sum += p
	return sum / float(eyes.size()) - Vector2(SlimeBall.SIZE, SlimeBall.SIZE) / 2.0

func test_the_ball_is_round_and_the_size_of_the_slime() -> void:
	var img := SlimeBall.image(0.0)
	assert_eq(img.get_size(), Vector2i(SlimeBall.SIZE, SlimeBall.SIZE))
	var last := SlimeBall.SIZE - 1
	var opaque := 0
	for y in SlimeBall.SIZE:
		for x in SlimeBall.SIZE:
			opaque += 1 if _alpha(img, x, y) else 0
			assert_eq(_alpha(img, x, y), _alpha(img, last - x, y), "mirrored left to right at %d,%d" % [x, y])
			assert_eq(_alpha(img, x, y), _alpha(img, x, last - y), "mirrored top to bottom at %d,%d" % [x, y])
			assert_eq(_alpha(img, x, y), _alpha(img, y, x), "the same turned a quarter at %d,%d" % [x, y])
	assert_almost_eq(float(opaque), PI * SlimeBall.RADIUS * SlimeBall.RADIUS, PI * SlimeBall.RADIUS * SlimeBall.RADIUS * 0.03)
	assert_false(_alpha(img, 0, 0), "the corners are empty")

func test_the_eyes_never_leave_the_ball_so_the_shape_never_changes() -> void:
	var body := SlimeBall.image(0.0)
	for k in 12:
		var img := SlimeBall.image(TAU * k / 12.0)
		for y in SlimeBall.SIZE:
			for x in SlimeBall.SIZE:
				assert_eq(_alpha(img, x, y), _alpha(body, x, y), "roll %d at %d,%d" % [k, x, y])

func test_the_eyes_roll_around_the_ball() -> void:
	var right := _eye_centre(SlimeBall.image(0.0))
	assert_gt(right.x, 5.0)
	assert_lt(absf(right.y), 2.0)
	var down := _eye_centre(SlimeBall.image(PI / 2.0))
	assert_gt(down.y, 5.0)
	assert_lt(absf(down.x), 2.0)
	assert_lt(_eye_centre(SlimeBall.image(PI)).x, -5.0)
	assert_lt(_eye_centre(SlimeBall.image(3.0 * PI / 2.0)).y, -5.0)
	for k in 8:
		var img := SlimeBall.image(TAU * k / 8.0)
		assert_almost_eq(_eye_centre(img).length(), right.length(), 1.5, "the eyes stay on one circle, roll %d" % k)
		assert_gte(_eye_pixels(img).size(), 8, "both eyes show, roll %d" % k)

func test_the_body_and_its_highlight_do_not_turn_with_the_eyes() -> void:
	for roll in [0.0, PI]:
		assert_eq(SlimeBall.image(roll).get_pixel(12, 10), SlimeBall.GLASS, "highlight, roll %s" % roll)
	assert_eq(SlimeBall.body().get_pixel(19, 19).a, 1.0)
	assert_eq(_eye_pixels(SlimeBall.body()).size(), 0, "the shared body has no eyes painted on it")
	SlimeBall.image(1.0)
	assert_eq(_eye_pixels(SlimeBall.body()).size(), 0, "drawing the eyes never touches the shared body")

func test_a_texture_has_the_same_size() -> void:
	assert_eq(SlimeBall.texture(0.3).get_size(), Vector2(SlimeBall.SIZE, SlimeBall.SIZE))
