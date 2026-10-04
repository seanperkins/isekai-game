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

func test_species_without_a_burst_row_ignore_the_button() -> void:
	var s := MoveState.new()  # the biped has its roll now: the spider's button is the zip, which needs the caller's probes
	VerbRunner.step(s, _signature(), spider, 1.0 / 60.0)
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

## An input standing on a one-way ledge (or a hard floor) with `down` as given.
func _ledge_input(down: float, oneway := true) -> MoveInput:
	var i := MoveInput.new()
	i.on_floor = true
	i.on_oneway_floor = oneway
	i.down = down
	return i

func test_a_press_of_down_on_a_one_way_ledge_starts_a_fall_through() -> void:
	for id in MovementProfile.IDS:
		var p := MovementProfile.of(id)
		var s := MoveState.new()
		VerbRunner.step(s, _ledge_input(1.0), p, 1.0 / 60.0)
		assert_eq(s.fall_through, 0.2, id)
		for _k in 13:
			VerbRunner.step(s, _ledge_input(1.0), p, 1.0 / 60.0)
		assert_lt(s.fall_through, 0.001, "%s: it runs out after 0.2 s" % id)

func test_a_held_down_does_not_drop() -> void:
	for id in MovementProfile.IDS:
		var p := MovementProfile.of(id)
		var s := MoveState.new()
		s.down_prev = 1.0  # down was already held as it landed on the ledge
		VerbRunner.step(s, _ledge_input(1.0), p, 1.0 / 60.0)
		assert_eq(s.fall_through, 0.0, "%s: landing with down held" % id)
		VerbRunner.step(s, _ledge_input(0.0), p, 1.0 / 60.0)
		VerbRunner.step(s, _ledge_input(1.0), p, 1.0 / 60.0)
		assert_eq(s.fall_through, 0.2, "%s: released and pressed again" % id)
		for _k in 20:
			VerbRunner.step(s, _ledge_input(1.0), p, 1.0 / 60.0)
		assert_lt(s.fall_through, 0.001, "%s: and still held it does not start again" % id)

func test_a_hard_floor_and_the_air_do_not_drop() -> void:
	for id in MovementProfile.IDS:
		var p := MovementProfile.of(id)
		var hard := MoveState.new()
		VerbRunner.step(hard, _ledge_input(1.0, false), p, 1.0 / 60.0)
		assert_eq(hard.fall_through, 0.0, "%s on a hard floor" % id)
		var air := MoveState.new()
		var i := _ledge_input(1.0)
		i.on_floor = false
		i.on_oneway_floor = false
		VerbRunner.step(air, i, p, 1.0 / 60.0)
		assert_eq(air.fall_through, 0.0, "%s in the air" % id)

func test_the_slime_does_not_spread_or_slide_on_the_dropping_press() -> void:
	var s := MoveState.new()
	s.velocity.x = 120.0
	var i := _ledge_input(1.0)
	i.dir = 1.0
	VerbRunner.step(s, i, slime, 1.0 / 60.0)
	assert_false(s.spread, "no flattening on the press that drops through")
	assert_ne(s.verb, "puddle")
	var hard := MoveState.new()
	hard.velocity.x = 120.0
	var j := _ledge_input(1.0, false)
	j.dir = 1.0
	VerbRunner.step(hard, j, slime, 1.0 / 60.0)
	assert_true(hard.spread, "on a hard floor it spreads as before")
	assert_eq(hard.verb, "puddle")

# --- the wolf's pounce ---

func _pounce_input(aim := Vector2.ZERO, on_floor := true) -> MoveInput:
	var i := MoveInput.new()
	i.on_floor = on_floor
	i.aim = aim
	i.signature_pressed = true
	return i

