extends GutTest
## Volume settings (0..1, saved in the Profile) and the bus layout they drive.

const PATH := "user://test_audio_profile.json"

var profile: Profile

func before_each() -> void:
	profile = Profile.new(PATH)
	profile.warn = func(_msg: String) -> void: pass

func after_each() -> void:
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	AudioSettings.new().apply()  # default volumes on the buses again after a test changed them

func test_defaults_are_eighty_percent() -> void:
	var s := AudioSettings.new()
	for k in AudioSettings.KEYS:
		assert_almost_eq(s.values[k], 0.8, 0.0001, k)
	assert_false(s.dirty)

func test_values_round_trip_through_the_profile() -> void:
	var s := AudioSettings.new()
	s.set_value("music", 0.3)
	s.set_value("sfx", 1.0)
	assert_true(s.dirty)
	assert_true(s.save_to(profile))
	assert_false(s.dirty)
	var again := Profile.new(PATH)
	again.reload()
	var t := AudioSettings.new()
	t.load_from(again)
	assert_almost_eq(t.values["music"], 0.3, 0.0001)
	assert_almost_eq(t.values["sfx"], 1.0, 0.0001)
	assert_almost_eq(t.values["master"], 0.8, 0.0001)

func test_a_malformed_section_resets_to_defaults() -> void:
	profile.set_section("audio", "loud")
	var s := AudioSettings.new()
	s.load_from(profile)
	for k in AudioSettings.KEYS:
		assert_almost_eq(s.values[k], 0.8, 0.0001, k)

func test_bad_values_are_dropped_one_by_one() -> void:
	profile.set_section("audio", {"master": 5.0, "music": "x", "ambience": 0.25, "sfx": -1.0})
	var s := AudioSettings.new()
	s.load_from(profile)
	assert_almost_eq(s.values["master"], 0.8, 0.0001)
	assert_almost_eq(s.values["music"], 0.8, 0.0001)
	assert_almost_eq(s.values["ambience"], 0.25, 0.0001)
	assert_almost_eq(s.values["sfx"], 0.8, 0.0001)

func test_adjust_steps_by_a_tenth_and_clamps() -> void:
	var s := AudioSettings.new()
	s.adjust("music", 1)
	assert_almost_eq(s.values["music"], 0.9, 0.0001)
	s.adjust("music", 1)
	s.adjust("music", 1)
	assert_almost_eq(s.values["music"], 1.0, 0.0001)
	for i in 12:
		s.adjust("music", -1)
	assert_almost_eq(s.values["music"], 0.0, 0.0001)

func test_the_bus_layout_has_every_bus_and_its_effects() -> void:
	for b in ["Music", "Ambience", "SFX_Player", "SFX_Enemy", "SFX_World", "UI"]:
		var i := AudioServer.get_bus_index(b)
		assert_ne(i, -1, b)
		assert_eq(AudioServer.get_bus_send(i), &"Master", b)
	assert_true(AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0) is AudioEffectAmplify)
	assert_true(AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX_World"), 0) is AudioEffectReverb)
	assert_true(AudioServer.get_bus_effect(0, 0) is AudioEffectLimiter)

func test_a_slider_at_zero_mutes_the_bus_and_never_writes_minus_infinity() -> void:
	var s := AudioSettings.new()
	s.set_value("music", 0.0)
	s.set_value("sfx", 0.0)
	s.apply()
	var music := AudioServer.get_bus_index("Music")
	assert_true(AudioServer.is_bus_mute(music))
	assert_gt(AudioServer.get_bus_volume_db(music), -100.0)
	for b in ["SFX_Player", "SFX_Enemy", "SFX_World"]:
		assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(b)), b)
	s.set_value("music", 0.5)
	s.apply()
	assert_false(AudioServer.is_bus_mute(music))
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.5), 0.01)
