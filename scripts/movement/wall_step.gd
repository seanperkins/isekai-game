class_name WallStep
extends RefCounted
## The wall verbs over a MoveState and a MoveInput (pure statics, like GroundAirStep): stick then slide, the wall jump and
## the wall bounce. The caller probes the wall into `MoveInput.wall_side`; the step ignores it on the floor. The cling and the
## wall jump need the profile's "wall" verb (earned: Wall Cling); the bounce needs only `wall_bounce_keep`.

## Called after gravity: tracks the touch and the grace, then sticks and slides a body that presses into a wall while it
## falls. It only ever lowers a falling speed, so a wall adds no height.
static func contact(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> void:
	var touching := i.wall_side != 0 and not i.on_floor
	var can_cling := p.verbs.has("wall")
	s.wall_touch = touching
	if touching:
		s.wall_side = i.wall_side
		s.wall_grace = p.wall_grace if can_cling else 0.0
	else:
		s.wall_grace = maxf(0.0, s.wall_grace - dt)
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
