extends GutTest

const DT := 1.0 / 60.0

var biped: MovementProfile

func before_each() -> void:
	biped = MovementProfile.of("biped")

## An airborne input with a wall on `side` and a ledge `rise` px above the feet, the stick at `dir`.
func _ledge(rise := 4.0, side := 1, dir := 1.0) -> MoveInput:
	var i := MoveInput.new()
	i.on_floor = false
	i.wall_side = side
	i.dir = dir
	i.mantle = Vector2(side * 32.0, -rise)
	return i

func test_it_starts_airborne_at_a_ledge_with_a_wall_ahead() -> void:
	var s := MoveState.new()
	s.velocity = Vector2(30.0, 0.0)
	s.jumping = true
	var i := _ledge()
	assert_true(MantleStep.step(s, i, biped, DT))
	assert_eq(s.mantle_left, 0.25)
	assert_eq(s.mantle_event, "start")
	assert_eq(s.velocity, Vector2.ZERO)
	assert_eq(s.mantle_total, i.mantle)
	assert_true(s.air_verb_used)
	assert_false(s.jumping)

func test_the_feet_must_be_within_6_px_plus_the_fall_this_tick() -> void:
	var at_rest := func(rise: float, vy: float) -> bool:
		var s := MoveState.new()
		s.velocity.y = vy
		return MantleStep.step(s, _ledge(rise), biped, DT)
	assert_true(at_rest.call(6.0, 0.0))
	assert_false(at_rest.call(7.0, 0.0))
	assert_true(at_rest.call(7.9, 120.0), "falling 2 px a tick adds 2")
	assert_false(at_rest.call(8.1, 120.0))
	assert_false(at_rest.call(0.0, 0.0), "no ledge above the feet")

func test_it_does_not_start_rising_faster_than_40() -> void:
	var rising := MoveState.new()
	rising.velocity.y = -41.0
	assert_false(MantleStep.step(rising, _ledge(), biped, DT))
	var slow := MoveState.new()
	slow.velocity.y = -40.0
	assert_true(MantleStep.step(slow, _ledge(), biped, DT))

func test_it_needs_a_wall_in_the_held_or_facing_direction() -> void:
	var away := MoveState.new()
	assert_false(MantleStep.step(away, _ledge(4.0, 1, -1.0), biped, DT), "the stick pulls away from the wall")
	var none := _ledge()
	none.wall_side = 0
	assert_false(MantleStep.step(MoveState.new(), none, biped, DT))
	var behind := MoveState.new()
	behind.facing = -1
	assert_false(MantleStep.step(behind, _ledge(4.0, 1, 0.0), biped, DT), "no stick: the facing says the wall is behind")
	var ahead := MoveState.new()
	ahead.facing = 1
	assert_true(MantleStep.step(ahead, _ledge(4.0, 1, 0.0), biped, DT), "no stick: the facing is the wall")
	var left := MoveState.new()
	left.facing = -1
	assert_true(MantleStep.step(left, _ledge(4.0, -1, 0.0), biped, DT))

func test_never_on_the_floor_or_with_no_probe_or_with_the_air_verb_spent() -> void:
	var floor_input := _ledge()
	floor_input.on_floor = true
	assert_false(MantleStep.step(MoveState.new(), floor_input, biped, DT))
	var no_probe := _ledge()
	no_probe.mantle = Vector2.ZERO
	assert_false(MantleStep.step(MoveState.new(), no_probe, biped, DT))
	var spent := MoveState.new()
	spent.air_verb_used = true
	assert_false(MantleStep.step(spent, _ledge(), biped, DT))

func test_the_pull_goes_up_then_over_and_sums_to_the_displacement() -> void:
	var s := MoveState.new()
	var i := _ledge(5.0)
	MantleStep.step(s, i, biped, DT)
	var sum := Vector2.ZERO
	var last_up := -1
	var first_over := -1
	var ticks := 1
	var calm := MoveInput.new()
	while s.mantle_event != "stand" and ticks < 40:
		assert_true(MantleStep.step(s, calm, biped, DT), "it owns the body every tick")
		sum += s.surface_shift
		if s.surface_shift.y != 0.0:
			last_up = ticks
		if s.surface_shift.x != 0.0 and first_over < 0:
			first_over = ticks
		ticks += 1
	assert_eq(s.mantle_event, "stand")
	assert_between(ticks, 15, 17)
	assert_almost_eq(sum.x, i.mantle.x, 0.001)
	assert_almost_eq(sum.y, i.mantle.y, 0.001)
	assert_lte(last_up, first_over, "all of the way up before the way over")
	assert_eq(s.mantle_left, 0.0)
	assert_eq(s.velocity, Vector2.ZERO)

# --- through the runner ---

func test_mantle_beats_a_wall_jump_on_the_same_press() -> void:
	var with_ledge := MoveState.new()
	var press := _ledge()
	press.jump_pressed = true
	VerbRunner.step(with_ledge, press, biped, DT)
	assert_eq(with_ledge.mantle_event, "start")
	assert_eq(with_ledge.launched, "", "no kick-off")
	var no_ledge := MoveState.new()
	var bare := _ledge()
	bare.mantle = Vector2.ZERO
	bare.jump_pressed = true
	VerbRunner.step(no_ledge, bare, biped, DT)
	assert_eq(no_ledge.launched, "wall", "without the ledge it is the wall jump")

func test_a_jump_pressed_during_the_mantle_fires_when_it_ends() -> void:
	var s := MoveState.new()
	VerbRunner.step(s, _ledge(), biped, DT)
	var press := MoveInput.new()
	press.jump_pressed = true
	VerbRunner.step(s, press, biped, DT)
	assert_true(s.queued_jump)
	var calm := MoveInput.new()
	var guard := 0
	while s.mantle_event != "stand" and guard < 40:
		VerbRunner.step(s, calm, biped, DT)
		guard += 1
	assert_eq(s.mantle_event, "stand")
	assert_eq(s.launched, "", "nothing fires while it owns the body")
	var landed := MoveInput.new()
	landed.on_floor = true
	VerbRunner.step(s, landed, biped, DT)
	assert_eq(s.launched, "ground", "the queued press jumps off the ledge")
	assert_false(s.queued_jump)

func test_only_the_biped_mantles() -> void:
	for id in ["slime", "spider", "wolf"]:
		var s := MoveState.new()
		VerbRunner.step(s, _ledge(), MovementProfile.of(id), DT)
		assert_eq(s.mantle_event, "", id)
		assert_eq(s.mantle_left, 0.0, id)
