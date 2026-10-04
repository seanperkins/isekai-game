class_name SurfaceStep
extends RefCounted
## The crawl: a body on a hard surface walks it, turns up walls and round ends, and hops off along the surface normal. Pure
## statics over a MoveState and a MoveInput, like GroundAirStep; the world is read only through the two probes on MoveInput
## (a sweep and a ray), so it is tested on a fake world of rectangles and then on real collision. Surfaces are axis-aligned.
## `surface_n` is the outward normal of the surface under the feet and the tangent is that normal turned 90 degrees
## clockwise; the caller moves the body by `surface_shift` and swaps its box to `box_size(surface_n)`. Validated in the crawl
## spike (docs/research/spider-crawl-spike.md).

## Half the box along the surface and off it, and how far past the box the surface probe looks.
const HT := 14.0
const HN := 12.0
const STICK := 3.0
## What a ray probe reports.
const NONE := 0
const HARD := 1
const ONEWAY := 2
## The stick must be this far along a surface to move, and a latch holds while the stick is within acos(LATCH_DOT) of it.
const DEAD := 0.2
const LATCH_DOT := 0.7
## Seconds after a hop before it may grip a surface again.
const REATTACH_LOCK := 0.1

## Runs one tick. True while this step owns the body (it is on a surface, or has just left one with its own velocity); false
## in the air or with no probes, when the caller runs the ground and air step.
static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, jump_boost := 1.0) -> bool:
	s.surface_shift = Vector2.ZERO
	s.surface_event = ""
	if not i.sweep.is_valid() or not i.ray.is_valid():
		return false
	s.surface_since += dt
	s.surface_lock = maxf(0.0, s.surface_lock - dt)
	if s.surface_n == Vector2.ZERO:
		if not _attach(s, i):
			return false
		GroundAirStep.timers(s, i, p, dt)  # a press on the tick it grips is buffered, and fires on the next
		return true
	s.launched = ""
	GroundAirStep.timers(s, i, p, dt)
	if s.buffer > 0.0:
		_hop(s, p, jump_boost)
		return true
	var stick := i.stick()
	var t := tangent(s.surface_n)
	var sense := _intent(s, stick, t, p)
	if sense == 0.0:
		return true
	var dir := t * sense
	var motion := dir * p.top_speed * dt
	if s.surface_lock <= 0.0:
		var hit: Dictionary = i.sweep.call(motion)
		if not hit.is_empty():
			var wall := axis(hit["normal"])
			if wall.dot(s.surface_n) == 0.0 and wall.dot(dir) < -0.5:
				s.surface_shift = (hit["travel"] as Vector2) + (s.surface_n + dir) * (HT - HN)
				_corner(s, p, "concave", dir, wall, stick)
				return true
	var support := _support(i, s.surface_n, motion)
	if support == NONE:
		if s.surface_lock <= 0.0:
			_wrap(s, i, p, motion, dir, stick)
		return true  # inside the lockout it waits at the edge
	s.surface_oneway = support == ONEWAY
	s.surface_shift = motion
	return true

## A press while on a surface: off along the normal at the base jump, with steering locked off a wall or ceiling and no
## re-attaching for a moment (the body is still touching what it left).
static func _hop(s: MoveState, p: MovementProfile, jump_boost: float) -> void:
	var n := s.surface_n
	s.launch_speed = p.jump_velocity * jump_boost
	s.velocity = n * s.launch_speed
	s.launched = "hop"
	s.jumping = n == Vector2.UP
	s.buffer = 0.0
	s.coyote = 0.0  # the floor refilled it this tick; the hop is the jump, there is no second one in the air
	s.surface_n = Vector2.ZERO
	s.surface_lock = REATTACH_LOCK
	s.surface_event = "hop"
	if n != Vector2.UP:
		s.lock = p.wall_lock

## In the air: grip a floor the centre is over, or a hard wall or ceiling the stick presses toward. True on the tick it grips.
static func _attach(s: MoveState, i: MoveInput) -> bool:
	if s.surface_lock > 0.0:
		return false
	var stick := i.stick()
	var n := Vector2.ZERO
	var kind := NONE
	if i.on_floor:
		kind = i.ray.call(Vector2.ZERO, Vector2(0.0, HN + STICK), false)
		if kind != NONE:
			n = Vector2.UP
	if n == Vector2.ZERO and i.wall_side != 0 and stick.x * float(i.wall_side) > 0.5:
		# no further than the support probe holds (HN + STICK), or the first move up the wall finds no surface and drops
		kind = i.ray.call(Vector2.ZERO, Vector2(float(i.wall_side) * (HN + STICK), 0.0), true)
		if kind == HARD:
			n = Vector2(-float(i.wall_side), 0.0)
	if n == Vector2.ZERO and i.on_ceiling and stick.y < -0.5:
		kind = i.ray.call(Vector2.ZERO, Vector2(0.0, -(HN + STICK)), true)
		if kind == HARD:
			n = Vector2.DOWN
	if n == Vector2.ZERO:
		return false
	s.surface_n = n
	s.surface_oneway = kind == ONEWAY
	s.surface_latch = Vector2.ZERO
	s.velocity = Vector2.ZERO
	s.surface_event = "attach"
	return true

