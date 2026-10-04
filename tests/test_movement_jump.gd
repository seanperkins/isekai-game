extends GutTest

var biped: MovementProfile
var slime: MovementProfile
var wolf: MovementProfile

func before_each() -> void:
	biped = MovementProfile.of("biped")
	slime = MovementProfile.of("slime")
	wolf = MovementProfile.of("wolf")

func test_gravity_only_in_the_air_with_fall_and_apex_rules() -> void:
	var s := MoveState.new()
	GroundAirStep.step(s, MoveInput.new(), biped, 1.0 / 60.0)
	assert_eq(s.velocity.y, 0.0)
	var air := MoveInput.new()
	air.on_floor = false
	GroundAirStep.step(s, air, biped, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, 15.0, 0.001)
	s = MoveState.new()
	s.velocity.y = 100.0
	GroundAirStep.step(s, air, slime, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, 100.0 + 900.0 * 1.53 / 60.0, 0.001, "falling is heavier")
	s = MoveState.new()
	s.velocity.y = -20.0
	air.jump_held = true
	GroundAirStep.step(s, air, slime, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, -20.0 + 450.0 / 60.0, 0.001, "float at the apex while held")
	s = MoveState.new()
	s.velocity.y = 20.0
	GroundAirStep.step(s, air, slime, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, 20.0 + 900.0 * 0.5 * 1.53 / 60.0, 0.001, "float and fall compound")
	s = MoveState.new()
	s.velocity.y = -20.0
	air.jump_held = false
	GroundAirStep.step(s, air, slime, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, -20.0 + 900.0 / 60.0, 0.001, "no float once released")

func test_a_press_launches_and_the_boost_scales_it() -> void:
	var sim := MovementSim.new(biped)
	sim.tick(0.0, true, true)
	assert_eq(sim.state.velocity.y, -330.0)
	assert_eq(sim.state.launched, "ground")
	sim = MovementSim.new(biped)
	sim.tick(0.0, true, true, 1.3)
	assert_almost_eq(sim.state.velocity.y, -330.0 * 1.3, 0.001)

func test_coyote_lets_a_late_jump_through_for_three_ticks_not_nine() -> void:
	for late in [3, 9]:
		var sim := MovementSim.new(biped)
		sim.tick()  # a floor tick refills the coyote window
		sim.pos.y = -50.0
		sim.on_floor = false  # the floor ends under the body
		for _k in late:
			sim.tick()
		sim.tick(0.0, true, true)
		if late == 3:
			assert_lt(sim.state.velocity.y, -300.0)
			assert_eq(sim.state.launched, "coyote")
		else:
			assert_gt(sim.state.velocity.y, 0.0)
			assert_eq(sim.state.launched, "")

func test_a_buffered_press_fires_on_landing_inside_the_window_only() -> void:
	for early in [4, 8]:
		var s := MoveState.new()
		var i := MoveInput.new()
		i.on_floor = false
		i.jump_pressed = true
		i.jump_held = true
		GroundAirStep.step(s, i, biped, 1.0 / 60.0)  # the press, in the air
		i.jump_pressed = false
		for _k in early - 1:
			GroundAirStep.step(s, i, biped, 1.0 / 60.0)
		i.on_floor = true  # lands `early` ticks after the press
		s.velocity.y = 0.0
		GroundAirStep.step(s, i, biped, 1.0 / 60.0)
		assert_eq(s.velocity.y, -330.0 if early == 4 else 0.0, "%d ticks" % early)

func test_coyote_and_buffer_together_launch_once() -> void:
	var s := MoveState.new()
	var i := MoveInput.new()
	i.on_floor = false
	i.jump_pressed = true
	i.jump_held = true
	s.coyote = 0.05
	s.buffer = 0.05
	GroundAirStep.step(s, i, biped, 1.0 / 60.0)
	assert_eq(s.velocity.y, -330.0)
	assert_eq(s.buffer, 0.0)
	assert_eq(s.coyote, 0.0)
	i.jump_pressed = false
	GroundAirStep.step(s, i, biped, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, -315.0, 0.001, "no second launch")
	assert_eq(s.launched, "")

func test_a_frame_hitch_stays_finite() -> void:
	var s := MoveState.new()
	var i := MoveInput.new()
	i.on_floor = false
	i.dir = 1.0
	s.coyote = 0.1
	s.buffer = 0.1
	GroundAirStep.step(s, i, slime, 0.25)
	assert_almost_eq(s.velocity.y, 225.0, 0.001)
	assert_true(is_finite(s.velocity.x))
	assert_eq(s.coyote, 0.0)
	assert_eq(s.buffer, 0.0)
