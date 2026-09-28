extends GutTest
## The slime's body scale is one constant; the collision boxes and the floor line derive from it.

func test_the_boxes_scale_together() -> void:
	assert_eq(BodyConfig.SCALE, 2)
	assert_eq(BodyConfig.size(), Vector2(28, 24))
	assert_eq(BodyConfig.spread_size(), Vector2(28, 10))
	assert_eq(BodyConfig.BOTTOM, 12.0)

func test_the_spread_box_is_shorter_and_as_wide() -> void:
	assert_eq(BodyConfig.spread_size().x, BodyConfig.size().x)
	assert_lt(BodyConfig.spread_size().y, BodyConfig.size().y)
