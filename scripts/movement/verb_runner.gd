class_name VerbRunner
extends RefCounted
## The species' verbs on top of the ground and air step: facing, Ooze (the flat slime) and, in later tasks, the bursts
## (Tackle, the puddle slide). Pure statics like GroundAirStep. A burst only owns horizontal velocity, so the step keeps
## running underneath it (gravity, jump, coyote and the jump buffer never stop), as Player._dash does today.

## The raw down input at which the slime flattens and holds flat.
const SPREAD_DOWN := 0.6
## Walking speed while flat, as a fraction.
const SPREAD_SPEED := 0.5
## Standing up from flat needs this many px free above (the standing box's extra height).
const STAND_RISE := 14.0

static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, speed_scale := 1.0, jump_boost := 1.0) -> void:
	if i.dir != 0.0:
		s.facing = 1 if i.dir > 0.0 else -1
	_ooze(s, i, p)
	var input := i
	if s.spread and i.jump_pressed and i.clearance_above < STAND_RISE:
		input = i.copy()  # a flat slime under a low ceiling cannot jump, and the press is not buffered
		input.jump_pressed = false
	var scale := speed_scale * (SPREAD_SPEED if s.spread else 1.0)
	GroundAirStep.step(s, input, p, dt, scale, jump_boost)

## True while the body should use the flat collision box.
static func is_flat(s: MoveState, _p: MovementProfile) -> bool:
	return s.spread

## Down on the floor flattens the slime; it stands again once down is released (or it jumps) with room above.
static func _ooze(s: MoveState, i: MoveInput, p: MovementProfile) -> void:
	if not p.verbs.has("ooze"):
		return
	var want := i.on_floor and i.down >= SPREAD_DOWN and not i.jump_pressed
	if want:
		s.spread = true
	elif s.spread and i.clearance_above >= STAND_RISE:
		s.spread = false
