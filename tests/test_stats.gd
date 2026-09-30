extends GutTest

func _lizard() -> CreatureDef:
	return TestDefs.creature("lizard", {"eat_bonus": {"stat": "def", "amount": 1, "per": 3}})

func _toad() -> CreatureDef:
	return TestDefs.creature("toad", {"eat_bonus": {"stat": "max_hp", "amount": 1}})

func test_final_value_is_base_plus_eat_plus_modifiers() -> void:
	var s := Stats.new({"max_hp": 30, "atk": 1, "def": 0, "spd": 100})
	s.apply_eat(_toad())
	s.set_modifiers("toughness", [{"stat": "max_hp", "op": "add", "value": 3}])
	assert_eq(s.get_stat("max_hp"), 34)
	assert_eq(s.get_stat("jump_height"), 100)
	assert_eq(s.get_stat("regen_interval"), 0)

func test_per_n_bonus_applies_on_the_nth_eat() -> void:
	var s := Stats.new({"def": 0})
	s.apply_eat(_lizard())
	s.apply_eat(_lizard())
	assert_eq(s.get_stat("def"), 0)
	s.apply_eat(_lizard())
	assert_eq(s.get_stat("def"), 1)

func test_eat_bonus_stops_at_cap_but_skill_modifiers_do_not() -> void:
	var s := Stats.new({"max_hp": 30})
	for i in 15:
		s.apply_eat(_toad())
	assert_eq(s.eat_bonus("max_hp"), 10)
	s.set_modifiers("toughness", [{"stat": "max_hp", "op": "add", "value": 15}])
	assert_eq(s.get_stat("max_hp"), 55)

func test_set_modifier_overrides_and_removal_restores() -> void:
	var s := Stats.new()
	s.set_modifiers("regeneration", [{"stat": "regen_interval", "op": "set", "value": 8}])
	assert_eq(s.get_stat("regen_interval"), 8)
	s.set_modifiers("regeneration", [])
	assert_eq(s.get_stat("regen_interval"), 0)

func test_reset_run_clears_eat_bonus_and_modifiers() -> void:
	var s := Stats.new({"max_hp": 30})
	s.apply_eat(_toad())
	s.set_modifiers("x", [{"stat": "max_hp", "op": "add", "value": 5}])
	s.reset_run()
	assert_eq(s.get_stat("max_hp"), 30)

func test_hit_percent_then_flat_then_floor_min_one() -> void:
	assert_eq(Damage.hit(4, "physical", 0, 20, 0), 3)    # 3.2 -> 3
	assert_eq(Damage.hit(4, "physical", 0, 80, 0), 1)    # 0.8 -> min 1
	assert_eq(Damage.hit(3, "physical", 0, 0, 5), 1)     # flat above the damage -> min 1
	assert_eq(Damage.hit(6, "physical", 0, 0, 1), 5)     # the flat argument, not DEF: DEF 1 would be the serpent row (4)
	assert_eq(Damage.hit(10, "physical", 0, 90, 0), 1)   # integer math, no 0.999 error

func test_tick_milli_takes_percent_only_in_thousandths() -> void:
	assert_eq(Damage.tick_milli(2, 0), 2000)
	assert_eq(Damage.tick_milli(2, 35), 1300)
	assert_eq(Damage.tick_milli(2, 65), 700, "not 0: the fraction is carried")
	assert_eq(Damage.tick_milli(10, 90), 1000)
	assert_eq(Damage.tick_milli(1, 20), 800)
	assert_eq(Damage.tick_milli(1, 30), 700, "Venom Blood")
	assert_eq(Damage.tick_milli(1, 100), 50, "clamped at 95%; a clamp of 100 would give 0")
