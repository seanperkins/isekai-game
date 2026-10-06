extends GutTest
## The shipped projectile verbs, cast for real as the skill files have them: what each does and what it costs.

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
	lizard.global_position = Vector2(900, 0)
	player._invuln = 1000.0
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("loose"):
		n.free()
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _hits() -> int:
	return arena.foes[0].hits.size()

func test_the_whip_and_the_thrown_head_alternate() -> void:
	var a := arena.verb("undead_dullahan")
	a.activate()
	assert_eq(_hits(), 1, "the whip")
	a._cooldown = 0.0
	a.activate()
	await wait_seconds(0.6)
	assert_eq(_hits(), 3, "the head: out and back")

func test_the_bone_returns_and_a_bow_arm_stretches_it() -> void:
	var a := arena.verb("undead_skeletal_archer")
	a.activate()
	await wait_seconds(0.6)
	assert_eq(_hits(), 2, "out and back")
	assert_eq(arena.verb("undead_skeletal_archer").spec["reach_with"]["part"], "bow_arm")

func test_the_seventh_sure_shot_is_cursed() -> void:
	var a := arena.verb("undead_deadeye")
	player.health.hp = 20
	for i in 6:
		a._cooldown = 0.0
		a.activate()
	assert_eq(player.health.hp, 20)
	a._cooldown = 0.0
	a.activate()
	assert_lt(player.health.hp, 20, "the seventh costs HP")

func test_the_life_arrow_leaves_you_at_one_hp() -> void:
	player.health.hp = 15
	arena.verb("undead_arash").activate()
	assert_eq(player.health.hp, 1)

func test_the_huntsmans_arrows_home_on_one_mark() -> void:
	lizard.global_position = Vector2(150, 0)
	var a := arena.verb("undead_wild_huntsman")
	a.activate()
	assert_true(lizard.has_meta("verb_hunted"))
	lizard.global_position = Vector2(400, 0)
	a._cooldown = 0.0
	a.activate()
	assert_lt(lizard.health.hp, 1000)

func test_three_barks_and_a_lunge() -> void:
	lizard.global_position = Vector2(180, 0)
	var a := arena.verb("wolf_cu_sith")
	a.activate()
	assert_true(player.is_held_still(), "stand still to bark")
	for i in 2:
		a._cooldown = 0.0
		a.activate()
	assert_lt(lizard.health.hp, 1000, "the third is the lunge")

func test_the_cap_needs_blood_to_dye_it() -> void:
	var a := arena.verb("goblin_bloodcap")
	assert_false(a.ready(), "needs blood")
	arena.rules.handle_event(Events.ABSORBED, {"essence": "blood", "source": "test"})
	assert_true(a.ready())
	a.activate()
	await wait_seconds(0.6)
	assert_eq(_hits(), 2, "out and back")
	assert_eq(arena.rules.held("blood"), 0)

func test_the_blessed_throw_is_holy_and_behind_a_shield() -> void:
	arena.verb("goblin_paladin").activate()
	assert_eq(arena.foes[0].hits[0][1], "holy")
	assert_eq(player.rage.percent_off("fire"), 40, "the shield")

func test_hurl_needs_loose_objects() -> void:
	var a := arena.verb("poltergeist")
	assert_false(a.ready(), "needs loose objects")
	var rock := Rubble.new()
	add_child_autofree(rock)
	rock.global_position = Vector2(30, 0)
	assert_true(a.ready())
	a.activate()
	assert_eq(_hits(), 1)
	assert_eq(get_tree().get_nodes_in_group("loose").size(), 0)