func test_a_pounce_goes_along_the_aim_at_300_plus_half_the_run_speed() -> void:
	var wolf := MovementProfile.of("wolf")
	var s := MoveState.new()
	VerbRunner.step(s, _pounce_input(Vector2(1, -1).normalized()), wolf, 1.0 / 60.0)
	assert_eq(s.verb, "pounce")
	assert_almost_eq(s.velocity.x, 212.13, 0.1)
	assert_almost_eq(s.velocity.y, -212.13, 0.1)
	var running := MoveState.new()
	running.velocity.x = 200.0
	VerbRunner.step(running, _pounce_input(Vector2(1, -1).normalized()), wolf, 1.0 / 60.0)
	assert_almost_eq(running.velocity.length(), 400.0, 0.1, "300 plus half of 200")

func test_with_no_aim_a_pounce_goes_along_the_facing() -> void:
	var wolf := MovementProfile.of("wolf")
	var s := MoveState.new()
	s.facing = -1
	VerbRunner.step(s, _pounce_input(), wolf, 1.0 / 60.0)
	assert_eq(s.velocity, Vector2(-300.0, 0.0))

func test_gravity_acts_during_a_pounce_and_straight_up_rises_less_than_the_base_jump() -> void:
	var wolf := MovementProfile.of("wolf")
	var sim := MovementSim.new(wolf)
	sim.tick(-1.0, false, false, 1.0, 0.0, true, Vector2.UP)
	var top := 0.0
	for k in 120:
		sim.tick(-1.0)  # the stick is held left the whole time
		top = minf(top, sim.pos.y)
		if k < 20:
			assert_eq(sim.state.velocity.x, 0.0, "the stick does not steer a pounce")
		if sim.on_floor:
			break
	assert_between(-top, 33.0, 37.0, "300 squared over twice 1344 is 33.5, plus 2.5 for the 60 Hz step")
	assert_lt(-top, 63.25)

func test_a_pounce_lasts_0_35_s_then_waits_0_8_s_from_its_end() -> void:
	var wolf := MovementProfile.of("wolf")
	var s := MoveState.new()
	VerbRunner.step(s, _pounce_input(Vector2.RIGHT), wolf, 1.0 / 60.0)
	var ticks := 1
	while s.verb == "pounce" and ticks < 60:
		VerbRunner.step(s, _pounce_input(Vector2.ZERO, true).copy(), wolf, 1.0 / 60.0)
		ticks += 1
	assert_between(ticks, 21, 23, "0.35 s")
	var calm := MoveInput.new()
	for _k in 41:
		VerbRunner.step(s, calm, wolf, 1.0 / 60.0)
	VerbRunner.step(s, _pounce_input(Vector2.RIGHT), wolf, 1.0 / 60.0)
	assert_eq(s.verb, "", "0.7 s after the end it is cooling down")
	for _k in 9:
		VerbRunner.step(s, calm, wolf, 1.0 / 60.0)
	VerbRunner.step(s, _pounce_input(Vector2.RIGHT), wolf, 1.0 / 60.0)
	assert_eq(s.verb, "pounce", "0.8 s after the end it goes again")

func test_a_pounce_ends_at_a_wall_it_is_moving_toward() -> void:
	var wolf := MovementProfile.of("wolf")
	var right := MoveState.new()
	VerbRunner.step(right, _pounce_input(Vector2.RIGHT), wolf, 1.0 / 60.0)
	var away := MoveInput.new()
	away.wall_side = -1
	VerbRunner.step(right, away, wolf, 1.0 / 60.0)
	assert_eq(right.verb, "pounce", "a wall behind it does not end it")
	var toward := MoveInput.new()
	toward.wall_side = 1
	VerbRunner.step(right, toward, wolf, 1.0 / 60.0)
	assert_eq(right.verb, "", "a wall ahead does")
	var up := MoveState.new()
	VerbRunner.step(up, _pounce_input(Vector2.UP), wolf, 1.0 / 60.0)
	VerbRunner.step(up, toward, wolf, 1.0 / 60.0)
	assert_eq(up.verb, "pounce", "straight up is moving toward no wall")

