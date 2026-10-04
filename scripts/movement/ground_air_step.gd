class_name GroundAirStep
extends RefCounted
## The ground and air movement model: pure statics over a MoveState and a MoveInput (the style of PlayerWater), so
## player.gd and the sandbox share it and tests drive it a tick at a time. The caller moves the body with the velocity
## this leaves. Tick order: timers, horizontal control, gravity, wall contact, jump, wall jump, release.

## A jump that fires on the floor after at least this many seconds of air is a landing's rebound, not a step down's.
const REBOUND_MIN_AIR := 0.12

## `speed_scale` is the speed stat as a fraction (spd / 100); `jump_boost` scales a launch (sqrt(jump_height / 100)).
static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, speed_scale := 1.0, jump_boost := 1.0) -> void:
	s.launched = ""
	s.wall_bounced = false
	timers(s, i, p, dt)
	if s.verb == "" and s.lock <= 1e-6:  # a burst or a wall kick owns the horizontal velocity
		_horizontal(s, i, p, dt, speed_scale)
	_gravity(s, i, p, dt)
	WallStep.contact(s, i, p, dt)
	_jump(s, i, p, jump_boost)
	WallStep.jump(s, i, p, jump_boost)
	_release(s, i, p)
	s.air_time = 0.0 if i.on_floor else s.air_time + dt
	s.last_vy = s.velocity.y
	s.last_vx = s.velocity.x

## Every timer is decremented and clamped to zero first and tested `> 0.0` after, so floating-point residue is never
## treated as time left. The floor refills coyote time; a press fills the buffer.
static func timers(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> void:
	s.coyote = p.coyote if i.on_floor else maxf(0.0, s.coyote - dt)
	s.buffer = p.buffer if i.jump_pressed else maxf(0.0, s.buffer - dt)
	s.lock = maxf(0.0, s.lock - dt)
	var grace := s.rebound_left > 0.0
	s.rebound_left = maxf(0.0, s.rebound_left - dt)
	if grace and (s.rebound_left <= 1e-6 or not i.on_floor):
		s.rebound_left = 0.0
		s.chain = 0  # the grace ran out, or the body left the floor, with no timed rebound

## Toward `dir * top`, braking or bleeding to rest when there is no input or it opposes the velocity (accelerating the
## other way then starts from rest on the next tick). A zero speed stat roots the body.
static func _horizontal(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, speed_scale: float) -> void:
	var top := p.top_speed * speed_scale
	if top <= 0.0:
		s.velocity.x = 0.0
		return
	var target := i.dir * top
	var rate := top / p.ground_accel_time
	if i.on_floor:
		if i.dir == 0.0:
			rate = top / p.ground_stop_time
		elif s.velocity.x * i.dir < 0.0:
			rate = top / p.ground_turn_time
			target = 0.0
	elif i.dir == 0.0:
		if p.air_keeps_momentum:
			return
		rate = top / p.air_stop_time
	else:
		rate *= p.air_accel_mult
	s.velocity.x = move_toward(s.velocity.x, target, rate * dt)

## Airborne only. Starts from `gravity`; the apex float and the heavier fall both apply when both match (held with
## 0 < vy < apex_band), and a SOFT release multiplies it while rising with the button up. A body on the floor has
## positive vy zeroed.
static func _gravity(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> void:
	if i.on_floor:
		s.velocity.y = minf(s.velocity.y, 0.0)
		return
	var g := p.gravity
	if i.jump_held and absf(s.velocity.y) < p.apex_band:
		g *= p.apex_gravity_mult
	if s.velocity.y > 0.0:
		g *= p.fall_mult
	elif s.jumping and not i.jump_held and p.release_style == MovementProfile.ReleaseStyle.SOFT:
		g *= p.release_factor
	s.velocity.y += g * dt

## A live buffer launches from the floor or inside the coyote window; one launch per press. A press on a landing (the floor
## after at least REBOUND_MIN_AIR of air) or inside the profile's rebound grace after one is a timed rebound, which chains;
## with no press, a hard enough landing with jump held bounces instead. The chain ends when a landing, or its grace, passes
## with no timed rebound.
static func _jump(s: MoveState, i: MoveInput, p: MovementProfile, jump_boost: float) -> void:
	var fresh := i.on_floor and s.air_time >= REBOUND_MIN_AIR
	if fresh and p.rebound_rise > 0.0:
		s.rebound_left = p.rebound_grace
	var landing := fresh or (i.on_floor and s.rebound_left > 0.0)
	if s.buffer > 0.0 and (i.on_floor or s.coyote > 0.0):
		s.launch_speed = p.jump_velocity * jump_boost
		s.launched = "ground" if i.on_floor else "coyote"
		if landing and p.rebound_rise > 0.0:
			s.chain += 1
			var cap := p.rebound_cap if p.rebound_cap > 0.0 else p.rebound_rise
			s.launch_speed *= sqrt(1.0 + minf(p.rebound_rise * s.chain, cap))
			s.launched = "rebound"
		s.velocity.y = -s.launch_speed
		s.jumping = true
		s.buffer = 0.0
		s.coyote = 0.0
		s.rebound_left = 0.0
	elif fresh and p.bounce_keep > 0.0 and i.jump_held and s.last_vy >= p.bounce_min_impact:
		# The slime falls with fall_mult times gravity, so its impact speed is sqrt(fall_mult) above the speed it launched
		# at; dividing it out makes each bounce 0.85 times the last launch speed, never more than the base jump.
		s.launch_speed = minf(s.last_vy * p.bounce_keep / sqrt(p.fall_mult), p.jump_velocity * jump_boost)
		s.launched = "bounce"
		s.velocity.y = -s.launch_speed
		s.jumping = true
		s.buffer = 0.0
		s.coyote = 0.0  # the floor tick just refilled it; a bounce must not leave a free mid-air jump behind
		s.rebound_left = 0.0
	if i.on_floor and s.air_time > 0.0 and s.launched != "rebound" and s.rebound_left <= 0.0:
		s.chain = 0  # any landing without a timed rebound ends the chain, including a flight too short to qualify

## Jump released while rising from a jump (never on the launch tick). CUT caps the rise speed once and never raises it;
## SOFT already did its work in the gravity step. The rise ends at the apex or on the floor.
static func _release(s: MoveState, i: MoveInput, p: MovementProfile) -> void:
	if not s.jumping or s.launched != "":
		return
	if i.on_floor or s.velocity.y >= 0.0:
		s.jumping = false
	elif not i.jump_held and p.release_style == MovementProfile.ReleaseStyle.CUT:
		s.velocity.y = maxf(s.velocity.y, -s.launch_speed * p.release_factor)
		s.jumping = false
