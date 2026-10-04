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

# --- the wolf: pounce, vault, skid ---

func _wolf_at(pos: Vector2, vx := 0.0, dir := 0.0) -> void:
	sb.set_profile("wolf")
	sb.body.global_position = pos
	sb.state.velocity.x = vx
	sb.scripted.dir = dir
	await _frames(2)

func _pounce(aim: Vector2) -> void:
	sb.scripted.aim = aim
	sb.scripted.signature_pressed = true

func test_a_wolf_gallops_up_to_the_low_step_and_vaults_it() -> void:
	await _wolf_at(Vector2(95.0, -12.0), -200.0, -1.0)
	var vaulted_at := -1
	var highest := 0.0
	for k in 40:
		await get_tree().physics_frame
		if sb.state.launched == "vault" and vaulted_at < 0:
			vaulted_at = k
			assert_gte(absf(sb.state.velocity.x), 150.0, "the speed is kept through the hop")
		highest = minf(highest, sb.body.global_position.y)
	assert_gte(vaulted_at, 0, "it hopped with no jump press")
	assert_lt(highest, -12.0 - 10.0, "the body rose over the 16 px step")
	assert_lt(sb.body.global_position.x, 45.0, "and got past its near edge instead of stopping at it")

func test_a_slow_wolf_stops_at_the_low_step_like_any_wall() -> void:
	await _wolf_at(Vector2(95.0, -12.0), -100.0, -0.43)  # the stick scales the target: about 100 px/s
	for _k in 40:
		await get_tree().physics_frame
		assert_ne(sb.state.launched, "vault")
	assert_almost_eq(sb.body.global_position.x, 45.0 + 14.0, 3.0)

func test_a_40_px_ledge_is_not_vaulted_at_any_speed() -> void:
	await _wolf_at(Vector2(365.0, -12.0), 200.0, 1.0)
	for _k in 50:
		await get_tree().physics_frame
		assert_ne(sb.state.launched, "vault")
	assert_almost_eq(sb.body.global_position.x, 400.0 - 14.0, 3.0)

func test_the_pounce_leaps_along_the_aim_and_lands() -> void:
	await _wolf_at(Vector2(100.0, -12.0))
	_pounce(Vector2(1.0, -1.0).normalized())
	await _frames(1)
	assert_eq(sb.state.verb, "pounce")
	assert_almost_eq(sb.state.velocity.length(), 300.0, 5.0)
	await _frames(2)
	assert_false(sb.body.is_on_floor(), "it left the floor")
	var end := 0
	while sb.state.verb == "pounce" and end < 60:
		await get_tree().physics_frame
		end += 1
	assert_between(end, 17, 21, "about 0.35 s")
	var again := 0
	while sb.state.verb != "pounce" and again < 80:
		sb.scripted.aim = Vector2.RIGHT
		sb.scripted.signature_pressed = true
		await get_tree().physics_frame
		again += 1
	assert_between(again, 44, 52, "0.8 s after the end, not before")
	assert_true(sb.body.is_on_floor() or sb.state.verb == "pounce")

func test_the_pounce_marks_the_dummy() -> void:
	await _wolf_at(Vector2(80.0, -12.0))
	assert_false(sb.state.pounce_hit)
	_pounce(Vector2.RIGHT)
	await _frames(30)
	assert_true(sb.state.pounce_hit, "the leap reached the dummy at x 120 to 140")

func test_the_pounce_ends_at_a_wall() -> void:
	await _wolf_at(Vector2(250.0, -12.0))
	_pounce(Vector2.RIGHT)
	var ticks := 0
	for _k in 30:
		await get_tree().physics_frame
		if sb.state.verb == "pounce":
			ticks += 1
	assert_between(ticks, 3, 12, "it ended on the slick block's wall, not after 0.35 s")
	assert_almost_eq(sb.body.global_position.x, 300.0 - 14.0, 4.0)

func test_a_reversal_at_a_gallop_skids_with_dust_and_a_lean() -> void:
	await _wolf_at(Vector2(100.0, -12.0), 0.0, 1.0)
	await _frames(30)
	assert_gt(sb.state.velocity.x, 200.0)
	sb.scripted.dir = -1.0
	var skid_frames := 0
	var leaned := 0.0
	for _k in 8:
		await get_tree().physics_frame
		if sb.state.skidding:
			skid_frames += 1
			leaned = minf(leaned, _sprite().rotation)
	assert_gte(skid_frames, 2, "the reversal skids")
	assert_lt(leaned, -0.05, "it leans back, nose up, going right")
	assert_gt(get_tree().get_nodes_in_group("dust").size(), 0, "dust")
	sb.scripted.dir = 0.0
	await _frames(40)
	assert_eq(get_tree().get_nodes_in_group("dust").size(), 0, "faded away")
	assert_almost_eq(_sprite().rotation, 0.0, 0.05, "upright again")

