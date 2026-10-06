extends GutTest
## The shipped mind verbs, cast for real as the skill files have them: what each does (the agreed text) and what it costs (its drawback).

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	player = arena.player
	lizard = arena.lizard
	lizard.health.max_hp = 1000
	lizard.health.hp = 1000

func after_each() -> void:
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _cast(form: String) -> VerbAbility:
	var a := arena.verb(form)
	assert_true(a.activate(), "%s cast" % form)
	return a

func _enemy(id: String, at: Vector2) -> Enemy:
	var c: CreatureDef = DefLoader.load_dir("res://data/creatures").filter(func(d): return d.id == id)[0]
	var e := Enemy.new()
	e.setup(c, {})
	e.position = at
	add_child_autofree(e)
	return e

func test_the_wail_stuns_and_frightens_and_wakes_the_sleepers() -> void:
	var far := _enemy("lizard", Vector2(220, 0))
	await wait_physics_frames(3)
	assert_false(far.is_alert())
	_cast("undead_banshee")
	assert_eq(lizard.status.state, EnemyStatus.STUNNED, "stunned")
	assert_true(lizard.is_fleeing(), "and frightened")
	assert_true(far.is_alert(), "the wail woke what was asleep (the drawback)")

func test_the_howl_sends_enemies_running_and_locks_the_pounce() -> void:
	_cast("wolf_barghest")
	assert_true(lizard.is_fleeing())
	assert_true(player.is_blow_locked(), "no pounce while howling")

func test_the_lull_calms_enemies_but_not_a_boss() -> void:
	var boss := _enemy("lizard", Vector2(-40, 0))
	boss.hunting = true
	_cast("goblin_orpheus")
	assert_true(lizard.is_calm())
	assert_false(boss.is_calm(), "fails on bosses (the drawback)")

func test_the_dance_venom_makes_a_bitten_enemy_stagger_but_slowly() -> void:
	_cast("spider_tarantella")
	assert_false(lizard.is_confused(), "slow to take hold (the drawback)")
	await wait_seconds(1.4)
	assert_true(lizard.is_confused())

func test_slink_hides_you_and_a_lit_room_spoils_it() -> void:
	player.in_dark = true
	var a := _cast("wolf_black_dog")
	assert_true(player.is_unseen())
	var dark_left := player._veil_t
	player.break_veil()
	player.in_dark = false
	a._cooldown = 0.0
	a.activate()
	assert_lt(player._veil_t, dark_left, "a lit room shows you sooner (the drawback)")

func test_the_goblin_veil_fools_goblins_and_stops_webbing() -> void:
	_cast("spider_jorogumo")
	assert_true(player.unseen_by(_enemy("village_goblin", Vector2(500, 0))))
	assert_false(player.unseen_by(lizard))
	player.skillset.slots.add("sticky_thread")
	var before := player.mana.mp
	player.use_active(0)
	assert_eq(player.mana.mp, before, "no webbing while veiled (the drawback)")
	player._invuln = 0.0
	player.receive_hit(1, "physical", Vector2(40, 0))
	assert_false(player.is_unseen(), "the veil drops when hit (the drawback)")

func test_the_veil_web_hides_those_in_it_and_tears_on_an_attack() -> void:
	_cast("spider_veil_spinner")
	assert_true(player.is_unseen())
	player.break_veil()
	assert_false(player.is_unseen(), "the veil breaks on any attack (the drawback)")

func test_stalk_kill_is_a_stealth_opener_a_crowd_spoils_and_the_body_shrugs_off_ranged_hits() -> void:
	var a := arena.verb("wolf_beast_of_gevaudan")
	a.activate()
	assert_true(player.is_unseen(), "the first cast stalks")
	await wait_seconds(0.6)
	player.cast_unseen = true
	a._cooldown = 0.0
	a.activate()
	assert_lt(lizard.health.hp, 1000, "the second strikes")
	var form := load("res://data/forms/wolf_beast_of_gevaudan.tres") as FormDef
	assert_true(form.traits.has("ranged_proof"), "it shrugs off ranged hits")
	for e in 3:
		_enemy("lizard", Vector2(100.0 + e * 20.0, 0))
	player.break_veil()
	player.cast_unseen = false
	a._cooldown = 0.0
	a.activate()
	assert_false(player.is_unseen(), "helpless against crowds (the drawback)")

