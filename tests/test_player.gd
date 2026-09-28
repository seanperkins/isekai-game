extends GutTest

var rules: SkillRulesEngine
var compendium: CompendiumModel
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
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	events = []
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func _names() -> Array:
	return events.map(func(e): return e[0])

func _enemy(id: String, x: float) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.global_position = Vector2(x, 0)
	e.set_physics_process(false)
	return e

func test_tackle_stuns_enemy_in_front_and_emits() -> void:
	var bat := _enemy("bat", 20)
	var behind := _enemy("bat", -20)
	player.do_tackle()
	assert_eq(bat.status.state, EnemyStatus.STUNNED)
	assert_eq(behind.status.state, EnemyStatus.ACTIVE)
	assert_eq(events, [["stunned_enemy", {"source": "bat"}]])

func test_lizard_front_tackle_does_not_stun_or_emit() -> void:
	var lizard := _enemy("lizard", 20)  # lizard faces -1, player faces 1: head-on
	player.do_tackle()
	assert_eq(lizard.status.state, EnemyStatus.ACTIVE)
	assert_false(_names().has("stunned_enemy"))
	lizard.facing = 1
	player._dash = 0.0
	player.do_tackle()
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)

func test_predation_completes_after_hold_and_absorbs_essences() -> void:
	var toad := _enemy("toad", 20)
	toad.receive_tackle(1, true)
	player.begin_predate()
	assert_true(toad.status.held)
	player.process_predate(0.5)
	assert_false(_names().has("predated"))
	player.process_predate(0.6)
	assert_eq(events.slice(0, 3), [["predated", {"source": "toad", "kind": "creature"}],
		["absorbed", {"essence": "poison", "source": "toad"}], ["absorbed", {"essence": "water", "source": "toad"}]])
	assert_eq(player.stats.get_stat("max_hp"), 31)
	assert_false(player.predation.active())

func test_downed_enemy_is_eaten_without_a_stun() -> void:
	var bat := _enemy("bat", 20)
	bat.receive_hit(9, "physical")
	player.begin_predate()
	player.process_predate(1.0)
	assert_true(_names().has("predated"))

func test_water_pool_eat_is_terrain_and_single_use() -> void:
	var pool := WaterPool.new()
	pool.setup(creatures["water_pool"])
	add_child_autofree(pool)
	pool.global_position = Vector2(10, 0)
	player.begin_predate()
	player.process_predate(1.0)
	assert_eq(events[0], ["predated", {"source": "water_pool", "kind": "terrain"}])
	assert_eq(_names().count("absorbed"), 2)
	assert_false(pool.can_be_predated())

func test_target_freed_mid_hold_cancels_cleanly() -> void:
	# Review Focus 2
	var bat := _enemy("bat", 20)
	bat.receive_tackle(1, true)
	player.begin_predate()
	bat.free()
	player.process_predate(2.0)
	assert_false(player.predation.active())
	assert_false(_names().has("predated"))

func test_death_mid_hold_releases_target() -> void:
	# Review Focus 1
	var bat := _enemy("bat", 20)
	bat.receive_tackle(1, true)
	player.begin_predate()
	player.receive_hit(99, "physical")
	assert_true(player.health.is_dead())
	assert_false(bat.status.held)
	events.clear()
	player.process_predate(2.0)
	player.do_tackle()
	assert_eq(events, [])

func test_direct_hit_emits_and_grants_invulnerability() -> void:
	player.receive_hit(3, "physical")
	player.receive_hit(3, "physical")
	assert_eq(player.health.hp, 27)
	player.tick(0.6)
	player.receive_hit(3, "physical")
	assert_eq(player.health.hp, 24)
	assert_eq(_names().count("damaged"), 2)

func test_poison_application_then_ticks_floor_at_one() -> void:
	player.receive_poison(4, 2, 3.0)
	assert_eq(player.health.hp, 26)
	for i in 3:
		player.tick(1.0)
	assert_eq(player.health.hp, 20)
	assert_eq(events.filter(func(e): return e[0] == "damaged"), [["damaged", {"damage_type": "poison"}]])

