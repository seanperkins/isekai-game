extends GutTest

const DT := 1.0 / 60.0

var spider: MovementProfile

func before_each() -> void:
	spider = MovementProfile.of("spider")

## A world with the spike's terrain, the spider at `pos` on the surface `n` (ZERO for in the air), and the state to match.
func _at(pos: Vector2, n := Vector2.UP) -> Array:
	var w := FakeSurfaceWorld.build_spike_terrain()
	w.pos = pos
	w.n = n if n != Vector2.ZERO else Vector2.UP
	var s := MoveState.new()
	s.surface_n = n
	return [w, s]

## One tick: `aim` resolved by the caller, `press` the signature button, `jump` a jump press.
func _tick(w: FakeSurfaceWorld, s: MoveState, aim := Vector2.ZERO, press := false, jump := false) -> bool:
	var i := w.input()
	i.aim = aim
	i.signature_pressed = press
	i.jump_pressed = jump
	i.jump_held = jump
	var owns := ZipStep.step(s, i, spider, DT)
	w.apply(s)
	return owns

## Fires at tick 0, then ticks until the zip ends (an event "grip", "arrive" or "cancel"); returns every event.
func _zip(w: FakeSurfaceWorld, s: MoveState, aim: Vector2, limit := 120) -> Array[String]:
	var events: Array[String] = []
	_tick(w, s, aim, true)
	events.append(s.zip_event)
	for _k in limit:
		_tick(w, s, aim)
		if s.zip_event != "":
			events.append(s.zip_event)
			if s.zip_dir == Vector2.ZERO:
				break
	return events

func test_the_direction_is_the_aim_or_the_facing() -> void:
	assert_almost_eq(ZipStep.direction(Vector2(0.7, -0.7), 1).x, 0.7071, 0.001)
	assert_almost_eq(ZipStep.direction(Vector2(0.7, -0.7), 1).y, -0.7071, 0.001)
	assert_eq(ZipStep.direction(Vector2(0, 2), 1), Vector2(0, 1), "normalised")
	assert_eq(ZipStep.direction(Vector2.ZERO, -1), Vector2.LEFT)
	assert_eq(ZipStep.direction(Vector2.ZERO, 1), Vector2.RIGHT)

func test_the_thread_pulls_at_400_to_the_first_solid_and_grips_it() -> void:
	var a := _at(Vector2(120, -12))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	assert_true(_tick(w, s, Vector2.RIGHT, true))
	assert_eq(s.zip_event, "start")
	assert_almost_eq((s.zip_target as Vector2).x, 80.0, 0.01, "the block's left face is 80 px away")
	assert_eq(s.surface_n, Vector2.ZERO, "off its surface while the thread pulls")
	assert_eq(w.pos.x, 120.0, "no movement on the firing tick")
	_tick(w, s, Vector2.RIGHT)
	assert_almost_eq(w.pos.x - 120.0, 400.0 / 60.0, 0.001, "400 px/s")
	var events: Array[String] = []
	for _k in 30:
		_tick(w, s, Vector2.RIGHT)
		if s.zip_event != "":
			events.append(s.zip_event)
	assert_eq(events, ["grip"])
	assert_eq(s.surface_n, Vector2.LEFT)
	assert_almost_eq(w.pos.x, 188.0, 1.5, "flush to the face as a wall crawler")
	assert_eq(s.zip_dir, Vector2.ZERO)

func test_nothing_in_range_costs_nothing() -> void:
	var a := _at(Vector2(600, -300), Vector2.ZERO)
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	assert_false(_tick(w, s, Vector2.LEFT, true))
	assert_eq(s.zip_event, "fizzle")
	assert_eq([s.zip_cooldown, s.air_verb_used, s.zip_dir], [0.0, false, Vector2.ZERO])

func test_the_range_is_160_px() -> void:
	var near := _at(Vector2(50, -12))  # the block's face is 150 px away
	_tick(near[0], near[1], Vector2.RIGHT, true)
	assert_eq((near[1] as MoveState).zip_event, "start")
	var far := _at(Vector2(30, -12))  # 170 px
	_tick(far[0], far[1], Vector2.RIGHT, true)
	assert_eq((far[1] as MoveState).zip_event, "fizzle")

func test_a_zip_up_grips_the_ceiling_and_a_diagonal_one_stops_at_the_first_contact() -> void:
	var up := _at(Vector2(600, -12))
	var ev := _zip(up[0], up[1], Vector2.UP)
	assert_eq(ev, ["start", "grip"])
	assert_eq((up[1] as MoveState).surface_n, Vector2.DOWN)
	assert_almost_eq((up[0] as FakeSurfaceWorld).pos.y, -148.0, 1.5, "hanging from the slab's underside")
	var d := _at(Vector2(400, -12))
	_zip(d[0], d[1], Vector2(1, -1).normalized())
	assert_eq((d[1] as MoveState).surface_n, Vector2.LEFT, "it met the pillar's left face")
	var w: FakeSurfaceWorld = d[0]
	assert_false(Rect2(w.pos - Vector2(12, 14), Vector2(24, 28)).intersects(FakeSurfaceWorld.PILLAR), "and never ended inside it")