func test_the_pounce_pose_follows_the_leap() -> void:
	if not _has_art("wolf"):
		pending("the wolf sheet is not imported")
		return
	await _wolf_at(Vector2(100.0, -12.0))
	_pounce(Vector2(1.0, -1.0).normalized())
	await _frames(8)
	assert_eq(sb.state.verb, "pounce")
	var v := sb.state.velocity
	assert_almost_eq(_sprite().rotation, atan2(v.y, absf(v.x)), 0.3, "nose along the velocity")
	assert_false(_sprite().flip_h)
	assert_eq(sb.clip(), "windup")
	await _frames(100)  # lands, and the 0.8 s wait is over
	_pounce(Vector2(-1.0, -1.0).normalized())
	await _frames(8)
	assert_eq(sb.state.verb, "pounce")
	v = sb.state.velocity
	assert_true(_sprite().flip_h, "mirrored going left")
	assert_almost_eq(_sprite().rotation, -atan2(v.y, absf(v.x)), 0.3)

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

func test_a_falling_slime_sticks_then_slides_down_the_left_wall() -> void:
	sb.body.global_position = Vector2(15.0, -250.0)
	sb.scripted.dir = -1.0
	await _frames(8)
	assert_lte(sb.body.velocity.y, 16.0, "stuck")
	assert_eq(sb.clip(), "wall")
	assert_true((sb.get_node("Sprite") as Sprite2D).flip_h, "a wall on the left is gripped facing left")
	await _frames(25)
	assert_almost_eq(sb.body.velocity.y, 90.0, 1.0, "sliding")

func test_a_jump_from_the_wall_kicks_off_and_up() -> void:
	sb.body.global_position = Vector2(15.0, -250.0)
	sb.scripted.dir = -1.0
	await _frames(12)  # long enough for the coyote time the floor left behind to run out
	sb.scripted.jump_pressed = true
	var launched := false
	var best_vx := 0.0
	var best_vy := 0.0
	for _k in 6:
		await get_tree().physics_frame
		launched = launched or sb.state.launched == "wall"
		best_vx = maxf(best_vx, sb.body.velocity.x)
		best_vy = minf(best_vy, sb.body.velocity.y)
	assert_true(launched)
	assert_gt(best_vx, 100.0)
	assert_lt(best_vy, -300.0)

func test_holding_jump_into_the_wall_bounces_off_it() -> void:
	sb.body.global_position = Vector2(80.0, -350.0)
	sb.state.velocity.x = -140.0
	sb.scripted.dir = -1.0
	sb.scripted.jump_held = true
	var bounced := false
	for _k in 80:
		await get_tree().physics_frame
		if sb.state.wall_bounced:
			bounced = true
			break
	assert_true(bounced, "it bounced")
	await _frames(2)
	assert_gt(sb.body.velocity.x, 50.0)
	assert_ne(sb.clip(), "wall")

func test_the_shaft_wall_is_solid() -> void:
	sb.body.global_position = Vector2(1230.0, -12.0)
	sb.scripted.dir = 1.0
	await _frames(60)
	assert_lt(sb.body.global_position.x, 1247.0)

func _sprite() -> Sprite2D:
	return sb.get_node("Sprite") as Sprite2D

func test_a_plain_landing_still_squashes() -> void:
	sb.body.global_position = Vector2(100.0, -150.0)
	var low := 1.0
	var land_seen := false
	for _k in 60:
		await get_tree().physics_frame
		low = minf(low, _sprite().scale.y)
		land_seen = land_seen or sb.clip() == "land"
	assert_lt(low, 0.97)
	assert_true(land_seen)

func test_a_timed_rebound_lands_as_a_ball_not_a_squash() -> void:
	sb.body.global_position = Vector2(100.0, -200.0)
	var pressed := false
	var launch_frame := -1
	var low := 9.0
	var ball_seen := false
	var shots: Array[Image] = []
	var round_ok := true
	for k in 120:
		await get_tree().physics_frame
		if not pressed and sb.body.velocity.y > 0.0 and sb.body.global_position.y > -42.0:
			sb.scripted.jump_pressed = true  # within 30 px of the floor and falling
			pressed = true
		if launch_frame < 0 and sb.state.launched == "rebound":
			launch_frame = k
		if launch_frame >= 0 and k - launch_frame <= 4:
			low = minf(low, _sprite().scale.y)
			if sb.clip() == "ball":
				ball_seen = true
				shots.append(_sprite().texture.get_image())
				round_ok = round_ok and _sprite().scale == Vector2.ONE and _sprite().rotation == 0.0 \
					and shots.back().get_size() == Vector2i(SlimeBall.SIZE, SlimeBall.SIZE)
	assert_gte(launch_frame, 0, "it rebounded")
	assert_true(ball_seen)
	assert_true(round_ok, "a round ball the size of the slime, never stretched, squashed or turned")
	assert_gte(shots.size(), 2)
	assert_true(shots[0].get_data() != shots[shots.size() - 1].get_data(), "the eyes roll")
	assert_gte(low, 0.999, "never squashed")