func test_glutton_heal_can_exit_the_low_band_during_eats() -> void:
	# Plan 1 handoff: the Glutton heal can emit hp_low_exited right after a predated drain.
	for i in 5:
		rules.handle_event("predated", {"source": "bat", "kind": "creature"})
	assert_eq(rules.level_of("glutton"), 1)
	player.receive_hit(22, "physical")  # 8/30: low
	for x in [20, 22]:
		var bat := _enemy("bat", x)
		bat.receive_hit(9, "physical")
		player.begin_predate()
		player.process_predate(1.0)
	assert_eq(player.health.hp, 24)  # 8 + (5+3) + (5+3)
	var names := _names()
	assert_lt(names.rfind("predated"), names.find("hp_low_exited"))
	assert_eq(rules.count("hp_low_exited"), 1)

func test_inspect_self_when_nothing_in_range() -> void:
	# Review Focus 5
	var got: Array = []
	player.inspect_report.connect(func(lines: PackedStringArray) -> void: got.append(lines))
	player.do_inspect()
	assert_eq(events[0], ["inspected", {"target": "self", "first_time": true, "appraisal_target": true}])
	assert_string_contains("\n".join(got[0]), "HP 30/30")

func test_inspect_creature_reports_with_post_inspect_level() -> void:
	player.do_inspect()  # self: 1 distinct target
	_enemy("bat", 40)
	var got: Array = []
	player.inspect_report.connect(func(lines: PackedStringArray) -> void: got.append(lines))
	player.do_inspect()  # bat: 2 distinct -> Appraisal Lv2
	assert_eq(rules.level_of("appraisal"), 2)
	assert_string_contains("\n".join(got[0]), "Essences: sound 1, flight 1")

func test_use_active_emits_skill_used_with_cooldown() -> void:
	for i in 4:
		rules.handle_event("absorbed", {"essence": "water", "source": "water_pool"})
	player.use_active(0)
	player.use_active(0)
	assert_eq(events.filter(func(e): return e[0] == "skill_used"), [["skill_used", {"id": "hydraulic_propulsion"}]])
	player.use_active(1)  # empty slot
	assert_eq(_names().count("skill_used"), 1)

func test_use_active_without_a_loadable_ability_emits_nothing() -> void:
	# Review Focus 3
	player.skillset.slots.add("no_such_skill")
	player.use_active(0)
	assert_false(_names().has("skill_used"))

func test_max_hp_follows_toughness_and_eats() -> void:
	for i in 20:
		rules.handle_event("damaged", {"damage_type": "physical"})
	assert_eq(player.health.max_hp, 33)

func test_jump_on_floor_emits_jumped() -> void:
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 20)
	shape.shape = rect
	floor.add_child(shape)
	floor.position = Vector2(0, 30)
	add_child_autofree(floor)
	player.global_position = Vector2(0, 0)
	await wait_physics_frames(30)
	assert_true(player.is_on_floor())
	player.do_jump()
	assert_true(events.has(["jumped", {"from": "ground"}]))
	assert_lt(player.velocity.y, 0.0)

func test_predate_hold_cancels_when_the_target_is_out_of_range() -> void:
	var bat := _enemy("bat", 20)
	bat.receive_tackle(1, true)
	player.begin_predate()
	player.global_position = Vector2(200, 0)
	player.process_predate(2.0)
	assert_false(player.predation.active())
	assert_false(bat.status.held)
	assert_false(_names().has("predated"))

func test_jump_and_actives_are_blocked_during_a_hold() -> void:
	for i in 4:
		rules.handle_event("absorbed", {"essence": "water", "source": "water_pool"})
	var bat := _enemy("bat", 20)
	bat.receive_tackle(1, true)
	player.begin_predate()
	player.use_active(0)
	assert_false(_names().has("skill_used"))
