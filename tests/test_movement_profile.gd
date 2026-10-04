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

func test_the_slime_wall_numbers() -> void:
	var s := MovementProfile.of("slime")
	assert_true(s.verbs.has("ooze"))
	assert_true(s.verbs.has("wall"))
	assert_eq([s.wall_stick_time, s.wall_stick_speed, s.wall_slide_speed], [0.2, 15.0, 90.0])
	assert_eq([s.wall_jump_push, s.wall_lock, s.wall_grace], [180.0, 0.15, 0.15])
	assert_eq([s.wall_bounce_keep, s.wall_bounce_min], [0.85, 100.0])

func test_the_other_species_have_no_wall_kit() -> void:
	for id in ["biped", "wolf", "spider"]:
		var p := MovementProfile.of(id)
		assert_false(p.verbs.has("wall"), id)
		assert_eq(p.wall_bounce_keep, 0.0, id)

func test_copy_keeps_the_wall_side() -> void:
	var i := MoveInput.new()
	i.wall_side = -1
	assert_eq(i.copy().wall_side, -1)

func test_the_spider_crawls_and_the_others_do_not() -> void:
	var sp := MovementProfile.of("spider")
	assert_true(sp.verbs.has("crawl"))
	assert_eq([sp.corner_lock, sp.crawl_back_window], [0.10, 0.6])
	for id in ["biped", "slime", "wolf"]:
		assert_false(MovementProfile.of(id).verbs.has("crawl"), id)

func test_stick_is_dir_and_down_minus_up() -> void:
	var i := MoveInput.new()
	i.dir = 1.0
	i.up = 1.0
	assert_eq(i.stick(), Vector2(1.0, -1.0))
	i.up = 0.0
	i.down = 0.5
	assert_eq(i.stick(), Vector2(1.0, 0.5))

func test_copy_keeps_the_probes_and_up() -> void:
	var i := MoveInput.new()
	i.sweep = func(_m: Vector2) -> Dictionary: return {}
	i.ray = func(_a: Vector2, _b: Vector2, _h: bool) -> int: return 1
	i.up = 0.7
	i.on_ceiling = true
	var c := i.copy()
	assert_eq(c.sweep, i.sweep)
	assert_eq(c.ray, i.ray)
	assert_eq([c.up, c.on_ceiling], [0.7, true])

func test_the_spider_zips_with_the_spec_numbers() -> void:
	var sp := MovementProfile.of("spider")
	assert_true(sp.verbs.has("zip"))
	assert_true(sp.verbs.has("crawl"))
	assert_eq([sp.zip_range, sp.zip_speed, sp.zip_keep, sp.zip_cooldown], [160.0, 400.0, 0.6, 0.4])
	for id in ["biped", "slime", "wolf"]:
		assert_false(MovementProfile.of(id).verbs.has("zip"), id)

func test_copy_keeps_aim_and_cast() -> void:
	var i := MoveInput.new()
	i.aim = Vector2(0.5, -1.0)
	i.cast = func(_a: Vector2, _b: Vector2, _o: bool) -> Dictionary: return {}
	var c := i.copy()
	assert_eq(c.aim, i.aim)
	assert_eq(c.cast, i.cast)
