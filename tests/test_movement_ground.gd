extends GutTest

var biped: MovementProfile
var slime: MovementProfile
var wolf: MovementProfile
var spider: MovementProfile

func before_each() -> void:
	biped = MovementProfile.of("biped")
	slime = MovementProfile.of("slime")
	wolf = MovementProfile.of("wolf")
	spider = MovementProfile.of("spider")

func _run(p: MovementProfile, s: MoveState, i: MoveInput, ticks: int) -> void:
	for _k in ticks:
		GroundAirStep.step(s, i, p, 1.0 / 60.0)

func _in(dir := 0.0, on_floor := true) -> MoveInput:
	var i := MoveInput.new()
	i.dir = dir
	i.on_floor = on_floor
	return i

func _at(vx: float) -> MoveState:
	var s := MoveState.new()
	s.velocity.x = vx
	return s

func test_ground_ramps_per_profile() -> void:
	var s := MoveState.new()
	_run(biped, s, _in(1.0), 3)
	assert_eq(s.velocity.x, 140.0)
	s = MoveState.new()
	_run(slime, s, _in(1.0), 2)
	assert_almost_eq(s.velocity.x, 93.33, 0.05)
	_run(slime, s, _in(1.0), 2)
	assert_eq(s.velocity.x, 140.0)
	_run(slime, s, _in(), 4)
	assert_eq(s.velocity.x, 0.0, "stops in 0.06 s")
	s = MoveState.new()
	_run(wolf, s, _in(1.0), 12)
	assert_almost_eq(s.velocity.x, 115.0, 0.1)
	_run(wolf, s, _in(1.0), 12)
	assert_almost_eq(s.velocity.x, 230.0, 0.01)

func test_wolf_brakes_in_six_ticks_then_reverses() -> void:
	var s := _at(230.0)
	_run(wolf, s, _in(-1.0), 6)
	assert_almost_eq(s.velocity.x, 0.0, 0.001)
	_run(wolf, s, _in(-1.0), 2)
	assert_lt(s.velocity.x, 0.0)

func test_air_control_per_profile() -> void:
	var s := _at(140.0)
	_run(slime, s, _in(0.0, false), 10)
	assert_almost_eq(s.velocity.x, 73.33, 0.05, "bleeds at 400 px/s^2")
	s = _at(230.0)
	_run(wolf, s, _in(0.0, false), 30)
	assert_eq(s.velocity.x, 230.0, "the wolf keeps its momentum")
	s = _at(140.0)
	_run(biped, s, _in(0.0, false), 3)
	assert_eq(s.velocity.x, 0.0)
	s = MoveState.new()
	_run(slime, s, _in(1.0, false), 3)
	assert_almost_eq(s.velocity.x, 70.0, 0.05, "slime air accel is 1400 px/s^2")

func test_analog_input_and_a_zero_speed_stat() -> void:
	var s := MoveState.new()
	_run(biped, s, _in(0.5), 10)
	assert_eq(s.velocity.x, 70.0)
	s = _at(100.0)
	GroundAirStep.step(s, _in(0.5), biped, 1.0 / 60.0, 0.0)
	assert_eq(s.velocity.x, 0.0, "speed_scale 0 roots the body")

func test_the_spider_skitters() -> void:
	var s := MoveState.new()
	_run(spider, s, _in(1.0), 2)
	assert_eq(s.velocity.x, 140.0)
	_run(spider, s, _in(), 2)
	assert_eq(s.velocity.x, 0.0)

func test_the_wolf_skids_when_it_reverses_at_a_gallop() -> void:
	var s := _at(230.0)
	var seen: Array = []
	for _k in 6:
		GroundAirStep.step(s, _in(-1.0), wolf, 1.0 / 60.0)
		seen.append(s.skidding)
	assert_eq(seen, [true, true, true, false, false, false], "230, 192, 153 px/s skid; 115 and under do not")
	assert_almost_eq(s.velocity.x, 0.0, 0.01, "the brake is the tuned 0.1 s turn")
	var left := _at(-230.0)
	GroundAirStep.step(left, _in(1.0), wolf, 1.0 / 60.0)
	assert_true(left.skidding, "to the left too")

func test_no_skid_in_the_air_or_with_the_stick_released_or_below_150() -> void:
	var air := _at(230.0)
	GroundAirStep.step(air, _in(-1.0, false), wolf, 1.0 / 60.0)
	assert_false(air.skidding, "in the air")
	var released := _at(230.0)
	GroundAirStep.step(released, _in(0.0), wolf, 1.0 / 60.0)
	assert_false(released.skidding, "a plain stop is not a skid")
	var same := _at(230.0)
	GroundAirStep.step(same, _in(1.0), wolf, 1.0 / 60.0)
	assert_false(same.skidding, "the stick with the motion")
	var slow := _at(149.0)
	GroundAirStep.step(slow, _in(-1.0), wolf, 1.0 / 60.0)
	assert_false(slow.skidding, "under 150")
	var edge := _at(150.0)
	GroundAirStep.step(edge, _in(-1.0), wolf, 1.0 / 60.0)
	assert_true(edge.skidding, "150 is the line")

func test_the_skid_flag_does_not_stay_set_when_a_burst_owns_the_velocity() -> void:
	var s := _at(230.0)
	GroundAirStep.step(s, _in(-1.0), wolf, 1.0 / 60.0)
	assert_true(s.skidding)
	s.verb = "pounce"
	GroundAirStep.step(s, _in(-1.0), wolf, 1.0 / 60.0)
	assert_false(s.skidding)

func test_a_slime_and_a_biped_do_not_skid_at_their_top_speeds() -> void:
	for p in [slime, biped, spider]:
		var s := _at(140.0)
		GroundAirStep.step(s, _in(-1.0), p, 1.0 / 60.0)
		assert_false(s.skidding, p.id)
