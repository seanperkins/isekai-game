class_name GroundAirStep
extends RefCounted
## The ground and air movement model: pure statics over a MoveState and a MoveInput (the style of PlayerWater), so
## player.gd and the sandbox share it and tests drive it a tick at a time. The caller moves the body with the velocity
## this leaves. Tick order: timers, horizontal control, gravity, jump, release.

## `speed_scale` is the speed stat as a fraction (spd / 100); `jump_boost` scales a launch (sqrt(jump_height / 100)).
static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, speed_scale := 1.0, jump_boost := 1.0) -> void:
	s.launched = ""
	_timers(s, i, p, dt)
	_horizontal(s, i, p, dt, speed_scale)
	_gravity(s, i, p, dt)
	_jump(s, i, p, jump_boost)
	s.air_time = 0.0 if i.on_floor else s.air_time + dt

## Every timer is decremented and clamped to zero first and tested `> 0.0` after, so floating-point residue is never
## treated as time left. The floor refills coyote time; a press fills the buffer.
static func _timers(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> void:
	s.coyote = p.coyote if i.on_floor else maxf(0.0, s.coyote - dt)
	s.buffer = p.buffer if i.jump_pressed else maxf(0.0, s.buffer - dt)

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
## 0 < vy < apex_band). A body on the floor has positive vy zeroed.
static func _gravity(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> void:
	if i.on_floor:
		s.velocity.y = minf(s.velocity.y, 0.0)
		return
	var g := p.gravity
	if i.jump_held and absf(s.velocity.y) < p.apex_band:
		g *= p.apex_gravity_mult
	if s.velocity.y > 0.0:
		g *= p.fall_mult
	s.velocity.y += g * dt

## A live buffer launches from the floor or inside the coyote window; one launch per press.
static func _jump(s: MoveState, i: MoveInput, p: MovementProfile, jump_boost: float) -> void:
	if s.buffer <= 0.0 or not (i.on_floor or s.coyote > 0.0):
		return
	s.launch_speed = p.jump_velocity * jump_boost
	s.velocity.y = -s.launch_speed
	s.jumping = true
	s.launched = "ground" if i.on_floor else "coyote"
	s.buffer = 0.0
	s.coyote = 0.0