func test_a_hold_bounce_is_a_ball_too() -> void:
	sb.body.global_position = Vector2(100.0, -300.0)
	sb.scripted.jump_held = true
	var launch_frame := -1
	var ball_seen := false
	for k in 120:
		await get_tree().physics_frame
		if launch_frame < 0 and sb.state.launched == "bounce":
			launch_frame = k
		if launch_frame >= 0 and k - launch_frame <= 2 and sb.clip() == "ball":
			ball_seen = true
	assert_gte(launch_frame, 0)
	assert_true(ball_seen)

func test_a_late_press_swaps_the_squash_for_the_ball() -> void:
	sb.body.global_position = Vector2(100.0, -200.0)
	var landed := -1
	var launch_frame := -1
	var ball_seen := false
	var low := 9.0
	for k in 120:
		await get_tree().physics_frame
		if landed < 0 and sb.body.is_on_floor():
			landed = k
		if landed >= 0 and k == landed + 2:
			sb.scripted.jump_pressed = true
		if launch_frame < 0 and sb.state.launched == "rebound":
			launch_frame = k
		if launch_frame >= 0 and k - launch_frame >= 2 and k - launch_frame <= 3:
			low = minf(low, _sprite().scale.y)
			ball_seen = ball_seen or sb.clip() == "ball"
	assert_gte(launch_frame, 0, "a press 2 frames after landing still rebounds")
	assert_true(ball_seen)
	assert_gte(low, 0.999, "the squash gave way to the ball")

func test_the_ball_ends_when_the_bouncing_does() -> void:
	sb.body.global_position = Vector2(100.0, -300.0)
	sb.scripted.jump_held = true
	await _frames(40)
	sb.scripted.jump_held = false
	await _frames(250)
	assert_eq(sb.clip(), "idle")
	assert_ne(_sprite().texture.get_size(), Vector2(SlimeBall.SIZE, SlimeBall.SIZE), "the slime's own frame is back")

func test_a_moving_flat_slime_wobbles_and_a_still_one_does_not() -> void:
	sb.scripted.down = 1.0
	await _frames(5)
	sb.scripted.dir = 1.0
	var lo := 9.0
	var hi := 0.0
	for _k in 40:
		await get_tree().physics_frame
		lo = minf(lo, _sprite().scale.x)
		hi = maxf(hi, _sprite().scale.x)
	assert_gt(hi - lo, 0.1, "it wobbles as it crawls")
	sb.scripted.dir = 0.0
	await _frames(30)
	lo = 9.0
	hi = 0.0
	for _k in 10:
		await get_tree().physics_frame
		lo = minf(lo, _sprite().scale.x)
		hi = maxf(hi, _sprite().scale.x)
	assert_lt(hi - lo, 0.01, "still, it is still")

func test_switching_species_mid_bounce_leaves_nothing_of_the_ball_behind() -> void:
	sb.body.global_position = Vector2(100.0, -300.0)
	sb.scripted.jump_held = true
	for _k in 120:
		await get_tree().physics_frame
		if sb.clip() == "ball":
			break
	assert_eq(sb.clip(), "ball")
	sb.set_profile("wolf")
	await _frames(3)
	assert_eq(sb.look(), "wolf")
	assert_ne(sb.clip(), "ball")
	assert_eq(_sprite().scale, Vector2.ONE)
	assert_eq(_sprite().rotation, 0.0)

func test_a_wall_bounce_shows_the_ball_not_the_tackle() -> void:
	sb.body.global_position = Vector2(50.0, -350.0)
	sb.scripted.dir = -1.0
	sb.scripted.jump_held = true
	sb.scripted.signature_pressed = true
	var bounced := -1
	var ball_seen := false
	for k in 40:
		await get_tree().physics_frame
		if bounced < 0 and sb.state.wall_bounced:
			bounced = k
		if bounced >= 0 and k - bounced <= 3 and sb.clip() == "ball":
			ball_seen = true
		if bounced >= 0 and k - bounced <= 3:
			assert_ne(sb.state.verb, "tackle", "the bounce ended the tackle")
	assert_gte(bounced, 0, "it tackled into the wall and bounced")
	assert_true(ball_seen)

