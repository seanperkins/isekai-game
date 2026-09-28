extends GutTest

const S := CompendiumModel.State

var engine: SkillRulesEngine
var model: CompendiumModel

func _defs() -> Array:
	return [
		TestDefs.skill("appraisal", {"starting": true,
			"levels_on": {"event": "inspected", "tags": {"first_time": true, "appraisal_target": true}},
			"level_curve": 2, "max_level": 4}),
		TestDefs.skill("leap", {"hint": "Your body remembers each leap.", "unlock": [TestDefs.counter("jumped", 40)]}),
		TestDefs.skill("pain", {"unlock": [TestDefs.counter("hp_low_exited", 2)]}),
		TestDefs.skill("glutton", {"secret": true, "unlock": [TestDefs.counter("predated", 4)]}),
		TestDefs.skill("echolocation", {"source": "essence", "hidden": false,
			"unlock": [TestDefs.counter("absorbed", 3, {"essence": "sound"})]}),
		TestDefs.skill("poison_resistance", {"unlock": [TestDefs.counter("damaged", 6, {"damage_type": "poison"})]}),
		TestDefs.skill("hydraulic_propulsion", {"source": "essence", "hidden": false,
			"unlock": [TestDefs.counter("absorbed", 4, {"essence": "water"})]}),
		TestDefs.skill("water_blade", {"source": "evolution", "unlock": [TestDefs.level("hydraulic_propulsion", 2)]}),
		TestDefs.skill("flight", {"source": "enemy_only"}),
	]

func _creatures() -> Array:
	var c := TestDefs.all_creatures()
	c[0].essences = {"sound": 1, "flight": 1}
	c[0].skills = [{"id": "echolocation", "level": 1}, {"id": "flight", "level": 1}]
	c[1].essences = {"poison": 1, "water": 1}
	c[1].skills = [{"id": "poison_resistance", "level": 2}]
	c[5].skills = [{"id": "water_blade", "level": 1}]  # serpent
	return c

func before_each() -> void:
	engine = autofree(SkillRulesEngine.new())
	engine.report_error = func(msg: String) -> void: fail_test(msg)
	engine.setup(_defs())
	model = CompendiumModel.new(_defs(), _creatures())
	engine.skill_unlocked.connect(model.on_skill_unlocked)
	engine.run_started.connect(func() -> void: model.on_run_started(engine))
	engine.inspect_processed.connect(func(t: Dictionary, lv: int) -> void: model.on_inspect_processed(t, lv, engine))
	engine.start_run()

func _inspect(target: String, first := true) -> void:
	engine.handle_event("inspected", {"target": target, "first_time": first,
		"appraisal_target": target != "serpent"})

func test_every_non_enemy_only_skill_has_a_slot() -> void:
	assert_true(model.states().has("leap"))
	assert_false(model.states().has("flight"))
	assert_eq(model.state("nope"), S.UNKNOWN)  # Review Focus 3

func test_states_only_ratchet_upward() -> void:
	assert_true(model.raise("leap", S.HINTED))
	assert_false(model.raise("leap", S.NAMED))
	assert_eq(model.state("leap"), S.HINTED)

func test_unlock_marks_owned_once_and_starting_skill_marked_on_run_started() -> void:
	assert_eq(model.state("appraisal"), S.OWNED_ONCE)
	for i in 40:
		engine.handle_event("jumped", {})
	assert_eq(model.state("leap"), S.OWNED_ONCE)

func test_lv1_creature_inspect_shows_name_and_hp_only() -> void:
	_inspect("bat")  # one distinct target so far: Appraisal stays Lv1
	var r := model.creature_report("bat", 1)
	assert_eq(r.keys(), ["id", "name", "hp"])
	assert_eq(model.state("echolocation"), S.UNKNOWN)

func test_lv2_creature_inspect_names_essence_skills_on_the_levelling_press() -> void:
	_inspect("self")
	_inspect("bat")  # second distinct target -> Lv2, and the reveal uses Lv2
	assert_eq(engine.level_of("appraisal"), 2)
	assert_eq(model.state("echolocation"), S.NAMED)
	var r := model.creature_report("bat", 2)
	assert_eq(r["essences"], {"sound": 1, "flight": 1})
	assert_true(r.has("eat_bonus"))

