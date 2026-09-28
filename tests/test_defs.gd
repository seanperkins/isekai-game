extends GutTest

func test_listens_to_is_derived_from_unlock_and_levels_on() -> void:
	var d := TestDefs.skill("leap", {
		"unlock": [TestDefs.counter("jumped", 40)],
		"levels_on": {"event": "jumped", "tags": {}}, "level_curve": 40, "max_level": 5})
	assert_eq(d.listens_to(), ["jumped"])

func test_skill_level_conditions_listen_to_internal_events() -> void:
	var d := TestDefs.skill("jet_dash", {"source": "evolution",
		"unlock": [TestDefs.level("hydraulic_propulsion", 3), TestDefs.level("leap", 2)]})
	assert_eq(d.listens_to(), ["skill_unlocked", "skill_leveled"])
	assert_eq(d.parent_ids(), ["hydraulic_propulsion", "leap"])

func test_levels_on_event_is_added_once() -> void:
	var d := TestDefs.skill("poison_breath", {
		"unlock": [TestDefs.counter("absorbed", 4, {"essence": "poison"})],
		"levels_on": {"event": "skill_used", "tags": {"id": "poison_breath"}},
		"level_curve": 8, "max_level": 5})
	assert_eq(d.listens_to(), ["absorbed", "skill_used"])
	assert_eq(d.essences_used(), ["poison"])

func test_reset_counter_listens_to_its_counted_event() -> void:
	var d := TestDefs.skill("glutton", {"unlock": [TestDefs.reset_counter("predated", 5, "damaged", {"kind": "creature"})]})
	assert_eq(d.listens_to(), ["predated"])

func test_load_dir_returns_sorted_resources_and_empty_for_missing_dir() -> void:
	var dir := "user://gut_defs_%d" % randi()
	DirAccess.make_dir_recursive_absolute(dir)
	ResourceSaver.save(TestDefs.skill("b_skill"), dir.path_join("b_skill.tres"))
	ResourceSaver.save(TestDefs.skill("a_skill"), dir.path_join("a_skill.tres"))
	var loaded := DefLoader.load_dir(dir)
	assert_eq(loaded.size(), 2)
	assert_eq(loaded[0].id, "a_skill")
	assert_eq(DefLoader.load_dir("user://no_such_dir_%d" % randi()), [])
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