func test_one_pounce_per_airtime() -> void:
	var wolf := MovementProfile.of("wolf")
	var s := MoveState.new()
	var air := MoveInput.new()
	air.on_floor = false
	VerbRunner.step(s, _pounce_input(Vector2.RIGHT, false), wolf, 1.0 / 60.0)
	assert_eq(s.verb, "pounce")
	for _k in 30:
		VerbRunner.step(s, air, wolf, 1.0 / 60.0)
	s.cooldowns.clear()
	VerbRunner.step(s, _pounce_input(Vector2.RIGHT, false), wolf, 1.0 / 60.0)
	assert_eq(s.verb, "", "the air verb is spent until it lands")

func test_touching_a_hostile_marks_the_pounce() -> void:
	var wolf := MovementProfile.of("wolf")
	var s := MoveState.new()
	var touch := MoveInput.new()
	touch.touching_hostile = true
	VerbRunner.step(s, touch, wolf, 1.0 / 60.0)
	assert_false(s.pounce_hit, "contact outside a pounce is ignored")
	VerbRunner.step(s, _pounce_input(Vector2.RIGHT), wolf, 1.0 / 60.0)
	assert_false(s.pounce_hit)
	VerbRunner.step(s, touch, wolf, 1.0 / 60.0)
	assert_true(s.pounce_hit)

# --- review fixes: pounce against the vault, a released jump, and the last tick ---

func test_a_vault_never_overrides_a_pounce_begun_on_the_same_tick() -> void:
	var wolf := MovementProfile.of("wolf")
	var s := MoveState.new()
	s.velocity.x = -200.0  # running left, a step ahead of it in that direction, and it pounces up and right
	var i := _pounce_input(Vector2(1, -1).normalized())
	i.step_ahead = 16.0
	VerbRunner.step(s, i, wolf, 1.0 / 60.0)
	assert_eq(s.verb, "pounce")
	assert_eq(s.launched, "", "the vault did not launch")
	assert_almost_eq(s.velocity.y, -282.84, 0.1, "the pounce's own velocity: 300 plus half of 200 along the aim")
	assert_almost_eq(s.velocity.x, 282.84, 0.1)

func test_no_vault_while_a_pounce_is_running() -> void:
	var wolf := MovementProfile.of("wolf")
	var s := MoveState.new()
	VerbRunner.step(s, _pounce_input(Vector2.RIGHT), wolf, 1.0 / 60.0)
	var i := MoveInput.new()
	i.on_floor = true
	i.step_ahead = 16.0
	VerbRunner.step(s, i, wolf, 1.0 / 60.0)
	assert_eq(s.launched, "")
	assert_eq(s.velocity.y, 0.0)

func test_an_air_pounce_after_a_released_jump_is_not_slowed_by_the_release() -> void:
	var wolf := MovementProfile.of("wolf")
	var s := MoveState.new()
	s.jumping = true  # in a jump, button already up, still rising
	s.velocity.y = -100.0
	var i := _pounce_input(Vector2.UP, false)
	VerbRunner.step(s, i, wolf, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, -300.0 + 1344.0 / 60.0, 0.1, "plain gravity, not release_factor times it")

func test_contact_on_the_tick_the_pounce_expires_still_marks_the_hit() -> void:
	var wolf := MovementProfile.of("wolf")
	var s := MoveState.new()
	VerbRunner.step(s, _pounce_input(Vector2.RIGHT), wolf, 1.0 / 60.0)
	var calm := MoveInput.new()
	calm.on_floor = true
	for _k in 20:
		VerbRunner.step(s, calm, wolf, 1.0 / 60.0)
	assert_eq(s.verb, "pounce", "still running one tick before it expires")
	var touch := MoveInput.new()
	touch.on_floor = true
	touch.touching_hostile = true
	VerbRunner.step(s, touch, wolf, 1.0 / 60.0)
	assert_eq(s.verb, "", "this is the tick it ends")
	assert_true(s.pounce_hit, "the contact on it was not dropped")

