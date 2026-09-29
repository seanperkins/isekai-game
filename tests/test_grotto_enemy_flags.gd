extends GutTest
## The crab reuses the lizard's charger and armored front through data flags; slow_for is the one _slow writer.

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _enemy(id: String) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	return e

func test_a_front_tackle_hurts_an_armored_charger_but_does_not_stun_it() -> void:
	for id in ["lizard", "mushroom_crab"]:
		var e := _enemy(id)
		var before := e.health.hp
		var stunned := e.receive_tackle(4, false)
		assert_false(stunned, "%s front" % id)
		assert_lt(e.health.hp, before, "%s still takes damage from the front" % id)
		assert_ne(e.status.state, EnemyStatus.STUNNED, id)

func test_a_rear_tackle_stuns_an_armored_charger() -> void:
	for id in ["lizard", "mushroom_crab"]:
		var e := _enemy(id)
		assert_true(e.receive_tackle(1, true), id)
		assert_eq(e.status.state, EnemyStatus.STUNNED, id)

func test_other_creatures_are_stunned_from_the_front() -> void:
	var e := _enemy("toad")
	assert_true(e.receive_tackle(1, false))

func test_slow_for_halves_speed_for_its_seconds_and_thread_uses_it() -> void:
	var e := _enemy("toad")
	var base := e._speed()
	e.slow_for(1.5)
	assert_almost_eq(e._speed(), base * 0.5, 0.001)
	var f := _enemy("toad")
	f.receive_thread(1)
	assert_almost_eq(f._speed(), base * 0.5, 0.001, "receive_thread slows through slow_for")

# --- the public seams the enemy characterization uses ---

func test_seed_rng_makes_a_bats_rhythm_repeatable() -> void:
	var a := _enemy("bat")
	var b := _enemy("bat")
	a.seed_rng(1234)
	b.seed_rng(1234)
	assert_eq(a._rng.randf(), b._rng.randf())

func test_telegraphing_is_public_and_true_during_a_windup() -> void:
	var lizard := _enemy("lizard")
	assert_false(lizard.telegraphing())
	lizard._state = "windup"
	assert_true(lizard.telegraphing())

func test_anim_state_is_the_clip_pick_chose_and_empty_without_a_sheet() -> void:
	var serpent := _enemy("serpent")
	await wait_physics_frames(3)
	assert_eq(serpent.anim_state(), "", "the serpent has no sheet")
	var toad := Enemy.new()
	toad.setup(creatures["toad"], skills_by_id)
	add_child_autofree(toad)
	await wait_physics_frames(3)
	assert_true(["idle", "walk"].has(toad.anim_state()), toad.anim_state())
