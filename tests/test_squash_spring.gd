extends GutTest

func _settle(sp: SquashSpring, vy: float, ticks: int) -> void:
	for _k in ticks:
		sp.update(vy, 1.0 / 60.0)

func test_at_rest_and_in_steady_motion() -> void:
	var sp := SquashSpring.new()
	_settle(sp, 0.0, 60)
	assert_eq(sp.sprite_scale(), Vector2.ONE)
	_settle(sp, 400.0, 300)
	assert_almost_eq(sp.sprite_scale().y, 1.22, 0.01, "fast vertical motion stretches")

func test_a_landing_squashes_overshoots_and_settles() -> void:
	var sp := SquashSpring.new()
	sp.land(500.0)
	sp.update(0.0, 1.0 / 60.0)
	assert_lt(sp.sprite_scale().y, 1.0, "squashed")
	var peak := 0.0
	var low := 1.0
	for _k in 90:
		sp.update(0.0, 1.0 / 60.0)
		peak = maxf(peak, sp.sprite_scale().y)
		low = minf(low, sp.sprite_scale().y)
	assert_gt(peak, 1.0, "springs back past rest")
	assert_gte(low, 0.78)
	_settle(sp, 0.0, 300)
	assert_almost_eq(sp.sprite_scale().y, 1.0, 0.01)

func test_a_long_frame_and_absurd_inputs_stay_bounded_and_keep_volume() -> void:
	var sp := SquashSpring.new()
	sp.land(500.0)
	sp.update(0.0, 0.25)
	for k in 200:
		if k % 7 == 0:
			sp.land(1e6)
		sp.update(1e6 if k % 2 == 0 else -1e6, 1.0 / 60.0)
		var v := sp.sprite_scale()
		assert_true(is_finite(v.x) and is_finite(v.y))
		assert_between(v.y, 0.78 - 0.0001, 1.22 + 0.0001)
		assert_almost_eq(v.x * v.y, 1.0, 0.000001)