func test_the_ranged_proof_trait_cuts_a_hit_from_afar_and_not_one_up_close() -> void:
	player.skillset.capabilities["trait_ranged_proof"] = 1
	var near := player.skillset.incoming("physical", 20, 30, 10.0)
	var far := player.skillset.incoming("physical", 20, 30, 200.0)
	assert_eq(near["percent_off"], 0)
	assert_eq(far["percent_off"], 60)

func test_shed_leaves_a_husk_that_draws_enemies_and_is_spent_until_you_rest() -> void:
	var a := _cast("selkie")
	assert_true(lizard.is_lured(), "the husk draws")
	a._cooldown = 0.0
	assert_false(a.ready(), "gone until you rest (the drawback)")
	player.rest_refresh()
	assert_true(a.ready())

func test_mislead_draws_and_turns_enemies_about() -> void:
	player.global_position = Vector2(-100, 0)
	_cast("goblin_puck")
	assert_true(lizard.is_lured())
	assert_true(lizard._reverse_t > 0.0, "facing reversed")

func test_swap_looks_like_a_creature_and_takes_a_beat() -> void:
	var a := _cast("goblin_changeling")
	assert_eq(get_tree().get_nodes_in_group("verb_husks").size(), 1)
	await wait_seconds(0.6)
	a._cooldown = 0.0
	a.activate()
	assert_true(player.is_held_still(), "the swap takes a beat (the drawback)")

func test_the_lure_light_draws_enemies_and_shows_where_you_are() -> void:
	player.veil_for(5.0)
	_cast("undead_corpse_candle")
	await wait_physics_frames(3)
	assert_true(lizard.is_lured())
	assert_false(player.is_unseen(), "the light shows where you are (the drawback)")

func test_the_trick_lure_holds_the_first_enemy_that_touches_it() -> void:
	_cast("undead_stingy_jack")
	assert_eq(get_tree().get_nodes_in_group("verb_traps").size(), 1, "the lure has to be placed first (the drawback)")

func test_disperse_is_a_swarm_that_cannot_fight() -> void:
	_cast("spider_swarm_sovereign")
	assert_true(player.is_swarm())
	assert_true(player.is_blow_locked())

func test_pocket_blinks_and_robs() -> void:
	lizard.global_position = Vector2(900, 0)
	var mark := _enemy("skeleton", Vector2(95, 0))
	await wait_physics_frames(2)
	_cast("goblin_leprechaun")
	assert_true(mark.robbed)
	assert_gt(player.global_position.x, 60.0)

func test_the_sneak_strike_opens_from_hiding_and_throws_smoke() -> void:
	player.cast_unseen = true
	_cast("goblin_skulker")
	assert_true(player.is_unseen(), "smoke")

func test_sabotage_jams_an_enemy_and_can_backfire() -> void:
	VerbMind.rng.seed = 3
	var a := arena.verb("goblin_gremlin")
	var jammed_enemy := 0
	var jammed_self := 0
	for i in 40:
		lizard._disarm_t = 0.0
		player._jam_t = 0.0
		a._cooldown = 0.0
		a.activate()
		jammed_enemy += 1 if lizard.is_disarmed() else 0
		jammed_self += 1 if player.is_jammed() else 0
	assert_gt(jammed_enemy, 20, "mostly it works")
	assert_gt(jammed_self, 2, "backfires sometimes (the drawback)")

func test_the_fate_thread_sends_the_next_blow_back() -> void:
	_cast("spider_norn")
	assert_true(player.is_fated(lizard))

func test_the_omen_kills_unless_it_cleanses_and_there_is_only_one() -> void:
	lizard.health.max_hp = 100
	lizard.health.hp = 100
	_cast("wolf_black_shuck")
	assert_true(lizard.has_meta("verb_omen"))
	assert_eq(get_tree().get_nodes_in_group("verb_omens").size(), 1)

func test_the_chaser_cannot_be_slowed_and_marks_what_runs() -> void:
	lizard.flee_for(5.0)
	_cast("wolf_skoll")
	assert_true(player.is_chasing(lizard))
	var spd := player.stats.get_stat("spd")
	player.slow_for(2.0)
	assert_eq(player.stats.get_stat("spd"), spd)
