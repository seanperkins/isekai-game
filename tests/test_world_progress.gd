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

# --- reached forms ---

func test_the_slime_is_reached_by_definition_and_never_stored() -> void:
	var w := WorldProgress.new()
	assert_true(w.is_form_reached("slime"))
	w.reach_form("slime")
	w.reach_form("")
	assert_eq(w.forms_reached, [])

func test_reached_forms_are_unique_and_survive_a_reload() -> void:
	var w := WorldProgress.new(_profile())
	w.reach_form("weaver")
	w.reach_form("weaver")
	w.reach_form("snare")
	assert_eq(w.forms_reached, ["weaver", "snare"])
	var again := WorldProgress.new(_profile())
	assert_eq(again.forms_reached, ["weaver", "snare"])
	assert_true(again.is_form_reached("snare"))
	assert_false(again.is_form_reached("arachne"))

func test_other_saves_keep_the_reached_forms() -> void:
	var w := WorldProgress.new(_profile())
	w.reach_form("tide")
	w.visit("C2")
	w.sanitize(["C1"])
	assert_eq(WorldProgress.new(_profile()).forms_reached, ["tide"])

func test_a_malformed_forms_section_is_dropped_with_a_warning() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(dir.path_join("profile.json"), FileAccess.WRITE)
	f.store_string('{"version": 1, "forms_reached": ["weaver", 3], "map": ["C1"]}')
	f.close()
	var warnings: Array = []
	var p := Profile.new(dir.path_join("profile.json"))
	p.warn = func(msg: String) -> void: warnings.append(msg)
	p.reload()
	var w := WorldProgress.new(p)
	assert_eq(w.forms_reached, [])
	assert_eq(w.visited, ["C1"], "the other sections still load")
	assert_eq(warnings.size(), 1)

# --- defeated bosses (plan: boss arenas, Task 5) ---

## A profile whose first write fails, like a full disk.
class FlakyProfile extends Profile:
	var fail_next := true
	func save() -> bool:
		if fail_next:
			fail_next = false
			return false
		return super.save()

func test_a_defeated_boss_is_stored_and_survives_a_reload() -> void:
	var w := WorldProgress.new(_profile())
	assert_false(w.is_defeated("taratect"))
	w.defeat_boss("taratect")
	w.defeat_boss("taratect")
	assert_true(w.is_defeated("taratect"))
	assert_eq(w.bosses, ["taratect"])
	var again := WorldProgress.new(_profile())
	assert_true(again.is_defeated("taratect"))
	assert_false(again.is_defeated("serpent"))

func test_a_failed_write_keeps_the_boss_dead_for_the_session_and_the_next_save_retries() -> void:
	var flaky := FlakyProfile.new(dir.path_join("profile.json"))
	flaky.reload()
	var w := WorldProgress.new(flaky)
	w.defeat_boss("taratect")  # this write fails
	assert_true(w.is_defeated("taratect"), "dead for the session whatever the disk said")
	assert_false(WorldProgress.new(_profile()).is_defeated("taratect"), "and not on disk yet")
	w.visit("C1")  # any later progress save rewrites every section, the boss included
	assert_true(WorldProgress.new(_profile()).is_defeated("taratect"), "the next save retried it")