# --- the biped's roll and slide ---

func _tackle(on_floor := true, clearance := 1000.0) -> MoveInput:
	var i := MoveInput.new()
	i.on_floor = on_floor
	i.signature_pressed = true
	i.clearance_above = clearance
	return i

func _calm(on_floor := true, clearance := 1000.0) -> MoveInput:
	var i := MoveInput.new()
	i.on_floor = on_floor
	i.clearance_above = clearance
	return i

## Ticks until the running verb ends (the begin tick counts), at most `limit`.
func _until_verb_ends(s: MoveState, p: MovementProfile, i: MoveInput, limit := 80) -> int:
	var ticks := 0
	while s.verb != "" and ticks < limit:
		VerbRunner.step(s, i, p, 1.0 / 60.0)
		ticks += 1
	return ticks

func test_a_standing_biped_rolls_220_along_its_facing_for_035_s() -> void:
	var biped := MovementProfile.of("biped")
	for facing in [1, -1]:
		var s := MoveState.new()
		s.facing = facing
		VerbRunner.step(s, _tackle(), biped, 1.0 / 60.0)
		assert_eq(s.verb, "roll")
		assert_eq(s.velocity.x, 220.0 * facing)
		assert_true(VerbRunner.is_flat(s, biped), "it ducks")
		var ticks := 1 + _until_verb_ends(s, biped, _calm())
		assert_between(ticks, 21, 23, "0.35 s")

func test_at_100_px_s_it_slides_and_at_99_9_it_rolls() -> void:
	var biped := MovementProfile.of("biped")
	var at_100 := MoveState.new()
	at_100.velocity.x = 100.0
	VerbRunner.step(at_100, _tackle(), biped, 1.0 / 60.0)
	assert_eq(at_100.verb, "slide")
	var at_99 := MoveState.new()
	at_99.velocity.x = 99.9
	VerbRunner.step(at_99, _tackle(), biped, 1.0 / 60.0)
	assert_eq(at_99.verb, "roll")
	var run := MoveState.new()
	run.velocity.x = -140.0
	VerbRunner.step(run, _tackle(), biped, 1.0 / 60.0)
	assert_eq(run.verb, "slide")
	assert_almost_eq(run.velocity.x, -140.0 + 350.0 / 60.0, 0.01, "it keeps the speed it had and bleeds 350 px/s per second")
	var ticks := 1 + _until_verb_ends(run, biped, _calm())
	assert_between(ticks, 20, 24, "under 20 px/s ends it, 0.4 s at most")

func test_neither_starts_in_the_air_and_both_end_when_it_leaves_the_floor() -> void:
	var biped := MovementProfile.of("biped")
	var air := MoveState.new()
	VerbRunner.step(air, _tackle(false), biped, 1.0 / 60.0)
	assert_eq(air.verb, "")
	var s := MoveState.new()
	VerbRunner.step(s, _tackle(), biped, 1.0 / 60.0)
	assert_eq(s.verb, "roll")
	VerbRunner.step(s, _calm(false), biped, 1.0 / 60.0)
	assert_eq(s.verb, "", "over a drop it ends")

func test_a_roll_and_a_slide_share_one_cooldown_of_0_3_s_from_the_end() -> void:
	var biped := MovementProfile.of("biped")
	var s := MoveState.new()
	VerbRunner.step(s, _tackle(), biped, 1.0 / 60.0)
	_until_verb_ends(s, biped, _calm())
	s.velocity.x = 150.0  # fast enough to slide
	VerbRunner.step(s, _tackle(), biped, 1.0 / 60.0)
	assert_eq(s.verb, "", "no slide straight after a roll")
	for _k in 8:
		VerbRunner.step(s, _calm(), biped, 1.0 / 60.0)
	s.velocity.x = 0.0
	VerbRunner.step(s, _tackle(), biped, 1.0 / 60.0)
	assert_eq(s.verb, "", "still cooling down at about 0.17 s")
	for _k in 12:
		VerbRunner.step(s, _calm(), biped, 1.0 / 60.0)
	s.velocity.x = 0.0
	VerbRunner.step(s, _tackle(), biped, 1.0 / 60.0)
	assert_eq(s.verb, "roll", "ready again after 0.3 s")

