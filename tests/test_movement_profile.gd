extends GutTest

func test_the_three_profiles_load_with_the_spec_values() -> void:
	assert_eq(MovementProfile.IDS, ["biped", "slime", "wolf", "spider"])
	for id in MovementProfile.IDS:
		var p := MovementProfile.of(id)
		assert_not_null(p, id)
		assert_eq(p.id, id)
		for v in [p.top_speed, p.ground_accel_time, p.ground_stop_time, p.ground_turn_time, p.air_stop_time, p.jump_velocity, p.gravity, p.fall_mult]:
			assert_gt(v, 0.0, id)
	var b := MovementProfile.of("biped")
	assert_eq([b.jump_velocity, b.gravity, b.fall_mult, b.release_factor], [330.0, 900.0, 1.0, 0.35])
	assert_eq(b.release_style, MovementProfile.ReleaseStyle.CUT)
	var s := MovementProfile.of("slime")
	assert_eq([s.top_speed, s.jump_velocity, s.fall_mult, s.apex_band, s.rebound_rise], [140.0, 328.5, 1.53, 40.0, 0.3])
	assert_eq([s.rebound_cap, s.bounce_keep, s.bounce_min_impact], [0.6, 0.85, 250.0])
	assert_eq(s.release_style, MovementProfile.ReleaseStyle.SOFT)
	var w := MovementProfile.of("wolf")
	assert_eq([w.top_speed, w.ground_accel_time, w.ground_turn_time, w.jump_velocity, w.gravity], [230.0, 0.4, 0.1, 403.0, 1344.0])
	assert_true(w.air_keeps_momentum)
	var sp := MovementProfile.of("spider")
	assert_eq([sp.top_speed, sp.ground_accel_time, sp.ground_stop_time, sp.ground_turn_time, sp.jump_velocity, sp.gravity, sp.fall_mult], [140.0, 0.03, 0.02, 0.02, 330.0, 900.0, 1.0])
	assert_eq(sp.release_style, MovementProfile.ReleaseStyle.CUT)
	assert_eq(sp.release_factor, 1.0)

func test_an_unknown_id_is_null() -> void:
	assert_null(MovementProfile.of("dragon"))
