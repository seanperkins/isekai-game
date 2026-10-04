class_name DropStep
extends RefCounted
## The spider's silk drop: a press of down in the air, or hanging from a ceiling, spins a thread from the hard solid above (within
## range) and the spider slides down it. Down reels, up climbs (never above the anchor), the stick steers at half the air
## control, a jump lets go with the velocity it has, and touching the floor grips it. Pure statics over a MoveState and a
## MoveInput, like ZipStep: the body moves by a displacement each tick (`surface_shift`, which the caller applies) and the
## world is read through the sweep and `cast` probes. It is the airtime's one air verb (shared with the zip).

## Runs one tick. True while a drop runs or ended this tick (this step owns the body); false otherwise, and with no probes.
static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	s.drop_event = ""
	s.surface_shift = Vector2.ZERO
	if not i.sweep.is_valid() or not i.cast.is_valid():
		return false
	if s.drop_up > 0.0:
		return _run(s, i, p, dt)
	return _start(s, i, p, dt)

static func _start(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	if not s.down_pressed or s.zip_dir != Vector2.ZERO:
		return false
	var airborne := s.surface_n == Vector2.ZERO
	if not (airborne and not s.air_verb_used) and s.surface_n != Vector2.DOWN:
		return false  # from the air (once per airtime) or a ceiling; down on a wall is crawling down it
	var hit: Dictionary = i.cast.call(Vector2.ZERO, Vector2(0.0, -p.drop_range), false)
	var up := -(hit["point"] as Vector2).y if not hit.is_empty() else 0.0
	if hit.is_empty() or up < SurfaceStep.HN - 0.5 or hit.get("slick", false):
		s.drop_event = "fizzle"  # nothing to hang from (a slick ceiling refuses a thread): it costs nothing
		return false
	var half := p.top_speed * p.drop_air
	s.drop_up = maxf(up, SurfaceStep.HN)
	s.drop_target = hit["point"]
	s.drop_vx = clampf(s.velocity.x, -half, half)
	s.air_verb_used = true
	s.surface_n = Vector2.ZERO
	s.surface_latch = Vector2.ZERO
	s.velocity = Vector2.ZERO
	s.launched = ""
	GroundAirStep.timers(s, i, p, dt)
	var owns := _reel(s, i, p, dt)
	s.drop_event = "start" if s.drop_event == "" else s.drop_event
	return owns

static func _run(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	GroundAirStep.timers(s, i, p, dt)
	if s.buffer > 0.0:
		s.velocity = Vector2(s.drop_vx, _reel_speed(i, p))  # let go with what it has: no extra impulse
		s.launched = "drop_release"
		s.jumping = false
		s.buffer = 0.0
		s.coyote = 0.0
		s.drop_up = 0.0
		s.drop_vx = 0.0
		s.drop_event = "release"
		return true
	return _reel(s, i, p, dt)

## Down reels the thread out, up climbs it (never above the anchor), the stick steers; a blocked axis stops, and a reel
## onto the floor is the landing.
static func _reel(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	var dy := _reel_speed(i, p) * dt
	if dy < 0.0:
		dy = maxf(dy, SurfaceStep.HN - s.drop_up)
	var target := i.dir * p.top_speed * p.drop_air
	s.drop_vx = move_toward(s.drop_vx, target, p.top_speed / maxf(p.ground_accel_time, 0.001) * p.air_accel_mult * dt)
	var dx := s.drop_vx * dt
	if dx != 0.0:
		var hx: Dictionary = i.sweep.call(Vector2(dx, 0.0))
		if not hx.is_empty():
			dx = (hx["travel"] as Vector2).x
			s.drop_vx = 0.0
	var landed := false
	if dy != 0.0:
		var hy: Dictionary = i.sweep.call(Vector2(0.0, dy))
		if not hy.is_empty():
			landed = dy > 0.0 and SurfaceStep.axis(hy["normal"]) == Vector2.UP
			dy = (hy["travel"] as Vector2).y
	s.surface_shift = Vector2(dx, dy)
	s.drop_up += dy
	if landed:
		s.surface_n = Vector2.UP
		s.surface_since = 99.0
		s.surface_lock = 0.0
		s.surface_latch = Vector2.ZERO
		s.air_verb_used = false
		s.drop_up = 0.0
		s.drop_vx = 0.0
		s.velocity = Vector2.ZERO
		s.drop_event = "land"
	return true

static func _reel_speed(i: MoveInput, p: MovementProfile) -> float:
	if i.down >= 0.5:
		return p.drop_reel
	if i.up >= 0.5:
		return -p.drop_climb
	return 0.0