func test_a_jump_cancels_and_keeps_60_percent() -> void:
	var a := _at(Vector2(120, -12))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	_tick(w, s, Vector2.RIGHT, true)
	for _k in 4:
		_tick(w, s, Vector2.RIGHT)
	_tick(w, s, Vector2.RIGHT, false, true)
	assert_eq(s.zip_event, "cancel")
	assert_eq(s.zip_dir, Vector2.ZERO)
	assert_almost_eq(s.velocity.x, 240.0, 0.01)
	assert_eq(s.launched, "zip_cancel")
	assert_eq(s.zip_cooldown, spider.zip_cooldown)
	var early := _at(Vector2(120, -12))
	_tick(early[0], early[1], Vector2.RIGHT, true, true)  # a jump on the firing tick: buffered, cancels next tick, no travel
	assert_eq((early[0] as FakeSurfaceWorld).pos.x, 120.0)
	_tick(early[0], early[1], Vector2.RIGHT)
	assert_eq((early[1] as MoveState).zip_event, "cancel")
	assert_eq((early[0] as FakeSurfaceWorld).pos.x, 120.0, "no displacement")

func test_the_cooldown_runs_from_the_end_and_a_zip_works_from_a_ceiling() -> void:
	var a := _at(Vector2(600, -12))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	_zip(w, s, Vector2.UP)
	assert_eq(s.zip_cooldown, spider.zip_cooldown)
	assert_false(_tick(w, s, Vector2.DOWN, true), "a second press at once is refused")
	assert_ne(s.zip_event, "start")
	for _k in 25:
		_tick(w, s)
	assert_eq(s.zip_cooldown, 0.0)
	var ev := _zip(w, s, Vector2.DOWN)
	assert_eq(ev, ["start", "grip"])
	assert_eq(s.surface_n, Vector2.UP)
	assert_almost_eq(w.pos.y, -12.0, 1.5, "back on the floor")

func test_a_zip_from_a_wall_into_open_air_fizzles() -> void:
	var a := _at(Vector2(188, -50), Vector2.LEFT)
	_tick(a[0], a[1], Vector2(-1, -1).normalized(), true)
	assert_eq((a[1] as MoveState).zip_event, "fizzle")
	assert_eq((a[1] as MoveState).surface_n, Vector2.LEFT, "still on the wall")

func test_too_close_is_not_a_zip() -> void:
	var a := _at(Vector2(190, -12))  # the block's face is 10 px away
	_tick(a[0], a[1], Vector2.RIGHT, true)
	assert_eq((a[1] as MoveState).zip_event, "fizzle")

func test_no_probes_and_no_press_do_nothing() -> void:
	var s := MoveState.new()
	assert_false(ZipStep.step(s, MoveInput.new(), spider, DT))
	var a := _at(Vector2(120, -12))
	assert_false(_tick(a[0], a[1], Vector2.RIGHT, false), "no press, no zip")
	assert_eq((a[1] as MoveState).zip_event, "")

func test_a_zip_starting_right_after_a_corner_does_not_carry_the_corner_event() -> void:
	var a := _at(Vector2(120, -12))
	var s: MoveState = a[1]
	s.surface_event = "convex"  # the crawl's last tick turned a corner
	_tick(a[0], s, Vector2.RIGHT, true)
	assert_eq(s.surface_event, "", "the zip owns the tick, and the corner is over")
	_tick(a[0], s, Vector2.RIGHT)
	assert_eq(s.surface_event, "")

func test_a_zip_onto_a_wall_keeps_climbing_while_the_stick_stays_toward_it() -> void:
	var a := _at(Vector2(120, -12))
	var w: FakeSurfaceWorld = a[0]
	var s: MoveState = a[1]
	var i := w.input()
	i.aim = Vector2.RIGHT
	i.dir = 1.0
	i.signature_pressed = true
	ZipStep.step(s, i, spider, DT)
	i.signature_pressed = false
	for _k in 40:
		ZipStep.step(s, i, spider, DT)
		w.apply(s)
		if s.zip_event == "grip":
			break
	assert_eq(s.surface_n, Vector2.LEFT)
	var y := w.pos.y
	for _k in 12:
		SurfaceStep.step(s, i, spider, DT)
		w.apply(s)
	assert_lt(w.pos.y, y - 15.0, "the stick is still toward the wall: it climbs")
