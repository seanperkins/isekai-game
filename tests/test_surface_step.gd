extends GutTest

const DT := 1.0 / 60.0

var spider: MovementProfile

func before_each() -> void:
	spider = MovementProfile.of("spider")

## A world with the spike's terrain, the body on a surface, and the state to match.
func _on(pos: Vector2, n: Vector2, sigma := 1.0) -> Array:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = pos
	w.n = n
	var s := MoveState.new()
	s.surface_n = n
	s.surface_sigma = sigma
	return [w, s]

## One tick with `stick` held (x right, y down).
func _tick(w: FakeSurfaceWorld, s: MoveState, stick: Vector2, press := false, boost := 1.0) -> bool:
	var i := w.input()
	i.dir = stick.x
	i.down = maxf(stick.y, 0.0)
	i.up = maxf(-stick.y, 0.0)
	i.jump_pressed = press
	i.jump_held = press
	var owns := SurfaceStep.step(s, i, spider, DT, boost)
	w.apply(s)
	return owns

## Runs `ticks` ticks and returns the events that happened, in order.
func _run(w: FakeSurfaceWorld, s: MoveState, stick: Vector2, ticks: int) -> Array[String]:
	var events: Array[String] = []
	for _k in ticks:
		_tick(w, s, stick)
		if s.surface_event != "":
			events.append(s.surface_event)
	return events

func test_the_box_matches_the_body_config() -> void:
	assert_eq(SurfaceStep.box_size(Vector2.UP), BodyConfig.size())
	assert_eq(SurfaceStep.box_size(Vector2.DOWN), BodyConfig.size())
	assert_eq(SurfaceStep.box_size(Vector2.LEFT), Vector2(BodyConfig.size().y, BodyConfig.size().x))
	assert_eq(SurfaceStep.HT, BodyConfig.size().x / 2.0)
	assert_eq(SurfaceStep.HN, BodyConfig.size().y / 2.0)

func test_the_tangent_is_the_exact_clockwise_axis() -> void:
	assert_eq(SurfaceStep.tangent(Vector2.UP), Vector2.RIGHT)
	assert_eq(SurfaceStep.tangent(Vector2.RIGHT), Vector2.DOWN)
	assert_eq(SurfaceStep.tangent(Vector2.DOWN), Vector2.LEFT)
	assert_eq(SurfaceStep.tangent(Vector2.LEFT), Vector2.UP)

func test_a_held_direction_crawls_at_140_and_stops_at_once() -> void:
	var sc := _on(Vector2(40, -12), Vector2.UP)
	var w: FakeSurfaceWorld = sc[0]
	var s: MoveState = sc[1]
	_run(w, s, Vector2.RIGHT, 30)
	assert_almost_eq(w.pos.x, 110.0, 1.0, "140 px/s for half a second")
	var at := w.pos.x
	_run(w, s, Vector2.ZERO, 10)
	assert_eq(w.pos.x, at, "no coasting")

func test_screen_relative_on_a_ceiling_and_a_wall() -> void:
	var up := _on(Vector2(600, -148), Vector2.DOWN)
	_run(up[0], up[1], Vector2.RIGHT, 10)
	assert_gt((up[0] as FakeSurfaceWorld).pos.x, 620.0, "right is right on a ceiling")
	var wall := _on(Vector2(188, -60), Vector2.LEFT)
	_run(wall[0], wall[1], Vector2.UP, 10)
	assert_lt((wall[0] as FakeSurfaceWorld).pos.y, -80.0, "up is up on a wall")
	var still := _on(Vector2(188, -60), Vector2.LEFT)
	_run(still[0], still[1], Vector2.RIGHT, 10)
	assert_eq((still[0] as FakeSurfaceWorld).pos.y, -60.0, "right does nothing on a wall that is to the right")

func test_a_wall_ahead_turns_the_crawl_up_it() -> void:
	var sc := _on(Vector2(120, -12), Vector2.UP)
	var w: FakeSurfaceWorld = sc[0]
	var s: MoveState = sc[1]
	var events := _run(w, s, Vector2.RIGHT, 40)
	assert_eq(events, ["concave"])
	assert_eq(s.surface_n, Vector2.LEFT)
	assert_almost_eq(w.pos.x, 188.0, 1.5)
	var y := w.pos.y
	_run(w, s, Vector2.RIGHT, 10)
	assert_lt(w.pos.y, y - 20.0, "it climbs with the stick still pointing at the wall: the latch")

func test_the_latch_survives_a_release_and_a_different_direction_drops_it() -> void:
	var sc := _on(Vector2(120, -12), Vector2.UP)
	var w: FakeSurfaceWorld = sc[0]
	var s: MoveState = sc[1]
	_run(w, s, Vector2.RIGHT, 40)
	_run(w, s, Vector2.RIGHT, 5)
	var y := w.pos.y
	_run(w, s, Vector2.ZERO, 3)
	assert_eq(w.pos.y, y, "released: it holds")
	_run(w, s, Vector2.RIGHT, 5)
	assert_lt(w.pos.y, y - 8.0, "the same direction again carries on up")
	y = w.pos.y
	_run(w, s, Vector2.DOWN, 5)
	assert_gt(w.pos.y, y + 8.0, "a clearly different direction is screen-relative: down goes down")
	y = w.pos.y
	_run(w, s, Vector2.RIGHT, 5)
	assert_eq(w.pos.y, y, "and the latch is gone")
