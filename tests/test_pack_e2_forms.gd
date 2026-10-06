extends GutTest
## The shipped world verbs of Pack E2 (tiamat, beanstalk, ariadne, slime mold, talos, cube), cast for real.

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	player = arena.player
	lizard = arena.lizard
	lizard.global_position = Vector2(900, 0)
	player._invuln = 1000.0
	await wait_physics_frames(3)
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for g in ["verb_floods", "verb_vines", "verb_trails", "verb_networks", "deep_water", "climbables", "verb_fields"]:
		for n in get_tree().get_nodes_in_group(g):
			n.free()
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_flood_is_real_water() -> void:
	arena.verb("tiamat").activate()
	await wait_physics_frames(3)
	assert_not_null(DeepWater.at(get_tree(), Vector2(0, 0)))

func test_stalk_grows_slowly_and_is_climbable() -> void:
	arena.verb("beanstalk").activate()
	var vine: VerbVine = get_tree().get_nodes_in_group("verb_vines")[0]
	assert_lt(vine.grown(), 30.0, "slow to grow")
	assert_true(vine.is_in_group("climbables"))

func test_recall_must_lay_the_trail_first() -> void:
	var a := arena.verb("ariadne")
	a.activate()
	assert_eq(get_tree().get_nodes_in_group("verb_trails").size(), 1)

func test_the_network_begins_small_and_creeps() -> void:
	arena.verb("slime_mold").activate()
	var net: VerbNetwork = get_tree().get_nodes_in_group("verb_networks")[0]
	assert_lt(net.current_radius(), 60.0)

func test_the_guardian_has_a_nail() -> void:
	arena.verb("talos").activate()
	player.facing = 1
	player.health.hp = player.health.max_hp
	player._invuln = 0.0
	player.receive_hit(1, "physical", Vector2(-60, 0))
	assert_lt(player.health.hp, player.health.max_hp - 2, "hit from behind it drains")

func test_the_cube_swallows_a_small_enemy_and_holds_it() -> void:
	lizard.global_position = Vector2(30, 0)
	arena.verb("cube").activate()
	await wait_physics_frames(6)
	assert_lt(lizard.global_position.distance_to(player.global_position), 8.0)
	assert_lt(int(load("res://data/forms/cube.tres").stats.get("jump_height", 0)), 0, "a low jump")
