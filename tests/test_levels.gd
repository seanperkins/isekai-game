extends GutTest
## Character levels: XP from downing and eating, level-ups grant EP and stats, and
## evolutions wait for the player to spend EP.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var announcer: AnnouncerQueue
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
	compendium = CompendiumModel.new(skills, creature_list)
	announcer = AnnouncerQueue.new()
	CoreWiring.connect_core(rules, compendium, announcer)
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func _emit(ev: String, tags: Dictionary, n: int) -> void:
	for i in n:
		rules.handle_event(ev, tags)

func _downed(id: String) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.global_position = Vector2(20, 0)
	e.set_physics_process(false)
	e.downed.connect(player.on_enemy_downed)
	e.receive_hit(99, "physical")
	e.finish_dying()
	return e

func test_progression_curve_and_ep() -> void:
	var p := Progression.new()
	p.add_xp(9)
	assert_eq([p.level, p.xp, p.ep], [1, 9, 0])
	p.add_xp(1)
	assert_eq([p.level, p.xp, p.ep], [2, 0, 1])
	p.add_xp(40)  # 15 to reach Lv3, then 20 to reach Lv4
	assert_eq([p.level, p.xp, p.ep], [4, 5, 3])
	assert_true(p.spend_ep(2))
	assert_eq(p.ep, 1)
	assert_false(p.spend_ep(5))
	assert_eq(Progression.xp_to_next(1), 10)
	assert_eq(Progression.xp_to_next(3), 20)

func test_creature_xp_values() -> void:
	var expected := {"bat": 2, "toad": 3, "spider": 3, "lizard": 5, "serpent": 20, "water_pool": 0}
	for id in expected:
		assert_eq(creatures[id].xp, expected[id], id)

func test_downing_then_eating_awards_xp_twice() -> void:
	_downed("bat")
	assert_eq(player.progression.xp, 2)
	player.begin_predate()
	player.process_predate(1.0)
	assert_eq(player.progression.xp, 4)

func test_level_up_grants_ep_and_stats() -> void:
	player.award_xp(10)
	assert_eq(player.progression.level, 2)
	assert_eq(player.progression.ep, 1)
	assert_eq(player.health.max_hp, 32)
	assert_eq(player.mana.max_mp, 21)
	assert_eq(player.stats.level_bonus("max_hp"), 2)
	assert_eq(player.stats.skill_bonus("max_hp"), 0)

func test_stats_level_bonus_survives_skill_refresh_and_resets_per_run() -> void:
	var s := Stats.new({"max_hp": 30})
	s.add_level_bonus("max_hp", 2)
	s.add_level_bonus("max_hp", 2)
	s.clear_modifiers()
	assert_eq(s.get_stat("max_hp"), 34)
	s.reset_run()
	assert_eq(s.get_stat("max_hp"), 30)

func test_evolution_waits_until_ep_is_spent() -> void:
	var ready: Array = []
	rules.evolution_ready.connect(func(id: String) -> void: ready.append(id))
	_emit("absorbed", {"essence": "water"}, 4)
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)  # Lv2: Water Blade's condition
	assert_eq(rules.level_of("water_blade"), 0)
	assert_true(rules.is_evolution_ready("water_blade"))
	assert_eq(ready, ["water_blade"])
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)
	assert_eq(ready, ["water_blade"])  # announced once
	assert_eq(rules.evolution_cost("water_blade"), 1)
	assert_eq(rules.evolution_cost("jet_dash"), 2)
	assert_true(rules.evolve("water_blade"))
	assert_eq(rules.level_of("water_blade"), 1)
	assert_false(rules.evolve("water_blade"))
	assert_false(rules.evolve("jet_dash"))  # not ready

func test_player_evolves_only_with_enough_ep() -> void:
	_emit("absorbed", {"essence": "water"}, 4)
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)
	assert_false(player.try_evolve("water_blade"))
	player.award_xp(10)
	assert_true(player.try_evolve("water_blade"))
	assert_eq(player.progression.ep, 0)
	assert_eq(rules.level_of("water_blade"), 1)
	assert_true(player.skillset.slots.slots.has("water_blade"))

func test_ready_evolution_is_announced_and_named_in_the_compendium() -> void:
	_emit("absorbed", {"essence": "water"}, 4)
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)
	var texts: Array = announcer.pending().map(func(p): return p.get("text", ""))
	assert_true(texts.any(func(t): return t.contains("Evolution available") and t.contains("Water Blade")))
	assert_eq(compendium.state("water_blade"), CompendiumModel.State.NAMED)

func test_skill_screen_lists_ready_evolutions_and_evolves_on_accept() -> void:
	_emit("absorbed", {"essence": "water"}, 4)
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)
	player.award_xp(10)
	var screen := SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, compendium, skills_by_id.values())
	screen.open()
	assert_true(screen.row_texts().has("Water Blade  EVOLVE 1 EP"))
	while screen.selected_id() != "water_blade":
		screen.move(1)
	assert_string_contains("\n".join(screen.detail_texts()), "Ready to evolve")
	assert_string_contains(screen.hint_text(), "Evolve")
	screen.accept()
	assert_eq(rules.level_of("water_blade"), 1)
	screen.close()

func test_hud_shows_level_xp_and_ep_and_enemies_award_xp_in_game() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(1)
	assert_eq(game.hud.level_text(), "Lv 1  XP 0/10  EP 0")
	var bat: Enemy = get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy and n.def.id == "bat")[0]
	bat.receive_hit(99, "physical")
	bat.finish_dying()
	assert_eq(game.player.progression.xp, 2)

func test_locked_teaser_ignores_evolutions_that_are_ready() -> void:
	_emit("absorbed", {"essence": "water"}, 4)
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)  # Lv3
	_emit("jumped", {}, 80)  # Leap Lv2: Jet Dash ready too
	var rows := SkillScreenModel.skill_rows(rules, skills_by_id.values())
	var evo_start := rows.find(rows.filter(func(r): return r.get("text") == "EVOLUTION")[0])
	var evo_rows := rows.slice(evo_start + 1)
	# Swing Thread is still locked, so one teaser remains; ready ones don't add another.
	assert_eq(evo_rows.filter(func(r): return r["kind"] == "locked").size(), 1)
	assert_eq(evo_rows.filter(func(r): return r["kind"] == "ready").size(), 2)
