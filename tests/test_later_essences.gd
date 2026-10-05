extends GutTest
## Fire, mind and blood: the three elements no shipped creature carries yet. They validate, they are absorbed and counted, and
## they show in the HUD and at an altar once held.

var rules: SkillRulesEngine

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(DefLoader.load_dir("res://data/skills"))
	rules.start_run()

func _absorb(element: String, n: int) -> void:
	for i in n:
		rules.handle_event("absorbed", {"essence": element, "source": "test"})

# --- Task 1: the vocabulary ---

func test_the_vocabulary_is_eight_elements_in_canonical_order() -> void:
	assert_eq(Essences.ALL, ["water", "earth", "air", "light", "dark", "fire", "mind", "blood"])
	assert_eq(Essences.FIRST_PASS, ["water", "earth", "air", "light", "dark"])
	assert_eq(Essences.LATER, ["fire", "mind", "blood"])

func test_a_creature_may_carry_a_later_element() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creatures := DefLoader.load_dir("res://data/creatures")
	creatures[0] = (creatures[0] as CreatureDef).duplicate()  # load_dir hands out cached resources: never edit one in place
	(creatures[0] as CreatureDef).essences = {"blood": 2}
	assert_eq(Array(DefValidator.validate(skills, creatures)), [])

func test_a_skill_may_unlock_on_a_later_element() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	skills.append(TestDefs.skill("test_fire", {"unlock": [TestDefs.counter("absorbed", 3, {"essence": "fire"})]}))
	assert_eq(Array(DefValidator.validate(skills, DefLoader.load_dir("res://data/creatures"))), [])

func test_an_unknown_element_is_still_refused() -> void:
	var creatures := DefLoader.load_dir("res://data/creatures")
	creatures[0] = (creatures[0] as CreatureDef).duplicate()
	(creatures[0] as CreatureDef).essences = {"ether": 1}
	var errors := "\n".join(DefValidator.validate(DefLoader.load_dir("res://data/skills"), creatures))
	assert_string_contains(errors, "unknown essence 'ether'")

# --- Task 2: SkillRulesEngine.absorbed ---

func test_absorbed_counts_every_element_including_the_later_ones() -> void:
	_absorb("mind", 3)
	assert_eq(rules.absorbed("mind"), 3)
	assert_eq(rules.held("mind"), 3)
	assert_eq(rules.absorbed("fire"), 0)

func test_absorbed_never_goes_down_when_essence_is_spent() -> void:
	_absorb("blood", 4)
	assert_true(rules.spend_essence("blood", 3))
	assert_eq(rules.held("blood"), 1)
	assert_eq(rules.absorbed("blood"), 4)