func test_the_ball_lasts_the_whole_flight_and_ends_at_the_plain_landing() -> void:
	sb.body.global_position = Vector2(100.0, -200.0)
	var pressed := false
	var launch_frame := -1
	var flight := 0
	var ball_frames := 0
	var after := ""
	for k in 220:
		await get_tree().physics_frame
		if not pressed and sb.body.velocity.y > 0.0 and sb.body.global_position.y > -42.0:
			sb.scripted.jump_pressed = true
			pressed = true
		if launch_frame < 0 and sb.state.launched == "rebound":
			launch_frame = k
		if launch_frame >= 0 and k - launch_frame >= 2 and not sb.body.is_on_floor() and k - launch_frame < 100:
			flight += 1
			ball_frames += 1 if sb.clip() == "ball" else 0
		if launch_frame >= 0 and k - launch_frame == 150:
			after = sb.clip()
	assert_gte(launch_frame, 0, "it rebounded")
	assert_gte(flight, 15, "a real flight")
	assert_eq(ball_frames, flight, "a ball for the whole flight, rising and falling, not just its start")
	assert_eq(after, "idle", "a plain landing ends the ball")

func test_a_tackle_in_mid_bounce_ends_the_ball() -> void:
	sb.body.global_position = Vector2(100.0, -300.0)
	sb.scripted.jump_held = true
	var bounce_frame := -1
	var verb_seen := false
	var clip_after := ""
	for k in 120:
		await get_tree().physics_frame
		if bounce_frame < 0 and sb.state.launched == "bounce":
			bounce_frame = k
		if bounce_frame >= 0 and k == bounce_frame + 8:
			sb.scripted.signature_pressed = true
		if bounce_frame >= 0 and sb.state.verb == "tackle":
			verb_seen = true
		if bounce_frame >= 0 and k == bounce_frame + 26:
			clip_after = sb.clip()
	assert_true(verb_seen, "it tackled in the air")
	assert_true(clip_after == "rise" or clip_after == "fall", "after the tackle it is the slime again, not the ball: %s" % clip_after)

## The sandbox's spider at `pos`, gripping the floor under it, or the surface `n` it is placed on (no time to fall first).
func _spider_at(pos: Vector2, n := Vector2.ZERO) -> void:
	sb.set_profile("spider")
	sb.body.global_position = pos
	sb.state.surface_n = n
	await _frames(4)

func _normals_seen(frames: int, until: Callable) -> Dictionary:
	var seen := {}
	for _k in frames:
		await get_tree().physics_frame
		seen[sb.state.surface_n] = true
		if until.call():
			break
	return seen

func test_the_spider_goes_over_a_ledge_block_with_one_held_direction() -> void:
	await _spider_at(Vector2(490.0, -12.0))
	assert_eq(sb.state.surface_n, Vector2.UP, "it grips the floor")
	sb.scripted.dir = 1.0
	var seen := await _normals_seen(600, func(): return sb.state.surface_n == Vector2.UP and sb.body.global_position.x > 606.0 and sb.body.global_position.y > -20.0)
	assert_true(seen.has(Vector2.LEFT) and seen.has(Vector2.RIGHT), "up the left face, down the right")
	assert_gt(sb.body.global_position.x, 606.0)
	assert_almost_eq(sb.body.global_position.y, -12.0, 1.5, "back on the floor")

func test_the_spider_rounds_the_pillar_and_slab() -> void:
	_visited = {}
	await _spider_at(Vector2(740.0, -12.0))
	sb.scripted.dir = 1.0
	var seen := await _normals_seen(1200, func(): return seen_all(sb) and sb.state.surface_n == Vector2.UP and sb.body.global_position.x > 810.0 and sb.body.global_position.y > -20.0)
	assert_eq(seen.size(), 4, "floor, wall, ceiling and wall again")
	assert_gt(sb.body.global_position.x, 810.0)

var _visited := {}

func seen_all(box: MovementSandbox) -> bool:
	_visited[box.state.surface_n] = true
	return _visited.size() >= 4

func test_the_spider_hangs_from_the_slab_without_falling() -> void:
	await _spider_at(Vector2(800.0, -138.0), Vector2.DOWN)
	sb.scripted.dir = 1.0
	await _frames(25)
	assert_almost_eq(sb.body.global_position.y, -138.0, 1.5, "it hangs")
	assert_gt(sb.body.global_position.x, 840.0, "and crawls along the underside")

