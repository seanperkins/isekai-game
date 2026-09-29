extends GutTest
## The Player draws the slime's frames: the right frame for the state, standing on the floor line,
## mirrored when facing left, with shapes that follow. Without the sheet it falls back to the old sprite.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	Input.action_release("aim_down")

func _floor() -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(0, Player.BODY_BOTTOM + 10)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(600, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _sprite() -> Sprite2D:
	return player.get_node("Sprite")

func test_it_starts_on_the_idle_frame() -> void:
	assert_eq(_sprite().texture, player._sheet.frame_texture("idle_1"))
	assert_eq(_sprite().scale, Vector2.ONE)

func test_the_frame_follows_the_state_and_stands_on_the_floor_line() -> void:
	_floor()
	await wait_physics_frames(12)  # the 0.12 s land squash must be over before we expect idle
	player._update_visual(0.016)
	var idle_size := player._sheet.frame_size("idle_1")
	assert_eq(_sprite().texture, player._sheet.frame_texture("idle_1"))
	assert_almost_eq(_sprite().position.y + idle_size.y / 2.0, Player.BODY_BOTTOM, 0.001)
	player.velocity = Vector2(0, -200)
	player.global_position.y -= 30.0
	await wait_physics_frames(1)
	player._update_visual(0.016)
	assert_eq(_sprite().texture, player._sheet.frame_texture("rise"))
	assert_almost_eq(_sprite().position.y + player._sheet.frame_size("rise").y / 2.0, Player.BODY_BOTTOM, 0.001)

func test_holding_down_spreads_and_letting_go_plays_the_exit() -> void:
	_floor()
	await wait_physics_frames(12)
	Input.action_press("aim_down")
	await wait_physics_frames(4)
	assert_true(player.spreading)
	for i in 6:
		player._update_visual(0.05)
	assert_eq(_sprite().texture, player._sheet.frame_texture("spread_2"))
	Input.action_release("aim_down")
	await wait_physics_frames(1)
	assert_false(player.spreading)
	assert_eq(player._animator.state(), "idle")
	var exit_frames := [player._sheet.frame_texture("spread_2"), player._sheet.frame_texture("spread_1")]
	assert_true(exit_frames.has(_sprite().texture), "the un-squash plays the spread frames in reverse first")
	for i in 6:
		player._update_visual(0.05)
	assert_eq(_sprite().texture, player._sheet.frame_texture("idle_1"))

func test_facing_left_mirrors_the_sprite_and_the_shapes() -> void:
	_floor()
	await wait_physics_frames(12)
	player.facing = -1
	player._update_visual(0.016)
	assert_true(_sprite().flip_h)
	assert_eq(player._shapes.hurt_poly.polygon[0].x, -player._sheet.hurt("idle_1")[0].x)
	player.facing = 1
	player._update_visual(0.016)
	assert_false(_sprite().flip_h)

func test_the_wall_grip_is_mirrored_from_the_wall_not_from_facing() -> void:
	assert_true(player._faces_left("wall", Vector2.RIGHT))
	assert_false(player._faces_left("wall", Vector2.LEFT))

func test_the_shapes_follow_the_frame() -> void:
	_floor()
	await wait_physics_frames(12)
	player._update_visual(0.016)
	assert_eq(player._shapes.hurt_poly.polygon, player._sheet.hurt("idle_1"))
	player._tackle_time = 0.1
	player._update_visual(0.016)
	assert_false(player._shapes.attack_poly.disabled)

func test_the_player_falls_back_without_the_sheet() -> void:
	var bare := Player.new()
	bare.use_sheet = false
	bare.setup(rules, CompendiumModel.new([], []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(bare)
	assert_null(bare._sheet)
	var s: Sprite2D = bare.get_node("Sprite")
	bare._update_visual(0.016)
	assert_eq(s.scale, Vector2(BodyConfig.SCALE, BodyConfig.SCALE))
	assert_not_null(s.texture)
