extends GutTest

var skills: Array
var creatures: Array

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	creatures = DefLoader.load_dir("res://data/creatures")

func _skill(id: String) -> SkillDef:
	for d in skills:
		if d.id == id:
			return d
	return null

func _creature(id: String) -> CreatureDef:
	for c in creatures:
		if c.id == id:
			return c
	return null

func test_all_content_validates() -> void:
	assert_eq(skills.size(), 24)
	assert_eq(creatures.size(), 9)
	assert_eq(Array(DefValidator.validate(skills, creatures)), [])

func test_spec_numbers_are_verbatim() -> void:
	assert_eq(_skill("leap").unlock[0]["n"], 40)
	assert_eq(_skill("wall_cling").unlock[0]["n"], 15)
	assert_eq(_skill("poison_resistance").unlock[0]["n"], 6)
	assert_eq(_skill("pain_resistance").unlock[0]["n"], 2)
	assert_eq(_skill("toughness").unlock[0], {"kind": "counter", "event": "damaged",
		"tags": {"damage_type": "physical"}, "n": 20})
	assert_eq(_skill("glutton").unlock[0]["kind"], "reset_counter")
	assert_true(_skill("glutton").secret)
	assert_eq(_skill("echolocation").unlock[0]["n"], 3)
	assert_eq(_skill("poison_breath").unlock[0]["n"], 4)
	assert_eq(_skill("hydraulic_propulsion").unlock[0]["n"], 4)
	assert_eq(_skill("regeneration").unlock[0], {"kind": "counter", "event": "predated",
		"tags": {"kind": "creature"}, "n": 10})
	assert_eq(_skill("body_armor").max_level, 8)
	assert_eq(_skill("jet_dash").parent_ids(), ["hydraulic_propulsion", "leap"])
	assert_true(_skill("appraisal").starting)

func test_creature_numbers_are_verbatim() -> void:
	assert_eq(_creature("bat").stats, {"max_hp": 2, "atk": 3, "def": 0, "spd": 140})
	assert_eq(_creature("toad").essences, {"poison": 1, "water": 1})
	assert_eq(_creature("lizard").eat_bonus, {"stat": "def", "amount": 1, "per": 3})
	assert_eq(_creature("water_pool").essences, {"water": 2})
	assert_false(_creature("serpent").predatable)
	assert_false(_creature("serpent").appraisal_target)
	assert_eq(_creature("serpent").stats["max_hp"], 40)

func test_essence_minimums_satisfy_every_essence_skill() -> void:
	# Placement minimums from the spec: 3 bats, 4 toads, 3 lizards, 3 spiders, 2 pools.
	# The Grotto's creatures add spore and shell: 4 of each is 4 moths and 2 crabs.
	var minimums := {"bat": 3, "toad": 4, "lizard": 3, "spider": 3, "water_pool": 2, "spore_moth": 4, "mushroom_crab": 2}
	var totals := {}
	for sid in minimums:
		var c := _creature(sid)
		for ess in c.essences:
			totals[ess] = int(totals.get(ess, 0)) + int(c.essences[ess]) * minimums[sid]
	for d in skills:
		if d.source != "essence":
			continue
		for cond in d.unlock:
			if cond["event"] == "absorbed":
				assert_gte(int(totals.get(cond["tags"]["essence"], 0)), int(cond["n"]), d.id)
