extends GutTest

var slime: MovementProfile
var biped: MovementProfile
var spider: MovementProfile

func before_each() -> void:
	slime = MovementProfile.of("slime")
	biped = MovementProfile.of("biped")
	spider = MovementProfile.of("spider")

func _in(dir := 0.0, on_floor := true, down := 0.0) -> MoveInput:
	var i := MoveInput.new()
	i.dir = dir
	i.on_floor = on_floor
	i.down = down
	return i

func _run(p: MovementProfile, s: MoveState, i: MoveInput, ticks: int) -> void:
	for _k in ticks:
		VerbRunner.step(s, i, p, 1.0 / 60.0)

func test_facing_follows_the_last_direction_pressed() -> void:
	var s := MoveState.new()
	assert_eq(s.facing, 1)
	_run(slime, s, _in(-1.0), 1)
	assert_eq(s.facing, -1)
	_run(slime, s, _in(0.0), 1)
	assert_eq(s.facing, -1, "letting go keeps it")

func test_down_on_the_floor_spreads_and_halves_the_walk() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(1.0, true, 1.0), 10)
	assert_true(s.spread)
	assert_eq(s.velocity.x, 70.0)
	assert_true(VerbRunner.is_flat(s, slime))

func test_it_stands_up_only_with_room_above() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(0.0, true, 1.0), 2)
	var low := _in()
	low.clearance_above = 0.0
	_run(slime, s, low, 5)
	assert_true(s.spread, "a low ceiling keeps it flat")
	_run(slime, s, _in(), 1)
	assert_false(s.spread)

func test_down_in_the_air_does_not_spread_and_only_the_slime_has_ooze() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(0.0, false, 1.0), 3)
	assert_false(s.spread)
	s = MoveState.new()
	_run(biped, s, _in(0.0, true, 1.0), 3)
	assert_false(s.spread)

func test_a_jump_stands_the_slime_up_with_room_and_is_refused_without() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(0.0, true, 1.0), 2)
	var jump := _in(0.0, true, 1.0)
	jump.jump_pressed = true
	jump.jump_held = true
	VerbRunner.step(s, jump, slime, 1.0 / 60.0)
	assert_eq(s.launched, "ground")
	assert_false(s.spread)
	s = MoveState.new()
	_run(slime, s, _in(0.0, true, 1.0), 2)
	var blocked := _in(0.0, true, 1.0)
	blocked.jump_pressed = true
	blocked.clearance_above = 0.0
	VerbRunner.step(s, blocked, slime, 1.0 / 60.0)
	assert_eq(s.launched, "")
	assert_true(s.spread)
	assert_eq(s.buffer, 0.0, "a refused press is not buffered")

func _signature() -> MoveInput:
	var i := _in()
	i.signature_pressed = true
	return i

func test_tackle_holds_340_for_eleven_ticks_then_returns_control() -> void:
	var s := MoveState.new()
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_eq(s.verb, "tackle")
	assert_eq(s.velocity.x, 340.0)
	for k in 10:
		VerbRunner.step(s, _in(), slime, 1.0 / 60.0)
		assert_eq(s.velocity.x, 340.0, "tick %d" % (k + 2))
	assert_eq(s.verb, "tackle")
	VerbRunner.step(s, _in(), slime, 1.0 / 60.0)
	assert_eq(s.verb, "")
	assert_lt(s.velocity.x, 340.0)

func test_tackle_goes_the_way_the_slime_faces_and_a_second_press_does_not_restart_it() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(-1.0), 1)
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_eq(s.velocity.x, -340.0)
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_lt(s.verb_left, 0.15)

func test_a_jump_during_a_tackle_fires_and_keeps_the_tackle_speed() -> void:
	var s := MoveState.new()
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	var j := _in()
	j.jump_pressed = true
	j.jump_held = true
	VerbRunner.step(s, j, slime, 1.0 / 60.0)
	assert_eq(s.launched, "ground")
	assert_eq(s.velocity.x, 340.0)

