extends GutTest
## Poison ticks are counted in thousandths of an HP: Poison Resistance reaches 1-point ticks instead of deleting them, and the
## fraction a tick leaves over is carried to the next tick and the next application.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

## A toad spit: 4 on hit, then 1 a second for three seconds.
func _spit() -> void:
	player.receive_poison(4, 1, 3.0)

func _run_out() -> void:
	for i in 3:
		player.tick(1.0)

func _resist(pct: int) -> void:
	player.skillset = FixedResist.make(rules, player.stats, pct)

func test_a_toad_spit_at_no_resistance_costs_its_application_and_three_ticks() -> void:
	var hp := player.health.hp
	_spit()
	_run_out()
	assert_eq(hp - player.health.hp, 4 + 3)
	assert_eq(player._poison_milli, 0)

func test_toad_spit_ticks_at_20_percent_cost_two_hp_from_a_fresh_player() -> void:
	_resist(20)
	_spit()
	var after_application := player.health.hp
	assert_eq(30 - after_application, 3, "the application: 4 x 80 / 100 = 3.2 -> 3")
	_run_out()
	assert_eq(after_application - player.health.hp, 2, "800, then 1600 -> 1, then 1400 -> 1")
	assert_eq(player._poison_milli, 400)
	assert_eq(rules.level_of("poison_resistance"), 0, "the stub is the resistance; no real skill was levelled")

func test_two_spits_at_67_percent_cost_one_hp_of_ticks_and_the_carry_survives() -> void:
	_resist(67)
	_spit()
	_run_out()
	assert_eq(player._poison_milli, 990, "330, 660, 990: three ticks and not a whole HP yet")
	_spit()
	var after_second_application := player.health.hp
	_run_out()
	assert_eq(after_second_application - player.health.hp, 1, "1320 -> 1 HP, then 650, 980")
	assert_eq(player._poison_milli, 980)

func test_three_spits_at_67_percent_cost_two_hp_of_ticks_with_970_carried() -> void:
	_resist(67)
	var applications := 0
	var tick_hp := 0
	for i in 3:
		var before := player.health.hp
		_spit()
		applications += before - player.health.hp
		var after := player.health.hp
		_run_out()
		tick_hp += after - player.health.hp
	assert_eq(applications, 3, "each application is max(1, 4 x 33 / 100)")
	assert_eq(tick_hp, 2)
	assert_eq(player._poison_milli, 970)
	assert_eq(rules.level_of("poison_resistance"), 0)

func test_a_moth_puff_at_20_percent_costs_one_hp_of_ticks() -> void:
	_resist(20)
	player.receive_poison(1, 1, 2.0)
	var after := player.health.hp
	player.tick(1.0)
	player.tick(1.0)
	assert_eq(after - player.health.hp, 1, "800, then 1600 -> 1 HP with 600 carried")
	assert_eq(player._poison_milli, 600)

func test_a_whole_hp_drawn_at_one_hp_is_consumed() -> void:
	player.receive_poison(1, 1, 2.0)
	player.health.hp = 1
	player.tick(1.0)
	assert_eq(player.health.hp, 1, "ticks never kill")
	assert_eq(player._poison_milli, 0, "the whole HP was consumed, not banked")

func test_a_new_application_keeps_the_carry_and_restarts_the_clock() -> void:
	_resist(67)
	_spit()
	player.tick(1.0)
	assert_eq(player._poison_milli, 330)
	_spit()  # the first application's invulnerability has run out
	assert_eq(player._poison_milli, 330, "a new application keeps the fraction")
	_run_out()
	assert_eq(player._poison_milli, 320, "660, 990, 1320 -> 1 HP: a fresh three seconds of ticks")