func test_a_hop_off_a_wall_lands_back_on_the_floor() -> void:
	await _spider_at(Vector2(628.0, -60.0), Vector2.LEFT)
	sb.scripted.jump_pressed = true
	await _frames(150)
	assert_eq(sb.state.surface_n, Vector2.UP, "it grips the floor again")
	assert_lt(sb.body.global_position.x, 626.0, "out along the normal, away from the wall")
	assert_almost_eq(sb.body.global_position.y, -12.0, 1.5)

func test_the_one_way_ledge_carries_the_spider_from_above_and_drops_it_at_the_end() -> void:
	await _spider_at(Vector2(200.0, -12.0))
	sb.scripted.jump_pressed = true
	await _frames(70)
	assert_eq(sb.state.surface_n, Vector2.UP)
	assert_almost_eq(sb.body.global_position.y, -62.0, 1.5, "on the ledge's top, hopped through it from below")
	assert_true(sb.state.surface_oneway)
	sb.scripted.dir = 1.0
	var dropped := false
	for _k in 120:
		await get_tree().physics_frame
		if sb.state.surface_event == "ledge_fall":
			dropped = true
			break
	assert_true(dropped, "its end drops the spider")
	await _frames(40)
	assert_eq(sb.state.surface_n, Vector2.UP, "it lands and grips the floor")
	assert_almost_eq(sb.body.global_position.y, -12.0, 1.5, "on the floor")

func test_every_species_still_jumps_its_own_height_on_the_new_terrain() -> void:
	for id in ["biped", "slime", "wolf"]:
		sb.set_profile(id)
		sb.body.global_position = Vector2(100.0, -12.0)
		await _frames(4)
		await _jump(30, 120)
		var want: float = MovementSim.flat_jump(MovementProfile.of(id))["rise"]
		assert_almost_eq(sb.last_jump()["rise"], want, 3.0, id)

func test_the_spider_sprite_follows_the_surface_with_an_ease() -> void:
	await _spider_at(Vector2(628.0, -60.0), Vector2.LEFT)
	await _frames(1)
	assert_lt(absf(_sprite().rotation), PI / 2.0 - 0.05, "it has not snapped")
	await _frames(14)
	assert_almost_eq(_sprite().rotation, -PI / 2.0, 0.05, "and has settled on the wall's angle")

func test_legs_turn_with_distance_and_freeze_when_it_stops() -> void:
	await _spider_at(Vector2(60.0, -12.0))
	sb.scripted.dir = 1.0
	var seen := {}
	for _k in 30:
		await get_tree().physics_frame
		seen[sb.clip()] = true
	assert_gte(seen.size(), 3, "the legs step as it goes: %s" % [seen.keys()])
	sb.scripted.dir = 0.0
	await _frames(3)
	var held := sb.clip()
	assert_true(held.begins_with("crawl_"), "it freezes on a stride frame, no idle animation: %s" % held)
	for _k in 40:
		await get_tree().physics_frame
		assert_eq(sb.clip(), held)

func test_the_spider_does_not_bob_or_squash() -> void:
	await _spider_at(Vector2(60.0, -12.0))
	sb.scripted.dir = 1.0
	for _k in 30:
		await get_tree().physics_frame
		assert_eq(_sprite().scale, Vector2.ONE)

func test_a_reversal_pivots() -> void:
	await _spider_at(Vector2(60.0, -12.0))
	sb.scripted.dir = 1.0
	await _frames(20)
	sb.scripted.dir = -1.0
	var narrowest := 1.0
	for _k in 8:
		await get_tree().physics_frame
		narrowest = minf(narrowest, _sprite().scale.x)
	assert_lt(narrowest, 0.7, "a quick squeeze as it turns")
	await _frames(14)
	assert_eq(_sprite().scale.x, 1.0)

## The zip's thread line.
func _thread() -> Line2D:
	return sb.get_node("Thread") as Line2D

func _fire_zip(aim: Vector2) -> void:
	sb.scripted.aim = aim
	sb.scripted.signature_pressed = true

func test_a_zip_pulls_the_spider_to_a_wall_and_it_grips() -> void:
	await _spider_at(Vector2(850.0, -12.0))  # under the slab, 60 px right of the pillar's right face
	_fire_zip(Vector2.LEFT)
	var started := false
	var gripped := false
	var step_max := 0.0
	var last_x := sb.body.global_position.x
	for _k in 60:
		await get_tree().physics_frame
		started = started or sb.state.zip_event == "start"
		var x := sb.body.global_position.x
		if started and not gripped:
			step_max = maxf(step_max, last_x - x)
		last_x = x
		if sb.state.zip_event == "grip":
			gripped = true
			break
	assert_true(started and gripped, "fired and gripped")
	assert_between(step_max, 6.0, 9.0, "pulled at about 400 px/s (the grip frame adds its 2 px closing the gap to the wall)")
	await _frames(2)
	assert_eq(sb.state.surface_n, Vector2.RIGHT)
	assert_almost_eq(sb.body.global_position.x, 802.0, 2.5, "flush to the pillar's right face")

