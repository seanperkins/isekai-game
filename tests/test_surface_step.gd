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

## An input from the world with the stick and contact flags set, for attach tests that call the step by hand.
func _make_input(w: FakeSurfaceWorld, stick := Vector2.ZERO) -> MoveInput:
	var i := w.input()
	i.dir = stick.x
	i.down = maxf(stick.y, 0.0)
	i.up = maxf(-stick.y, 0.0)
	return i

func test_a_one_way_ledge_end_drops_the_spider() -> void:
	var a := _on(Vector2(900, -62), Vector2.UP)
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	var ev := _until(w, s, Vector2.RIGHT, 200, func(): return s.surface_event == "ledge_fall")
	assert_eq(ev, ["ledge_fall"], "never a convex wrap on a one-way ledge")
	assert_eq(s.surface_n, Vector2.ZERO)
	assert_almost_eq(s.velocity.x, 70.0, 0.01)
	assert_false(_tick(w, s, Vector2.RIGHT), "in the air the ground step takes over")

func test_a_hard_ledge_end_wraps_where_a_one_way_one_falls() -> void:
	var a := _on(Vector2(1160, -72), Vector2.UP)
	var ev := _until(a[0], a[1], Vector2.RIGHT, 100, func(): return (a[1] as MoveState).surface_event == "convex")
	assert_eq(ev, ["convex"])
	assert_eq((a[1] as MoveState).surface_n, Vector2.RIGHT)

func test_a_hop_goes_along_the_normal_at_the_base_jump_speed() -> void:
	var f := _on(Vector2(40, -12), Vector2.UP)
	assert_true(_tick(f[0], f[1], Vector2.ZERO, true), "the hop tick belongs to this step")
	var s: MoveState = f[1]
	assert_eq(s.velocity, Vector2(0, -330))
	assert_eq(s.launched, "hop")
	assert_eq(s.surface_n, Vector2.ZERO)
	assert_eq(s.lock, 0.0, "off a floor it steers at once")
	var wall := _on(Vector2(188, -60), Vector2.LEFT)
	_tick(wall[0], wall[1], Vector2.ZERO, true)
	assert_eq((wall[1] as MoveState).velocity, Vector2(-330, 0))
	assert_eq((wall[1] as MoveState).lock, spider.wall_lock)
	var ceiling := _on(Vector2(600, -148), Vector2.DOWN)
	_tick(ceiling[0], ceiling[1], Vector2.ZERO, true)
	assert_eq((ceiling[1] as MoveState).velocity, Vector2(0, 330))
	var boosted := _on(Vector2(40, -12), Vector2.UP)
	_tick(boosted[0], boosted[1], Vector2.ZERO, true, 1.5)
	assert_eq((boosted[1] as MoveState).velocity, Vector2(0, -330 * 1.5))

func test_a_buffered_press_hops_one_tick_after_attaching() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(100, -12)
	var s := MoveState.new()
	s.buffer = 0.1
	var i := _make_input(w)
	i.on_floor = true
	assert_true(SurfaceStep.step(s, i, spider, DT))
	assert_eq(s.surface_event, "attach")
	w.apply(s)
	assert_true(SurfaceStep.step(s, i, spider, DT))
	assert_eq(s.launched, "hop")

func test_it_lands_on_a_floor_and_attaches_only_if_the_centre_is_over_it() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(100, -12)
	var s := MoveState.new()
	var i := _make_input(w)
	i.on_floor = true
	assert_true(SurfaceStep.step(s, i, spider, DT))
	assert_eq([s.surface_event, s.surface_n, s.velocity], ["attach", Vector2.UP, Vector2.ZERO])
	var edge := FakeSurfaceWorld.build_spike_terrain()
	edge.pos = Vector2(980, -62)  # 10 px past the one-way ledge's end: its rim would catch the box
	var air := MoveState.new()
	var j := _make_input(edge)
	j.on_floor = true
	assert_false(SurfaceStep.step(air, j, spider, DT))
	assert_eq(air.surface_n, Vector2.ZERO)

