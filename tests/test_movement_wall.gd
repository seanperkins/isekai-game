extends GutTest

const DT := 1.0 / 60.0

var slime: MovementProfile
var wolf: MovementProfile
var biped: MovementProfile

func before_each() -> void:
	slime = MovementProfile.of("slime")
	wolf = MovementProfile.of("wolf")
	biped = MovementProfile.of("biped")

## An airborne input with a wall on `side` (-1 left, 1 right, 0 none) and the stick at `dir`.
func _wall(side: int, dir := 0.0) -> MoveInput:
	var i := MoveInput.new()
	i.on_floor = false
	i.wall_side = side
	i.dir = dir
	return i

func _step(s: MoveState, i: MoveInput, p := slime, boost := 1.0) -> void:
	GroundAirStep.step(s, i, p, DT, 1.0, boost)

func test_a_fall_onto_a_wall_sticks_for_twelve_ticks_then_slides_at_90() -> void:
	var s := MoveState.new()
	s.velocity.y = 300.0
	var i := _wall(-1, -1.0)
	for k in 12:
		_step(s, i)
		assert_eq(s.velocity.y, 15.0, "stuck, tick %d" % (k + 1))
		assert_true(s.clinging)
	var top := 0.0
	var rose := false
	for _k in 40:
		_step(s, i)
		top = maxf(top, s.velocity.y)
		rose = rose or s.velocity.y > 15.0
		assert_true(s.clinging)
	assert_true(rose, "it starts to slide")
	assert_eq(top, 90.0)

func test_it_does_not_cling_without_pressing_toward_the_wall() -> void:
	for dir in [0.0, 1.0]:
		var s := MoveState.new()
		for _k in 30:
			_step(s, _wall(-1, dir))
		assert_gt(s.velocity.y, 200.0, "dir %s" % dir)
		assert_false(s.clinging)

func test_it_does_not_cling_while_rising() -> void:
	var s := MoveState.new()
	s.velocity.y = -200.0
	_step(s, _wall(-1, -1.0))
	assert_lt(s.velocity.y, 0.0)
	assert_false(s.clinging)

func test_leaving_the_wall_rearms_the_stick() -> void:
	var s := MoveState.new()
	s.velocity.y = 300.0
	for _k in 20:
		_step(s, _wall(-1, -1.0))
	for _k in 3:
		_step(s, _wall(0, -1.0))
	assert_false(s.clinging)
	s.velocity.y = 100.0
	_step(s, _wall(-1, -1.0))
	assert_eq(s.velocity.y, 15.0)

func test_a_species_without_the_wall_verb_ignores_walls() -> void:
	var s := MoveState.new()
	for _k in 30:
		_step(s, _wall(-1, -1.0), wolf)
	assert_gt(s.velocity.y, 200.0)
	assert_false(s.clinging)

## A slime stuck to a wall on `side` (the stick pressed into it), ready to jump.
func _stuck(side: int, p := slime) -> MoveState:
	var s := MoveState.new()
	s.velocity.y = 300.0
	for _k in 3:
		_step(s, _wall(side, -float(side)), p)
	return s

func _press(side: int, held := true) -> MoveInput:
	var i := _wall(side, -float(side))
	i.jump_pressed = true
	i.jump_held = held
	return i

func test_a_wall_jump_kicks_away_at_180_with_the_full_jump_speed() -> void:
	var s := _stuck(-1)
	_step(s, _press(-1))
	assert_eq(s.velocity, Vector2(180.0, -328.5))
	assert_eq(s.launched, "wall")
	assert_true(s.jumping)
	assert_eq(s.wall_grace, 0.0)
	var right := _stuck(1)
	_step(right, _press(1))
	assert_eq(right.velocity.x, -180.0)
	var boosted := _stuck(-1)
	_step(boosted, _press(-1), slime, 1.5)
	assert_eq(boosted.velocity.y, -328.5 * 1.5)

