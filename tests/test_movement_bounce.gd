extends GutTest

var slime: MovementProfile
var biped: MovementProfile

func before_each() -> void:
	slime = MovementProfile.of("slime")
	biped = MovementProfile.of("biped")

## Drops a body `height` px above the floor and ticks it with jump held or not; returns the launch speed of every bounce.
func _drop(p: MovementProfile, height: float, hold: bool) -> Array:
	var sim := MovementSim.new(p)
	sim.pos.y = -height
	sim.on_floor = false
	var launches: Array = []
	for _k in 900:
		sim.tick(0.0, false, hold)
		if sim.state.launched == "bounce":
			launches.append(sim.state.launch_speed)
	return launches

func test_a_hard_landing_with_jump_held_bounces_at_85_percent_until_it_settles() -> void:
	var launches := _drop(slime, 300.0, true)
	assert_between(launches.size(), 3, 6)
	assert_almost_eq(launches[0], 328.5, 0.01, "capped at the base jump")
	for k in range(1, launches.size()):
		assert_almost_eq(launches[k] / launches[k - 1], 0.85, 0.06)

func test_a_soft_landing_does_not_bounce() -> void:
	assert_eq(_drop(slime, 15.0, true).size(), 0)

func test_releasing_jump_stops_the_bouncing() -> void:
	assert_eq(_drop(slime, 300.0, false).size(), 0)

func test_species_without_bounce_never_bounce() -> void:
	assert_eq(_drop(biped, 300.0, true).size(), 0)

func test_a_hold_bounce_never_rises_above_the_base_jump() -> void:
	var sim := MovementSim.new(slime)
	sim.pos.y = -300.0
	sim.on_floor = false
	var highest := 0.0
	var landed := false
	for _k in 600:
		sim.tick(0.0, false, true)
		if sim.on_floor:
			landed = true
		if landed:
			highest = maxf(highest, -sim.pos.y)
	assert_lte(highest, MovementSim.flat_jump(slime)["rise"] + 0.5)

func test_a_timed_press_beats_the_hold_bounce_with_one_launch() -> void:
	var s := MoveState.new()
	var i := MoveInput.new()
	i.jump_held = true
	s.air_time = 0.5
	s.last_vy = 400.0
	s.buffer = 0.05
	GroundAirStep.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.launched, "rebound")
	assert_almost_eq(s.launch_speed, 328.5 * sqrt(1.3), 0.01)

func test_the_timed_chain_tops_out_near_one_point_six_times_the_base_rise() -> void:
	var base: float = MovementSim.flat_jump(slime)["rise"]
	var sim := MovementSim.new(slime)
	sim.state.chain = 5
	sim.state.air_time = 0.5
	sim.tick(0.0, true, true)
	var rise := 0.0
	for _k in 120:
		sim.tick(0.0, false, true)
		rise = maxf(rise, -sim.pos.y)
		if sim.on_floor:
			break
	assert_between(rise / base, 1.5, 1.7)

func test_a_jump_pressed_just_after_a_bounce_is_not_a_free_mid_air_jump() -> void:
	for delay in [1, 3, 6]:
		var sim := MovementSim.new(slime)
		sim.pos.y = -300.0
		sim.on_floor = false
		var bounced := false
		for _k in 200:
			sim.tick(0.0, false, true)
			if sim.state.launched == "bounce":
				bounced = true
				break
		assert_true(bounced, "it bounced")
		for _k in delay:
			sim.tick(0.0, false, true)
		sim.tick(0.0, true, true)
		assert_ne(sim.state.launched, "coyote", "a press %d ticks after the bounce" % delay)