## The box for a surface with normal `n`: the body config's box on a floor or ceiling, turned on a wall.
static func box_size(n: Vector2) -> Vector2:
	var box := BodyConfig.size()
	return box if absf(n.y) > 0.5 else Vector2(box.y, box.x)

## The tangent of a surface: its normal turned a quarter clockwise, an exact axis.
static func tangent(n: Vector2) -> Vector2:
	return axis(n.rotated(PI / 2.0))

## The sign (1 or -1, 0 for none) of the way along the surface the stick asks for. A latch (the direction held at the last
## corner) keeps the rotational sense through a corner while the stick stays near it; releasing keeps it, a clearly
## different direction drops it. Otherwise the stick is screen-relative: its component along the tangent.
static func _intent(s: MoveState, stick: Vector2, t: Vector2, p: MovementProfile) -> float:
	var held := stick.length() > 0.5
	if s.surface_latch != Vector2.ZERO:
		if not held:
			return 0.0
		if stick.normalized().dot(s.surface_latch) > LATCH_DOT:
			return s.surface_sigma
		s.surface_latch = Vector2.ZERO
	var along := stick.dot(t)
	if absf(along) >= DEAD:
		s.surface_sigma = signf(along)
		return s.surface_sigma
	if stick.length() > 0.5 and s.surface_since < p.crawl_back_window and stick.normalized().dot(s.surface_prev) < -0.5:
		# nothing along this surface, and the stick is pressed back the way it came: back round the corner
		s.surface_sigma = -s.surface_sigma
		s.surface_latch = axis(stick)
		s.surface_prev = -s.surface_prev
		return s.surface_sigma
	return 0.0

## What is under a centre `offset` from the body's own: the ray goes along the inward normal, and a floor counts a one-way
## ledge while a wall or ceiling never does.
static func _support(i: MoveInput, n: Vector2, offset: Vector2) -> int:
	return i.ray.call(offset, offset - n * (HN + STICK), n != Vector2.UP)

## The surface ended under the centre: turn round its end. The box turns rigidly about the corner and stands on the end face
## with its centre one half-height out from it and 2 px below the corner, about 19 px from where it was (28 px if it were put
## flush below the corner). An end face with nothing under it detaches.
static func _wrap(s: MoveState, i: MoveInput, p: MovementProfile, motion: Vector2, dir: Vector2, stick: Vector2) -> void:
	var lo := 0.0
	var hi := 1.0
	for _k in 8:
		var mid := (lo + hi) / 2.0
		if _support(i, s.surface_n, motion * mid) == NONE:
			hi = mid
		else:
			lo = mid
	if s.surface_oneway:
		# a one-way ledge is a floor on its top only: no end face to turn onto, so the spider drops off its end
		s.surface_shift = motion * lo
		s.surface_event = "ledge_fall"
		s.surface_n = Vector2.ZERO
		s.surface_lock = REATTACH_LOCK  # it is still over the ledge by a hair: let it move off before it can grip again
		s.velocity = dir * p.top_speed * 0.5
		return
	var edge := dir.dot(motion * hi)
	var shift := s.surface_n * (-HN - 2.0) + dir * (edge + HN)
	s.surface_shift = shift
	if _support(i, dir, shift) == NONE:
		s.surface_event = "convex_nothing"
		s.surface_n = Vector2.ZERO
		s.surface_lock = REATTACH_LOCK
		return
	_corner(s, p, "convex", dir, dir, stick)

## Records a corner: the new surface, the lockout, and the latch (what was held, if anything).
static func _corner(s: MoveState, p: MovementProfile, event: String, dir: Vector2, new_n: Vector2, stick: Vector2) -> void:
	s.surface_event = event
	s.surface_prev = dir
	s.surface_n = new_n
	s.surface_lock = p.corner_lock
	s.surface_since = 0.0
	s.surface_latch = axis(stick) if stick.length() > 0.5 else Vector2.ZERO  # the axis it is mostly held along, so noise around it holds

## Snaps a vector to the nearest of the four axis directions (a tie goes to vertical).
static func axis(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))
