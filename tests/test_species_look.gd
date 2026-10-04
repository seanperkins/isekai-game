extends GutTest

func test_which_species_have_a_look() -> void:
	assert_false(SpeciesLook.has_look("biped"))
	for id in ["slime", "spider", "wolf"]:
		assert_true(SpeciesLook.has_look(id), id)
	assert_eq(SpeciesLook.clip_for("biped", true, 0.0, 0.0, 0.0), "")
	assert_eq(SpeciesLook.clips_for("biped"), {})
	assert_null(SpeciesLook.sheet_for("biped"))

func test_the_slime_uses_its_state_picker() -> void:
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 0.0, 0.0), "idle")
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 100.0, 0.0), "run")
	assert_eq(SpeciesLook.clip_for("slime", false, -50.0, 0.0, 0.0), "rise")
	assert_eq(SpeciesLook.clip_for("slime", false, 50.0, 0.0, 0.0), "fall")
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 0.0, 0.1), "land")

func test_the_spider_hangs_still_crawls_moving_and_drops_in_the_air() -> void:
	assert_eq(SpeciesLook.clip_for("spider", true, 0.0, 0.0, 0.0), "hang")
	assert_eq(SpeciesLook.clip_for("spider", true, 0.0, 100.0, 0.0), "crawl")
	assert_eq(SpeciesLook.clip_for("spider", false, -50.0, 0.0, 0.0), "drop")
	assert_eq(SpeciesLook.clip_for("spider", false, 50.0, 100.0, 0.0), "drop")

func test_the_wolf_has_two_gears_and_a_windup_in_the_air() -> void:
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, 0.0, 0.0), "idle")
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, 100.0, 0.0), "walk")
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, 149.9, 0.0), "walk")
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, 150.0, 0.0), "charge")
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, -230.0, 0.0), "charge", "the sign of the speed does not matter")
	assert_eq(SpeciesLook.clip_for("wolf", false, -50.0, 230.0, 0.0), "windup")

func test_every_clip_it_names_exists_in_the_data() -> void:
	for id in ["slime", "spider", "wolf"]:
		var clips := SpeciesLook.clips_for(id)
		assert_false(clips.is_empty(), id)
		for on_floor in [true, false]:
			for vy in [-50.0, 0.0, 50.0]:
				for vx in [0.0, 100.0, -200.0]:
					for land in [0.0, 0.1]:
						var clip := SpeciesLook.clip_for(id, on_floor, vy, vx, land)
						assert_true(clips.has(clip), "%s %s" % [id, clip])
						for flags in [[true, false], [false, true], [true, true]]:
							clip = SpeciesLook.clip_for(id, on_floor, vy, vx, land, "", false, flags[0], flags[1])
							assert_true(clips.has(clip), "%s %s %s" % [id, clip, flags])

func test_the_slime_shows_its_tackle_and_flat_poses_and_others_ignore_them() -> void:
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 100.0, 0.0, "tackle", false), "tackle")
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 0.0, 0.0, "", true), "spread")
	assert_eq(SpeciesLook.clip_for("spider", true, 0.0, 0.0, 0.0, "tackle", true), "hang")

func test_the_wall_pose_beats_every_other_slime_pose() -> void:
	assert_eq(SpeciesLook.clip_for("slime", false, 50.0, 0.0, 0.0, "tackle", true, true, true), "wall")

func test_ball_replaces_only_the_airborne_and_landing_poses() -> void:
	assert_eq(SpeciesLook.clip_for("slime", false, -50.0, 0.0, 0.0, "", false, false, true), "ball")
	assert_eq(SpeciesLook.clip_for("slime", false, 50.0, 0.0, 0.0, "", false, false, true), "ball")
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 0.0, 0.1, "", false, false, true), "ball")
	assert_eq(SpeciesLook.clip_for("slime", false, -50.0, 100.0, 0.0, "tackle", false, false, true), "tackle")
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 0.0, 0.0, "", true, false, true), "spread")
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 0.0, 0.0, "", false, false, true), "idle")
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 100.0, 0.0, "", false, false, true), "run")

