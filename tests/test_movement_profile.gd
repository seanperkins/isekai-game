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

func test_the_wolf_and_spider_have_no_wall_kit() -> void:
	for id in ["wolf", "spider"]:
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

func test_the_spider_drops_with_the_spec_numbers() -> void:
	var sp := MovementProfile.of("spider")
	assert_true(sp.verbs.has("drop"))
	assert_eq([sp.drop_range, sp.drop_reel, sp.drop_climb, sp.drop_air], [200.0, 90.0, 60.0, 0.5])
	for id in ["biped", "slime", "wolf"]:
		assert_false(MovementProfile.of(id).verbs.has("drop"), id)

func test_every_species_falls_through_for_a_fifth_of_a_second() -> void:
	for id in MovementProfile.IDS:
		assert_eq(MovementProfile.of(id).fall_through, 0.2, id)

func test_the_wolf_pounces_with_the_spec_numbers() -> void:
	var rows := MovementProfile.of("wolf").bursts.filter(func(r): return (r as BurstDef).id == "pounce")
	assert_eq(rows.size(), 1)
	if rows.is_empty():
		return
	var r := rows[0] as BurstDef
	assert_eq([r.trigger, r.speed, r.run_fraction, r.duration, r.cooldown], ["signature", 300.0, 0.5, 0.35, 0.8])
	assert_true(r.aimed)
	assert_true(r.ends_at_wall)
	for id in ["biped", "slime", "spider"]:
		var others := MovementProfile.of(id).bursts.filter(func(b): return (b as BurstDef).id == "pounce")
		assert_eq(others.size(), 0, id)

func test_the_wolf_vaults_with_the_spec_numbers_and_nobody_else_does() -> void:
	var wolf := MovementProfile.of("wolf")
	assert_true(wolf.verbs.has("vault"))
	assert_eq([wolf.vault_speed, wolf.vault_step, wolf.vault_margin], [150.0, 24.0, 6.0])
	for id in ["biped", "slime", "spider"]:
		assert_false(MovementProfile.of(id).verbs.has("vault"), id)

func test_the_biped_rolls_and_slides_with_the_spec_numbers() -> void:
	var rows := {}
	for r in MovementProfile.of("biped").bursts:
		rows[(r as BurstDef).id] = r
	assert_eq(rows.keys().size(), 2)
	if rows.size() != 2:
		return
	var roll := rows["roll"] as BurstDef
	assert_eq([roll.trigger, roll.speed, roll.duration, roll.max_start_speed, roll.iframes, roll.cooldown], ["signature", 220.0, 0.35, 100.0, 0.2, 0.3])
	assert_true(roll.flat and roll.needs_floor)
	var slide := rows["slide"] as BurstDef
	assert_eq([slide.trigger, slide.speed, slide.duration, slide.min_start_speed, slide.decel, slide.min_speed, slide.iframes, slide.cooldown], ["signature", 0.0, 0.4, 100.0, 350.0, 20.0, 0.2, 0.3])
	assert_true(slide.flat and slide.needs_floor)
	assert_eq(roll.cooldown_group, slide.cooldown_group)
	assert_ne(roll.cooldown_group, "")
	for id in ["slime", "spider", "wolf"]:
		for r in MovementProfile.of(id).bursts:
			assert_false((r as BurstDef).id in ["roll", "slide"], id)

func test_the_biped_has_the_wall_verb_with_the_spec_numbers() -> void:
	var biped := MovementProfile.of("biped")
	assert_true(biped.verbs.has("wall"))
	assert_eq([biped.wall_stick_time, biped.wall_slide_speed, biped.wall_jump_push, biped.wall_lock, biped.wall_grace, biped.wall_bounce_keep], [0.0, 90.0, 180.0, 0.15, 0.1, 0.0])

func test_the_biped_mantles_with_the_spec_numbers_and_nobody_else_does() -> void:
	var biped := MovementProfile.of("biped")
	assert_true(biped.verbs.has("mantle"))
	assert_true(biped.verbs.has("wall"))
	assert_eq([biped.mantle_reach, biped.mantle_max_rise, biped.mantle_time], [6.0, 40.0, 0.25])
	for id in ["slime", "spider", "wolf"]:
		assert_false(MovementProfile.of(id).verbs.has("mantle"), id)
