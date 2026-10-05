extends GutTest
## A kill reaches the run's ledger as a `defeated` deed with the flags of how it was made; eating says the creature's species.

var skills: Array
var creatures := {}
var skills_by_id := {}
var rules: SkillRulesEngine
var player: Player
var events: Array

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	for d in skills:
		skills_by_id[d.id] = d
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	events = []
	player = Player.new()
	player.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func _enemy(id: String, at := Vector2.ZERO) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = at
	add_child_autofree(e)
	return e

func _defeats() -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == Deeds.DEFEATED)

func test_a_tackle_from_behind_is_recorded_on_the_enemy() -> void:
	var e := _enemy("lizard")
	e.receive_tackle(1, true, Vector2(-10, 0))
	assert_true(e.last_blow["from_behind"])
	assert_almost_eq(float(e.last_blow["distance"]), 10.0, 0.01)
	assert_eq(e.last_blow["damage_type"], "physical")

func test_a_front_tackle_is_not_from_behind_and_a_far_hit_is_ranged() -> void:
	var e := _enemy("stone_drake")  # 28 HP: it lives through the blows
	e.receive_tackle(1, false, Vector2(-10, 0))
	assert_false(e.last_blow["from_behind"])
	e.receive_hit(1, "physical", Vector2(300, 0))
	assert_gte(float(e.last_blow["distance"]), DeedTags.RANGED_PX)

func test_the_flag_of_a_tackle_from_behind_does_not_leak_into_the_next_blow() -> void:
	var e := _enemy("stone_drake")
	e.receive_tackle(1, true, Vector2(-10, 0))
	assert_true(e.last_blow["from_behind"])
	e.receive_hit(1, "physical", Vector2(300, 0))
	assert_false(e.last_blow["from_behind"], "a bolt after a backstab is not a backstab")

func test_an_enemy_that_was_not_alert_is_recorded_as_unaware() -> void:
	var e := _enemy("toad")
	e.receive_hit(1, "physical", Vector2(30, 0))
	assert_false(e.last_blow["alert"])

func test_a_marked_or_appraised_enemy_is_marked() -> void:
	var e := _enemy("toad")
	e.set_meta("verb_marked", true)
	e.receive_hit(1, "physical", Vector2(30, 0))
	assert_true(e.last_blow["marked"])
	var other := _enemy("toad", Vector2(40, 0))
	player.global_position = Vector2(30, 0)
	player.do_inspect()
	other.receive_hit(1, "physical", Vector2(30, 0))
	assert_true(other.last_blow["marked"], "appraising an enemy marks it")

func test_noting_a_defeat_puts_a_deed_in_the_ledger_with_its_flags() -> void:
	var e := _enemy("bat")
	e.receive_hit(99, "poison", Vector2(200, 0))
	player.note_defeat(e)
	var d := _defeats()
	assert_eq(d.size(), 1)
	assert_eq(d[0][1]["source"], "bat")
	assert_true(d[0][1]["poison"] and d[0][1]["ranged"])
	assert_eq(rules.condition_value({"kind": "counter", "event": Deeds.DEFEATED, "tags": {"poison": true}, "n": 1}), 1)
	assert_eq(rules.condition_value({"kind": "counter", "event": Deeds.DEFEATED, "tags": {"behind": true}, "n": 1}), 0)

func test_two_defeats_in_one_frame_count_twice() -> void:
	var a := _enemy("bat")
	var b := _enemy("toad")
	player.note_defeat(a)
	player.note_defeat(b)
	assert_eq(_defeats().size(), 2)

func test_a_defeat_with_no_recorded_blow_has_only_its_source() -> void:
	var e := _enemy("bat")
	player.note_defeat(e)
	assert_eq(_defeats()[0][1], {"source": "bat"})

func test_a_dead_player_notes_nothing() -> void:
	var e := _enemy("bat")
	player.health.take_hit(9999, "physical")
	assert_true(player.health.is_dead())
	player.note_defeat(e)
	assert_eq(_defeats().size(), 0)

func test_hanging_from_the_ceiling_counts_and_for_a_moment_after() -> void:
	player.set_species("spider")
	player.species_body.state.surface_n = Vector2.DOWN
	player.track_ceiling(0.016)
	var e := _enemy("bat")
	player.note_defeat(e)
	assert_true(_defeats()[0][1].has("ceiling"))
	player.species_body.state.surface_n = Vector2.ZERO
	player.track_ceiling(0.5)  # it has just dropped
	player.note_defeat(_enemy("bat", Vector2(5, 0)))
	assert_true(_defeats()[1][1].has("ceiling"))
	player.track_ceiling(3.0)
	player.note_defeat(_enemy("bat", Vector2(9, 0)))
	assert_false(_defeats()[2][1].has("ceiling"), "the moment is over")

func test_the_ceiling_window_is_kept_by_every_physics_tick_of_a_crawler() -> void:
	player.set_species("spider")
	player._ceiling_t = 1.0
	await wait_physics_frames(20)
	assert_lt(player._ceiling_t, 1.0, "the species step ticks it down")

func test_a_slime_is_never_on_the_ceiling() -> void:
	player.track_ceiling(0.1)
	player.note_defeat(_enemy("bat"))
	assert_false(_defeats()[0][1].has("ceiling"))

func test_a_kill_in_a_dark_area_is_dark() -> void:
	player.in_dark = true
	player.note_defeat(_enemy("bat"))
	assert_true(_defeats()[0][1].has("dark"))

func test_eating_a_goblin_says_its_species_and_eating_a_bat_does_not() -> void:
	var goblin := _enemy("village_goblin")
	player._complete_predation(goblin)
	var bat := _enemy("bat", Vector2(20, 0))
	player._complete_predation(bat)
	var eaten := events.filter(func(e: Array) -> bool: return e[0] == Events.PREDATED)
	assert_eq(eaten[0][1]["species"], "goblin")
	assert_false(eaten[1][1].has("species"))

func test_the_game_hands_every_downed_enemy_to_the_player() -> void:
	Game.launch_override = {"headless": true, "args": ["--skip-opening"]}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	var before: int = SkillRules.condition_value({"kind": "counter", "event": Deeds.DEFEATED, "tags": {"source": "bat"}, "n": 1})
	var bat: Node2D = game._spawn("bat", game.player.global_position + Vector2(300, -40))
	game.world.room.add_child(bat)
	bat.receive_hit(99, "physical", game.player.global_position)
	await wait_physics_frames(2)
	var after: int = SkillRules.condition_value({"kind": "counter", "event": Deeds.DEFEATED, "tags": {"source": "bat"}, "n": 1})
	assert_eq(after, before + 1)
