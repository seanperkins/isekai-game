extends GutTest

var engine: SkillRulesEngine
var log: Array

func _make(defs: Array) -> void:
	engine = autofree(SkillRulesEngine.new())
	engine.report_error = func(msg: String) -> void: fail_test("unexpected engine error: " + msg)
	engine.setup(defs)
	log = []
	engine.skill_unlocked.connect(func(id: String) -> void: log.append("unlock:" + id))
	engine.skill_leveled.connect(func(id: String, lv: int) -> void: log.append("level:%s:%d" % [id, lv]))
	engine.start_run()

func _leap() -> SkillDef:
	return TestDefs.skill("leap", {"unlock": [TestDefs.counter("jumped", 40)],
		"levels_on": {"event": "jumped", "tags": {}}, "level_curve": 40, "max_level": 5})

func _jump(n: int) -> void:
	for i in n:
		engine.handle_event("jumped", {})

func test_level_baseline_counts_from_unlock() -> void:
	_make([_leap()])
	_jump(40)
	assert_eq(engine.level_of("leap"), 1)
	_jump(39)
	assert_eq(engine.level_of("leap"), 1)
	_jump(1)
	assert_eq(engine.level_of("leap"), 2)

func test_unlock_emits_only_skill_unlocked() -> void:
	_make([_leap()])
	_jump(40)
	assert_eq(log, ["unlock:leap"])

func test_levelling_stops_at_max_level() -> void:
	_make([_leap()])
	_jump(40 + 40 * 10)
	assert_eq(engine.level_of("leap"), 5)
	assert_eq(log.filter(func(e): return e.begins_with("level:")).size(), 4)

func test_prior_events_do_not_prelevel_a_late_unlock() -> void:
	# Body Armor unlocked after 30 hits starts at Lv1.
	var armor := TestDefs.skill("body_armor", {
		"unlock": [TestDefs.counter("absorbed", 3, {"essence": "armor"})],
		"levels_on": {"event": "damaged", "tags": {}}, "level_curve": 10, "max_level": 3})
	_make([armor])
	for i in 30:
		engine.handle_event("damaged", {"damage_type": "physical"})
	for i in 3:
		engine.handle_event("absorbed", {"essence": "armor", "source": "lizard"})
	assert_eq(engine.level_of("body_armor"), 1)
	for i in 10:
		engine.handle_event("damaged", {"damage_type": "physical"})
	assert_eq(engine.level_of("body_armor"), 2)

func test_evolution_unlocks_from_parent_level_and_parent_is_announced_first() -> void:
	var hydro := TestDefs.skill("hydraulic_propulsion", {"source": "essence",
		"unlock": [TestDefs.counter("absorbed", 4, {"essence": "water"})],
		"levels_on": {"event": "skill_used", "tags": {"id": "hydraulic_propulsion"}}, "level_curve": 6, "max_level": 5})
	var blade := TestDefs.skill("water_blade", {"source": "evolution",
		"unlock": [TestDefs.level("hydraulic_propulsion", 2)]})
	_make([blade, hydro])  # listener order must not matter
	for i in 4:
		engine.handle_event("absorbed", {"essence": "water", "source": "water_pool"})
	for i in 6:
		engine.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	assert_eq(log, ["unlock:hydraulic_propulsion", "level:hydraulic_propulsion:2", "unlock:water_blade"])

func test_two_parent_evolution_needs_both() -> void:
	var leap := _leap()
	var hydro := TestDefs.skill("hydraulic_propulsion", {"source": "essence",
		"unlock": [TestDefs.counter("absorbed", 1, {"essence": "water"})],
		"levels_on": {"event": "skill_used", "tags": {"id": "hydraulic_propulsion"}}, "level_curve": 1, "max_level": 5})
	var dash := TestDefs.skill("jet_dash", {"source": "evolution",
		"unlock": [TestDefs.level("hydraulic_propulsion", 3), TestDefs.level("leap", 2)]})
	_make([leap, hydro, dash])
	engine.handle_event("absorbed", {"essence": "water"})
	engine.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	engine.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	assert_eq(engine.level_of("jet_dash"), 0)
	_jump(80)
	assert_eq(engine.level_of("jet_dash"), 1)