func test_other_species_ignore_wall_and_ball() -> void:
	for id in ["spider", "wolf"]:
		assert_eq(SpeciesLook.clip_for(id, false, -50.0, 0.0, 0.0, "", false, true, true), SpeciesLook.clip_for(id, false, -50.0, 0.0, 0.0), id)

func test_the_slimes_clips_gain_a_ball_stand_in_without_touching_the_game_data() -> void:
	assert_true(SpeciesLook.clips_for("slime").has("ball"))
	assert_eq(SpeciesLook.clips_for("slime")["ball"]["frames"], ["fall"])
	assert_false(SlimeAnimator.load_clips("res://data/slime_clips.json").has("ball"))

func test_the_crawl_wobble_stretches_and_squeezes_without_changing_volume() -> void:
	assert_eq(SpeciesLook.crawl_scale(0.0), Vector2.ONE)
	var out := SpeciesLook.crawl_scale(PI / 2.0)
	assert_gt(out.x, 1.0)
	assert_lt(out.y, 1.0)
	var back := SpeciesLook.crawl_scale(3.0 * PI / 2.0)
	assert_lt(back.x, 1.0)
	assert_gt(back.y, 1.0)
	for k in 10:
		var s := SpeciesLook.crawl_scale(k * 0.7)
		assert_almost_eq(s.x * s.y, 1.0, 0.001)
		assert_lte(absf(s.x - 1.0), SpeciesLook.CRAWL_AMPLITUDE + 0.0001)
	var a := SpeciesLook.crawl_scale(0.3)
	var b := SpeciesLook.crawl_scale(TAU + 0.3)
	assert_almost_eq(a.x, b.x, 0.0001)
	assert_almost_eq(a.y, b.y, 0.0001)

func test_the_crawl_phase_follows_distance_travelled() -> void:
	assert_almost_eq(SpeciesLook.crawl_advance(0.0, 70.0, 1.0), 70.0 * SpeciesLook.CRAWL_RATE, 0.0001)
	assert_eq(SpeciesLook.crawl_advance(1.5, 0.0, 1.0), 1.5)
	assert_eq(SpeciesLook.crawl_advance(0.0, -70.0, 1.0), SpeciesLook.crawl_advance(0.0, 70.0, 1.0))

func test_the_stride_follows_distance_not_time() -> void:
	assert_eq(SpeciesLook.stride_advance(0.0, SpeciesLook.STRIDE_PX), 1.0)
	assert_eq(SpeciesLook.stride_advance(0.3, 0.0), 0.3, "no movement, no step")
	assert_eq(SpeciesLook.stride_advance(0.0, -SpeciesLook.STRIDE_PX), 1.0, "the sign does not matter")

func test_four_frames_to_a_stride() -> void:
	assert_eq(SpeciesLook.stride_frame(0.0), 0)
	assert_eq(SpeciesLook.stride_frame(0.26), 1)
	assert_eq(SpeciesLook.stride_frame(0.5), 2)
	assert_eq(SpeciesLook.stride_frame(0.76), 3)
	assert_eq(SpeciesLook.stride_frame(1.0), 0, "it wraps")
	assert_eq(SpeciesLook.stride_frame(1.26), 1)

func test_the_sprite_turns_a_quarter_per_surface() -> void:
	assert_almost_eq(SpeciesLook.surface_angle(Vector2.UP), 0.0, 0.0001)
	assert_almost_eq(SpeciesLook.surface_angle(Vector2.RIGHT), PI / 2.0, 0.0001)
	assert_almost_eq(absf(SpeciesLook.surface_angle(Vector2.DOWN)), PI, 0.0001)
	assert_almost_eq(SpeciesLook.surface_angle(Vector2.LEFT), -PI / 2.0, 0.0001)
