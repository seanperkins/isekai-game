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
	sb.body.global_position = Vector2(300.0, -150.0)
	var low := 1.0
	var land_seen := false
	for _k in 60:
		await get_tree().physics_frame
		low = minf(low, _sprite().scale.y)
		land_seen = land_seen or sb.clip() == "land"
	assert_lt(low, 0.97)
	assert_true(land_seen)

func test_a_timed_rebound_lands_as_a_ball_not_a_squash() -> void:
	sb.body.global_position = Vector2(300.0, -200.0)
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
	sb.body.global_position = Vector2(300.0, -300.0)
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
	sb.body.global_position = Vector2(300.0, -200.0)
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
	sb.body.global_position = Vector2(300.0, -300.0)
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
	sb.body.global_position = Vector2(300.0, -300.0)
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
	sb.body.global_position = Vector2(300.0, -200.0)
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
	sb.body.global_position = Vector2(300.0, -300.0)
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
