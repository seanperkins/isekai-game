extends GutTest
## The swing rope as pure math: taut length, slack, reeling, pumping, release.

func _rope(anchor := Vector2(0, 0), from := Vector2(0, 80)) -> Rope:
	return Rope.new(anchor, from, 120.0, 60.0, 1.4)

func test_length_starts_at_the_attach_distance_clamped_to_max() -> void:
	assert_eq(_rope().length, 80.0)
	assert_eq(_rope(Vector2.ZERO, Vector2(0, 300)).length, 120.0)
	assert_eq(_rope(Vector2.ZERO, Vector2(0, 2)).length, Rope.MIN_LENGTH)

func test_a_taut_rope_removes_outward_speed_only() -> void:
	var r := _rope()
	assert_eq(r.constrain_velocity(Vector2(0, 80), Vector2(50, 200)), Vector2(50, 0))
	assert_eq(r.constrain_velocity(Vector2(0, 80), Vector2(50, -200)), Vector2(50, -200))

func test_a_slack_rope_leaves_velocity_alone() -> void:
	assert_eq(_rope().constrain_velocity(Vector2(0, 40), Vector2(0, 300)), Vector2(0, 300))

func test_correction_pulls_back_onto_the_rope() -> void:
	var r := _rope()
	assert_eq(r.correction(Vector2(0, 100)), Vector2(0, -20))
	assert_eq(r.correction(Vector2(0, 60)), Vector2.ZERO)

func test_reel_moves_length_within_limits() -> void:
	var r := _rope()
	r.reel(-1.0, 0.5)  # up reels in
	assert_eq(r.length, 50.0)
	r.reel(1.0, 10.0)  # down reels out, capped at max
	assert_eq(r.length, 120.0)
	r.reel(-1.0, 10.0)
	assert_eq(r.length, Rope.MIN_LENGTH)

func test_pump_pushes_along_the_swing_in_the_held_direction() -> void:
	var r := _rope()
	var right := r.pump(Vector2(0, 80), Vector2.ZERO, 1.0, 0.1)
	var left := r.pump(Vector2(0, 80), Vector2.ZERO, -1.0, 0.1)
	assert_gt(right.x, 0.0)
	assert_lt(left.x, 0.0)
	assert_eq(r.pump(Vector2(0, 80), Vector2(5, 5), 0.0, 0.1), Vector2(5, 5))

func test_release_keeps_momentum_times_the_boost_with_some_lift() -> void:
	var r := _rope()
	assert_eq(r.release_velocity(Vector2(200, -300)), Vector2(280, -420))
	assert_eq(r.release_velocity(Vector2(200, 100)).y, Rope.RELEASE_LIFT)

func test_pay_out_lengthens_to_the_body_up_to_max() -> void:
	var r := _rope()
	r.pay_out(Vector2(0, 100))
	assert_eq(r.length, 100.0)
	r.pay_out(Vector2(0, 50))  # never shortens
	assert_eq(r.length, 100.0)
	r.pay_out(Vector2(0, 300))
	assert_eq(r.length, 120.0)
