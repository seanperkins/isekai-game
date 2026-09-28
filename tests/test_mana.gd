extends GutTest
## Mana (MP): a pool with regen, per-skill costs, eating restores it, and the hidden
## Mana Recovery skill rewards casting a lot.

var rules: SkillRulesEngine
var creatures := {}
var skills_by_id := {}
var events: Array
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
	events = []
	player = Player.new()
	player.setup(rules, CompendiumModel.new(skills, creature_list), creature_list,
		func(n: String, t: Dictionary) -> void:
			events.append([n, t])
			rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func _names() -> Array:
	return events.map(func(e): return e[0])

func _unlock_hydraulic() -> void:
	for i in 4:
		rules.handle_event("absorbed", {"essence": "water", "source": "water_pool"})

func _eat_downed(id: String) -> void:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.global_position = Vector2(20, 0)
	e.set_physics_process(false)
	e.receive_hit(99, "physical")
	player.begin_predate()
	player.process_predate(1.0)

func test_pool_spend_regen_restore_and_clamp() -> void:
	var m := Mana.new(20)
	assert_true(m.spend(4))
	assert_eq(m.mp, 16)
	assert_false(m.spend(17))
	assert_eq(m.mp, 16)
	m.regen(1.5, 100)
	m.regen(0.5, 100)
	assert_eq(m.mp, 18)
	m.restore(99)
	assert_eq(m.mp, 20)
	m.set_max_mp(10)
	assert_eq(m.mp, 10)

func test_regen_rate_is_a_percent_of_one_mp_per_second() -> void:
	var m := Mana.new(20)
	m.spend(10)
	m.regen(1.0, 150)
	assert_eq(m.mp, 11)
	m.regen(1.0, 150)
	assert_eq(m.mp, 13)

func test_every_player_active_has_the_approved_mp_cost() -> void:
	var costs := {"poison_breath": 4, "hydraulic_propulsion": 3, "water_blade": 5,
		"sticky_thread": 3, "swing_thread": 4, "jet_dash": 5}
	for id in costs:
		assert_eq(skills_by_id[id].mp_cost, costs[id], id)
	for d in skills_by_id.values():
		if d.source != "enemy_only" and SkillEffects.active_scene(d) != "":
			assert_gt(d.mp_cost, 0, d.id)

func test_validator_requires_an_mp_cost_on_player_actives() -> void:
	var s := [TestDefs.skill("appraisal", {"starting": true}),
		TestDefs.skill("zap", {"unlock": [TestDefs.counter("jumped", 1)],
			"effects": [{"kind": "active", "scene": "res://scenes/abilities/jet_dash.tscn"}]})]
	assert_string_contains("\n".join(DefValidator.validate(s, TestDefs.all_creatures())), "needs a positive mp_cost")

func test_casting_spends_mp_and_emits_mana_spent_per_point() -> void:
	_unlock_hydraulic()
	player.use_active(0)
	assert_eq(player.mana.mp, 17)
	assert_eq(_names().count("skill_used"), 1)
	assert_eq(_names().count("mana_spent"), 3)

func test_cannot_cast_without_enough_mp() -> void:
	_unlock_hydraulic()
	var refused := [0]
	player.not_enough_mp.connect(func(_id: String) -> void: refused[0] += 1)
	player.mana.mp = 2
	player.use_active(0)
	assert_eq(player.mana.mp, 2)
	assert_false(_names().has("skill_used"))
	assert_eq(refused[0], 1)

func test_a_cast_blocked_by_cooldown_costs_nothing() -> void:
	_unlock_hydraulic()
	player.use_active(0)
	player.use_active(0)
	assert_eq(player.mana.mp, 17)

func test_mana_regenerates_one_per_second() -> void:
	player.mana.mp = 10
	player.tick(2.0)
	assert_eq(player.mana.mp, 12)

func test_eating_creatures_restores_mp_and_every_third_raises_max_mp() -> void:
	player.mana.mp = 0
	for i in 3:
		_eat_downed("bat")
	assert_eq(player.mana.max_mp, 22)
	assert_eq(player.mana.mp, 12)

func test_max_mp_eat_bonus_caps_at_ten() -> void:
	var s := Stats.new({"max_mp": 20})
	for i in 8:
		s.add_eat_bonus("max_mp", 2)
	assert_eq(s.eat_bonus("max_mp"), 10)
	assert_eq(s.get_stat("max_mp"), 30)

func test_mana_recovery_unlocks_after_spending_60_mp_and_boosts_regen() -> void:
	for i in 59:
		rules.handle_event("mana_spent", {})
	assert_eq(rules.level_of("mana_recovery"), 0)
	rules.handle_event("mana_spent", {})
	assert_eq(rules.level_of("mana_recovery"), 1)
	assert_eq(player.stats.get_stat("mp_regen"), 150)
