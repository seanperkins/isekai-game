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

# --- Task 3: eating, the HUD and the altar ---

func test_eating_a_blood_creature_absorbs_blood() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	var player := Player.new()
	player.setup(rules, CompendiumModel.new(skills, creature_list), creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	var def: CreatureDef = (creature_list.filter(func(c: CreatureDef) -> bool: return c.id == "toad")[0] as CreatureDef).duplicate()
	def.essences = {"blood": 2}
	var toad := Enemy.new()
	toad.setup(def, by_id)
	add_child_autofree(toad)
	toad.global_position = Vector2(20, 0)
	toad.set_physics_process(false)
	toad.receive_tackle(1, true)
	player.begin_predate()
	player.process_predate(1.2)
	assert_eq(rules.held("blood"), 2)
	assert_eq(rules.held("fire"), 0)

func test_status_text_lists_a_later_element_once_it_is_held() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var compendium := CompendiumModel.new(skills, DefLoader.load_dir("res://data/creatures"))
	var stats := Stats.new({"max_hp": 30, "atk": 1, "def": 0, "spd": 100})
	_absorb("blood", 2)
	var text := "\n".join(StatusText.self_lines(stats, Health.new(30), rules, compendium, 2))
	assert_string_contains(text, "blood 2")
	assert_false(text.contains("fire"))

func _altar() -> AltarModel:
	var perk := PerkDef.new()
	perk.id = "stats"
	perk.display_name = "Stronger base stats"
	perk.price_base = 5
	perk.price_step = 3
	return AltarModel.new("C1", perk, WorldProgress.new(), SoulProgress.new(null, ["stats"]), SoulRules.new(), rules)

func _altar_kinds(m: AltarModel) -> Array:
	return m.rows().map(func(r: Dictionary) -> String: return r["kind"] if r["kind"] != "element" else r["element"])

func test_an_altar_shows_five_element_rows_until_a_later_one_is_held() -> void:
	var m := _altar()
	assert_eq(_altar_kinds(m), ["attune", "water", "earth", "air", "light", "dark", "perk"])
	_absorb("blood", 2)
	assert_eq(_altar_kinds(m), ["attune", "water", "earth", "air", "light", "dark", "blood", "perk"])

func test_banking_a_later_element_works_and_its_row_goes_when_empty() -> void:
	var m := _altar()
	var rate := SoulRules.new().bank_rate
	_absorb("blood", rate)
	m.move(6)
	assert_eq(m.rows()[6]["element"], "blood")
	m.adjust(1)
	assert_true(m.act(), m.message)
	assert_eq(rules.held("blood"), 0)
	assert_eq(_altar_kinds(m), ["attune", "water", "earth", "air", "light", "dark", "perk"])
	assert_lt(m.row(), m.rows().size(), "the highlighted row is still a row")
