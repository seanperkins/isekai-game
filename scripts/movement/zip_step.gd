class_name ZipStep
extends RefCounted
## The spider's web zip: a thread fired along the aim at the first solid within range, then a pull to it. Pure statics over a
## MoveState and a MoveInput, like SurfaceStep; the world is read through the sweep the crawl already uses and the `cast` probe.
## The body moves by a displacement each tick (`surface_shift`, which the caller applies); a sweep stops it at the first
## contact, where it grips the surface it met (a wall, a ceiling or a floor). A jump cancels the pull and keeps part of its
## speed. There is no windup: the thread fires on the press (a delay would cost the responsiveness the species is built on).

## An anchor this close or closer (px from the body's centre) is not a zip: the body is already touching it.
const MIN_ANCHOR := 14.0

## Runs one tick. True while a zip runs or ended this tick (this step owns the body); false otherwise, and with no probes.
static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	s.zip_event = ""
	s.surface_event = ""  # the crawl's last corner is over; this step may own the tick
	s.surface_shift = Vector2.ZERO
	if not i.sweep.is_valid() or not i.cast.is_valid():
		return false
	s.zip_cooldown = maxf(0.0, s.zip_cooldown - dt)
	if s.zip_dir == Vector2.ZERO:
		return _start(s, i, p, dt)
	return _pull(s, i, p, dt)

## The unit direction of a zip: the resolved aim (the caller applies the cast aim order: pointer, left stick 8-way), else the
## facing.
static func direction(aim: Vector2, facing: int) -> Vector2:
	if aim.length() < 0.001:
		return Vector2(float(facing), 0.0)
	return aim.normalized()

static func _start(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	if not i.signature_pressed or s.zip_cooldown > 0.0:
		return false
	var airborne := s.surface_n == Vector2.ZERO
	if airborne and s.air_verb_used:
		return false  # one air verb per airtime
	var dir := direction(i.aim, s.facing)
	var hit: Dictionary = i.cast.call(Vector2.ZERO, dir * p.zip_range, dir.y > 0.0)
	if hit.is_empty() or (hit["point"] as Vector2).length() <= MIN_ANCHOR:
		s.zip_event = "fizzle"  # nothing to fire at: it costs nothing
		return false
	s.zip_dir = dir
	s.zip_target = hit["point"]
	s.zip_left = (hit["point"] as Vector2).length()
	s.air_verb_used = s.air_verb_used or airborne
	s.surface_n = Vector2.ZERO
	s.surface_latch = Vector2.ZERO
	s.surface_shift = Vector2.ZERO
	s.velocity = Vector2.ZERO
	s.launched = ""
	s.zip_event = "start"
	GroundAirStep.timers(s, i, p, dt)  # a jump pressed on this tick is buffered and cancels on the next
	return true

static func _pull(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool:
	GroundAirStep.timers(s, i, p, dt)
	if s.buffer > 0.0:
		s.velocity = s.zip_dir * p.zip_speed * p.zip_keep
		s.launched = "zip_cancel"
		s.jumping = false
		s.buffer = 0.0
		s.coyote = 0.0
		s.surface_shift = Vector2.ZERO
		_end(s, p, "cancel")
		return true
	var move := minf(p.zip_speed * dt, s.zip_left)
	var motion := s.zip_dir * move
	var hit: Dictionary = i.sweep.call(motion)
	if not hit.is_empty():
		var normal := SurfaceStep.axis(hit["normal"])
		# the standing box is 28 wide and the wall box 24: close the 2 px to a wall; a floor or ceiling needs no change
		s.surface_shift = (hit["travel"] as Vector2) - (normal * (SurfaceStep.HT - SurfaceStep.HN) if absf(normal.x) > 0.5 else Vector2.ZERO)
		s.surface_n = normal
		s.surface_since = 99.0
		s.surface_lock = 0.0
		s.surface_latch = Vector2.ZERO
		SurfaceStep.grip_wall(s, normal, i.stick())  # still holding toward the wall: keep climbing
		s.air_verb_used = false
		_end(s, p, "grip")
		return true
	s.surface_shift = motion
	s.zip_left -= move
	if s.zip_left <= 0.001:
		_end(s, p, "arrive")
	return true

static func _end(s: MoveState, p: MovementProfile, event: String) -> void:
	s.zip_dir = Vector2.ZERO
	s.zip_left = 0.0
	s.zip_cooldown = p.zip_cooldown
	s.zip_event = event
	if event != "cancel":
		s.velocity = Vector2.ZERO
