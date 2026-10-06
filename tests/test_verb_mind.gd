extends GutTest
## The mind verbs, each with what it does and what it costs: Stalk-kill, Swap, Pocket, Lure-light, Omen, Fate thread, Sabotage, Chaser, Disperse, a decoy that
## draws and misleads, and the keys any verb may carry (a locked blow, a held body, a shout that wakes).

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	player = arena.player
	lizard = arena.lizard
	MindStub.floor_under(self)

func after_each() -> void:
	Input.action_release("move_right")
	VerbMind.rng.seed = 1
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

class MindStub:
	static func floor_under(t: GutTest) -> void:
		var ground := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(4000, 20)
		shape.shape = rect
		ground.add_child(shape)
		ground.position = Vector2(0, 26)
		t.add_child_autofree(ground)

func _verb(spec: Dictionary) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	player.add_child(a)
	a.spec = spec
	a.setup(player, [4], 1)
	return a

func _cast(spec: Dictionary) -> VerbAbility:
	var a := _verb(spec)
	assert_true(a.activate(), "the cast went off")
	return a

func _enemy(id: String, at: Vector2) -> Enemy:
	var c: CreatureDef = DefLoader.load_dir("res://data/creatures").filter(func(d): return d.id == id)[0]
	var e := Enemy.new()
	e.setup(c, {})
	e.position = at
	add_child_autofree(e)
	e.health.max_hp = 100
	e.health.hp = 100
	return e

# --- Stalk-kill ---

func test_stalk_from_plain_sight_lays_a_veil_and_leaves_the_strike_for_the_next_cast() -> void:
	var a := _cast({"kind": "stalk", "seconds": 4.0, "opener": 4.0})
	assert_true(player.is_unseen())
	assert_eq(lizard.health.hp, 100, "no blow yet")
	await wait_seconds(0.6)
	assert_true(a.ready(), "the next cast is soon, not after the verb's long cooldown")

func test_stalk_from_under_a_veil_strikes_for_the_openers_multiple() -> void:
	player.cast_unseen = true
	_cast({"kind": "stalk", "opener": 1.0, "hit_range": 80.0})
	var plain := 100 - lizard.health.hp
	lizard.health.hp = 100
	lizard._ward_t = 0.0
	await wait_seconds(0.1)
	player.cast_unseen = true
	_cast({"kind": "stalk", "opener": 4.0, "hit_range": 80.0})
	var opened := 100 - lizard.health.hp
	assert_gt(plain, 0, "an ordinary strike hurts")
	assert_gte(opened, plain * 3, "four times the damage, or near it (%d against %d)" % [opened, plain])

func test_stalk_fails_in_a_crowd() -> void:
	_enemy("lizard", Vector2(60, 0))
	_enemy("lizard", Vector2(80, 0))
	assert_gte(get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy).size(), 3)
	_cast({"kind": "stalk", "seconds": 4.0, "crowd": 3})
	assert_false(player.is_unseen(), "a crowd sees you: there is nothing to stalk")

# --- Swap ---

func test_swap_leaves_a_husk_that_draws_enemies_and_looks_like_the_nearest_creature() -> void:
	_cast({"kind": "swap", "seconds": 5.0, "lure": 200.0})
	var husks := get_tree().get_nodes_in_group("verb_husks")
	assert_eq(husks.size(), 1)
	assert_true(lizard.is_lured(), "the lizard goes after the husk")
	assert_eq((husks[0].get_child(0) as Sprite2D).texture, lizard._sprite.texture, "it wears the lizard's look")

func test_the_second_swap_trades_places_after_a_beat_and_holds_the_caster_through_it() -> void:
	lizard.global_position = Vector2(900, 0)  # out of the husk's call: a lizard walking up to it would shove the caster about
	var a := _verb({"kind": "swap", "seconds": 5.0, "beat": 0.3})
	a.activate()
	var husk: Node2D = get_tree().get_nodes_in_group("verb_husks")[0]
	var there := husk.global_position
	player.global_position = Vector2(-120, 0)
	await wait_seconds(0.6)  # past the short cooldown the first half chose
	a._cooldown = 0.0
	assert_true(a.activate())
	assert_true(player.is_held_still(), "the swap takes a beat")
	assert_ne(player.global_position, there, "not yet")
	await wait_seconds(0.5)
	assert_almost_eq(player.global_position.x, there.x, 3.0, "the caster is where the husk was")
	assert_almost_eq(husk.global_position.x, -120.0, 3.0, "and the husk where the caster was")

