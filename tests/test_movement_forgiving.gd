extends GutTest

const DT := 1.0 / 60.0

var slime: MovementProfile
var biped: MovementProfile
var wolf: MovementProfile
var spider: MovementProfile

func before_each() -> void:
	slime = MovementProfile.of("slime")
	biped = MovementProfile.of("biped")
	wolf = MovementProfile.of("wolf")
	spider = MovementProfile.of("spider")

## A slime dropped from 300 px, ticked with no input until it has landed; the next tick is the first floor tick.
func _landed() -> MovementSim:
	var sim := MovementSim.new(slime)
	sim.pos.y = -300.0
	sim.on_floor = false
	for _k in 600:
		sim.tick()
		if sim.on_floor:
			break
	return sim

func test_a_press_eight_ticks_before_landing_is_a_timed_rebound_and_twelve_is_not() -> void:
	for early in [8, 12]:
		var s := MoveState.new()
		s.air_time = 0.5
		var i := MoveInput.new()
		i.on_floor = false
		i.jump_pressed = true
		i.jump_held = true
		GroundAirStep.step(s, i, slime, DT)  # the press, in the air
		i.jump_pressed = false
		for _k in early - 1:
			GroundAirStep.step(s, i, slime, DT)
		i.on_floor = true
		s.velocity.y = 0.0
		GroundAirStep.step(s, i, slime, DT)
		assert_eq(s.launched, "rebound" if early == 8 else "", "%d ticks" % early)

func test_a_press_after_the_landing_inside_the_grace_is_a_timed_rebound() -> void:
	for late in [1, 4, 8]:
		var sim := _landed()
		for _k in late:
			sim.tick()
		sim.tick(0.0, true, true)
		assert_eq(sim.state.launched, "rebound" if late < 8 else "ground", "%d ticks after landing" % late)
		assert_eq(sim.state.chain, 1 if late < 8 else 0, "%d ticks after landing" % late)

func test_late_presses_chain_up_to_the_cap() -> void:
	var sim := _landed()
	for _k in 2:
		sim.tick()
	sim.tick(0.0, true, true)
	assert_eq(sim.state.chain, 1)
	for _k in 600:
		sim.tick(0.0, false, false)
		if sim.on_floor:
			break
	for _k in 2:
		sim.tick()
	sim.tick(0.0, true, true)
	assert_eq(sim.state.launched, "rebound")
	assert_eq(sim.state.chain, 2)
	assert_almost_eq(sim.state.launch_speed, 328.5 * sqrt(1.6), 0.01)

func test_the_chain_resets_when_the_grace_runs_out() -> void:
	var sim := _landed()
	sim.state.chain = 1
	for _k in 10:
		sim.tick()
	assert_eq(sim.state.chain, 0)
	assert_eq(sim.state.rebound_left, 0.0)

func test_walking_off_the_floor_inside_the_grace_ends_the_chain() -> void:
	var sim := _landed()
	sim.state.chain = 1
	sim.tick()
	assert_eq(sim.state.chain, 1, "still inside the grace")
	sim.on_floor = false
	sim.tick()
	assert_eq(sim.state.chain, 0)

func test_only_the_slime_is_forgiving() -> void:
	assert_eq(slime.buffer, 0.15)
	assert_eq(slime.rebound_grace, 0.08)
	for p in [biped, wolf, spider]:
		assert_eq(p.buffer, 0.1, p.id)
		assert_eq(p.rebound_grace, 0.0, p.id)
