extends GutTest

func test_engine_count_reads_this_runs_ledger() -> void:
	var e: SkillRulesEngine = autofree(SkillRulesEngine.new())
	e.setup([])
	e.start_run()
	e.handle_event("absorbed", {"essence": "poison", "source": "toad"})
	e.handle_event("absorbed", {"essence": "water", "source": "toad"})
	assert_eq(e.count("absorbed", {"essence": "poison"}), 1)
	assert_eq(e.count("absorbed"), 2)
	e.reset_run()
	assert_eq(e.count("absorbed"), 0)

func test_stats_split_base_eat_and_skill() -> void:
	var s := Stats.new({"def": 1})
	s.apply_eat(TestDefs.creature("lizard", {"eat_bonus": {"stat": "def", "amount": 1, "per": 1}}))
	s.set_modifiers("body_armor", [{"stat": "def", "op": "add", "value": 2}])
	assert_eq(s.get_stat("def"), 4)
	assert_eq(s.base("def"), 1)
	assert_eq(s.eat_bonus("def"), 1)
	assert_eq(s.skill_bonus("def"), 2)
	s.clear_modifiers()
	assert_eq(s.get_stat("def"), 2)
	assert_eq(s.eat_bonus("def"), 1)

func test_controls_register_every_action() -> void:
	Controls.ensure_actions()
	for action in ["move_left", "move_right", "jump", "tackle", "predate", "inspect", "active_1", "active_2", "active_3", "active_4", "aim_up", "aim_down"]:
		assert_true(InputMap.has_action(action), action)
		assert_gt(InputMap.action_get_events(action).size(), 0, action)
	Controls.ensure_actions()  # idempotent
	assert_eq(InputMap.action_get_events("tackle").size(), 2)  # J + gamepad X
