extends GutTest
## Profile: one save file with sections, written together, each validated on its own.

var dir: String
var warnings: Array

func before_each() -> void:
	dir = "user://test_profile_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	warnings = []

func after_each() -> void:
	var abs := ProjectSettings.globalize_path(dir)
	for f in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(f))
	DirAccess.remove_absolute(abs)

func _profile(legacy: bool = false) -> Profile:
	var p := Profile.new(dir.path_join("profile.json"), dir.path_join("compendium.json") if legacy else "")
	p.warn = func(msg: String) -> void: warnings.append(msg)
	p.reload()
	return p

func _write(name: String, text: String) -> void:
	var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_sections_round_trip() -> void:
	var p := _profile()
	p.set_section("map", ["C1", "C2"])
	p.save_states({"leap": 3}, CompendiumModel.STATE_NAMES, {"bat": {"seen": true, "appraisal": 0, "eaten": 1, "defeated": 0}})
	var again := _profile()
	assert_eq(again.list_section("map"), ["C1", "C2"])
	assert_eq(again.load_states(CompendiumModel.STATE_NAMES), {"leap": 3})
	assert_eq(again.load_creatures()["bat"]["eaten"], 1)

func test_a_missing_file_is_a_fresh_start() -> void:
	var p := _profile()
	assert_eq(p.list_section("map"), [])
	assert_eq(p.load_states(CompendiumModel.STATE_NAMES), {})

func test_a_malformed_section_is_dropped_alone() -> void:
	_write("profile.json", '{"version": 1, "map": 7, "shortcuts": ["c6_drop"], "compendium": {"leap": "named"}}')
	var p := _profile()
	assert_eq(p.list_section("map"), [])
	assert_eq(p.list_section("shortcuts"), ["c6_drop"])
	assert_eq(p.load_states(CompendiumModel.STATE_NAMES), {"leap": 1})
	assert_eq(warnings.size(), 1)

func test_a_corrupt_file_is_backed_up_and_fresh() -> void:
	_write("profile.json", "{not json")
	var p := _profile()
	assert_eq(p.list_section("map"), [])
	var baks := Array(DirAccess.get_files_at(ProjectSettings.globalize_path(dir))).filter(func(f: String) -> bool: return f.ends_with(".bak"))
	assert_eq(baks.size(), 1)

func test_legacy_compendium_is_migrated() -> void:
	_write("compendium.json", '{"version": 1, "slots": {"leap": "owned-once"}, "creatures": {"toad": {"seen": true, "appraisal": 2, "eaten": 0, "defeated": 1}}}')
	var p := _profile(true)
	assert_eq(p.load_states(CompendiumModel.STATE_NAMES), {"leap": 3})
	assert_eq(p.load_creatures()["toad"]["appraisal"], 2)
	assert_true(FileAccess.file_exists(dir.path_join("profile.json")))

func test_an_existing_profile_is_not_re_migrated() -> void:
	_write("profile.json", '{"version": 1, "compendium": {"leap": "named"}}')
	_write("compendium.json", '{"version": 1, "slots": {"leap": "owned-once", "glutton": "named"}}')
	var p := _profile(true)
	assert_eq(p.load_states(CompendiumModel.STATE_NAMES), {"leap": 1})

func test_the_compendium_model_saves_through_a_profile() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creatures := DefLoader.load_dir("res://data/creatures")
	var m := CompendiumModel.new(skills, creatures, _profile())
	m.raise("leap", CompendiumModel.State.NAMED)
	m.on_creature_seen("bat")
	var again := CompendiumModel.new(skills, creatures, _profile())
	assert_eq(again.state("leap"), CompendiumModel.State.NAMED)
	assert_true(again.creature_record("bat")["seen"])

func test_the_autoload_uses_a_profile() -> void:
	assert_true(Compendium.profile is Profile)
	assert_eq(Compendium.model.store, Compendium.profile)