func test_it_attaches_to_a_wall_or_ceiling_only_when_pressing_toward_it() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(312, -60)  # beside the block's right face
	var i := _make_input(w, Vector2.LEFT)
	i.wall_side = -1
	var s := MoveState.new()
	assert_true(SurfaceStep.step(s, i, spider, DT))
	assert_eq(s.surface_n, Vector2.RIGHT)
	var idle := MoveState.new()
	var k := _make_input(w, Vector2.ZERO)
	k.wall_side = -1
	assert_false(SurfaceStep.step(idle, k, spider, DT), "no stick, no grip")
	var c := FakeSurfaceWorld.build_spike_terrain()
	c.pos = Vector2(600, -148)
	var cs := MoveState.new()
	var ci := _make_input(c, Vector2.UP)
	ci.on_ceiling = true
	assert_true(SurfaceStep.step(cs, ci, spider, DT))
	assert_eq(cs.surface_n, Vector2.DOWN)
	var o := FakeSurfaceWorld.build_spike_terrain()
	o.pos = Vector2(840, -47)  # beside the one-way ledge's left end
	var os := MoveState.new()
	var oi := _make_input(o, Vector2.RIGHT)
	oi.wall_side = 1
	assert_false(SurfaceStep.step(os, oi, spider, DT), "never to a one-way ledge's side")

func test_it_does_not_re_attach_the_instant_after_a_hop() -> void:
	var a := _on(Vector2(40, -12), Vector2.UP)
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	_tick(w, s, Vector2.ZERO, true)
	var i := _make_input(w)
	i.on_floor = true  # the body has not left the floor yet
	assert_false(SurfaceStep.step(s, i, spider, DT))
	assert_eq(s.surface_n, Vector2.ZERO)
	for _k in 8:
		SurfaceStep.step(s, i, spider, DT)
	assert_ne(s.surface_n, Vector2.ZERO, "after the lock it grips the floor again")

func test_no_probes_means_not_a_crawler() -> void:
	var s := MoveState.new()
	s.surface_n = Vector2.UP
	var i := MoveInput.new()
	i.on_floor = true
	assert_false(SurfaceStep.step(s, i, spider, DT))
	assert_eq([s.surface_shift, s.surface_event], [Vector2.ZERO, ""])

func test_a_press_on_the_attach_tick_is_kept() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(100, -12)
	var s := MoveState.new()
	var i := _make_input(w)
	i.on_floor = true
	i.jump_pressed = true
	i.jump_held = true
	assert_true(SurfaceStep.step(s, i, spider, DT))
	assert_eq(s.surface_event, "attach")
	w.apply(s)
	i.jump_pressed = false
	assert_true(SurfaceStep.step(s, i, spider, DT))
	assert_eq(s.launched, "hop", "the landing press fires one tick later")

func test_a_floor_hop_leaves_no_second_jump() -> void:
	var a := _on(Vector2(40, -12), Vector2.UP)
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	_tick(w, s, Vector2.ZERO, true)
	assert_eq(s.coyote, 0.0)
	var air := MoveInput.new()
	air.on_floor = false
	air.jump_pressed = true
	air.jump_held = true
	GroundAirStep.step(s, air, spider, DT)
	GroundAirStep.step(s, air, spider, DT)
	assert_eq(s.launched, "", "no coyote jump a few ticks after the hop")

func test_a_wall_grip_needs_the_wall_within_what_the_support_probe_holds() -> void:
	var far := FakeSurfaceWorld.build_spike_terrain()
	far.pos = Vector2(319, -60)  # 19 px from the block's right face: the support probe reaches 15
	var fi := _make_input(far, Vector2.LEFT)
	fi.wall_side = -1
	var fs := MoveState.new()
	assert_false(SurfaceStep.step(fs, fi, spider, DT), "too far to hold")
	var near := FakeSurfaceWorld.build_spike_terrain()
	near.pos = Vector2(313, -60)
	var ni := _make_input(near, Vector2.LEFT)
	ni.wall_side = -1
	var ns := MoveState.new()
	assert_true(SurfaceStep.step(ns, ni, spider, DT))
	near.apply(ns)
	var events := _run(near, ns, Vector2.UP, 12)
	assert_false(events.has("convex_nothing"), "it climbs, it does not drop: %s" % [events])
	assert_eq(ns.surface_n, Vector2.RIGHT)
	assert_lt(near.pos.y, -75.0)

