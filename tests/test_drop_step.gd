extends GutTest

const DT := 1.0 / 60.0

var spider: MovementProfile

func before_each() -> void:
	spider = MovementProfile.of("spider")

## A world with the spike's terrain, the spider at `pos` on the surface `n` (ZERO for in the air), and the state to match.
func _at(pos: Vector2, n := Vector2.ZERO) -> Array:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = pos
	w.n = n if n != Vector2.ZERO else Vector2.UP
	var s := MoveState.new()
	s.surface_n = n
	return [w, s]

## One tick: `stick` is x right and y down (up negative); `press` marks the down edge as the runner would; `jump` a jump press.
func _tick(w: FakeSurfaceWorld, s: MoveState, stick := Vector2.ZERO, press := false, jump := false) -> bool:
	var i := w.input()
	i.dir = stick.x
	i.down = maxf(stick.y, 0.0)
	i.up = maxf(-stick.y, 0.0)
	i.jump_pressed = jump
	i.jump_held = jump
	s.down_pressed = press
	var owns := DropStep.step(s, i, spider, DT)
	w.apply(s)
	return owns

## Starts a drop and returns the state ready for the next tick.
func _dropping(pos: Vector2, n := Vector2.ZERO) -> Array:
	var a := _at(pos, n)
	_tick(a[0], a[1], Vector2.ZERO, true)
	return a

func test_a_press_of_down_in_the_air_spins_a_thread_from_the_solid_above() -> void:
	var a := _at(Vector2(600, -100))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	s.velocity = Vector2(0, 300)  # falling
	assert_true(_tick(w, s, Vector2.ZERO, true))
	assert_eq(s.drop_event, "start")
	assert_almost_eq(s.drop_up, 60.0, 1.0, "the slab's underside is 60 px above the centre")
	assert_almost_eq(s.drop_target.y, -60.0, 0.5)
	assert_true(s.air_verb_used)
	assert_eq(s.surface_n, Vector2.ZERO)
	assert_eq(s.velocity, Vector2.ZERO, "the fall stops")

func test_it_needs_a_fresh_press_not_a_held_down() -> void:
	var a := _at(Vector2(600, -100))
	assert_false(_tick(a[0], a[1], Vector2(0, 1), false))
	assert_eq((a[1] as MoveState).drop_event, "")

func test_nothing_above_within_200_costs_nothing() -> void:
	var a := _at(Vector2(100, -300))
	assert_false(_tick(a[0], a[1], Vector2.ZERO, true))
	assert_eq((a[1] as MoveState).drop_event, "fizzle")
	assert_false((a[1] as MoveState).air_verb_used)
	var under_ledge := _at(Vector2(900, -12))  # a one-way ledge is above it: not an anchor
	_tick(under_ledge[0], under_ledge[1], Vector2.ZERO, true)
	assert_eq((under_ledge[1] as MoveState).drop_event, "fizzle")

func test_down_reels_at_90_and_up_climbs_at_60() -> void:
	var a := _dropping(Vector2(600, -100))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	var up0 := s.drop_up
	var y0 := w.pos.y
	for _k in 30:
		_tick(w, s, Vector2(0, 1))
	assert_almost_eq(w.pos.y - y0, 45.0, 1.0, "90 px/s for half a second")
	assert_almost_eq(s.drop_up - up0, 45.0, 1.0)
	y0 = w.pos.y
	for _k in 30:
		_tick(w, s, Vector2(0, -1))
	assert_almost_eq(y0 - w.pos.y, 30.0, 1.0, "60 px/s up")

func test_it_never_climbs_above_the_anchor() -> void:
	var a := _dropping(Vector2(600, -100))
	for _k in 200:
		_tick(a[0], a[1], Vector2(0, -1))
	assert_almost_eq((a[1] as MoveState).drop_up, 12.0, 0.01, "the box's half height under the anchor")
	_tick(a[0], a[1], Vector2(0, -1))
	assert_eq((a[1] as MoveState).surface_shift, Vector2.ZERO)

