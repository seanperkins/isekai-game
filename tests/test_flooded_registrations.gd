extends GutTest
## The names the Flooded Tunnels add to the shared registries, before any behaviour uses them.

func test_submerged_is_an_event_and_swim_speed_a_stat() -> void:
	assert_true(Events.ALL.has(Events.SUBMERGED))
	assert_eq(Events.SUBMERGED, "submerged")
	assert_true(StatKeys.ALL.has(StatKeys.SWIM_SPEED))
	assert_eq(StatKeys.SWIM_SPEED, "swim_speed")
	assert_eq(Stats.new().get_stat("swim_speed"), 120, "px/s, not a percent")

func test_creature_def_flags_default_off() -> void:
	var c := CreatureDef.new()
	assert_false(c.swimmer)
	assert_false(c.untackleable)
	assert_eq(c.contact_type, "physical")
	assert_eq(c.projectile, "")
	assert_false(c.puffs)
	assert_false(c.pack)
	assert_false(c.charges)
	assert_false(c.stomper)

func test_submerged_has_a_silent_audio_entry_with_a_reason() -> void:
	var cues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio/cues.json"))
	assert_true(cues["events"].has("submerged"))
	assert_null(cues["events"]["submerged"], "once a second is not a sound")
	assert_true(cues["events"].has("_why:submerged"))
