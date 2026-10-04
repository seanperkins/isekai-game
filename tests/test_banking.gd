extends GutTest
## Banking: held essence becomes soul points at a flat rate, whatever the element.

var rules: SkillRulesEngine
var soul: SoulProgress
var soul_rules := SoulRules.new()

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	rules.start_run()
	soul = SoulProgress.new()

func _absorb(element: String, n: int) -> void:
	for i in n:
		rules.handle_event("absorbed", {"essence": element, "source": "test"})

func test_max_units_rounds_down_to_the_rate() -> void:
	_absorb("water", 27)
	_absorb("dark", 9)
	assert_eq(Banking.max_units(soul_rules, rules, "water"), 20)
	assert_eq(Banking.max_units(soul_rules, rules, "dark"), 0)
	assert_eq(Banking.max_units(soul_rules, rules, "earth"), 0, "nothing held")

func test_bank_converts_at_the_flat_rate() -> void:
	_absorb("water", 27)
	assert_eq(Banking.bank(soul_rules, rules, soul, "water", 20), 2)
	assert_eq(soul.total_points(), 2)
	assert_eq(rules.held("water"), 7)

func test_any_element_banks_at_the_same_rate() -> void:
	_absorb("dark", 10)
	_absorb("earth", 10)
	assert_eq(Banking.bank(soul_rules, rules, soul, "dark", 10), 1)
	assert_eq(Banking.bank(soul_rules, rules, soul, "earth", 10), 1)
	assert_eq(soul.total_points(), 2)

func test_bank_refuses_what_it_cannot_do_and_spends_nothing() -> void:
	_absorb("water", 27)
	for units in [15, 30, 0, -10]:
		assert_eq(Banking.bank(soul_rules, rules, soul, "water", units), 0, "units %d" % units)
	assert_eq(rules.held("water"), 27)
	assert_eq(soul.total_points(), 0)

func test_banking_changes_what_an_evolution_can_afford() -> void:
	_absorb("water", 12)
	assert_true(rules.can_afford("water_blade"))
	Banking.bank(soul_rules, rules, soul, "water", 10)
	assert_false(rules.can_afford("water_blade"), "2 water is left of the 6 the evolution costs")
