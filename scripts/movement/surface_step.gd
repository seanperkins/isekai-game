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

## Runs one tick. True while this step owns the body (it is on a surface, or has just left one with its own velocity); false
## in the air or with no probes, when the caller runs the ground and air step.
static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, _jump_boost := 1.0) -> bool:
	s.surface_shift = Vector2.ZERO
	s.surface_event = ""
	if not i.sweep.is_valid() or not i.ray.is_valid() or s.surface_n == Vector2.ZERO:
		return false
	s.surface_since += dt
	s.surface_lock = maxf(0.0, s.surface_lock - dt)
	var stick := i.stick()
	var t := tangent(s.surface_n)
	var sense := _intent(s, stick, t)
	if sense == 0.0:
		return true
	var dir := t * sense
	var motion := dir * p.top_speed * dt
	if s.surface_lock <= 0.0:
		var hit: Dictionary = i.sweep.call(motion)
		if not hit.is_empty():
			var wall := _axis(hit["normal"])
			if wall.dot(s.surface_n) == 0.0 and wall.dot(dir) < -0.5:
				s.surface_shift = (hit["travel"] as Vector2) + (s.surface_n + dir) * (HT - HN)
				_corner(s, p, "concave", dir, wall, stick)
				return true
	s.surface_shift = motion
	return true

## The box for a surface with normal `n`: the body config's box on a floor or ceiling, turned on a wall.
static func box_size(n: Vector2) -> Vector2:
	var box := BodyConfig.size()
	return box if absf(n.y) > 0.5 else Vector2(box.y, box.x)

## The tangent of a surface: its normal turned a quarter clockwise, an exact axis.
static func tangent(n: Vector2) -> Vector2:
	return _axis(n.rotated(PI / 2.0))

## The sign (1 or -1, 0 for none) of the way along the surface the stick asks for. A latch (the direction held at the last
## corner) keeps the rotational sense through a corner while the stick stays near it; releasing keeps it, a clearly
## different direction drops it. Otherwise the stick is screen-relative: its component along the tangent.
static func _intent(s: MoveState, stick: Vector2, t: Vector2) -> float:
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
	return 0.0

## Records a corner: the new surface, the lockout, and the latch (what was held, if anything).
static func _corner(s: MoveState, p: MovementProfile, event: String, dir: Vector2, new_n: Vector2, stick: Vector2) -> void:
	s.surface_event = event
	s.surface_prev = dir
	s.surface_n = new_n
	s.surface_lock = p.corner_lock
	s.surface_since = 0.0
	s.surface_latch = stick.normalized() if stick.length() > 0.5 else Vector2.ZERO

static func _axis(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))
