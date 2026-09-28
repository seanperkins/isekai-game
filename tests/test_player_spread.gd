extends GutTest
## The Player wears the rig, and Spread: flatten on the floor with the aim straight down.

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

func _solid(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	return body

func _floor() -> void:
	_solid(Rect2(-300, Player.BODY_BOTTOM, 600, 20))

func test_spread_wants_the_floor_and_a_straight_down_aim() -> void:
	assert_true(Player.wants_spread(true, Vector2.DOWN, 1.0, false))
	assert_false(Player.wants_spread(false, Vector2.DOWN, 1.0, false))
	assert_false(Player.wants_spread(true, Vector2(1, 1).normalized(), 0.7, false))
	assert_false(Player.wants_spread(true, Vector2.DOWN, 0.4, false))

func test_once_spread_it_holds_while_down_stays_pressed() -> void:
	assert_true(Player.wants_spread(true, Vector2(1, 1).normalized(), 0.7, true))
	assert_false(Player.wants_spread(true, Vector2.RIGHT, 0.1, true))
	assert_false(Player.wants_spread(false, Vector2.DOWN, 1.0, true))

func test_spread_shrinks_the_collision_box_and_keeps_its_bottom_on_the_floor() -> void:
	var s := float(BodyConfig.SCALE)
	assert_eq(player._rect.size, BodyConfig.COLLISION * s)
	assert_almost_eq(player._shape.position.y + player._rect.size.y / 2.0, Player.BODY_BOTTOM, 0.001)
	player.set_spread(true)
	assert_true(player.spreading)
	assert_eq(player._rect.size, BodyConfig.SPREAD_COLLISION * s)
	assert_almost_eq(player._shape.position.y + player._rect.size.y / 2.0, Player.BODY_BOTTOM, 0.001)
	player.set_spread(false)
	assert_eq(player._rect.size, BodyConfig.COLLISION * s)

func test_spread_halves_the_walking_speed() -> void:
	var normal := player._walk_speed()
	player.set_spread(true)
	assert_almost_eq(player._walk_speed(), normal * Player.SPREAD_SPEED, 0.001)

func test_no_jump_or_stand_under_a_low_ceiling() -> void:
	_floor()
	await wait_physics_frames(6)
	Input.action_press("aim_down")  # hold down, so the slime really is spread when it tries to jump
	await wait_physics_frames(3)
	assert_true(player.spreading)
	var rise := (BodyConfig.COLLISION.y - BodyConfig.SPREAD_COLLISION.y) * BodyConfig.SCALE
	var top := Player.BODY_BOTTOM - BodyConfig.SPREAD_COLLISION.y * BodyConfig.SCALE
	var ceiling := _solid(Rect2(-40, top - rise / 2.0 - 4.0, 80, 4.0))
	await wait_physics_frames(2)
	assert_false(player._can_stand())
	player.do_jump()
	assert_true(player.spreading)
	assert_eq(player.velocity.y, 0.0)
	ceiling.free()
	await wait_physics_frames(2)
	assert_true(player._can_stand())
	assert_true(player.spreading)  # still held down: the jump itself must do the standing
	player.do_jump()
	Input.action_release("aim_down")
	assert_false(player.spreading)
	assert_lt(player.velocity.y, 0.0)

func test_the_wall_grip_faces_the_wall() -> void:
	# a wall on the left has its normal pointing right, so the slime (facing right) must flip
	assert_true(player._faces_left("wall", Vector2.RIGHT))
	assert_false(player._faces_left("wall", Vector2.LEFT))
	player.facing = -1
	assert_true(player._faces_left("idle", Vector2.ZERO))
	player.facing = 1
	assert_false(player._faces_left("idle", Vector2.ZERO))

func test_every_room_exit_fits_the_rigged_slime() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var body := BodyConfig.COLLISION * float(BodyConfig.SCALE)
	for id in rooms:
		for e in (rooms[id] as RoomDef).exits:
			var span := float(e["to"]) - float(e["from"])
			var needed := body.y if e["edge"] == "left" or e["edge"] == "right" else body.x
			assert_gte(span, needed + 8.0, "%s %s exit" % [id, e["edge"]])
