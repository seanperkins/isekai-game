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

## Ticks until `done` is true (at most `limit`), returning the events in order.
func _until(w: FakeSurfaceWorld, s: MoveState, stick: Variant, limit: int, done: Callable) -> Array[String]:
	var events: Array[String] = []
	for k in limit:
		_tick(w, s, stick.call(k) if stick is Callable else stick)
		if s.surface_event != "":
			events.append(s.surface_event)
		if done.call():
			break
	return events

func _on_floor_past(s: MoveState, w: FakeSurfaceWorld, x: float, right := true) -> bool:
	return s.surface_n == Vector2.UP and (w.pos.x > x if right else w.pos.x < x) and w.pos.y > -20.0

func test_one_held_direction_rounds_the_block_both_ways() -> void:
	var a := _on(Vector2(120, -12), Vector2.UP)
	var ev := _until(a[0], a[1], Vector2.RIGHT, 400, func(): return _on_floor_past(a[1], a[0], 330.0))
	assert_eq(ev, ["concave", "convex", "convex", "concave"])
	var b := _on(Vector2(420, -12), Vector2.UP, -1.0)
	ev = _until(b[0], b[1], Vector2.LEFT, 400, func(): return _on_floor_past(b[1], b[0], 170.0, false))
	assert_eq(ev, ["concave", "convex", "convex", "concave"])

func test_one_held_direction_rounds_the_pillar_and_slab() -> void:
	var a := _on(Vector2(400, -12), Vector2.UP)
	var seen := {}
	var ev := _until(a[0], a[1], Vector2.RIGHT, 600, func():
		seen[a[1].surface_n] = true
		return _on_floor_past(a[1], a[0], 520.0) and (a[1] as MoveState).surface_since > 0.0 and seen.size() == 4)
	assert_eq(ev, ["concave", "convex", "convex", "convex", "concave", "concave"])
	assert_eq(seen.size(), 4, "all four normals")
	var b := _on(Vector2(540, -12), Vector2.UP, -1.0)
	seen = {}
	ev = _until(b[0], b[1], Vector2.LEFT, 600, func():
		seen[b[1].surface_n] = true
		return _on_floor_past(b[1], b[0], 420.0, false) and seen.size() == 4)
	assert_eq(ev.size(), 6)
	assert_eq(seen.size(), 4)

func test_noisy_input_still_gets_round() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var noisy := func(_k: int) -> Vector2:
		var r := rng.randf()
		if r < 0.05:
			return Vector2.ZERO
		if r < 0.10:
			return Vector2(1.0, 0.5)
		if r < 0.15:
			return Vector2(1.0, -0.5)
		return Vector2.RIGHT
	var a := _on(Vector2(400, -12), Vector2.UP)
	var ev := _until(a[0], a[1], noisy, 1000, func(): return _on_floor_past(a[1], a[0], 520.0) and (a[1] as MoveState).surface_since > 0.5)
	assert_gte(ev.size(), 6)
	assert_true(_on_floor_past(a[1], a[0], 520.0), "it got round")

func test_pressing_back_just_after_a_corner_goes_back_round_it() -> void:
	var a := _on(Vector2(188, -60), Vector2.LEFT)
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	var ev := _until(w, s, Vector2.UP, 100, func(): return s.surface_event == "convex")
	assert_eq(ev, ["convex"])
	_run(w, s, Vector2.UP, 2)
	ev = _until(w, s, Vector2.DOWN, 300, func(): return _on_floor_past(s, w, 190.0, false))
	assert_eq(ev, ["convex", "concave"], "back round the corner, down the face, onto the floor")

func test_a_corner_does_not_repeat_inside_the_lockout() -> void:
	var flutter := func(k: int) -> Vector2: return Vector2.LEFT if (k / 4) % 2 == 0 else Vector2.RIGHT
	var a := _on(Vector2(206, -112), Vector2.UP)
	var ev := _until(a[0], a[1], flutter, 240, func(): return false)
	assert_lte(ev.size(), 1, "corner_lock 0.10")
	spider = spider.duplicate() as MovementProfile
	spider.corner_lock = 0.06
	var b := _on(Vector2(206, -112), Vector2.UP)
	ev = _until(b[0], b[1], flutter, 240, func(): return false)
	assert_gt(ev.size(), 20, "with 0.06 the same wiggle rounds it every few frames")

func test_a_convex_corner_moves_the_centre_about_19_px_and_a_concave_one_under_5() -> void:
	var a := _on(Vector2(120, -12), Vector2.UP)
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	var convex := []
	var concave := []
	for _k in 400:
		_tick(w, s, Vector2.RIGHT)
		if _on_floor_past(s, w, 330.0):
			break
		if s.surface_event == "convex":
			convex.append(s.surface_shift.length())
		elif s.surface_event == "concave":
			concave.append(s.surface_shift.length())
	assert_eq(convex.size(), 2)
	for d in convex:
		assert_almost_eq(float(d), 19.5, 1.5)
	for d in concave:
		assert_lt(float(d), 5.0)

func test_it_crosses_a_tile_seam_without_an_event() -> void:
	var a := _on(Vector2(1040, -12), Vector2.UP)
	var ev := _until(a[0], a[1], Vector2.RIGHT, 500, func(): return _on_floor_past(a[1], a[0], 1260.0))
	assert_eq(ev, ["concave", "convex", "convex", "concave"], "four, none at the seam")
