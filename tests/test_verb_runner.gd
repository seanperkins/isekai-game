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
