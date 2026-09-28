extends GutTest
## What the player has found, kept across runs: rooms visited, shortcuts opened, tablets read.

var dir: String

func before_each() -> void:
	dir = "user://test_progress_%d" % Time.get_ticks_usec()

func after_each() -> void:
	var abs := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs.path_join(f))
		DirAccess.remove_absolute(abs)

func _profile() -> Profile:
	var p := Profile.new(dir.path_join("profile.json"))
	p.reload()
	return p

func test_records_are_unique_and_queryable() -> void:
	var w := WorldProgress.new()
	w.visit("C1")
	w.visit("C1")
	w.read_tablet("c6_tablet")
	assert_eq(w.visited, ["C1"])
	assert_true(w.is_visited("C1"))
	assert_false(w.is_visited("C2"))
	assert_true(w.is_read("c6_tablet"))

func test_opening_a_shortcut_signals_once() -> void:
	var w := WorldProgress.new()
	var opened: Array = []
	w.shortcut_opened.connect(func(id: String) -> void: opened.append(id))
	w.open_shortcut("c6_drop")
	w.open_shortcut("c6_drop")
	assert_eq(opened, ["c6_drop"])
	assert_true(w.is_open("c6_drop"))

func test_progress_survives_a_reload() -> void:
	var w := WorldProgress.new(_profile())
	w.visit("C2")
	w.open_shortcut("c6_drop")
	w.read_tablet("c6_tablet")
	var again := WorldProgress.new(_profile())
	assert_eq([again.visited, again.shortcuts, again.tablets], [["C2"], ["c6_drop"], ["c6_tablet"]])

func test_the_autoload_owns_progress() -> void:
	assert_true(Compendium.progress is WorldProgress)
	assert_eq(Compendium.progress.profile, Compendium.profile)
