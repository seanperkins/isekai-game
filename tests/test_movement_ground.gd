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
