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

func test_cut_caps_the_rise_speed_once() -> void:
	var sim := MovementSim.new(biped)
	sim.tick(0.0, true, true)
	sim.tick(0.0, false, false)
	assert_almost_eq(sim.state.velocity.y, -330.0 * 0.35, 0.001)
	assert_false(sim.state.jumping)
	sim = MovementSim.new(biped)
	sim.tick(0.0, true, false)
	assert_eq(sim.state.velocity.y, -330.0, "the launch tick is never cut")

func test_cut_never_raises_speed_and_nothing_happens_after_the_apex() -> void:
	var air := MoveInput.new()
	air.on_floor = false
	var s := MoveState.new()
	s.jumping = true
	s.launch_speed = 330.0
	s.velocity.y = -50.0
	GroundAirStep.step(s, air, biped, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, -35.0, 0.001, "only gravity acted")
	s = MoveState.new()
	s.jumping = true
	s.launch_speed = 330.0
	s.velocity.y = 10.0
	GroundAirStep.step(s, air, biped, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, 25.0, 0.001)
	assert_false(s.jumping)

func test_tap_hops_are_rounded_per_profile_and_never_a_no_op() -> void:
	for row in [[biped, 8.0, 20.0], [slime, 18.0, 34.0], [wolf, 24.0, 40.0]]:
		var tap: float = MovementSim.flat_jump(row[0], 1.0, 0.0)["rise"]
		assert_between(tap, row[1], row[2], row[0].id)
		assert_lt(tap, 0.6 * MovementSim.flat_jump(row[0])["rise"], row[0].id)

func test_a_buffered_landing_rebounds_only_for_the_slime_and_never_compounds() -> void:
	var s := MoveState.new()
	for _n in 2:  # one state across two landings
		s.air_time = 0.5
		s.buffer = 0.05
		GroundAirStep.step(s, MoveInput.new(), slime, 1.0 / 60.0)
		assert_almost_eq(s.launch_speed, 328.5 * sqrt(1.15), 0.01)
		assert_eq(s.launched, "rebound")
	var w := MoveState.new()
	w.air_time = 0.5
	w.buffer = 0.05
	GroundAirStep.step(w, MoveInput.new(), wolf, 1.0 / 60.0)
	assert_eq(w.launch_speed, 403.0)
	assert_eq(w.launched, "ground")

func test_the_rebound_raises_the_apex_by_about_fifteen_percent() -> void:
	var ratio: float = MovementSim.flat_jump(slime, 1.0, 100.0, -1.0, true)["rise"] / MovementSim.flat_jump(slime)["rise"]
	assert_between(ratio, 1.10, 1.20)

func test_no_rebound_from_a_grounded_press_a_coyote_jump_or_a_held_button() -> void:
	var i := MoveInput.new()
	i.jump_pressed = true
	i.jump_held = true
	var s := MoveState.new()
	GroundAirStep.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.launch_speed, 328.5)
	assert_eq(s.launched, "ground")
	i.on_floor = false
	s = MoveState.new()
	s.air_time = 0.5  # long enough for a rebound, but the body is off the floor
	s.coyote = 0.05
	GroundAirStep.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.launch_speed, 328.5)
	assert_eq(s.launched, "coyote")
	i.on_floor = true
	i.jump_pressed = false  # held through the landing, never pressed
	s = MoveState.new()
	s.air_time = 0.5
	GroundAirStep.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.launched, "")

func test_air_time_and_the_rebound_come_from_a_real_flight() -> void:
	var sim := MovementSim.new(slime)
	var ticks := roundi(MovementSim.flat_jump(slime)["airtime"] * 60.0)
	sim.tick(0.0, true, true)
	for _k in range(1, ticks - 3):
		sim.tick(0.0, false, true)
	sim.tick(0.0, true, true)  # a press three ticks before the landing
	for _k in 6:
		sim.tick(0.0, false, true)
		if sim.state.launched != "":
			break
	assert_eq(sim.state.launched, "rebound")
	var hop := MovementSim.new(slime)
	hop.pos.y = -3.0  # a drop of five ticks, under the 0.12 s minimum
	hop.on_floor = false
	hop.tick()
	hop.tick()
	hop.tick(0.0, true, true)
	for _k in 6:
		hop.tick(0.0, false, true)
		if hop.state.launched != "":
			break
	assert_eq(hop.state.launched, "ground")

func test_the_spider_has_no_variable_jump() -> void:
	assert_almost_eq(MovementSim.flat_jump(spider, 1.0, 0.0)["rise"], MovementSim.flat_jump(spider)["rise"], 0.01)
