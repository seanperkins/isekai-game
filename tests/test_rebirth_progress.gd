extends GutTest
## Which rebirth pools are attuned, the last choice, and the pending start, saved through one Profile.

var dir := "user://gut_rebirth_%d" % randi()

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(dir)

func after_each() -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

func _profile() -> Profile:
	var p := Profile.new(dir.path_join("profile.json"))
	p.warn = func(_m: String) -> void: pass
	p.reload()
	return p

func test_the_cave_mouth_is_always_attuned() -> void:
	var w := WorldProgress.new(_profile())
	assert_true(w.is_attuned(WorldProgress.DEFAULT_POOL))
	assert_false(w.is_attuned("G1"))

func test_attuning_persists_across_a_reload_and_stores_once() -> void:
	var w := WorldProgress.new(_profile())
	w.attune("G1")
	w.attune("G1")
	assert_eq(w.rebirths, ["G1"])
	var again := WorldProgress.new(_profile())
	assert_true(again.is_attuned("G1"))
	assert_eq(again.rebirths, ["G1"])

func test_the_last_choice_defaults_to_the_cave_and_persists() -> void:
	var w := WorldProgress.new(_profile())
	assert_eq(w.last_choice(), {"pool": "C1", "species": "slime"})
	w.set_last_choice("G1")
	var again := WorldProgress.new(_profile())
	assert_eq(again.last_choice(), {"pool": "G1", "species": "slime"})

func test_species_is_saved_beside_the_choice() -> void:
	var w := WorldProgress.new(_profile())
	w.set_last_choice("C1", "spider")
	assert_eq(WorldProgress.new(_profile()).last_choice()["species"], "spider")

func test_sanitize_drops_unknown_pools_and_a_vanished_last_choice() -> void:
	var w := WorldProgress.new(_profile())
	w.attune("G1")
	w.attune("GONE")
	w.set_last_choice("GONE")
	w.sanitize(["C1", "G1"])
	assert_eq(w.rebirths, ["G1"])
	assert_eq(w.last_choice()["pool"], "C1", "falls back to the default")

func test_sanitize_keeps_a_valid_last_choice() -> void:
	var w := WorldProgress.new(_profile())
	w.attune("G1")
	w.set_last_choice("G1")
	w.sanitize(["C1", "G1"])
	assert_eq(w.last_choice()["pool"], "G1")

func test_a_malformed_rebirths_section_is_dropped_without_a_crash() -> void:
	var p := _profile()
	p.set_section("rebirths", 12)
	var w := WorldProgress.new(p)
	assert_eq(w.rebirths, [])
	var p2 := _profile()
	p2.set_section("rebirths", {"a": 1})
	assert_eq(WorldProgress.new(p2).rebirths, [])

func test_a_malformed_last_choice_falls_back() -> void:
	var p := _profile()
	p.set_section("rebirth_choice", [1, 2])
	assert_eq(WorldProgress.new(p).last_choice(), {"pool": "C1", "species": "slime"})
	var p2 := _profile()
	p2.set_section("rebirth_choice", {"pool": 7})
	assert_eq(WorldProgress.new(p2).last_choice()["pool"], "C1")

func test_take_pending_returns_it_once_and_clears_it() -> void:
	var w := WorldProgress.new(_profile())
	assert_eq(w.take_pending(), {})
	w.pending_start = {"pool": "G1", "species": "slime"}
	assert_eq(w.take_pending(), {"pool": "G1", "species": "slime"})
	assert_eq(w.take_pending(), {})

func test_every_progress_section_survives_one_round_trip_together() -> void:
	var p := _profile()
	var w := WorldProgress.new(p)
	w.visit("C1")
	w.open_shortcut("c6_drop")
	w.read_tablet("c6_tablet")
	w.attune("G1")
	w.set_last_choice("G1")
	var again := WorldProgress.new(_profile())
	assert_true(again.is_visited("C1"))
	assert_true(again.is_open("c6_drop"))
	assert_true(again.is_read("c6_tablet"))
	assert_true(again.is_attuned("G1"))
	assert_eq(again.last_choice()["pool"], "G1")

func test_without_a_profile_it_lives_in_memory() -> void:
	var w := WorldProgress.new()
	w.attune("G1")
	w.set_last_choice("G1")
	assert_true(w.is_attuned("G1"))
	assert_eq(w.last_choice()["pool"], "G1")
