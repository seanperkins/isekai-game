extends GutTest
## Evolutions replace their parent, and taking one branch closes its siblings.

var engine: SkillRulesEngine
var leveled: Array
var readied: Array

func _hydro() -> SkillDef:
	return TestDefs.skill("hydraulic_propulsion", {"source": "essence",
		"unlock": [TestDefs.counter("absorbed", 1, {"essence": "water"})],
		"levels_on": {"event": "skill_used", "tags": {"id": "hydraulic_propulsion"}}, "level_curve": 2, "max_level": 8})

func _evo(id: String, extra := {}) -> SkillDef:
	var f := {"source": "evolution", "replaces": "hydraulic_propulsion", "unlock": [TestDefs.level("hydraulic_propulsion", 2)]}
	f.merge(extra, true)
	return TestDefs.skill(id, f)

func _make() -> void:
	engine = autofree(SkillRulesEngine.new())
	engine.report_error = func(msg: String) -> void: fail_test("unexpected engine error: " + msg)
	engine.setup([_evo("dash"), _evo("blade"), _hydro()])  # listener order must not matter
	leveled = []
	readied = []
	engine.skill_leveled.connect(func(id: String, lv: int) -> void: leveled.append("%s:%d" % [id, lv]))
	engine.evolution_ready.connect(func(id: String) -> void: readied.append(id))
	engine.start_run()

func _reach_level_2() -> void:
	engine.handle_event("absorbed", {"essence": "water"})
	for i in 2:
		engine.handle_event("skill_used", {"id": "hydraulic_propulsion"})

func test_both_branches_become_ready_together() -> void:
	_make()
	_reach_level_2()
	assert_eq(engine.ready_evolutions().size(), 2)
	assert_true(engine.is_evolution_ready("blade") and engine.is_evolution_ready("dash"))
	assert_eq(engine.siblings_of("blade"), ["dash"])

func test_evolving_retires_the_parent_and_hides_it_from_owned() -> void:
	_make()
	_reach_level_2()
	assert_true(engine.evolve("blade"))
	assert_true(engine.owned().has("blade"))
	assert_false(engine.owned().has("hydraulic_propulsion"))
	assert_true(engine.is_retired("hydraulic_propulsion"))
	assert_eq(engine.level_of("hydraulic_propulsion"), 2, "level_of is the level reached")

func test_evolving_closes_the_siblings() -> void:
	_make()
	_reach_level_2()
	readied.clear()
	assert_true(engine.evolve("blade"))
	assert_true(engine.is_closed("dash"))
	assert_false(engine.is_closed("blade"))
	assert_false(engine.is_evolution_ready("dash"))
	assert_eq(engine.ready_evolutions(), [])
	assert_false(engine.evolve("dash"))
	assert_eq(readied, [], "no evolution_ready is emitted for the sibling during evolve()")

func test_a_retired_parent_does_not_level_through_recheck_levels() -> void:
	_make()
	engine.set_stage_cap(2)
	engine.handle_event("absorbed", {"essence": "water"})
	for i in 12:  # banks casts well past the cap: capped at level 2
		engine.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	assert_eq(engine.level_of("hydraulic_propulsion"), 2)
	assert_true(engine.evolve("blade"))
	var gained := [-1]
	engine.rechecked.connect(func(n: int) -> void: gained[0] = n)
	leveled.clear()
	engine.set_stage_cap(5)  # what advance_form does, then recheck_levels()
	engine.recheck_levels()
	assert_eq(leveled, [], "the retired parent must not level")
	assert_eq(gained[0], 0)
	engine.handle_event("skill_used", {"id": "blade"})  # and one more cast does not catch it up either
	assert_eq(leveled, [])
	assert_eq(engine.level_of("hydraulic_propulsion"), 2)

func test_grant_refuses_an_evolution() -> void:
	_make()
	assert_false(engine.grant("blade"))
	assert_false(engine.grant("blade", false))
	assert_false(engine.owned().has("blade"))

func test_a_retired_parent_is_not_granted_again() -> void:
	_make()
	_reach_level_2()
	engine.evolve("blade")
	assert_false(engine.grant("hydraulic_propulsion"))
	engine.handle_event("absorbed", {"essence": "water"})
	assert_false(engine.owned().has("hydraulic_propulsion"))

func test_start_run_reopens_every_branch() -> void:
	_make()
	_reach_level_2()
	engine.evolve("blade")
	engine.start_run()
	assert_eq(engine.owned(), [])
	assert_false(engine.is_closed("dash"))
	assert_false(engine.is_retired("hydraulic_propulsion"))
