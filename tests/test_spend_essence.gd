extends GutTest
## Spending held essence outside an evolution: what is written, and what is refused.

var rules: SkillRulesEngine

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	rules.start_run()

func _absorb(element: String, n: int) -> void:
	for i in n:
		rules.handle_event("absorbed", {"essence": element, "source": "test"})

func test_spend_lowers_held_by_exactly_the_units() -> void:
	_absorb("water", 7)
	assert_true(rules.spend_essence("water", 3))
	assert_eq(rules.held("water"), 4)
	assert_eq(rules.held("dark"), 0)

func test_spend_refuses_more_than_held_and_writes_nothing() -> void:
	_absorb("water", 2)
	assert_false(rules.spend_essence("water", 3))
	assert_eq(rules.held("water"), 2)
	assert_eq(rules.count(SkillRulesEngine.ESSENCE_SPENT), 0)

func test_spend_refuses_zero_negative_and_an_inactive_run() -> void:
	_absorb("water", 5)
	assert_false(rules.spend_essence("water", 0))
	assert_false(rules.spend_essence("water", -1))
	assert_eq(rules.held("water"), 5)
	rules.reset_run()
	assert_false(rules.spend_essence("water", 1))

func test_spending_makes_an_evolution_unaffordable() -> void:
	_absorb("water", 12)
	assert_true(rules.can_afford("water_blade"))
	assert_true(rules.spend_essence("water", 10))
	assert_false(rules.can_afford("water_blade"), "the afford memo must follow the ledger")
