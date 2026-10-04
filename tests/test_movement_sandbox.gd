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
