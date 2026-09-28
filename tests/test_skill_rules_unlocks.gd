extends GutTest

var engine: SkillRulesEngine
var unlocked: Array
var now := 0.0

func _make(defs: Array) -> void:
	engine = autofree(SkillRulesEngine.new())
	engine.clock = func() -> float: return now
	engine.report_error = func(msg: String) -> void: fail_test("unexpected engine error: " + msg)
	engine.setup(defs)
	unlocked = []
	engine.skill_unlocked.connect(func(id: String) -> void: unlocked.append(id))

func _leap() -> SkillDef:
	return TestDefs.skill("leap", {"unlock": [TestDefs.counter("jumped", 3)]})

func test_unlocks_at_n_and_not_at_n_minus_one() -> void:
	_make([_leap()])
	engine.start_run()
	engine.handle_event("jumped", {})
	engine.handle_event("jumped", {})
	assert_eq(engine.level_of("leap"), 0)
	engine.handle_event("jumped", {})
	assert_eq(engine.level_of("leap"), 1)
	assert_eq(unlocked, ["leap"])

func test_each_skill_unlocks_exactly_once() -> void:
	_make([_leap()])
	engine.start_run()
	for i in 10:
		engine.handle_event("jumped", {})
	assert_eq(unlocked, ["leap"])

func test_events_are_ignored_while_run_inactive() -> void:
	_make([_leap()])
	for i in 5:
		engine.handle_event("jumped", {})
	engine.start_run()
	assert_eq(engine.level_of("leap"), 0)
	engine.reset_run()
	assert_false(engine.run_active)
	for i in 5:
		engine.handle_event("jumped", {})
	assert_eq(engine.owned(), [])

func test_start_run_grants_starting_skills_silently() -> void:
	_make([TestDefs.skill("appraisal", {"starting": true}), _leap()])
	var started := [0]
	engine.run_started.connect(func() -> void: started[0] += 1)
	engine.start_run()
	assert_eq(engine.level_of("appraisal"), 1)
	assert_eq(unlocked, [])
	assert_eq(started[0], 1)
	assert_true(engine.run_active)

func test_start_run_twice_is_a_clean_fresh_run() -> void:
	# Review Focus 4
	_make([TestDefs.skill("appraisal", {"starting": true}), _leap()])
	var started := [0]
	engine.run_started.connect(func() -> void: started[0] += 1)
	engine.start_run()
	for i in 3:
		engine.handle_event("jumped", {})
	engine.start_run()
	assert_eq(engine.owned(), ["appraisal"])
	assert_eq(started[0], 2)
	assert_eq(engine.unlock_log(), [])

func test_reset_run_clears_counters_and_owned() -> void:
	_make([_leap()])
	engine.start_run()
	for i in 3:
		engine.handle_event("jumped", {})
	engine.reset_run()
	engine.start_run()
	engine.handle_event("jumped", {})
	assert_eq(engine.level_of("leap"), 0)

func test_rules_are_only_evaluated_for_events_they_listen_to() -> void:
	var d := TestDefs.skill("leap", {"unlock": [TestDefs.counter("jumped", 1)]})
	_make([d])
	engine.start_run()
	engine.handle_event("wall_touched", {})
	engine.handle_event("damaged", {"damage_type": "poison"})
	assert_eq(engine.level_of("leap"), 0)
	assert_eq(engine._listeners.get("wall_touched", []).size(), 0)
	assert_eq(engine._listeners.get("jumped", []).size(), 1)

func test_enemy_only_defs_are_never_loaded() -> void:
	_make([TestDefs.skill("flight", {"source": "enemy_only"}), _leap()])
	assert_null(engine.get_def("flight"))
	assert_not_null(engine.get_def("leap"))

func test_unlock_log_records_run_time() -> void:
	_make([_leap()])
	now = 100.0
	engine.start_run()
	now = 112.5
	for i in 3:
		engine.handle_event("jumped", {})
	assert_eq(engine.unlock_log(), [{"id": "leap", "run_time_s": 12.5}])

func test_all_unlock_conditions_are_required() -> void:
	_make([TestDefs.skill("both", {"unlock": [TestDefs.counter("jumped", 1), TestDefs.counter("wall_touched", 1)]})])
	engine.start_run()
	engine.handle_event("jumped", {})
	assert_eq(engine.level_of("both"), 0)
	engine.handle_event("wall_touched", {})
	assert_eq(engine.level_of("both"), 1)

func test_reset_counter_streak_breaks_on_reset_event() -> void:
	_make([TestDefs.skill("glutton", {"unlock": [TestDefs.reset_counter("predated", 3, "damaged", {"kind": "creature"})]})])
	engine.start_run()
	engine.handle_event("predated", {"kind": "creature"})
	engine.handle_event("predated", {"kind": "creature"})
	engine.handle_event("damaged", {"damage_type": "physical"})
	engine.handle_event("predated", {"kind": "creature"})
	engine.handle_event("predated", {"kind": "terrain"})
	engine.handle_event("predated", {"kind": "creature"})
	assert_eq(engine.level_of("glutton"), 0)
	engine.handle_event("predated", {"kind": "creature"})
	assert_eq(engine.level_of("glutton"), 1)

func test_queries_for_unknown_ids_are_safe() -> void:
	# Review Focus 3
	_make([_leap()])
	assert_eq(engine.level_of("nope"), 0)
	assert_null(engine.get_def("nope"))
