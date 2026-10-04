extends GutTest
## The price of evolving a power, in held essence: what a price reads, what is held, what can be afforded.

var rules: SkillRulesEngine
var skills_by_id := {}

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	for d in skills:
		skills_by_id[d.id] = d
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	rules.start_run()

func _absorb(element: String, n: int) -> void:
	for i in n:
		rules.handle_event("absorbed", {"essence": element, "source": "test"})

func test_the_four_base_powers_carry_the_prices_the_spec_starts_with() -> void:
	assert_eq(skills_by_id["hydraulic_propulsion"].evolution_price, {"water": 6})
	assert_eq(skills_by_id["poison_breath"].evolution_price, {"water": 6, "dark": 10})
	assert_eq(skills_by_id["spore_cloud"].evolution_price, {"air": 6, "dark": 12})
	assert_eq(skills_by_id["sticky_thread"].evolution_price, {"dark": 14})

func test_branches_read_their_parents_price() -> void:
	assert_eq(rules.evolution_price("water_blade"), {"water": 6})
	assert_eq(rules.evolution_price("jet_dash"), {"water": 6})
	assert_eq(rules.evolution_price("miasma"), rules.evolution_price("venom_bolt"))
	assert_eq(rules.evolution_price("leap"), {}, "a skill with no parent has no price")
	assert_eq(rules.evolution_price("nope"), {})

func test_held_is_what_was_absorbed() -> void:
	_absorb("water", 9)
	assert_eq(rules.held("water"), 9)
	assert_eq(rules.held("dark"), 0)

func test_can_afford_turns_true_when_every_element_of_the_price_is_held() -> void:
	_absorb("water", 6)
	_absorb("dark", 9)
	assert_false(rules.can_afford("miasma"), "dark 9 of 10")
	_absorb("dark", 1)
	assert_true(rules.can_afford("miasma"))

func test_can_afford_does_not_survive_a_new_life_at_the_same_ledger_size() -> void:
	_absorb("water", 8)
	assert_true(rules.can_afford("water_blade"))
	rules.start_run()
	_absorb("earth", 8)  # the same ledger size, none of the essence
	assert_false(rules.can_afford("water_blade"))

func _ready_poison_breath() -> void:
	TestDefs.satisfy(rules, "poison_breath")  # water 4, dark 4
	for i in 24:
		rules.handle_event("skill_used", {"id": "poison_breath"})  # Lv4: Miasma and Venom Bolt are ready together

func test_evolve_pays_exactly_the_price_and_leaves_the_recipe_counted() -> void:
	_ready_poison_breath()
	_absorb("water", 2)
	_absorb("dark", 6)
	var eaten_water := rules.count("absorbed", {"essence": "water"})
	assert_true(rules.can_afford("miasma"))
	assert_true(rules.evolve("miasma"))
	assert_eq(rules.held("water"), 0)
	assert_eq(rules.held("dark"), 0)
	assert_eq(rules.count("absorbed", {"essence": "water"}), eaten_water, "spending never undoes what was eaten")
	assert_gt(rules.level_of("poison_breath"), 0, "the parent keeps the level it reached")

func test_evolve_refuses_when_the_price_is_not_held_and_spends_nothing() -> void:
	_ready_poison_breath()
	assert_true(rules.is_evolution_ready("miasma"))
	assert_false(rules.can_afford("miasma"))
	assert_false(rules.evolve("miasma"))
	assert_eq(rules.held("water"), 4)
	assert_eq(rules.held("dark"), 4)
	assert_true(rules.is_evolution_ready("miasma"), "still ready, just not affordable")

func test_taking_one_branch_pays_once_and_closes_the_other() -> void:
	TestDefs.satisfy(rules, "hydraulic_propulsion")  # water 8
	for i in 12:
		rules.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	assert_true(rules.evolve("water_blade"))
	assert_eq(rules.held("water"), 2, "8 absorbed, 6 paid")
	assert_false(rules.evolve("jet_dash"), "closed: its sibling was taken")
	assert_eq(rules.held("water"), 2, "a refused evolve spends nothing")

func test_a_new_life_holds_nothing() -> void:
	_absorb("water", 8)
	rules.start_run()
	assert_eq(rules.held("water"), 0)