func test_walking_off_a_sliver_of_a_ledge_drops_from_where_it_is() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.add_hard(Rect2(1300, -60, 100, 1))  # a hard ledge 1 px thick: no end face to turn onto
	w.pos = Vector2(1380, -72)
	var s := MoveState.new()
	s.surface_n = Vector2.UP
	var events := _until(w, s, Vector2.RIGHT, 100, func(): return s.surface_event == "convex_nothing")
	assert_eq(events, ["convex_nothing"])
	assert_eq(s.surface_n, Vector2.ZERO)
	assert_lt(s.surface_shift.length(), 2.5, "it drops from the edge, it is not moved 19 px round a corner that is not there")

func test_gripping_a_wall_from_the_air_keeps_climbing_while_the_stick_stays_on_it() -> void:
	for side in [-1, 1]:
		var w := FakeSurfaceWorld.build_spike_terrain()
		# beside the block's right face (a wall on its left) and its left face (a wall on its right)
		w.pos = Vector2(313, -60) if side == -1 else Vector2(187, -60)
		var s := MoveState.new()
		var stick := Vector2(float(side), 0.0)
		var i := _make_input(w, stick)
		i.wall_side = side
		assert_true(SurfaceStep.step(s, i, spider, DT))
		assert_eq(s.surface_event, "attach")
		w.apply(s)
		var y := w.pos.y
		_run(w, s, stick, 12)
		assert_lt(w.pos.y, y - 15.0, "holding toward the wall climbs it, as walking into it does (side %d)" % side)

func test_gripping_a_wall_from_the_air_closes_the_gap_to_it() -> void:
	for x in [314.0, 315.0]:  # 14 (touching, for the 28 wide standing box) and 15 px from the block's right face (x 300)
		var w := FakeSurfaceWorld.build_spike_terrain()
		w.pos = Vector2(x, -60)
		var s := MoveState.new()
		var i := _make_input(w, Vector2.LEFT)
		i.wall_side = -1
		SurfaceStep.step(s, i, spider, DT)
		w.apply(s)
		assert_almost_eq(w.pos.x, 312.0, 0.01, "flush: the wall box's half width, 12, from the face (from %s)" % x)

func test_a_hop_onto_a_wall_then_up_goes_over_its_top_corner() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(315, -60)  # a hop that gripped the block's right face 15 px out
	var s := MoveState.new()
	var i := _make_input(w, Vector2.LEFT)
	i.wall_side = -1
	SurfaceStep.step(s, i, spider, DT)
	w.apply(s)
	var events := _until(w, s, Vector2.UP, 200, func(): return s.surface_n == Vector2.UP)
	assert_eq(events, ["convex"], "over the corner onto the block's top, not a drop (convex_nothing)")
	assert_almost_eq(w.pos.y, -112.0, 3.0)

func test_gripping_a_wall_holding_down_and_toward_it_does_not_climb() -> void:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = Vector2(315, -60)  # a hop that gripped the block's right face
	var s := MoveState.new()
	var stick := Vector2(-1.0, 1.0).normalized()  # toward the wall (left) and down
	var i := _make_input(w, stick)
	i.wall_side = -1
	SurfaceStep.step(s, i, spider, DT)
	w.apply(s)
	var y := w.pos.y
	_run(w, s, stick, 12)
	assert_gt(w.pos.y, y + 10.0, "the stick says down, so it goes down: an explicit vertical intent beats the climb latch")
