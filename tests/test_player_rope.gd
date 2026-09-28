extends GutTest
## The real slime on a rope: swinging stays on the rope, Jump lets go with a boost,
## firing again re-aims, and Swing Thread takes over Sticky Thread's slot.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func test_attaching_draws_the_thread_and_hanging_stays_on_the_rope() -> void:
	player.global_position = Vector2(60, 0)
	player.attach_rope(Vector2(0, -80), 120.0, 60.0, 1.0)
	assert_not_null(player.rope)
	await wait_physics_frames(30)
	assert_lte(player.global_position.distance_to(Vector2(0, -80)), player.rope.length + 1.0)
	assert_true(player.rope_line.visible)
	assert_eq(player.rope_line.points[1], Vector2(0, -80))

func test_jump_lets_go_with_boosted_momentum() -> void:
	player.attach_rope(player.global_position + Vector2(0, -80), 200.0, 120.0, 1.4)
	player.velocity = Vector2(200, 0)
	player.do_jump()
	assert_null(player.rope)
	assert_false(player.rope_line.visible)
	assert_eq(player.velocity, Vector2(280, Rope.RELEASE_LIFT))

func test_attaching_again_re_aims() -> void:
	player.attach_rope(Vector2(0, -80), 120.0, 60.0, 1.0)
	player.attach_rope(Vector2(40, -60), 120.0, 60.0, 1.0)
	assert_eq(player.rope.anchor, Vector2(40, -60))

func test_a_new_run_drops_the_rope() -> void:
	player.attach_rope(Vector2(0, -80), 120.0, 60.0, 1.0)
	rules.start_run()
	assert_null(player.rope)

func test_swing_thread_takes_over_sticky_threads_slot() -> void:
	player.skillset.slots.add("poison_breath")
	player.skillset.slots.add("sticky_thread")
	player.skillset.on_skill_unlocked("swing_thread")
	assert_eq(player.skillset.slots.slots, ["poison_breath", "swing_thread", "", ""])
	assert_false(player.skillset.slots.owned.has("sticky_thread"))

func _floor_under_player() -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(0, 26)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(800, 40)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func test_a_roped_slime_on_the_ground_walks_and_stops_normally() -> void:
	_floor_under_player()
	await wait_physics_frames(10)
	assert_true(player.is_on_floor())
	player.attach_rope(player.global_position + Vector2(0, -100), 120.0, 60.0, 1.0)
	Input.action_press("move_right")
	await wait_physics_frames(10)
	Input.action_release("move_right")
	await wait_physics_frames(2)
	assert_eq(player.velocity.x, 0.0)

func test_jumping_off_the_ground_while_roped_is_a_full_jump() -> void:
	_floor_under_player()
	await wait_physics_frames(10)
	player.attach_rope(player.global_position + Vector2(0, -100), 120.0, 60.0, 1.0)
	player.do_jump()
	assert_null(player.rope)
	assert_eq(player.velocity.y, Player.JUMP_VELOCITY)