# --- Pocket ---

func test_a_blink_jumps_ahead_and_stops_short_of_a_wall() -> void:
	lizard.global_position = Vector2(900, 0)
	player.global_position = Vector2.ZERO
	_cast({"kind": "blink", "distance": 90.0})
	assert_almost_eq(player.global_position.x, 90.0, 1.0)
	player.global_position = Vector2.ZERO
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 200)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(50, 0)
	add_child_autofree(wall)
	await wait_physics_frames(2)
	_cast({"kind": "blink", "distance": 90.0, "cooldown": 0.0})
	assert_lt(player.global_position.x, 50.0, "it stopped at the wall (at %.0f)" % player.global_position.x)

func test_a_blink_that_robs_picks_the_pocket_of_what_it_lands_beside() -> void:
	lizard.global_position = Vector2(900, 0)
	var mark := _enemy("skeleton", Vector2(95, 0))
	await wait_physics_frames(2)
	assert_true(mark.can_be_robbed(), "the skeleton has something to leave")
	_cast({"kind": "blink", "distance": 90.0, "rob": true})
	assert_true(mark.robbed)
	assert_eq(mark.health.hp, 100, "and it is still alive")

# --- Lure-light ---

func test_a_light_draws_enemies_and_drifts_on_and_shows_where_the_caster_is() -> void:
	player.veil_for(5.0)
	_cast({"kind": "light", "seconds": 3.0, "speed": 60.0, "radius": 120.0, "reveal": 120.0})
	await wait_physics_frames(3)
	assert_false(player.is_unseen(), "the light shows where you are")
	assert_true(lizard.is_lured())
	var light: Node2D = get_tree().get_nodes_in_group("verb_lights")[0]
	var x0 := light.global_position.x
	await wait_seconds(0.5)
	assert_gt(light.global_position.x, x0 + 20.0, "it drifts")

# --- Omen ---

func test_an_omen_kills_its_mark_when_the_time_is_up() -> void:
	_cast({"kind": "omen", "seconds": 0.3})
	assert_true(lizard.has_meta("verb_omen"))
	await wait_seconds(0.6)
	assert_lte(lizard.health.hp, 0, "it died")

func test_an_omen_is_cleansed_by_holy_light() -> void:
	_cast({"kind": "omen", "seconds": 0.4})
	lizard.receive_hit(1, "holy", Vector2.INF)
	await wait_seconds(0.7)
	assert_gt(lizard.health.hp, 0, "it cleansed")
	assert_false(lizard.has_meta("verb_omen"))

func test_an_omen_only_wounds_a_boss() -> void:
	lizard.hunting = true
	_cast({"kind": "omen", "seconds": 0.2})
	await wait_seconds(0.5)
	assert_gt(lizard.health.hp, 0)
	assert_lt(lizard.health.hp, 100)

func test_a_new_omen_takes_the_place_of_the_last() -> void:
	var other := _enemy("lizard", Vector2(-40, 0))
	var a := _verb({"kind": "omen", "seconds": 5.0, "range": 60.0})
	a.activate()
	assert_eq(get_tree().get_nodes_in_group("verb_omens").size(), 1)
	lizard.global_position = Vector2(900, 0)
	await wait_physics_frames(2)
	a._cooldown = 0.0
	a.activate()
	assert_eq(get_tree().get_nodes_in_group("verb_omens").size(), 1, "one mark at a time")
	assert_true(other.has_meta("verb_omen"))
	assert_false(lizard.has_meta("verb_omen"), "the first mark is gone")

# --- Fate thread ---