func test_gravity_still_pulls_during_an_air_tackle() -> void:
	var s := MoveState.new()
	var t := _signature()
	t.on_floor = false
	VerbRunner.step(s, t, slime, 1.0 / 60.0)
	assert_eq(s.velocity.x, 340.0)
	assert_gt(s.velocity.y, 0.0)

func test_species_without_a_tackle_row_ignore_the_button() -> void:
	var s := MoveState.new()
	VerbRunner.step(s, _signature(), biped, 1.0 / 60.0)
	assert_eq(s.verb, "")
	assert_eq(s.velocity.x, 0.0)

func test_a_tackle_mid_jump_adds_no_vertical_reach() -> void:
	var plain: float = MovementSim.flat_jump(slime)["rise"]
	var sim := MovementSim.new(slime)
	sim.tick(0.0, true, true)
	var rise := 0.0
	for k in 80:
		sim.tick(0.0, false, true, 1.0, 0.0, k == 12)
		rise = maxf(rise, -sim.pos.y)
		if sim.on_floor:
			break
	assert_almost_eq(rise, plain, 0.5)

func _running(p: MovementProfile, vx: float) -> MoveState:
	var s := MoveState.new()
	s.velocity.x = vx
	s.facing = 1 if vx >= 0.0 else -1
	return s

func test_down_at_run_speed_starts_a_puddle_slide_that_bleeds_and_ends() -> void:
	var s := _running(slime, 140.0)
	VerbRunner.step(s, _in(0.0, true, 1.0), slime, 1.0 / 60.0)
	assert_eq(s.verb, "puddle")
	assert_true(VerbRunner.is_flat(s, slime))
	assert_almost_eq(s.velocity.x, 137.5, 0.001)
	var ticks := 1
	while s.verb != "" and ticks < 60:
		VerbRunner.step(s, _in(0.0, true, 1.0), slime, 1.0 / 60.0)
		ticks += 1
	assert_between(ticks, 28, 31, "ends below 70 px/s")

func test_a_slide_after_a_tackle_stops_at_the_half_second_cap() -> void:
	var s := _running(slime, 260.0)
	VerbRunner.step(s, _in(0.0, true, 1.0), slime, 1.0 / 60.0)
	var ticks := 1
	while s.verb != "" and ticks < 60:
		VerbRunner.step(s, _in(0.0, true, 1.0), slime, 1.0 / 60.0)
		ticks += 1
	assert_between(ticks, 30, 32)

func test_releasing_down_or_leaving_the_floor_ends_the_slide_at_once() -> void:
	var s := _running(slime, 140.0)
	_run(slime, s, _in(0.0, true, 1.0), 3)
	assert_eq(s.verb, "puddle")
	_run(slime, s, _in(0.0, true, 0.0), 1)
	assert_eq(s.verb, "")
	s = _running(slime, 140.0)
	_run(slime, s, _in(0.0, true, 1.0), 2)
	_run(slime, s, _in(0.0, false, 1.0), 1)
	assert_eq(s.verb, "")

func test_it_needs_run_speed_and_the_floor() -> void:
	var slow := _running(slime, 99.0)
	_run(slime, slow, _in(0.0, true, 1.0), 1)
	assert_eq(slow.verb, "")
	assert_true(slow.spread, "below 100 it is the ordinary flat walk")
	var air := _running(slime, 140.0)
	_run(slime, air, _in(0.0, false, 1.0), 1)
	assert_eq(air.verb, "")

func test_tackle_wins_when_both_would_start() -> void:
	var s := _running(slime, 140.0)
	var i := _in(0.0, true, 1.0)
	i.signature_pressed = true
	VerbRunner.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.verb, "tackle")

func test_a_second_air_tackle_is_refused_until_the_slime_lands() -> void:
	var s := MoveState.new()
	var air := _signature()
	air.on_floor = false
	VerbRunner.step(s, air, slime, 1.0 / 60.0)
	assert_eq(s.verb, "tackle")
	for _k in 12:
		VerbRunner.step(s, _in(0.0, false), slime, 1.0 / 60.0)
	assert_eq(s.verb, "", "the first one ended")
	VerbRunner.step(s, air, slime, 1.0 / 60.0)
	assert_eq(s.verb, "", "one air verb per airtime")
	VerbRunner.step(s, _in(), slime, 1.0 / 60.0)
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_eq(s.verb, "tackle", "landing gives it back")

