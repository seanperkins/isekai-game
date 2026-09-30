extends GutTest
## Damage.hit: DEF is a hyperbolic percent of the hit's size for physical hits only; resistance percent (clamped at 95)
## applies to any type; flat reductions subtract; minimum 1.

var rules: SkillRulesEngine
var creatures := {}
var skills_by_id := {}
var player: Player

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	for c in creature_list:
		creatures[c.id] = c
	for d in skills:
		skills_by_id[d.id] = d
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func _enemy(id: String) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.set_physics_process(false)
	e.health.hp = 50
	e.health.max_hp = 50
	return e

func _def(value: int) -> void:
	player.stats.set_modifiers("t", [{"stat": "def", "op": "add", "value": value}])

func test_a_hit_at_def_zero_and_no_resistance_is_the_power_itself() -> void:
	for p in [1, 2, 5, 9, 16]:
		assert_eq(Damage.hit(p, "physical", 0, 0, 0), p)
		assert_eq(Damage.hit(p, "poison", 0, 0, 0), p)

func test_armor_is_a_percent_relative_to_the_hit() -> void:
	assert_eq(Damage.armor_pct(4, 5), 50)
	assert_eq(Damage.armor_pct(1, 5), 20)
	assert_eq(Damage.armor_pct(2, 5), 33)
	assert_eq(Damage.armor_pct(0, 5), 0)
	assert_eq(Damage.armor_pct(3, 0), 0)
	assert_eq(Damage.hit(40, "physical", 30, 0, 0), 20)

func test_armor_never_reaches_a_hundred_percent() -> void:
	assert_lt(Damage.armor_pct(100000, 1), 100)

func test_hit_is_monotone_in_def_and_in_power() -> void:
	for power in range(1, 61):
		var last := 1000
		for def in range(0, 81):
			var h := Damage.hit(power, "physical", def, 0, 0)
			assert_lte(h, last, "power %d def %d" % [power, def])
			last = h
	for def in range(0, 41):
		var last := 0
		for power in range(1, 61):
			var h := Damage.hit(power, "physical", def, 0, 0)
			assert_gte(h, last, "power %d def %d" % [power, def])
			last = h

func test_poison_ignores_def() -> void:
	assert_eq(Damage.hit(4, "poison", 3, 0, 0), 4)
	assert_eq(Damage.hit(9, "poison", 50, 0, 0), 9)

func test_resistance_applies_to_any_type_and_is_clamped_at_95() -> void:
	assert_eq(Damage.hit(10, "poison", 0, 50, 0), 5)
	assert_eq(Damage.hit(100, "poison", 0, 113, 0), 5, "113% behaves as 95%; a clamp of 100 would give 1")
	assert_eq(Damage.hit(4, "physical", 0, 20, 0), 3)  # 3.2 -> 3

func test_flat_reductions_subtract_after_the_percents_with_a_minimum_of_one() -> void:
	assert_eq(Damage.hit(6, "physical", 0, 0, 1), 5)
	assert_eq(Damage.hit(3, "physical", 0, 0, 5), 1)
	assert_eq(Damage.hit(10, "physical", 0, 90, 0), 1)

## ATK 1..5 against DEF 0..3: the old flat model, as literal expected values.
func test_the_legacy_grid_matches_except_one_cell() -> void:
	var old := {  # atk -> [def 0, def 1, def 2, def 3]
		1: [1, 1, 1, 1], 2: [2, 1, 1, 1], 3: [3, 2, 1, 1], 4: [4, 3, 2, 1], 5: [5, 4, 3, 2]}
	for atk in old:
		for def in 4:
			var want: int = old[atk][def]
			if atk == 4 and def == 3:
				want = 2  # the one intended difference: 4 x 52 / 100
			assert_eq(Damage.hit(atk, "physical", def, 0, 0), want, "atk %d def %d" % [atk, def])

func test_the_accepted_physical_rows() -> void:
	assert_eq(Damage.hit(4, "physical", 3, 0, 0), 2, "spider vs DEF 3")
	for def in [4, 5, 6]:
		assert_eq(Damage.hit(5, "physical", def, 0, 0), 2, "lizard vs DEF %d" % def)
	assert_eq(Damage.hit(6, "physical", 1, 0, 0), 4, "serpent vs DEF 1")
	assert_eq(Damage.hit(1, "physical", 3, 0, 0), 1, "a plain tackle vs the lizard")

func test_a_player_with_def_3_takes_2_from_a_physical_4_and_all_of_a_poison_4() -> void:
	_def(3)
	assert_eq(player.stats.get_stat("def"), 3)
	player.receive_hit(4, "physical")
	assert_eq(player.health.hp, 28)
	player.tick(1.0)
	player.receive_poison(4, 1, 3.0)
	assert_eq(player.health.hp, 24, "poison ignores DEF: the whole 4")

func test_a_player_at_def_0_takes_the_raw_amount_of_both() -> void:
	player.receive_hit(4, "physical")
	assert_eq(player.health.hp, 26)
	player.tick(1.0)
	player.receive_hit(4, "poison")
	assert_eq(player.health.hp, 22)

func test_a_toad_spit_on_def_5_with_20_percent_resistance_costs_3() -> void:
	_def(5)
	player.skillset = FixedResist.make(rules, player.stats, 20)
	player.receive_hit(4, "poison")
	assert_eq(player.health.hp, 27, "3.2 -> 3; DEF plays no part")

func test_a_lizard_takes_poison_whole_and_physical_through_its_armor() -> void:
	var lizard := _enemy("lizard")
	assert_eq(lizard.stats.get_stat("def"), 3)
	lizard.receive_hit(5, "poison")
	assert_eq(lizard.health.hp, 45, "poison ignores DEF")
	lizard.receive_hit(4, "physical")
	assert_eq(lizard.health.hp, 43, "4 vs DEF 3 is 4 x 100 / (300 + 320) -> 52% off -> 2")
	lizard.receive_hit(4, "physical", Vector2.INF, "", true)
	assert_eq(lizard.health.hp, 39, "a weak-point hit ignores DEF")

func test_skill_power_is_the_table_at_atk_1_and_grows_25_percent_per_point() -> void:
	for v in [2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16]:  # Poison Breath's values, Water Blade's 3, Venom Bolt's 9
		assert_eq(Damage.skill_power(v, 1), v)
	assert_eq(Damage.skill_power(16, 8), 44)
	assert_eq(Damage.skill_power(16, 3), 24)
	assert_eq(Damage.skill_power(2, 3), 3)
	assert_eq(Damage.skill_power(9, 3), 13)
	assert_eq(Damage.skill_power(1, 5), 2, "why the clouds do not use it: the value 1 is all rounding cliff")
	assert_eq(Damage.skill_power(3, 0), 3, "ATK below 1 is treated as 1")