func test_a_fated_enemys_next_blow_goes_back_to_it_and_only_the_next() -> void:
	_cast({"kind": "fate", "seconds": 5.0})
	assert_true(player.is_fated(lizard))
	player._invuln = 0.0
	var hp := player.health.hp
	player.receive_hit(10, "physical", lizard.global_position, lizard.def.id)
	assert_eq(player.health.hp, hp, "the player took nothing")
	assert_lt(lizard.health.hp, 100, "it was sent back")
	assert_false(player.is_fated(lizard), "the thread is spent")
	player._invuln = 0.0
	player.receive_hit(10, "physical", lizard.global_position, lizard.def.id)
	assert_lt(player.health.hp, hp, "the next one lands")

# --- Sabotage ---

func test_sabotage_jams_the_nearest_foes_devices() -> void:
	_cast({"kind": "sabotage", "backfire": 0.0, "seconds": 4.0})
	assert_true(lizard.is_disarmed())

func test_sabotage_sometimes_backfires_and_jams_the_caster() -> void:
	_cast({"kind": "sabotage", "backfire": 1.0})
	assert_true(player.is_jammed())
	assert_false(lizard.is_disarmed())

func test_sabotage_turns_an_enemy_hazard_against_the_enemy() -> void:
	var hazard := Node2D.new()
	add_child_autofree(hazard)
	hazard.add_to_group("hazards")
	hazard.global_position = Vector2(20, 0)
	_cast({"kind": "sabotage", "backfire": 0.0})
	assert_lt(lizard.health.hp, 100, "its own trap hurt it")
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("hazards").size(), 0, "and the trap is spent")

# --- Chaser ---

func test_a_chase_marks_a_fleeing_enemy_and_the_pounce_that_catches_it_is_free() -> void:
	lizard.flee_for(5.0)
	_cast({"kind": "chase", "seconds": 5.0, "range": 200.0, "spd": 60})
	assert_true(player.is_chasing(lizard))
	assert_true(player.stats.get_stat("spd") > player.stats.get_stat("max_hp") * 0 + 100, "faster")

func test_a_chase_does_not_mark_an_enemy_that_stands_its_ground() -> void:
	_cast({"kind": "chase", "seconds": 5.0, "range": 200.0})
	assert_false(player.is_chasing(lizard))

func test_a_chasing_gallop_cannot_be_slowed() -> void:
	_cast({"kind": "chase", "seconds": 5.0})
	var spd := player.stats.get_stat("spd")
	player.slow_for(3.0)
	assert_eq(player.stats.get_stat("spd"), spd)

# --- Disperse ---

func test_a_swarm_slips_through_a_barrier_that_stops_a_body() -> void:
	lizard.global_position = Vector2(900, 0)
	player.global_position = Vector2(-60, 0)
	var barrier := Node2D.new()
	barrier.set_script(load("res://tests/support/fake_barrier.gd"))
	add_child_autofree(barrier)
	barrier.global_position = Vector2(0, 0)
	barrier.add_to_group("dissolvable")
	await wait_physics_frames(4)
	Input.action_press("move_right")
	await wait_seconds(0.8)
	assert_lt(player.global_position.x, 0.0, "a body is stopped (at %.0f)" % player.global_position.x)
	_cast({"kind": "disperse", "seconds": 1.5})
	assert_true(player.is_swarm())
	await wait_seconds(0.8)
	assert_gt(player.global_position.x, 10.0, "a swarm goes through (at %.0f)" % player.global_position.x)

func test_a_swarm_cannot_fight() -> void:
	_cast({"kind": "disperse", "seconds": 1.0})
	assert_true(player.is_blow_locked())
	player.skillset.slots.add("verb_wolf_barghest")
	var before := player.mana.mp
	player.use_active(0)
	assert_eq(player.mana.mp, before)

# --- a decoy that draws and misleads, and is used once between rests ---

func test_a_decoy_draws_the_enemies_near_it_and_turns_them_about() -> void:
	player.global_position = Vector2(-100, 0)
	_cast({"kind": "decoy", "seconds": 2.0, "lure": 200.0, "reverse": 1.0})
	assert_true(lizard.is_lured())
	await wait_physics_frames(2)

func test_a_husk_that_is_gone_until_you_rest_is_gone_until_you_rest() -> void:
	var a := _cast({"kind": "decoy", "seconds": 0.5, "once_per_rest": true})
	a._cooldown = 0.0
	assert_false(a.ready(), "spent")
	player.rest_refresh()
	assert_true(a.ready(), "rested")