func test_mashing_tackle_in_a_jump_adds_no_horizontal_reach_beyond_one_tackle() -> void:
	var sim := MovementSim.new(slime)
	sim.state.velocity.x = slime.top_speed
	sim.tick(1.0, true, true)
	for k in 80:
		sim.tick(1.0, false, true, 1.0, 0.0, true)  # J every tick
		if sim.on_floor:
			break
	assert_lt(sim.pos.x, 175.0, "plain jump is 105 px; one air tackle adds about 50, five would add over 100")

func test_wall_contact_refreshes_the_air_tackle() -> void:
	var s := MoveState.new()
	var air := _signature()
	air.on_floor = false
	VerbRunner.step(s, air, slime, 1.0 / 60.0)
	for _k in 12:
		VerbRunner.step(s, _in(0.0, false), slime, 1.0 / 60.0)
	VerbRunner.step(s, air, slime, 1.0 / 60.0)
	assert_eq(s.verb, "", "one air verb per airtime")
	var wall := _in(1.0, false)
	wall.wall_side = 1
	VerbRunner.step(s, wall, slime, 1.0 / 60.0)
	assert_false(s.air_verb_used, "a wall gives it back")
	VerbRunner.step(s, air, slime, 1.0 / 60.0)
	assert_eq(s.verb, "tackle")
	var other := MoveState.new()
	other.air_verb_used = true
	VerbRunner.step(other, wall, biped, 1.0 / 60.0)
	assert_true(other.air_verb_used, "only a species with the wall verb gets it")

func test_a_tackle_into_a_wall_with_jump_held_reflects_it() -> void:
	var s := MoveState.new()
	var air := _signature()
	air.on_floor = false
	air.jump_held = true
	VerbRunner.step(s, air, slime, 1.0 / 60.0)
	VerbRunner.step(s, _in(0.0, false), slime, 1.0 / 60.0)
	assert_eq(s.verb, "tackle")
	var hit := _in(1.0, false)
	hit.jump_held = true
	hit.wall_side = 1
	VerbRunner.step(s, hit, slime, 1.0 / 60.0)
	assert_true(s.wall_bounced)
	assert_lt(s.velocity.x, -280.0)
	assert_eq(s.verb, "", "the bounce ends the tackle, so the slime is not still tackling as it leaves the wall")

func test_a_crawler_on_a_surface_skips_the_ground_step() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(40, -12)
	var s := MoveState.new()
	s.surface_n = Vector2.UP
	var i := w.input()
	i.dir = 1.0
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_eq(s.velocity, Vector2.ZERO, "the caller moves it by surface_shift")
	assert_almost_eq(s.surface_shift.x, 140.0 / 60.0, 0.001)

func test_a_crawler_in_the_air_runs_the_ground_step() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(40, -200)
	var s := MoveState.new()
	var i := w.input()
	i.on_floor = false
	i.dir = 1.0
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, 15.0, 0.001, "gravity")
	assert_gt(s.velocity.x, 0.0, "air control")
	assert_eq(s.surface_n, Vector2.ZERO)

func test_a_spider_without_probes_is_the_ground_step_as_before() -> void:
	var s := MoveState.new()
	var i := MoveInput.new()
	i.jump_pressed = true
	i.jump_held = true
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_eq(s.launched, "ground")
	assert_eq(s.velocity.y, -330.0)

func test_a_zip_owns_the_body_before_the_crawl_and_the_ground_step() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(120, -12)
	var s := MoveState.new()
	s.surface_n = Vector2.UP
	var i := w.input()
	i.aim = Vector2.RIGHT
	i.signature_pressed = true
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_eq(s.zip_event, "start")
	assert_eq([s.surface_n, s.velocity], [Vector2.ZERO, Vector2.ZERO])
	i.signature_pressed = false
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_almost_eq(s.surface_shift.x, 400.0 / 60.0, 0.001, "pulled at 400 px/s, not crawled at 140")

