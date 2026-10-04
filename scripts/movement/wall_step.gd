class_name WallStep
extends RefCounted
## The wall verbs over a MoveState and a MoveInput (pure statics, like GroundAirStep): stick then slide, the wall jump and
## the wall bounce. The caller probes the wall into `MoveInput.wall_side`; the step ignores it on the floor. The cling and the
## wall jump need the profile's "wall" verb (earned: Wall Cling); the bounce needs only `wall_bounce_keep`.

## Called after gravity: tracks the touch and the grace, bounces a body that hits a wall with jump held, and otherwise sticks
## and slides one that presses into it while it falls. Nothing here raises a speed upward, so a wall adds no height.
static func contact(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> void:
	var touching := i.wall_side != 0 and not i.on_floor
	var can_cling := p.verbs.has("wall")
	var first := touching and not s.wall_touch
	s.wall_touch = touching
	if touching:
		s.wall_side = i.wall_side
		s.wall_grace = p.wall_grace if can_cling else 0.0
	else:
		s.wall_grace = maxf(0.0, s.wall_grace - dt)
	if first and p.wall_bounce_keep > 0.0 and i.jump_held and s.last_vx * i.wall_side >= p.wall_bounce_min:
		# Holding jump into a wall reflects the speed it came in at (last tick's, before the physics zeroed it). Only x
		# changes, so a bounce never adds height; a wall jump later this tick still overrides it.
		s.velocity.x = -i.wall_side * absf(s.last_vx) * p.wall_bounce_keep
		s.lock = p.wall_lock
		s.wall_bounced = true
		s.clinging = false
		return
	var cling := can_cling and touching and i.dir * i.wall_side > 0.0 and (s.velocity.y > 0.0 or s.clinging)
	if cling and not s.clinging:
		s.wall_stick = p.wall_stick_time
	s.clinging = cling
	if not cling:
		return
	var cap := p.wall_slide_speed
	if s.wall_stick > 1e-6:
		cap = p.wall_stick_speed
		s.wall_stick -= dt
	s.velocity.y = minf(s.velocity.y, cap)

## Called after the ground jump: a live buffered press inside the wall grace (touching, or just off a wall) kicks away from
## the last wall at `wall_jump_push` with the full jump speed upward, and locks steering for `wall_lock`. The floor and coyote
## jumps have already had their chance this tick.
static func jump(s: MoveState, i: MoveInput, p: MovementProfile, jump_boost: float) -> void:
	if s.launched != "" or i.on_floor or not p.verbs.has("wall") or s.buffer <= 0.0 or s.wall_grace <= 0.0:
		return
	s.launch_speed = p.jump_velocity * jump_boost
	s.launched = "wall"
	s.velocity = Vector2(-s.wall_side * p.wall_jump_push, -s.launch_speed)
	s.jumping = true
	s.buffer = 0.0
	s.coyote = 0.0
	s.wall_grace = 0.0
	s.clinging = false
	s.wall_bounced = false
	s.lock = p.wall_lock