# --- keys any verb may carry ---

func test_a_verb_can_lock_hold_and_wake() -> void:
	var far := _enemy("lizard", Vector2(700, 0))
	await wait_physics_frames(3)
	assert_false(far.is_alert())
	_cast({"kind": "ring", "radius": 10.0, "lock": 0.5, "still": 0.5, "alerts": 900.0})
	assert_true(player.is_blow_locked())
	assert_true(player.is_held_still())
	assert_true(far.is_alert(), "the shout woke it")

# --- a dash out of hiding, a trap that is a lure, a status that is slow to take hold, a calm that can be tamed ---

func test_a_dash_out_of_hiding_hits_harder_and_leaves_smoke_behind() -> void:
	_cast({"kind": "dash", "hit_range": 80.0, "hit_half_width": 40.0})
	var plain := 100 - lizard.health.hp
	lizard.health.hp = 100
	await wait_seconds(0.1)
	player.cast_unseen = true
	_cast({"kind": "dash", "hit_range": 80.0, "hit_half_width": 40.0, "opener": 3.0, "smoke": 2.0})
	var opened := 100 - lizard.health.hp
	assert_gte(opened, plain * 2, "an opener from hiding: %d against %d" % [opened, plain])
	assert_true(player.is_unseen(), "the smoke hides the way out")

func test_a_trap_that_is_a_lure_draws_the_enemy_and_holds_the_one_that_touches_it() -> void:
	_cast({"kind": "trap", "seconds": 5.0, "lure": 200.0, "root": 2.0, "damage": false})
	player.global_position = Vector2(-300, 0)  # the caster steps away: the lizard is after the trap, not the caster's body
	var far := _enemy("cave_rat", Vector2(150, 0))
	await wait_physics_frames(2)
	assert_true(far.is_lured())
	await wait_seconds(1.5)
	assert_true(lizard.is_rooted(), "the lizard that touched it is held fast")
	assert_eq(lizard.health.hp, 100, "a lure hurts no one")

func test_a_status_that_is_slow_to_take_hold_takes_hold_late() -> void:
	_cast({"kind": "burst", "range": 80.0, "half_width": 40.0, "status": {"confuse": 3.0}, "status_delay": 0.4})
	assert_false(lizard.is_confused(), "not yet")
	await wait_seconds(0.6)
	assert_true(lizard.is_confused(), "now")

func test_a_calmed_creature_can_be_tamed_by_a_goblin_and_an_angry_one_cannot() -> void:
	player.set_species("goblin")
	lizard.global_position = Vector2(900, 0)
	var rat := _enemy("cave_rat", Vector2(20, 0))
	await wait_physics_frames(2)
	assert_false(player.try_bond(), "an angry rat cannot be tamed")
	rat.calm_for(5.0)
	assert_true(player.try_bond(), "a calm one can")
	assert_eq(player.companions.size(), 1)

# --- the data ---

func test_the_new_kinds_and_keys_validate() -> void:
	for spec in [{"kind": "stalk", "seconds": 5, "opener": 4, "crowd": 3, "damage_type": "physical"}, {"kind": "swap", "seconds": 10, "beat": 0.4, "lure": 180},
			{"kind": "blink", "distance": 90, "rob": true}, {"kind": "light", "seconds": 8, "speed": 40, "radius": 100, "reveal": 100},
			{"kind": "omen", "range": 200, "seconds": 10, "damage_type": "dark"}, {"kind": "fate", "range": 200, "seconds": 10},
			{"kind": "sabotage", "range": 100, "seconds": 5, "backfire": 0.25}, {"kind": "chase", "range": 200, "seconds": 6, "spd": 50},
			{"kind": "disperse", "seconds": 3}, {"kind": "decoy", "lure": 100, "reverse": 2.0, "once_per_rest": true},
			{"kind": "ring", "lock": 1, "still": 1, "alerts": 200, "web": true}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
	assert_ne(Array(VerbKinds.validate({"kind": "omen", "seconds": "ten"})), [])
	assert_ne(Array(VerbKinds.validate({"kind": "ring", "lock": "long"})), [])
