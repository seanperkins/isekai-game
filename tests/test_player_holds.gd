extends GutTest
## What a verb can do to the caster besides its effect: hold it still (a bark, a sowing), lock its own blow (a howl), turn it to a swarm that cannot fight
## (Disperse), or hide it as a goblin and stop it webbing (Veil). All of them are the drawback of the verb that lays them.

var arena: VerbArena

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()

func after_each() -> void:
	Input.action_release("move_right")
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _enemy(id: String) -> Enemy:
	var c: CreatureDef = DefLoader.load_dir("res://data/creatures").filter(func(d): return d.id == id)[0]
	var e := Enemy.new()
	e.setup(c, {})
	add_child_autofree(e)
	return e

func test_a_veil_that_passes_as_a_goblin_fools_goblins_and_no_one_else() -> void:
	arena.player.veil_for(5.0, "goblin")
	assert_true(arena.player.unseen_by(_enemy("village_goblin")))
	assert_true(arena.player.unseen_by(_enemy("goblin_shaman")))
	assert_false(arena.player.unseen_by(arena.lizard), "a lizard is not fooled")
	assert_true(arena.player.is_unseen())

func test_an_unseen_player_of_any_kind_is_unseen_by_everyone() -> void:
	arena.player.veil_for(5.0)
	assert_true(arena.player.unseen_by(arena.lizard))

func test_a_veil_that_stops_webbing_refuses_a_thread_verb_and_keeps_the_veil() -> void:
	arena.player.skillset.slots.add("sticky_thread")
	arena.player.veil_for(5.0, "", true)
	arena.player.mana.mp = arena.player.mana.max_mp
	var before := arena.player.mana.mp
	arena.player.use_active(0)
	assert_eq(arena.player.mana.mp, before, "nothing was spent")
	assert_true(arena.player.is_unseen(), "the veil is not broken by a cast that was refused")

func test_a_held_player_does_not_move_until_it_is_let_go() -> void:
	arena.player.global_position = Vector2(-300, 0)  # clear of the lizard, whose body would block the walk
	arena.player.hold_still(0.4)
	assert_true(arena.player.is_held_still())
	Input.action_press("move_right")
	await wait_physics_frames(10)
	assert_eq(arena.player.velocity.x, 0.0)
	await wait_seconds(0.5)
	assert_false(arena.player.is_held_still())
	await wait_physics_frames(6)
	assert_gt(arena.player.velocity.x, 10.0, "free to walk again")

func test_a_locked_blow_cannot_be_used_until_the_lock_ends() -> void:
	arena.player.lock_blow(0.3)
	assert_true(arena.player.is_blow_locked())
	await wait_seconds(0.5)
	assert_false(arena.player.is_blow_locked())

func test_a_swarm_cannot_cast_and_cannot_use_its_blow() -> void:
	arena.player.skillset.slots.add("verb_wolf_barghest")
	arena.player.swarm_for(1.0)
	assert_true(arena.player.is_swarm())
	assert_true(arena.player.is_blow_locked(), "a swarm has no blow")
	arena.player.mana.mp = arena.player.mana.max_mp
	var before := arena.player.mana.mp
	arena.player.use_active(0)
	assert_eq(arena.player.mana.mp, before, "a swarm cannot fight")

func test_a_swarm_reforms_when_its_time_is_up() -> void:
	arena.player.swarm_for(0.2)
	await wait_seconds(0.5)
	assert_false(arena.player.is_swarm())
