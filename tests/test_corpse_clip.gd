extends GutTest
## Dying and downed creatures don't block anyone: the slime and other creatures walk through them,
## while they still rest on the floor. A stunned creature is still standing and still blocks.

var rules: SkillRulesEngine
var player: Player
var creatures := {}
var skills := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	var body := StaticBody2D.new()
	body.position = Vector2(0, BodyConfig.BOTTOM + 10)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(800, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func after_each() -> void:
	Input.action_release("move_right")

func _enemy(id: String, dx: float) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills)
	e.position = Vector2(player.global_position.x + dx, BodyConfig.BOTTOM - 6.0)
	add_child_autofree(e)
	return e

func test_the_slime_walks_through_a_corpse_but_not_through_a_stunned_creature() -> void:
	await wait_physics_frames(14)
	var stunned := _enemy("toad", 34.0)
	stunned.set_physics_process(false)
	stunned.status.stun()
	assert_true(player.test_move(player.global_transform, Vector2(30, 0)), "a standing creature blocks")
	stunned.free()
	var corpse := _enemy("toad", 34.0)
	corpse.set_physics_process(false)
	corpse.receive_hit(9999, "physical", Vector2(-10, 0), "other")
	corpse.finish_dying()
	assert_eq(corpse.status.state, EnemyStatus.DOWNED)
	assert_false(player.test_move(player.global_transform, Vector2(30, 0)), "a corpse does not")

func test_the_slime_really_passes_a_corpse() -> void:
	await wait_physics_frames(14)
	var corpse := _enemy("toad", 34.0)
	corpse.receive_hit(9999, "physical", Vector2(-1000, 0), "other")  # a far blow: no knockback
	await wait_physics_frames(2)
	corpse.finish_dying()
	var x0 := player.global_position.x
	Input.action_press("move_right")
	await wait_physics_frames(60)
	assert_gt(player.global_position.x, corpse.global_position.x + 10.0, "walked right past it")
	assert_gt(player.global_position.x, x0 + 40.0)

func test_a_creature_walks_through_another_creatures_corpse() -> void:
	await wait_physics_frames(14)
	var corpse := _enemy("toad", 60.0)
	corpse.set_physics_process(false)
	corpse.receive_hit(9999, "physical", Vector2(-10, 0), "other")
	corpse.finish_dying()
	var walker := _enemy("lizard", 20.0)
	walker.set_physics_process(false)
	assert_false(walker.test_move(walker.global_transform, Vector2(40, 0)), "no block")
	var live := _enemy("toad", 90.0)
	live.set_physics_process(false)
	assert_true(walker.test_move(walker.global_transform, Vector2(60, 0)), "a living creature still blocks another")

func test_a_corpse_still_rests_on_the_floor() -> void:
	await wait_physics_frames(14)
	var corpse := _enemy("toad", 34.0)
	corpse.receive_hit(9999, "physical", Vector2(-1000, 0), "other")
	await wait_physics_frames(2)
	corpse.finish_dying()
	await wait_physics_frames(30)
	assert_true(corpse.is_on_floor())
	assert_almost_eq(corpse.global_position.y, BodyConfig.BOTTOM - 6.0, 1.5)

func test_a_dying_creature_is_clippable_from_the_first_frame() -> void:
	await wait_physics_frames(14)
	var e := _enemy("toad", 34.0)
	e.set_physics_process(false)
	e.receive_hit(9999, "physical", Vector2(-10, 0), "poison")
	assert_eq(e.status.state, EnemyStatus.DYING)
	assert_false(player.test_move(player.global_transform, Vector2(30, 0)))
