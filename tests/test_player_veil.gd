extends GutTest
## The veil: the player cannot be seen (an enemy does not notice it) until it runs out, the player is hurt, or the player attacks or casts. A web
## spun over a doorway hides whoever stands in it. A hunting boss is not fooled.

var arena: VerbArena

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()  # its player is invulnerable: the lizard beside it cannot hurt it, which would end a veil

func after_each() -> void:
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _cast(spec: Dictionary) -> void:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	arena.player.add_child(a)
	a.spec = spec
	a.setup(arena.player, [4], 1)
	a.activate()

func test_a_veiled_player_is_not_noticed_by_a_real_enemy() -> void:
	arena.player.veil_for(5.0)
	assert_true(arena.player.is_unseen())
	await wait_physics_frames(15)
	assert_false(arena.lizard.is_alert(), "the lizard beside it does not notice")
	arena.player.break_veil()
	await wait_physics_frames(8)
	assert_true(arena.lizard.is_alert(), "seen again")

func test_a_veil_runs_out() -> void:
	arena.player.veil_for(0.2)
	await wait_seconds(0.5)
	assert_false(arena.player.is_unseen())

func test_a_blow_that_lands_ends_the_veil() -> void:
	arena.player.veil_for(5.0)
	arena.player._invuln = 0.0
	arena.player.receive_hit(1, "physical", Vector2(40, 0))
	assert_false(arena.player.is_unseen())

func test_a_blow_that_is_warded_off_does_not_end_it() -> void:
	arena.player.veil_for(5.0)
	arena.player._invuln = 0.0
	arena.player.ward(1.0)
	arena.player.receive_hit(1, "physical", Vector2(40, 0))
	assert_true(arena.player.is_unseen())

func test_casting_another_verb_ends_the_veil_and_remembers_it_was_up() -> void:
	arena.player.skillset.slots.add("verb_wolf_barghest")
	arena.player.veil_for(5.0)
	arena.player.mana.mp = arena.player.mana.max_mp
	arena.player.use_active(0)
	assert_false(arena.player.is_unseen(), "an attack from hiding ends it")
	assert_true(arena.player.cast_unseen, "but the cast knew it came from hiding")

func test_the_veil_verb_hides_the_caster_for_its_seconds() -> void:
	_cast({"kind": "veil", "seconds": 4.0})
	assert_true(arena.player.is_unseen())

func test_the_veil_is_shorter_in_a_lit_room() -> void:
	arena.player.in_dark = false
	_cast({"kind": "veil", "seconds": 6.0, "lit_seconds": 0.3})
	assert_true(arena.player.is_unseen())
	await wait_seconds(0.6)
	assert_false(arena.player.is_unseen(), "a lit room shows you soon")
	arena.player.in_dark = true
	_cast({"kind": "veil", "seconds": 6.0, "lit_seconds": 0.3, "cooldown": 0.0})
	await wait_seconds(0.6)
	assert_true(arena.player.is_unseen(), "the dark keeps you")

func test_a_web_over_a_doorway_hides_whoever_stands_in_it_and_breaks_when_they_attack() -> void:
	_cast({"kind": "veil", "seconds": 5.0, "radius": 60.0})
	assert_true(arena.player.is_unseen())
	arena.player.global_position = Vector2(300, 0)
	assert_false(arena.player.is_unseen(), "out of the web they are seen")
	arena.player.global_position = Vector2.ZERO
	assert_true(arena.player.is_unseen())
	arena.player.break_veil()
	assert_false(arena.player.is_unseen(), "an attack tears the web")
	assert_eq(get_tree().get_nodes_in_group("verb_veils").size(), 0)

func test_a_veil_spec_validates() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "veil", "seconds": 4.0, "lit_seconds": 1.0, "radius": 50.0})), [])
	assert_ne(Array(VerbKinds.validate({"kind": "veil", "seconds": "long"})), [])