func test_a_zip_to_the_ceiling_grips_the_underside() -> void:
	await _spider_at(Vector2(830.0, -12.0))
	_fire_zip(Vector2.UP)
	await _frames(40)
	assert_eq(sb.state.surface_n, Vector2.DOWN)
	assert_almost_eq(sb.body.global_position.y, -138.0, 2.0, "hanging from the slab")

func test_nothing_in_range_leaves_the_spider_where_it_is() -> void:
	await _spider_at(Vector2(100.0, -12.0))
	_fire_zip(Vector2.UP)
	var fizzled := false
	for _k in 10:
		await get_tree().physics_frame
		fizzled = fizzled or sb.state.zip_event == "fizzle"
	assert_true(fizzled)
	assert_almost_eq(sb.body.global_position.x, 100.0, 0.5)
	assert_almost_eq(sb.body.global_position.y, -12.0, 1.5)
	assert_eq(sb.state.zip_cooldown, 0.0)

func test_a_jump_cancels_the_zip_in_the_air_with_60_percent_speed() -> void:
	await _spider_at(Vector2(850.0, -12.0))
	_fire_zip(Vector2.LEFT)
	await _frames(4)
	sb.scripted.jump_pressed = true
	var speed := 0.0
	for _k in 4:
		await get_tree().physics_frame
		if sb.state.zip_event == "cancel":
			speed = sb.body.velocity.x
			break
	assert_almost_eq(speed, -240.0, 6.0)

func test_the_thread_shows_while_it_zips_and_fades() -> void:
	await _spider_at(Vector2(850.0, -12.0))
	assert_false(_thread().visible)
	_fire_zip(Vector2.LEFT)
	await _frames(5)
	assert_true(_thread().visible, "a thread while it pulls")
	assert_eq(_thread().points.size(), 2)
	await _frames(60)
	assert_false(_thread().visible, "gone a moment after it ends")

func test_the_head_leads_the_zip() -> void:
	await _spider_at(Vector2(830.0, -12.0))
	_fire_zip(Vector2.UP)
	await _frames(6)
	assert_almost_eq(_sprite().rotation, -PI / 2.0, 0.3, "head up, toward the slab")

func test_the_slime_still_tackles_on_the_same_button() -> void:
	sb.set_profile("slime")
	sb.body.global_position = Vector2(100.0, -12.0)
	await _frames(4)
	sb.scripted.dir = 1.0
	sb.scripted.signature_pressed = true
	await _frames(2)
	assert_eq(sb.state.verb, "tackle")

func test_a_diagonal_cast_down_past_a_ledge_ignores_its_side() -> void:
	await _spider_at(Vector2(130.0, -77.0), Vector2.ZERO)
	var hit: Dictionary = sb._cast(Vector2.ZERO, Vector2(1, 1).normalized() * 160.0, true)
	assert_false(hit.is_empty())
	assert_false(hit["oneway"], "not the one-way ledge's side")
	assert_eq(hit["normal"], Vector2.UP)

func test_hanging_from_the_slab_and_pressing_down_slides_to_the_floor() -> void:
	await _spider_at(Vector2(830.0, -138.0), Vector2.DOWN)
	sb.scripted.down = 1.0
	var started := false
	var landed := false
	for _k in 200:
		await get_tree().physics_frame
		started = started or sb.state.drop_event == "start"
		if sb.state.drop_event == "land":
			landed = true
			break
	assert_true(started and landed, "it spun a thread and slid down it")
	await _frames(2)
	assert_eq(sb.state.surface_n, Vector2.UP)
	assert_almost_eq(sb.body.global_position.y, -12.0, 2.0)

func test_the_thread_runs_from_the_anchor_to_the_spider() -> void:
	await _spider_at(Vector2(830.0, -138.0), Vector2.DOWN)
	sb.scripted.down = 1.0
	await _frames(20)
	assert_true(_thread().visible)
	assert_eq(_thread().points.size(), 2)
	assert_almost_eq(_thread().points[1].y, -150.0, 2.0, "up at the slab's underside")
	assert_almost_eq(_thread().points[0].y, sb.body.global_position.y, 14.0, "down at the spider")