func test_invulnerable_for_exactly_the_first_twelve_ticks_and_not_after() -> void:
	var biped := MovementProfile.of("biped")
	var s := MoveState.new()
	assert_false(s.invulnerable)
	var flags: Array = []
	VerbRunner.step(s, _tackle(), biped, 1.0 / 60.0)
	flags.append(s.invulnerable)
	for _k in 24:
		VerbRunner.step(s, _calm(), biped, 1.0 / 60.0)
		flags.append(s.invulnerable)
	assert_eq(flags.slice(0, 12), [true, true, true, true, true, true, true, true, true, true, true, true], "0.2 s")
	assert_false(flags[12], "and not a tick more")
	assert_eq(s.verb, "", "the roll is over by now")
	assert_false(s.invulnerable)
	var slide := MoveState.new()
	slide.velocity.x = 140.0
	VerbRunner.step(slide, _tackle(), biped, 1.0 / 60.0)
	assert_true(slide.invulnerable, "a slide has the window too")

func test_a_roll_that_ends_under_a_low_ceiling_stays_crouched() -> void:
	var biped := MovementProfile.of("biped")
	var s := MoveState.new()
	VerbRunner.step(s, _tackle(true, 0.0), biped, 1.0 / 60.0)
	_until_verb_ends(s, biped, _calm(true, 0.0))
	assert_eq(s.verb, "")
	assert_true(VerbRunner.is_flat(s, biped), "no room to stand")
	var walk := _calm(true, 0.0)
	walk.dir = 1.0
	for _k in 6:
		VerbRunner.step(s, walk, biped, 1.0 / 60.0)
	assert_almost_eq(s.velocity.x, 70.0, 0.01, "it walks at half speed")
	var jump := _calm(true, 0.0)
	jump.jump_pressed = true
	VerbRunner.step(s, jump, biped, 1.0 / 60.0)
	assert_eq(s.launched, "", "it cannot jump into the ceiling")
	VerbRunner.step(s, _calm(true, 1000.0), biped, 1.0 / 60.0)
	assert_false(VerbRunner.is_flat(s, biped), "with room it stands")

func test_a_jump_during_a_roll_fires_at_once_and_ends_it() -> void:
	var biped := MovementProfile.of("biped")
	var s := MoveState.new()
	VerbRunner.step(s, _tackle(), biped, 1.0 / 60.0)
	var jump := _calm()
	jump.jump_pressed = true
	VerbRunner.step(s, jump, biped, 1.0 / 60.0)
	assert_eq(s.launched, "ground")
	assert_almost_eq(s.velocity.y, -330.0, 0.01)
	assert_eq(s.velocity.x, 220.0, "the roll's speed holds on the tick it jumps")
	VerbRunner.step(s, _calm(false), biped, 1.0 / 60.0)
	assert_eq(s.verb, "", "it left the floor")

func test_the_slime_and_the_wolf_start_their_bursts_as_before() -> void:
	var slime := MoveState.new()
	VerbRunner.step(slime, _tackle(), MovementProfile.of("slime"), 1.0 / 60.0)
	assert_eq(slime.verb, "tackle", "from a standstill")
	var moving := MoveState.new()
	moving.velocity.x = 140.0
	VerbRunner.step(moving, _tackle(false), MovementProfile.of("slime"), 1.0 / 60.0)
	assert_eq(moving.verb, "tackle", "in the air")
	var wolf := MoveState.new()
	VerbRunner.step(wolf, _tackle(false), MovementProfile.of("wolf"), 1.0 / 60.0)
	assert_eq(wolf.verb, "pounce", "the pounce is an air verb")
