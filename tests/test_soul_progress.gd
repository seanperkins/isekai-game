extends GutTest
## Soul points, perks and deaths: earned at altars, kept across runs in the profile's `soul` section.

var dir: String

func before_each() -> void:
	dir = "user://test_soul_%d" % Time.get_ticks_usec()

func after_each() -> void:
	var path := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(path):
		for f in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(f))
		DirAccess.remove_absolute(path)

func _profile() -> Profile:
	var p := Profile.new(dir.path_join("profile.json"))
	p.warn = func(_msg: String) -> void: pass
	p.reload()
	return p

func _perk() -> PerkDef:
	var p := PerkDef.new()
	p.id = "stats"
	p.price_base = 5
	p.price_step = 3
	return p

func _loaded_from(section) -> SoulProgress:
	var profile := _profile()
	profile.set_section("soul", section)
	return SoulProgress.new(profile, ["stats"])

func test_a_fresh_soul_is_empty() -> void:
	var soul := SoulProgress.new()
	assert_eq(soul.total_points(), 0)
	assert_eq(soul.deaths, 0)
	assert_eq(soul.perks, {})

func test_add_and_spend() -> void:
	var soul := SoulProgress.new()
	soul.add(5)
	assert_true(soul.spend(3))
	assert_eq(soul.total_points(), 2)
	assert_false(soul.spend(3), "short")
	assert_eq(soul.total_points(), 2, "a refused spend takes nothing")
	soul.add(0)
	soul.add(-3)
	assert_eq(soul.total_points(), 2, "adding nothing or less changes nothing")
	assert_false(soul.spend(-1))
	assert_true(soul.spend(0))

func test_session_points_are_spent_first() -> void:
	var soul := SoulProgress.new()
	soul.points = 3
	soul.session_points = 4
	assert_eq(soul.total_points(), 7)
	assert_false(soul.spend(8))
	assert_eq(soul.total_points(), 7, "a short balance spends nothing, session points included")
	assert_true(soul.spend(5))
	assert_eq(soul.session_points, 0)
	assert_eq(soul.points, 2)

func test_buying_a_perk_follows_the_price_curve() -> void:
	var soul := SoulProgress.new(null, ["stats"])
	soul.add(20)
	assert_true(soul.buy_perk(_perk()))
	assert_eq(soul.total_points(), 15, "the first costs 5")
	assert_true(soul.buy_perk(_perk()))
	assert_eq(soul.total_points(), 7, "the second costs 8")
	assert_false(soul.buy_perk(_perk()), "the third costs 11")
	assert_eq(soul.total_points(), 7)
	assert_eq(soul.perk_count("stats"), 2)

func test_progress_survives_a_reload_but_session_points_do_not() -> void:
	var soul := SoulProgress.new(_profile(), ["stats"])
	soul.add(20)
	soul.note_death()
	soul.buy_perk(_perk())
	soul.session_points = 9
	var again := SoulProgress.new(_profile(), ["stats"])
	assert_eq(again.points, 15)
	assert_eq(again.deaths, 1)
	assert_eq(again.perks, {"stats": 1})
	assert_eq(again.session_points, 0)

func test_a_malformed_section_loads_as_zero() -> void:
	var from_list := _loaded_from([1, 2])
	assert_eq([from_list.points, from_list.deaths, from_list.perks], [0, 0, {}])
	var from_junk := _loaded_from({"points": -4, "deaths": "x", "perks": "none"})
	assert_eq([from_junk.points, from_junk.deaths, from_junk.perks], [0, 0, {}])

func test_a_section_is_trimmed_to_known_perks_and_sane_numbers() -> void:
	var soul := _loaded_from({"points": 7.0, "deaths": 2, "perks": {"gone": 2, "stats": 1, "bad": -1}})
	assert_eq(soul.points, 7, "a float from JSON reads as an int")
	assert_eq(soul.deaths, 2)
	assert_eq(soul.perks, {"stats": 1}, "an unknown perk and a negative count are dropped")

func test_a_perk_the_data_does_not_hold_stays_in_the_file() -> void:
	var profile := _profile()
	profile.set_section("soul", {"points": 3, "deaths": 0, "perks": {"stats": 2, "retired": 4}})
	var without := SoulProgress.new(profile, [])  # as if the perk data failed to load this time
	assert_eq(without.perks, {}, "an unknown perk is not counted")
	without.add(1)  # any change saves
	var back := SoulProgress.new(_profile(), ["stats", "retired"])
	assert_eq(back.perks, {"stats": 2, "retired": 4}, "a perk that was only briefly unknown loses nothing")

func test_compendium_has_a_soul() -> void:
	assert_not_null(Compendium.soul)
