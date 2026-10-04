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
	assert_eq(skills.size(), 32)
	assert_eq(creatures.size(), 19)
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
	assert_eq(_skill("echolocation").unlock[0], {"kind": "counter", "event": "absorbed", "tags": {"essence": "air"}, "n": 6})
	assert_eq(_skill("poison_breath").unlock.size(), 2, "poison is water and dark")
	assert_eq(_skill("poison_breath").unlock[0]["n"], 4)
	assert_eq(_skill("hydraulic_propulsion").unlock[0], {"kind": "counter", "event": "absorbed", "tags": {"essence": "water"}, "n": 8})
	assert_eq(_skill("sticky_thread").unlock[0], {"kind": "counter", "event": "predated", "tags": {"source": "spider"}, "n": 3})
	assert_eq(_skill("regeneration").unlock[0], {"kind": "counter", "event": "predated",
		"tags": {"kind": "creature"}, "n": 10})
	assert_eq(_skill("body_armor").max_level, 8)
	assert_eq(_skill("jet_dash").parent_ids(), ["hydraulic_propulsion"])
	assert_true(_skill("appraisal").starting)

func test_creature_numbers_are_verbatim() -> void:
	assert_eq(_creature("bat").stats, {"max_hp": 2, "atk": 3, "def": 0, "spd": 140})
	assert_eq(_creature("toad").essences, {"water": 2, "dark": 1})
	assert_eq(_creature("lizard").eat_bonus, {"stat": "def", "amount": 1, "per": 3})
	assert_eq(_creature("water_pool").essences, {"water": 2})
	assert_false(_creature("serpent").predatable)
	assert_false(_creature("serpent").appraisal_target)
	assert_eq(_creature("serpent").stats["max_hp"], 40)

func test_essence_minimums_satisfy_every_essence_skill() -> void:
	# Placement minimums from the spec: 3 bats, 4 toads, 3 lizards, 3 spiders, 2 pools.
	# The Grotto's creatures add air and dark (4 moths) and earth (2 crabs). The Flooded adds light (4 eels) and earth (5 crayfish
	# and 6 lizardmen, a unit each). The Deep adds the rest of Tremor's earth: its census is 9 wolves, 9 ants and 3 drakes.
	var minimums := {"bat": 3, "toad": 4, "lizard": 3, "spider": 3, "water_pool": 2, "spore_moth": 4, "mushroom_crab": 2, "glass_eel": 4,
		"cave_crayfish": 5, "bog_lizardman": 6, "gloom_wolf": 9, "armed_ant": 9, "stone_drake": 3}
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
			elif cond["event"] == "predated" and cond.get("tags", {}).has("source"):
				assert_gte(int(minimums.get(cond["tags"]["source"], 0)), int(cond["n"]), "%s: eats of %s" % [d.id, cond["tags"]["source"]])

func _creature_map() -> Dictionary:
	var out := {}
	for c in creatures:
		out[c.id] = c
	return out

## The Cave-start unlock points before the element vocabulary: the eat, counting from 1, over every spawn of the shipped rooms
## (area order cave, grotto, flooded, deep; room-id order within an area; the jelly, which a tackle cannot down, is skipped).
## The calibration holds each within one eat. Spore Cloud was 28 (the fourth Grotto moth); the Cave's bats and toads now meet air 8
## and dark 4 first, a deliberate move the design accepted, pinned below.
const CAVE_START_BEFORE := {"body_armor": 13, "echolocation": 3, "hardened_shell": 27, "hydraulic_propulsion": 7, "jolt": 57,
	"poison_breath": 7, "regeneration": 11, "sticky_thread": 14, "tremor": 73}
const SPORE_CLOUD_NOW := 16

func test_every_power_unlocks_within_one_eat_of_where_it_did_on_a_cave_start() -> void:
	var points := CalibrationWalk.unlock_points(skills, _creature_map(), ShippedRooms.load_all(), "")
	for id in CAVE_START_BEFORE:
		assert_almost_eq(float(points.get(id, 0)), float(CAVE_START_BEFORE[id]), 1.0, id)
	assert_eq(points["spore_cloud"], SPORE_CLOUD_NOW, "the one deliberate move: Spore Cloud is reachable in the Cave")

func test_every_power_is_reachable_from_every_start_by_some_walk() -> void:
	for start in ["", "grotto", "flooded", "deep"]:
		var points := CalibrationWalk.unlock_points(skills, _creature_map(), ShippedRooms.load_all(), start)
		for d in skills:
			if d.source == "essence":
				assert_gt(int(points.get(d.id, 0)), 0, "%s from the %s start" % [d.id, start if start != "" else "cave"])

func test_echolocation_levels_from_air_so_the_grottos_moths_speed_it_up() -> void:
	var levels := CalibrationWalk.levels_by_area(skills, _creature_map(), ShippedRooms.load_all())
	var by_area: Array = []
	for a in CalibrationWalk.AREAS:
		by_area.append(levels[a]["echolocation"])
	assert_eq(by_area, [1, 4, 5, 5], "was 2, 2, 2, 5 on sound; a deliberate move recorded in docs/ledgers/essence-calibration.md")

func test_only_black_spiders_count_toward_sticky_thread() -> void:
	var by_id := _creature_map()
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	rules.start_run()
	for i in 6:
		CalibrationWalk.eat(rules, by_id["taratect"])
		CalibrationWalk.eat(rules, by_id["vine_snake"])
	assert_eq(rules.level_of("sticky_thread"), 0, "a Taratect and a vine snake are not the spider the unlock names")
	for i in 3:
		CalibrationWalk.eat(rules, by_id["spider"])
	assert_eq(rules.level_of("sticky_thread"), 1)

func test_the_four_parents_carry_a_price_and_nothing_else_does() -> void:
	var parents := {"sticky_thread": true, "hydraulic_propulsion": true, "poison_breath": true, "spore_cloud": true}
	for d in skills:
		assert_eq(not (d as SkillDef).evolution_price.is_empty(), parents.has(d.id), d.id)

func test_every_parent_has_exactly_two_evolutions() -> void:
	var counts := {}
	for d in skills:
		if d.source == "evolution":
			counts[d.replaces] = int(counts.get(d.replaces, 0)) + 1
	assert_eq(counts, {"sticky_thread": 2, "hydraulic_propulsion": 2, "poison_breath": 2, "spore_cloud": 2})