func test_air_control_is_half() -> void:
	var a := _dropping(Vector2(600, -100))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	var target := s.drop_target
	for _k in 60:
		_tick(w, s, Vector2.RIGHT)
	assert_almost_eq(s.drop_vx, 70.0, 0.01, "half of 140, and no more")
	assert_eq(s.drop_target, target, "the anchor stays where the thread was spun")

func test_it_lands_on_the_floor_and_grips_it() -> void:
	var a := _dropping(Vector2(600, -80))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	var landed := false
	for _k in 200:
		_tick(w, s, Vector2(0, 1))
		if s.drop_event == "land":
			landed = true
			break
	assert_true(landed)
	assert_eq(s.surface_n, Vector2.UP)
	assert_almost_eq(w.pos.y, -12.0, 1.5)
	assert_false(s.air_verb_used, "gripping a surface gives the air verb back")
	assert_eq(s.drop_up, 0.0)

func test_a_jump_lets_go_with_the_current_velocity() -> void:
	var a := _dropping(Vector2(600, -100))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	for _k in 30:
		_tick(w, s, Vector2(1, 1))
	_tick(w, s, Vector2(1, 1), false, true)
	assert_eq(s.drop_event, "release")
	assert_almost_eq(s.velocity.x, 70.0, 0.01)
	assert_eq(s.velocity.y, 90.0, "the reel's speed, no extra impulse")
	assert_eq(s.launched, "drop_release")
	assert_true(s.air_verb_used, "still the airtime's verb")
	assert_eq(s.drop_up, 0.0)
	var hanging := _dropping(Vector2(600, -100))
	_tick(hanging[0], hanging[1], Vector2.ZERO, false, true)
	assert_eq((hanging[1] as MoveState).velocity, Vector2.ZERO)

func test_a_wall_beside_stops_the_sideways_motion_not_the_reel() -> void:
	var a := _dropping(Vector2(505, -80))  # under the slab, 15 px right of the pillar's right face (x 490)
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	var x0 := w.pos.x
	var y0 := w.pos.y
	for _k in 30:
		_tick(w, s, Vector2(-1, 1))
	assert_almost_eq(w.pos.x, x0, 3.0, "stopped by the pillar's face")
	assert_gt(w.pos.y - y0, 40.0, "and still reeling down")
	assert_eq(s.drop_vx, 0.0)

func test_it_starts_while_hanging_from_a_ceiling_and_not_from_a_wall_or_the_floor() -> void:
	var ceiling := _at(Vector2(600, -148), Vector2.DOWN)
	assert_true(_tick(ceiling[0], ceiling[1], Vector2.ZERO, true))
	assert_eq((ceiling[1] as MoveState).drop_event, "start")
	assert_almost_eq((ceiling[1] as MoveState).drop_up, 12.0, 0.6)
	assert_eq((ceiling[1] as MoveState).surface_n, Vector2.ZERO)
	var wall := _at(Vector2(188, -60), Vector2.LEFT)
	assert_false(_tick(wall[0], wall[1], Vector2.ZERO, true), "down on a wall is crawling down it")
	var floor_ := _at(Vector2(600, -12), Vector2.UP)
	assert_false(_tick(floor_[0], floor_[1], Vector2.ZERO, true))

func test_one_drop_per_airtime() -> void:
	var a := _dropping(Vector2(600, -100))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	_tick(w, s, Vector2.ZERO, false, true)  # let go
	assert_false(_tick(w, s, Vector2.ZERO, true), "a second press in the same airtime")
	assert_eq(s.drop_event, "")

func test_no_probes_and_a_zip_in_flight_do_nothing() -> void:
	var s := MoveState.new()
	s.down_pressed = true
	assert_false(DropStep.step(s, MoveInput.new(), spider, DT))
	var a := _at(Vector2(600, -100))
	(a[1] as MoveState).zip_dir = Vector2.RIGHT
	assert_false(_tick(a[0], a[1], Vector2.ZERO, true), "a zip owns the tick")
