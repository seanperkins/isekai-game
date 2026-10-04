extends GutTest

var sb: MovementSandbox

func before_each() -> void:
	sb = load("res://scenes/movement_sandbox.tscn").instantiate()
	add_child_autofree(sb)
	sb.scripted = MoveInput.new()
	await _frames(3)  # the body settles onto the floor

func _frames(n: int) -> void:
	for _k in n:
		await get_tree().physics_frame

## One scripted jump: the press is consumed by the sandbox, the button stays down for `held` frames, then up.
func _jump(held: int, total: int) -> float:
	var floor_y := sb.body.global_position.y
	var highest := floor_y
	sb.scripted.jump_pressed = true
	sb.scripted.jump_held = true
	for k in total:
		await get_tree().physics_frame
		highest = minf(highest, sb.body.global_position.y)
		if k == held - 1:
			sb.scripted.jump_held = false
	return floor_y - highest

func test_it_starts_as_the_slime() -> void:
	assert_eq(sb.profile.id, "slime")

func test_a_slime_jump_rises_like_the_sim_and_the_state_follows_the_body() -> void:
	var seen := await _jump(30, 90)
	assert_gt(seen, 40.0, "left the floor")
	assert_true(sb.body.is_on_floor())
	assert_almost_eq(sb.last_jump()["rise"], 63.25, 3.0)
	assert_almost_eq(sb.state.velocity.y, 0.0, 0.001, "the landing zeroed the step's state too")

func test_the_boost_key_raises_the_jump() -> void:
	sb.set_boost(true)
	await _jump(40, 110)
	assert_gt(sb.last_jump()["rise"], 100.0)

func test_the_wolf_outruns_the_biped() -> void:
	sb.scripted.dir = 1.0
	sb.set_profile("wolf")
	var top := 0.0
	for _k in 40:
		await get_tree().physics_frame
		top = maxf(top, absf(sb.body.velocity.x))
	assert_gt(top, 200.0)
	sb.set_profile("biped")
	assert_eq(sb.body.velocity, Vector2.ZERO, "no momentum carries over a switch")
	top = 0.0
	for _k in 40:
		await get_tree().physics_frame
		top = maxf(top, absf(sb.body.velocity.x))
	assert_lt(top, 140.5)

func test_the_body_cannot_run_off_either_end_of_the_floor() -> void:
	sb.scripted.dir = -1.0
	sb.set_profile("wolf")
	await _frames(150)
	assert_true(sb.body.is_on_floor(), "stopped by the left wall")
	assert_gte(sb.body.global_position.x, 0.0)
	sb.body.global_position = Vector2(1350.0, -12.0)
	sb.scripted.dir = 1.0
	await _frames(150)
	assert_true(sb.body.is_on_floor(), "stopped by the right wall")
	assert_lte(sb.body.global_position.x, 1400.0)

func test_the_camera_follows_the_body_along_the_floor() -> void:
	sb.body.global_position = Vector2(1000.0, -12.0)
	await _frames(3)
	var cam := sb.get_node("Camera") as Camera2D
	assert_almost_eq(cam.global_position.x, 1000.0, 1.0)

func _has_art(id: String) -> bool:
	return SpeciesLook.has_look(id) and SpeciesLook.sheet_for(id) != null

func test_each_species_with_art_shows_its_sprite_and_the_biped_a_placeholder() -> void:
	for id in ["slime", "spider", "wolf"]:
		sb.set_profile(id)
		assert_eq(sb.look(), id if _has_art(id) else "placeholder", id)
	sb.set_profile("biped")
	assert_eq(sb.look(), "placeholder")
	assert_eq(sb.clip(), "")

func test_the_clip_follows_the_movement() -> void:
	if not _has_art("wolf"):
		pending("the wolf sheet is not imported")
		return
	sb.set_profile("wolf")
	await _frames(3)
	assert_eq(sb.clip(), "idle")
	sb.scripted.dir = 1.0
	await _frames(40)
	assert_eq(sb.clip(), "charge")
	sb.scripted.jump_pressed = true
	sb.scripted.jump_held = true
	await _frames(6)
	assert_eq(sb.clip(), "windup")

func test_the_feet_stay_on_the_floor_for_every_sheet_and_a_switch_mid_run_is_clean() -> void:
	sb.scripted.dir = 1.0
	for id in ["slime", "spider", "wolf", "biped", "spider"]:
		sb.set_profile(id)  # switching while running
		await _frames(30)
		sb.scripted.dir = 0.0
		await _frames(30)
		if sb.look() != "placeholder":
			var sprite := sb.get_node("Sprite") as Sprite2D
			var half := sprite.texture.get_size().y * sprite.scale.y / 2.0
			assert_almost_eq(sprite.global_position.y + half, sb.body.global_position.y + BodyConfig.BOTTOM, 1.0, id)
		sb.scripted.dir = 1.0

func test_key_four_picks_the_spider() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_4
	ev.pressed = true
	sb._unhandled_key_input(ev)
	assert_eq(sb.profile.id, "spider")

func after_each() -> void:
	for action in ["move_right", "aim_down", "tackle"]:
		Input.action_release(action)

func _box_size() -> Vector2:
	return ((sb.body.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size

func test_down_flattens_the_collision_box_and_releasing_stands_it_up() -> void:
	assert_eq(_box_size(), BodyConfig.size())
	sb.scripted.down = 1.0
	await _frames(5)
	assert_eq(_box_size(), BodyConfig.spread_size())
	sb.scripted.down = 0.0
	await _frames(5)
	assert_eq(_box_size(), BodyConfig.size())

func test_a_flat_slime_fits_the_tunnel_and_a_standing_one_does_not() -> void:
	sb.body.global_position = Vector2(850.0, -12.0)
	sb.scripted.dir = 1.0
	await _frames(60)
	assert_lt(sb.body.global_position.x, 890.0, "standing, it stops at the tunnel mouth")
	sb.scripted.down = 1.0
	await _frames(120)
	assert_gt(sb.body.global_position.x, 950.0, "flat, it crawls in")

func test_inside_the_tunnel_it_stays_flat_with_down_released() -> void:
	sb.scripted.down = 1.0
	await _frames(3)
	sb.body.global_position = Vector2(1000.0, -12.0)
	await _frames(3)
	sb.scripted.down = 0.0
	await _frames(10)
	assert_eq(_box_size(), BodyConfig.spread_size())
	assert_true(sb.state.spread)

func test_real_input_starts_a_tackle() -> void:
	sb.scripted = null
	Input.action_press("move_right")
	await _frames(15)
	Input.action_press("tackle")
	await _frames(2)
	Input.action_release("tackle")
	assert_eq(sb.state.verb, "tackle")

func test_real_input_starts_a_puddle_slide() -> void:
	sb.scripted = null
	Input.action_press("move_right")
	await _frames(20)
	Input.action_press("aim_down")
	await _frames(3)
	assert_eq(sb.state.verb, "puddle")

func test_holding_jump_after_a_long_fall_bounces_several_times() -> void:
	sb.body.global_position = Vector2(680.0, -300.0)  # above the 100 px ledge
	sb.scripted.jump_held = true
	var bounces := 0
	for _k in 300:
		await get_tree().physics_frame
		if sb.state.launched == "bounce":
			bounces += 1
	assert_between(bounces, 3, 6)