func test_up_climbs_back_toward_the_anchor_and_stops_there() -> void:
	await _spider_at(Vector2(830.0, -138.0), Vector2.DOWN)
	sb.scripted.down = 1.0
	await _frames(20)
	sb.scripted.down = 0.0
	sb.scripted.up = 1.0
	var highest := 0.0
	for _k in 200:
		await get_tree().physics_frame
		highest = minf(highest, sb.body.global_position.y)
	assert_almost_eq(sb.body.global_position.y, -138.0, 2.0, "back under the anchor")
	assert_gte(highest, -140.0, "and never above it")

func test_the_head_points_down_while_it_slides() -> void:
	await _spider_at(Vector2(830.0, -138.0), Vector2.DOWN)
	sb.scripted.down = 1.0
	await _frames(12)
	assert_almost_eq(absf(wrapf(_sprite().rotation, -PI, PI)), PI / 2.0, 0.3, "a quarter turn, whichever way it is mirrored")

func test_a_jump_lets_go_and_it_lands_later() -> void:
	await _spider_at(Vector2(830.0, -138.0), Vector2.DOWN)
	sb.scripted.down = 1.0
	await _frames(15)
	sb.scripted.jump_pressed = true
	var released := false
	for _k in 6:
		await get_tree().physics_frame
		released = released or sb.state.drop_event == "release"
	assert_true(released)
	await _frames(150)
	assert_eq(sb.state.surface_n, Vector2.UP, "it fell and gripped the floor")

func test_the_slime_ignores_down_in_the_air() -> void:
	sb.set_profile("slime")
	sb.body.global_position = Vector2(830.0, -100.0)
	sb.scripted.down = 1.0
	await _frames(20)
	assert_eq(sb.state.drop_event, "")
	assert_eq(sb.state.drop_up, 0.0)

func _hop_onto_the_pillar() -> void:
	await _spider_at(Vector2(738.0, -12.0))
	sb.scripted.dir = 1.0
	sb.scripted.jump_pressed = true
	await _frames(12)

func test_hopping_onto_the_pillar_then_climbing_goes_over_the_top_left_corner() -> void:
	await _hop_onto_the_pillar()
	assert_eq(sb.state.surface_n, Vector2.LEFT, "gripped the wall")
	sb.scripted.dir = 0.0
	sb.scripted.up = 1.0
	var over := false
	for _k in 200:
		await get_tree().physics_frame
		if sb.state.surface_n == Vector2.UP and sb.body.global_position.y < -150.0:
			over = true
			break
	assert_true(over, "over the corner onto the slab's top")
	await _frames(3)
	assert_almost_eq(sb.body.global_position.y, -192.0, 3.0)

func test_after_a_hop_onto_a_wall_holding_toward_it_keeps_climbing() -> void:
	await _hop_onto_the_pillar()
	var y := sb.body.global_position.y
	await _frames(30)
	assert_lt(sb.body.global_position.y, y - 30.0, "holding right climbs, as walking into the wall does")

## `id` standing on the one-way ledge (x 160 to 260, top y -50): the centre is 12 above it, at -62.
func _on_the_ledge(id: String) -> void:
	sb.scripted.down = 0.0
	sb.set_profile(id)
	sb.body.global_position = Vector2(200.0, -64.0)
	await _frames(12)

func test_every_species_drops_through_a_one_way_ledge_with_down() -> void:
	for id in ["biped", "slime", "wolf", "spider"]:
		await _on_the_ledge(id)
		assert_almost_eq(sb.body.global_position.y, -62.0, 3.0, "%s stands on the ledge" % id)
		sb.scripted.down = 1.0
		await _frames(60)
		assert_almost_eq(sb.body.global_position.y, -12.0, 2.0, "%s dropped through to the floor" % id)
		if id == "spider":
			assert_eq(sb.state.surface_n, Vector2.UP, "and the spider grips the floor below")

func test_nobody_falls_through_a_hard_floor() -> void:
	for id in ["biped", "slime", "wolf", "spider"]:
		sb.scripted.down = 0.0
		sb.set_profile(id)
		sb.body.global_position = Vector2(100.0, -12.0)
		await _frames(6)
		sb.scripted.down = 1.0
		await _frames(30)
		assert_almost_eq(sb.body.global_position.y, -12.0, 1.5, "%s stays on the hard floor" % id)

