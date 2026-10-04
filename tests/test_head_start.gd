extends GutTest
## The head start bought in the goddess's menu: which powers can be taken, what a cart costs, and the kit it makes.

var skills: Array
var compendium: CompendiumModel
var rules := SoulRules.new()

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	compendium = CompendiumModel.new(skills, DefLoader.load_dir("res://data/creatures"))

func _cart(levels: int, powers: Array = []) -> Dictionary:
	return {"levels": levels, "powers": powers}

func test_only_owned_once_base_powers_are_eligible() -> void:
	compendium.raise("leap", CompendiumModel.State.OWNED_ONCE)
	compendium.raise("water_blade", CompendiumModel.State.OWNED_ONCE)  # an evolution
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.NAMED)  # known, never owned
	compendium.raise("appraisal", CompendiumModel.State.OWNED_ONCE)  # the starting skill
	assert_eq(HeadStart.eligible_powers(compendium, skills), ["leap"])

func test_powers_are_sorted_by_display_name() -> void:
	var defs: Array = [TestDefs.skill("a_skill", {"display_name": "Zeta"}), TestDefs.skill("z_skill", {"display_name": "Alpha"})]
	var model := CompendiumModel.new(defs, [])
	model.raise("a_skill", CompendiumModel.State.OWNED_ONCE)
	model.raise("z_skill", CompendiumModel.State.OWNED_ONCE)
	assert_eq(HeadStart.eligible_powers(model, defs), ["z_skill", "a_skill"])

func test_price_sums_the_level_prices_and_powers() -> void:
	assert_eq(HeadStart.price(rules, _cart(0)), 0)
	assert_eq(HeadStart.price(rules, _cart(1)), 2)
	assert_eq(HeadStart.price(rules, _cart(3)), 9, "2 + 3 + 4")
	assert_eq(HeadStart.price(rules, _cart(9)), 14, "levels past the priced ones are capped")
	assert_eq(HeadStart.price(rules, _cart(-2)), 0)
	assert_eq(HeadStart.price(rules, _cart(0, ["leap", "poison_breath"])), 6)
	assert_eq(HeadStart.price(rules, _cart(3, ["leap", "poison_breath"])), 15)

func test_kit_has_only_the_keys_in_use() -> void:
	assert_eq(HeadStart.kit(_cart(0)), {})
	assert_eq(HeadStart.kit(_cart(2)), {"level": 3})
	assert_eq(HeadStart.kit(_cart(0, ["leap"])), {"skills": ["leap"]})
	assert_eq(HeadStart.kit(_cart(2, ["leap"])), {"skills": ["leap"], "level": 3})

func test_cheapest_is_the_least_for_sale() -> void:
	assert_eq(HeadStart.cheapest(rules, 0), 2, "the first level")
	assert_eq(HeadStart.cheapest(rules, 1), 2)
	var no_levels := SoulRules.new()
	no_levels.level_prices = []
	assert_eq(HeadStart.cheapest(no_levels, 1), 3, "a power is the only thing for sale")
	assert_eq(HeadStart.cheapest(no_levels, 0), -1, "nothing for sale")