func test_steering_is_locked_for_the_rest_of_the_wall_jumps_nine_ticks() -> void:
	var s := _stuck(-1)
	_step(s, _press(-1))
	for k in 8:
		_step(s, _wall(0, -1.0))
		assert_eq(s.velocity.x, 180.0, "locked, tick %d" % (k + 1))
	_step(s, _wall(0, -1.0))
	assert_lt(s.velocity.x, 180.0, "control is back on the ninth tick")

func test_a_wall_jump_works_inside_the_grace_and_not_after_it() -> void:
	for quiet in [3, 12]:
		var s := _stuck(-1)
		for _k in quiet:
			_step(s, _wall(0))
		var press := _wall(0)
		press.jump_pressed = true
		_step(s, press)
		assert_eq(s.launched, "wall" if quiet == 3 else "", "%d ticks off the wall" % quiet)

func test_a_press_just_before_touching_the_wall_still_jumps() -> void:
	var s := MoveState.new()
	s.velocity.y = 100.0
	var press := _wall(0)
	press.jump_pressed = true
	_step(s, press)
	for _k in 3:
		_step(s, _wall(0))
	_step(s, _wall(-1, -1.0))
	assert_eq(s.launched, "wall")

func test_the_floor_jump_beats_the_wall_jump() -> void:
	var s := MoveState.new()
	var i := _press(-1)
	i.on_floor = true
	_step(s, i)
	assert_eq(s.launched, "ground")
	assert_lt(absf(s.velocity.x), 180.0, "no wall kick on the floor")

func test_the_wall_jump_rises_exactly_as_far_as_the_base_jump() -> void:
	var s := _stuck(-1)
	_step(s, _press(-1))
	var y := s.velocity.y * DT
	var top := y
	var air := _wall(0)
	air.jump_held = true
	for _k in 120:
		_step(s, air)
		y += s.velocity.y * DT
		top = minf(top, y)
	var flat: Dictionary = MovementSim.flat_jump(slime, 1.0, 100.0, 0.0)
	assert_almost_eq(-top, flat["rise"], 0.001)

## A body in the air moving at `vx` with no wall in reach, so the step's `last_vx` is `vx`.
func _moving(vx: float, vy := 0.0) -> MoveState:
	var s := MoveState.new()
	s.velocity = Vector2(vx, vy)
	var i := _wall(0, signf(vx))
	i.jump_held = true
	_step(s, i)
	return s

func _hit(side: int, held := true) -> MoveInput:
	var i := _wall(side, float(side))
	i.jump_held = held
	return i

func test_holding_jump_into_a_wall_reflects_the_speed_at_85_percent() -> void:
	var s := _moving(140.0)
	_step(s, _hit(1))
	assert_almost_eq(s.velocity.x, -119.0, 0.01)
	assert_true(s.wall_bounced)
	assert_false(s.clinging)

func test_without_jump_held_it_sticks_instead() -> void:
	var s := _moving(140.0, 100.0)
	_step(s, _hit(1, false))
	assert_false(s.wall_bounced)
	assert_true(s.clinging)
	assert_gt(s.velocity.x, 0.0)

func test_a_slow_drift_into_a_wall_does_not_bounce() -> void:
	var s := _moving(60.0)
	s.velocity.x = 60.0
	s.last_vx = 60.0
	_step(s, _hit(1))
	assert_false(s.wall_bounced)

func test_a_bounce_happens_once_per_contact() -> void:
	var s := _moving(140.0)
	_step(s, _hit(1))
	_step(s, _hit(1))
	assert_false(s.wall_bounced)
	assert_lt(s.velocity.x, 0.0)
	assert_gt(s.velocity.x, -119.0 - 0.01, "not reflected a second time")

func test_a_bounce_locks_steering_for_nine_ticks() -> void:
	var s := _moving(140.0)
	_step(s, _hit(1))
	for k in 8:
		_step(s, _wall(0, 1.0))
		assert_almost_eq(s.velocity.x, -119.0, 0.01, "locked, tick %d" % (k + 1))
	_step(s, _wall(0, 1.0))
	assert_gt(s.velocity.x, -119.0, "control is back on the ninth tick")

