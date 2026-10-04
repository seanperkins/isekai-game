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