func test_down_already_held_does_not_drop_on_landing() -> void:
	sb.scripted.down = 1.0
	sb.set_profile("biped")
	sb.body.global_position = Vector2(200.0, -110.0)
	await _frames(60)
	assert_almost_eq(sb.body.global_position.y, -62.0, 3.0, "it landed on the ledge with down held and stayed")
	sb.scripted.down = 0.0
	await _frames(3)
	sb.scripted.down = 1.0
	await _frames(60)
	assert_almost_eq(sb.body.global_position.y, -12.0, 2.0, "a fresh press drops it")

func test_a_jump_up_through_the_ledge_from_below_still_lands_on_it() -> void:
	sb.scripted.down = 0.0
	sb.set_profile("biped")
	sb.body.global_position = Vector2(200.0, -12.0)
	await _frames(6)
	sb.scripted.jump_pressed = true
	sb.scripted.jump_held = true
	await _frames(30)
	sb.scripted.jump_held = false
	await _frames(90)
	assert_almost_eq(sb.body.global_position.y, -62.0, 3.0, "up through it and onto its top")

func test_a_body_standing_on_the_edge_of_a_ledge_still_drops_through() -> void:
	for x in [156.0, 264.0]:  # the centre is 4 px past the ledge's end (x 160 to 260) and the 28 px box still rests on it
		for id in ["biped", "slime", "wolf"]:
			sb.scripted.down = 0.0
			sb.set_profile(id)
			sb.body.global_position = Vector2(x, -64.0)
			await _frames(12)
			assert_almost_eq(sb.body.global_position.y, -62.0, 3.0, "%s stands on the ledge's edge at x %s" % [id, x])
			sb.scripted.down = 1.0
			await _frames(60)
			assert_almost_eq(sb.body.global_position.y, -12.0, 2.0, "%s dropped through from x %s" % [id, x])

func test_the_spider_crawling_into_the_slick_block_stops_at_it() -> void:
	await _spider_at(Vector2(250.0, -12.0))
	sb.scripted.dir = 1.0
	await _frames(90)
	assert_almost_eq(sb.body.global_position.x, 300.0 - 14.0, 3.0, "stopped at the slick face")
	assert_eq(sb.state.surface_n, Vector2.UP, "and did not climb it")
	assert_almost_eq(sb.body.global_position.y, -12.0, 1.5)

func test_a_zip_at_the_slick_block_fizzles() -> void:
	await _spider_at(Vector2(200.0, -12.0))
	_fire_zip(Vector2.RIGHT)
	var fizzled := false
	for _k in 10:
		await get_tree().physics_frame
		fizzled = fizzled or sb.state.zip_event == "fizzle"
	assert_true(fizzled)
	assert_almost_eq(sb.body.global_position.x, 200.0, 0.5)

func test_a_hop_at_the_slick_block_does_not_grip_it() -> void:
	await _spider_at(Vector2(250.0, -12.0))
	sb.scripted.dir = 1.0
	sb.scripted.jump_pressed = true
	var gripped := false
	for _k in 120:
		await get_tree().physics_frame
		gripped = gripped or sb.state.surface_n == Vector2.LEFT
	assert_false(gripped, "a slick face is not gripped")
	assert_lt(sb.body.global_position.x, 290.0)

func test_the_slick_ceiling_refuses_a_thread_and_a_zip() -> void:
	await _spider_at(Vector2(330.0, -150.0))
	sb.scripted.down = 1.0
	var fizzled := false
	for _k in 3:
		await get_tree().physics_frame
		fizzled = fizzled or sb.state.drop_event == "fizzle"
	assert_true(fizzled, "no thread from a slick ceiling")
	assert_eq(sb.state.drop_up, 0.0)
	sb.scripted.down = 0.0
	await _spider_at(Vector2(330.0, -102.0))  # standing on the slick block's top
	_fire_zip(Vector2.UP)
	var zip_fizzled := false
	for _k in 10:
		await get_tree().physics_frame
		zip_fizzled = zip_fizzled or sb.state.zip_event == "fizzle"
	assert_true(zip_fizzled, "no zip to a slick ceiling")

func test_the_sticky_ledge_block_beside_the_slick_one_is_still_climbed() -> void:
	await _spider_at(Vector2(378.0, -12.0))
	sb.scripted.dir = 1.0
	var climbed := false
	for _k in 90:
		await get_tree().physics_frame
		climbed = climbed or sb.state.surface_n == Vector2.LEFT
	assert_true(climbed, "an ordinary block is climbed")

func test_the_slime_stops_at_the_slick_block_like_any_wall() -> void:
	sb.set_profile("slime")
	sb.body.global_position = Vector2(250.0, -12.0)
	await _frames(4)
	sb.scripted.dir = 1.0
	await _frames(90)
	assert_almost_eq(sb.body.global_position.x, 300.0 - 14.0, 3.0)