func test_a_bounce_never_launches_so_it_cannot_climb() -> void:
	var s := _moving(140.0, 50.0)
	s.jumping = false
	_step(s, _hit(1))
	assert_eq(s.launched, "")
	assert_false(s.jumping)
	assert_gt(s.velocity.y, 0.0, "it is still falling")

func test_holding_jump_between_two_walls_never_rises() -> void:
	var s := MoveState.new()
	s.velocity = Vector2(140.0, 0.0)
	var x := 50.0
	var bounces := 0
	for _k in 300:
		var i := _wall(0, 1.0)
		i.jump_held = true
		if x <= 6.0:
			i.wall_side = -1
		elif x >= 94.0:
			i.wall_side = 1
		_step(s, i)
		x += s.velocity.x * DT
		bounces += 1 if s.wall_bounced else 0
		assert_eq(s.launched, "")
		assert_gte(s.velocity.y, 0.0)
	assert_gte(bounces, 2, "it did ping-pong between the walls")

func test_a_press_at_the_moment_of_contact_is_a_wall_jump_not_a_bounce() -> void:
	var s := _moving(140.0)
	var press := _wall(0, 1.0)
	press.jump_pressed = true
	press.jump_held = true
	_step(s, press)
	_step(s, _hit(1))
	assert_eq(s.launched, "wall")
	assert_false(s.wall_bounced)
	assert_eq(s.velocity.x, -180.0)

func test_the_bounce_does_not_need_the_wall_verb() -> void:
	var bare := slime.duplicate() as MovementProfile
	bare.verbs = PackedStringArray()
	var s := MoveState.new()
	s.velocity.x = 140.0
	var air := _wall(0, 1.0)
	air.jump_held = true
	_step(s, air, bare)
	_step(s, _hit(1), bare)
	assert_true(s.wall_bounced)
	assert_almost_eq(s.velocity.x, -119.0, 0.01)
	assert_false(s.clinging)

# --- the biped's wall slide and wall jump ---

func test_a_falling_biped_pressing_into_a_wall_slides_at_90_at_once() -> void:
	var s := MoveState.new()
	s.velocity.y = 300.0
	_step(s, _wall(-1, -1.0), biped)
	assert_eq(s.velocity.y, 90.0, "no stick: the first tick is already the slide")
	assert_true(s.clinging)
	for _k in 10:
		_step(s, _wall(-1, -1.0), biped)
		assert_eq(s.velocity.y, 90.0)

func test_the_biped_wall_jump_kicks_off_at_180_and_rises_as_far_as_the_base_jump() -> void:
	var s := _stuck(-1, biped)
	_step(s, _press(-1), biped)
	assert_eq(s.velocity, Vector2(180.0, -330.0))
	assert_eq(s.launched, "wall")
	var y := s.velocity.y * DT
	var top := y
	var air := _wall(0)
	air.jump_held = true
	for k in 120:
		_step(s, air, biped)
		if k < 8:
			assert_eq(s.velocity.x, 180.0, "locked for nine ticks, tick %d" % (k + 2))
		y += s.velocity.y * DT
		top = minf(top, y)
	var flat: Dictionary = MovementSim.flat_jump(biped, 1.0, 100.0, 0.0)
	assert_almost_eq(-top, flat["rise"], 0.001)

func test_the_biped_wall_grace_is_a_tenth_of_a_second() -> void:
	for quiet in [4, 7]:
		var s := _stuck(-1, biped)
		for _k in quiet:
			_step(s, _wall(0), biped)
		var press := _wall(0)
		press.jump_pressed = true
		_step(s, press, biped)
		assert_eq(s.launched, "wall" if quiet == 4 else "", "%d ticks off the wall" % quiet)

func test_the_biped_does_not_bounce_off_a_wall() -> void:
	var s := MoveState.new()
	s.velocity = Vector2(140.0, 0.0)
	var free := _wall(0, 1.0)
	free.jump_held = true
	_step(s, free, biped)
	_step(s, _hit(1), biped)
	assert_false(s.wall_bounced)