func test_one_air_zip_per_airtime() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(120, -60)
	var s := MoveState.new()
	s.air_verb_used = true  # it already used its air verb this airtime
	var i := w.input()
	i.on_floor = false
	i.aim = Vector2.RIGHT
	i.signature_pressed = true
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_eq(s.zip_event, "", "refused in the air")
	s.surface_n = Vector2.UP  # it gripped a surface: the air verb is back
	s.zip_cooldown = 0.0
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_false(s.air_verb_used)
	assert_eq(s.zip_event, "start")

func test_a_spider_without_the_zip_verb_ignores_the_button() -> void:
	var bare := spider.duplicate() as MovementProfile
	bare.verbs = PackedStringArray(["crawl"])
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(120, -12)
	var s := MoveState.new()
	s.surface_n = Vector2.UP
	var i := w.input()
	i.aim = Vector2.RIGHT
	i.signature_pressed = true
	VerbRunner.step(s, i, bare, 1.0 / 60.0)
	assert_eq(s.zip_event, "")
	assert_eq(s.surface_n, Vector2.UP)

func test_down_pressed_is_an_edge() -> void:
	var s := MoveState.new()
	var i := MoveInput.new()
	i.down = 1.0
	VerbRunner.step(s, i, biped, 1.0 / 60.0)
	assert_true(s.down_pressed)
	assert_eq(s.down_prev, 1.0)
	VerbRunner.step(s, i, biped, 1.0 / 60.0)
	assert_false(s.down_pressed, "held is not a press")
	i.down = 0.0
	VerbRunner.step(s, i, biped, 1.0 / 60.0)
	i.down = 1.0
	VerbRunner.step(s, i, biped, 1.0 / 60.0)
	assert_true(s.down_pressed, "released and pressed again")
	var light := MoveState.new()
	var j := MoveInput.new()
	j.down = 0.5
	VerbRunner.step(light, j, biped, 1.0 / 60.0)
	assert_false(light.down_pressed, "a light touch is under the 0.6 threshold")

func test_a_drop_owns_the_body_after_the_zip_and_before_the_crawl() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(600, -100)
	var s := MoveState.new()
	var i := w.input()
	i.on_floor = false
	i.down = 1.0
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_eq(s.drop_event, "start")
	assert_eq(s.velocity, Vector2.ZERO)
	var z := MoveState.new()
	z.zip_dir = Vector2.RIGHT  # a zip in flight keeps the tick
	z.zip_left = 50.0
	VerbRunner.step(z, i, spider, 1.0 / 60.0)
	assert_eq(z.drop_event, "")

func test_the_air_verb_is_shared_by_the_zip_and_the_drop() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(600, -100)
	var s := MoveState.new()
	var i := w.input()
	i.on_floor = false
	i.down = 1.0
	VerbRunner.step(s, i, spider, 1.0 / 60.0)  # a drop begins
	i.down = 0.0
	i.signature_pressed = true
	i.aim = Vector2.LEFT
	s.drop_up = 0.0  # it has let go
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_eq(s.zip_event, "", "no zip in the same airtime")
	s.surface_n = Vector2.UP  # it gripped a surface
	s.zip_cooldown = 0.0
	VerbRunner.step(s, i, spider, 1.0 / 60.0)
	assert_eq(s.zip_event, "start", "the air verb is back after gripping a surface")

func test_a_spider_without_the_drop_verb_ignores_down() -> void:
	var bare := spider.duplicate() as MovementProfile
	bare.verbs = PackedStringArray(["crawl"])
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(600, -100)
	var s := MoveState.new()
	var i := w.input()
	i.on_floor = false
	i.down = 1.0
	VerbRunner.step(s, i, bare, 1.0 / 60.0)
	assert_eq(s.drop_event, "")
