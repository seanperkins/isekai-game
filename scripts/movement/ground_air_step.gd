class_name GroundAirStep
extends RefCounted
## The ground and air movement model: pure statics over a MoveState and a MoveInput (the style of PlayerWater), so
## player.gd and the sandbox share it and tests drive it a tick at a time. The caller moves the body with the velocity
## this leaves. Tick order: timers, horizontal control, gravity, jump, release.

## `speed_scale` is the speed stat as a fraction (spd / 100); `jump_boost` scales a launch (sqrt(jump_height / 100)).
@warning_ignore("unused_parameter")
static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, speed_scale := 1.0, jump_boost := 1.0) -> void:
	s.launched = ""
	_horizontal(s, i, p, dt, speed_scale)

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
