class_name MovementSim
extends RefCounted
## A stand-in for move_and_slide on flat ground, in the engine's tick order: GroundAirStep.step, then the body moves by
## its velocity, then it lands. The floor is y = 0 (up is negative). Measures a profile's jump without a physics body.

const DT := 1.0 / 60.0
## A body this close above the floor (or below it) counts as landed, so a jump that ends exactly on the floor does not
## depend on which side of zero rounding leaves it.
const LAND_EPS := 0.001

var profile: MovementProfile
var state := MoveState.new()
var pos := Vector2.ZERO
var on_floor := true

func _init(p: MovementProfile) -> void:
	profile = p

func tick(dir := 0.0, pressed := false, held := false, boost := 1.0, down := 0.0, signature := false) -> void:
	var i := MoveInput.new()
	i.dir = dir
	i.on_floor = on_floor
	i.jump_pressed = pressed
	i.jump_held = held
	i.down = down
	i.signature_pressed = signature
	VerbRunner.step(state, i, profile, DT, 1.0, boost)
	pos += state.velocity * DT
	if pos.y >= -LAND_EPS and state.velocity.y >= 0.0:
		pos.y = 0.0
		state.velocity.y = 0.0
		on_floor = true
	else:
		on_floor = false

## Today's jump as a profile: Player's own constants, no float, no heavier fall, nothing else.
static func base_profile() -> MovementProfile:
	var p := MovementProfile.new()
	p.id = "base"
	p.jump_velocity = -Player.JUMP_VELOCITY
	p.gravity = Player.GRAVITY
	p.top_speed = Player.SPEED
	p.fall_mult = 1.0
	p.apex_band = 0.0
	p.release_style = MovementProfile.ReleaseStyle.CUT
	p.rebound_rise = 0.0
	p.air_keeps_momentum = false
	return p

## One flat-ground jump: presses on tick 0 (always held), runs right throughout, holds the button while elapsed time is
## under `hold_seconds`, and stops at the first landing. Starts at top speed unless `start_speed` is given (>= 0);
## `rebound` starts as if the body had just landed from a fall. Returns the rise (px above the floor), the airtime (s)
## and the distance travelled (px).
static func flat_jump(p: MovementProfile, boost := 1.0, hold_seconds := 100.0, start_speed := -1.0, rebound := false) -> Dictionary:
	var sim := MovementSim.new(p)
	sim.state.velocity.x = p.top_speed if start_speed < 0.0 else start_speed
	if rebound:
		sim.state.air_time = 0.5
	var rise := 0.0
	var ticks := 0
	while ticks < 600:
		var first := ticks == 0
		sim.tick(1.0, first, first or ticks * DT < hold_seconds, boost)
		ticks += 1
		rise = maxf(rise, -sim.pos.y)
		if sim.on_floor:
			break
	return {"rise": rise, "airtime": ticks * DT, "distance": sim.pos.x}