func test_lv3_creature_inspect_names_listed_skills_except_enemy_only_and_secret() -> void:
	for t in ["self", "bat", "toad", "lizard"]:
		_inspect(t)
	assert_eq(engine.level_of("appraisal"), 3)
	_inspect("toad", false)
	assert_eq(model.state("poison_resistance"), S.NAMED)
	assert_false(model.states().has("flight"))

func test_serpent_never_advances_appraisal_or_names_a_slot() -> void:
	for t in ["self", "bat", "toad", "lizard"]:
		_inspect(t)
	_inspect("serpent")
	assert_eq(engine.level_of("appraisal"), 3)
	assert_eq(model.state("water_blade"), S.UNKNOWN)
	assert_true(model.creature_report("serpent", 3).has("skills"))  # info still shown

func test_repeated_inspects_of_one_target_do_not_level_appraisal() -> void:
	for i in 5:
		_inspect("bat", i == 0)
	assert_eq(engine.level_of("appraisal"), 1)

func test_self_report_bands_hide_numbers_and_respect_ceil_half() -> void:
	for i in 19:
		engine.handle_event("jumped", {})
	var hints: Array = model.self_report(2, engine)["hints"]
	assert_eq(hints.filter(func(h): return h["id"] == "leap"), [])
	engine.handle_event("jumped", {})  # 20/40 = exactly half
	hints = model.self_report(2, engine)["hints"]
	var leap: Array = hints.filter(func(h): return h["id"] == "leap")
	assert_eq(leap.size(), 1)
	assert_eq(leap[0]["band"], "stirs")
	assert_false(leap[0].has("current"))
	for i in 12:
		engine.handle_event("jumped", {})  # 32/40 = 80%
	leap = model.self_report(2, engine)["hints"].filter(func(h): return h["id"] == "leap")
	assert_eq(leap[0]["band"], "close")

func test_self_report_never_lists_secret_skills() -> void:
	for i in 3:
		engine.handle_event("predated", {"kind": "creature"})
	var ids: Array = model.self_report(3, engine)["hints"].map(func(h): return h["id"])
	assert_false(ids.has("glutton"))

func test_self_inspect_applies_named_at_lv2_and_hinted_with_hint_at_lv3() -> void:
	for i in 20:
		engine.handle_event("jumped", {})
	model.self_report(2, engine, true)
	assert_eq(model.state("leap"), S.NAMED)
	var hints: Array = model.self_report(3, engine, true)["hints"]
	assert_eq(model.state("leap"), S.HINTED)
	assert_eq(hints.filter(func(h): return h["id"] == "leap")[0]["hint"], "Your body remembers each leap.")

func test_lv4_names_evolutions_whose_parents_are_owned() -> void:
	for i in 4:
		engine.handle_event("absorbed", {"essence": "water"})
	var evos: Array = model.self_report(4, engine, true)["evolutions"]
	assert_eq(evos.map(func(e): return e["id"]), ["water_blade"])
	assert_eq(model.state("water_blade"), S.NAMED)

func test_changes_are_saved_through_the_store() -> void:
	var dir := "user://gut_model_%d" % randi()
	var store := CompendiumStore.new(dir.path_join("compendium.json"))
	store.warn = func(msg: String) -> void: fail_test(msg)
	var m := CompendiumModel.new(_defs(), _creatures(), store)
	m.raise("leap", S.NAMED)
	var reloaded := CompendiumModel.new(_defs(), _creatures(), store)
	assert_eq(reloaded.state("leap"), S.NAMED)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

func test_saved_enemy_only_and_unknown_ids_are_dropped() -> void:
	var dir := "user://gut_model_%d" % randi()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("compendium.json"), FileAccess.WRITE)
	f.store_string('{"version": 1, "slots": {"flight": "named", "removed_skill": "hinted", "leap": "named"}}')
	f.close()
	var m := CompendiumModel.new(_defs(), _creatures(), CompendiumStore.new(dir.path_join("compendium.json")))
	assert_false(m.states().has("flight"))
	assert_false(m.states().has("removed_skill"))
	assert_eq(m.state("leap"), S.NAMED)
	for fn in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(fn))
	DirAccess.remove_absolute(dir)
