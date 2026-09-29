extends GutTest

var engine: SkillRulesEngine
var errors: Array

func _make(defs: Array) -> void:
	engine = autofree(SkillRulesEngine.new())
	errors = []
	engine.report_error = func(msg: String) -> void: errors.append(msg)
	engine.setup(defs)
	engine.start_run()

func _appraisal() -> SkillDef:
	return TestDefs.skill("appraisal", {"starting": true,
		"levels_on": {"event": "inspected", "tags": {"first_time": true, "appraisal_target": true}},
		"level_curve": 2, "max_level": 4})

func test_progress_reports_least_complete_condition() -> void:
	_make([TestDefs.skill("both", {"unlock": [TestDefs.counter("jumped", 40), TestDefs.counter("wall_touched", 10)]})])
	for i in 30:
		engine.handle_event("jumped", {})
	for i in 2:
		engine.handle_event("wall_touched", {})
	assert_eq(engine.progress("both"), {"current": 2, "target": 10})

func test_progress_caps_current_and_handles_unknown_ids() -> void:
	_make([TestDefs.skill("leap", {"unlock": [TestDefs.counter("jumped", 3)]})])
	for i in 5:
		engine.handle_event("jumped", {})
	assert_eq(engine.progress("leap"), {"current": 3, "target": 3})
	assert_eq(engine.progress("nope"), {"current": 0, "target": 0})  # Review Focus 3

func test_inspect_processed_uses_level_after_the_inspect() -> void:
	_make([_appraisal()])
	var seen: Array = []
	engine.inspect_processed.connect(func(tags: Dictionary, lv: int) -> void: seen.append([tags["target"], lv]))
	engine.handle_event("inspected", {"target": "self", "first_time": true, "appraisal_target": true})
	engine.handle_event("inspected", {"target": "bat", "first_time": true, "appraisal_target": true})
	engine.handle_event("inspected", {"target": "bat", "first_time": false, "appraisal_target": true})
	engine.handle_event("inspected", {"target": "serpent", "first_time": true, "appraisal_target": false})
	assert_eq(seen, [["self", 1], ["bat", 2], ["bat", 2], ["serpent", 2]])

func test_work_queue_cap_reports_and_stops() -> void:
	var loop := TestDefs.skill("loop", {"unlock": [TestDefs.counter("jumped", 1)],
		"levels_on": {"event": "wall_touched", "tags": {}}, "level_curve": 1, "max_level": 1000})
	_make([loop])
	engine.set_stage_cap(1000)  # the stage cap would otherwise stop the runaway chain before the queue limit
	engine.skill_leveled.connect(func(_id: String, _lv: int) -> void: engine.handle_event("wall_touched", {}))
	engine.handle_event("jumped", {})
	engine.handle_event("wall_touched", {})
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "exceeded 64 iterations")
	assert_lt(engine.level_of("loop"), 1000)

func test_events_emitted_by_handlers_are_queued_not_recursed() -> void:
	var a := TestDefs.skill("a", {"unlock": [TestDefs.counter("jumped", 1)]})
	var b := TestDefs.skill("b", {"unlock": [TestDefs.counter("wall_touched", 1)]})
	var c := TestDefs.skill("c", {"unlock": [TestDefs.level("a", 1)]})  # non-evolution: unlocks on its own
	_make([a, b, c])
	var order: Array = []
	engine.skill_unlocked.connect(func(id: String) -> void:
		order.append(id)
		if id == "a":
			engine.handle_event("wall_touched", {}))
	engine.handle_event("jumped", {})
	# c (child of a) was queued before the handler's wall_touched, so it is processed first.
	assert_eq(order, ["a", "c", "b"])
	assert_eq(errors, [])
