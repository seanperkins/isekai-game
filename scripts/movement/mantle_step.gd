class_name MantleStep
extends RefCounted
## The biped's ledge mantle: an airborne body whose feet are just under a hard ledge's top, with a wall ahead, is pulled up and
## onto it in `mantle_time`, no button. Pure statics over a MoveState and a MoveInput, run by VerbRunner before the ground step
## (so it also beats a wall jump on the same press). The caller probes the ledge into `MoveInput.mantle` (hard solids only, and
## only where the standing box fits); the body moves by a displacement each tick (`surface_shift`, which the caller applies),
## up first and then over, so the pull never drags the body's side along the ledge's corner.

## The share of the pull spent going up before it goes over.
const UP_SHARE := 0.6

## Runs one tick. True while a mantle runs or ended this tick (this step owns the body); false otherwise.
static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	s.mantle_event = ""
	s.surface_shift = Vector2.ZERO
	if s.mantle_left <= 0.0:
		return _start(s, i, p, dt)
	return _pull(s, i, p, dt)

static func _start(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	if i.on_floor or i.mantle == Vector2.ZERO or s.air_verb_used:
		return false
	var rise := -i.mantle.y
	if rise <= 0.0 or rise > p.mantle_reach + maxf(0.0, s.velocity.y * dt):
		return false
	var way := signf(i.dir) if i.dir != 0.0 else float(s.facing)
	if i.wall_side == 0 or float(i.wall_side) != way:
		return false
	s.mantle_left = p.mantle_time
	s.mantle_total = i.mantle
	s.mantle_event = "start"
	s.velocity = Vector2.ZERO
	s.air_verb_used = true
	s.jumping = false
	s.clinging = false
	s.wall_grace = 0.0  # a press queued during the pull must not kick off the wall it left
	s.launched = ""
	if i.jump_pressed:
		s.queued_jump = true
	return true

static func _pull(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	if i.jump_pressed:
		s.queued_jump = true  # buffered: it fires when control returns
	var u0 := (p.mantle_time - s.mantle_left) / p.mantle_time
	s.mantle_left -= dt
	var done := s.mantle_left <= 1e-6
	var u1 := 1.0 if done else (p.mantle_time - s.mantle_left) / p.mantle_time
	s.surface_shift = _path(s.mantle_total, u1) - _path(s.mantle_total, u0)
	s.velocity = Vector2.ZERO
	if done:
		s.mantle_left = 0.0
		s.mantle_event = "stand"
	return true

## Where `u` (0 to 1) of the way through the pull the body is, relative to where it started: up, then over.
static func _path(total: Vector2, u: float) -> Vector2:
	return Vector2(total.x * clampf((u - UP_SHARE) / (1.0 - UP_SHARE), 0.0, 1.0), total.y * clampf(u / UP_SHARE, 0.0, 1.0))
