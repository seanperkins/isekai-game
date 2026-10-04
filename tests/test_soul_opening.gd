extends GutTest
## SoulProgress.opening_seen: a fresh profile has not seen the opening, a profile that already holds progress has (it predates the
## opening), an explicit saved value wins, and every save carries the flag.

var dir: String

func before_each() -> void:
	dir = "user://test_soul_opening_%d" % Time.get_ticks_usec()

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

## A profile holding `sections`, written to disk and reloaded, then a SoulProgress over it.
func _loaded(sections: Dictionary) -> SoulProgress:
	var profile := _profile()
	for name in sections:
		profile.set_section(name, sections[name])
	profile.save()
	return SoulProgress.new(_profile(), [])

func test_a_fresh_profile_has_not_seen_the_opening() -> void:
	assert_false(_loaded({}).opening_seen)
	assert_false(SoulProgress.new().opening_seen, "no profile at all")

func test_a_profile_with_a_map_and_no_flag_counts_as_seen() -> void:
	assert_true(_loaded({"map": ["C1"]}).opening_seen)

func test_a_migrated_profile_with_only_compendium_or_bestiary_progress_counts_as_seen() -> void:
	assert_true(_loaded({"compendium": {"leap": "named"}}).opening_seen, "compendium alone")
	assert_true(_loaded({"bestiary": {"bat": {"seen": 1}}}).opening_seen, "bestiary alone")
	assert_false(_loaded({"compendium": {}, "bestiary": {}, "map": []}).opening_seen, "empty sections are not progress")

func test_an_explicit_false_wins_over_a_map() -> void:
	assert_false(_loaded({"soul": {"opening_seen": false}, "map": ["C1"]}).opening_seen)

func test_an_explicit_true_wins_over_an_empty_profile() -> void:
	assert_true(_loaded({"soul": {"opening_seen": true}}).opening_seen)

func test_begin_opening_saves_an_explicit_false_and_it_reloads_unseen_even_with_a_map() -> void:
	var profile := _profile()
	var soul := SoulProgress.new(profile, [])
	soul.begin_opening()
	profile.set_section("map", ["C1"])  # the first room's visit, after the flag
	profile.save()
	assert_false(SoulProgress.new(_profile(), []).opening_seen)
	assert_true(_profile().dict_section("soul").has("opening_seen"), "the key is on disk")

func test_finish_opening_saves_true_and_reloads_seen() -> void:
	var soul := SoulProgress.new(_profile(), [])
	soul.begin_opening()
	soul.finish_opening()
	assert_true(soul.opening_seen)
	assert_true(SoulProgress.new(_profile(), []).opening_seen)

func test_every_save_carries_the_flag() -> void:
	var soul := SoulProgress.new(_profile(), [])
	soul.add(1)
	var saved := _profile().dict_section("soul")
	assert_true(saved.has("opening_seen"))
	assert_false(saved["opening_seen"])
	assert_eq(saved["points"], 1)

func test_a_malformed_flag_follows_the_progress_rule() -> void:
	assert_false(_loaded({"soul": {"opening_seen": "yes"}}).opening_seen, "junk and an empty profile: unseen")
	assert_true(_loaded({"soul": {"opening_seen": "yes"}, "map": ["C1"]}).opening_seen, "junk and a map: seen")

func test_without_a_profile_the_flag_lives_in_memory() -> void:
	var soul := SoulProgress.new()
	soul.begin_opening()
	assert_false(soul.opening_seen)
	soul.finish_opening()
	assert_true(soul.opening_seen)
