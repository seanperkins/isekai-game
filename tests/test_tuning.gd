extends GutTest
## Tuning pass after the first controller playtest: toads, stun, invulnerability with
## knockback, tackle reach, bat swoops and the eat prompt.

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
	rules.setup(skills)
	events = []
	player = Player.new()
	player.setup(rules, CompendiumModel.new(skills, creature_list), creature_list,
		func(n: String, t: Dictionary) -> void:
			events.append([n, t])
			rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	Controls.using_joypad = false

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.global_position = pos
	e.set_physics_process(false)
	return e

func test_toad_spit_is_weaker_slower_and_shorter_ranged() -> void:
	assert_eq(Enemy.SPIT_COOLDOWN, 5.0)
	assert_eq(Enemy.SPIT_TICK, 1)
	assert_eq(Enemy.SPIT_RANGE, 90.0)

func test_stun_lasts_three_seconds() -> void:
	var s := EnemyStatus.new()
	s.stun()
	s.update(2.9)
	assert_eq(s.state, EnemyStatus.STUNNED)
	s.update(0.2)
	assert_eq(s.state, EnemyStatus.ACTIVE)

func test_hit_grants_one_second_of_invulnerability() -> void:
	player.receive_hit(3, "physical")
	player.tick(0.9)
	player.receive_hit(3, "physical")
	assert_eq(player.health.hp, 27)
	player.tick(0.1)
	player.receive_hit(3, "physical")
	assert_eq(player.health.hp, 24)

func test_contact_hit_knocks_the_player_away_from_the_enemy() -> void:
	player.global_position = Vector2(0, 0)
	player.receive_hit(3, "physical", Vector2(10, 0))  # enemy to the right
	assert_lt(player.velocity.x, 0.0)
	assert_lt(player.velocity.y, 0.0)

func test_tackle_reaches_farther_and_higher() -> void:
	var far := _enemy("bat", Vector2(34, 0))
	player.do_tackle()
	assert_eq(far.status.state, EnemyStatus.STUNNED)
	player._dash = 0.0
	var high := _enemy("toad", Vector2(20, -26))
	player.do_tackle()
	assert_eq(high.status.state, EnemyStatus.STUNNED)

func test_bat_swoop_has_a_readable_rhythm() -> void:
	assert_eq([Enemy.WARN_SECONDS, Enemy.DIVE_SECONDS, Enemy.CLIMB_SECONDS], [0.3, 0.6, 0.8])

func test_eat_prompt_appears_near_an_edible_target_with_device_label() -> void:
	player._update_prompt()
	assert_false(player.eat_prompt.visible)
	var bat := _enemy("bat", Vector2(20, 0))
	bat.receive_tackle(1, true)
	player._update_prompt()
	assert_true(player.eat_prompt.visible)
	assert_eq(player.eat_prompt.text, "Hold K to eat")
	Controls.using_joypad = true
	player._update_prompt()
	assert_eq(player.eat_prompt.text, "Hold B to eat")
	player.begin_predate()
	player._update_prompt()
	assert_false(player.eat_prompt.visible)
