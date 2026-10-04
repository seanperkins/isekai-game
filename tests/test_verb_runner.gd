extends GutTest

var slime: MovementProfile
var biped: MovementProfile

func before_each() -> void:
	slime = MovementProfile.of("slime")
	biped = MovementProfile.of("biped")

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

func test_tackle_holds_260_for_nine_ticks_then_returns_control() -> void:
	var s := MoveState.new()
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_eq(s.verb, "tackle")
	assert_eq(s.velocity.x, 260.0)
	for k in 8:
		VerbRunner.step(s, _in(), slime, 1.0 / 60.0)
		assert_eq(s.velocity.x, 260.0, "tick %d" % (k + 2))
	assert_eq(s.verb, "tackle")
	VerbRunner.step(s, _in(), slime, 1.0 / 60.0)
	assert_eq(s.verb, "")
	assert_lt(s.velocity.x, 260.0)

func test_tackle_goes_the_way_the_slime_faces_and_a_second_press_does_not_restart_it() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(-1.0), 1)
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_eq(s.velocity.x, -260.0)
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_lt(s.verb_left, 0.12)

func test_a_jump_during_a_tackle_fires_and_keeps_the_tackle_speed() -> void:
	var s := MoveState.new()
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	var j := _in()
	j.jump_pressed = true
	j.jump_held = true
	VerbRunner.step(s, j, slime, 1.0 / 60.0)
	assert_eq(s.launched, "ground")
	assert_eq(s.velocity.x, 260.0)

func test_gravity_still_pulls_during_an_air_tackle() -> void:
	var s := MoveState.new()
	var t := _signature()
	t.on_floor = false
	VerbRunner.step(s, t, slime, 1.0 / 60.0)
	assert_eq(s.velocity.x, 260.0)
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
	assert_almost_eq(s.velocity.x, 135.0, 0.001)
	var ticks := 1
	while s.verb != "" and ticks < 60:
		VerbRunner.step(s, _in(0.0, true, 1.0), slime, 1.0 / 60.0)
		ticks += 1
	assert_between(ticks, 20, 23, "ends below 40 px/s")

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
