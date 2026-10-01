class_name PlayerWater
extends RefCounted
## The player's water model: whether the body centre is in a DeepWater, the once-a-second `submerged` clock, the entry and
## exit edges, and the frame's velocity in water. Pure of Input and of the physics body: player.gd passes what it knows.
##   Without Swim: slow (x0.6), a third of the gravity, a sink cap, a bob (not a jump) from the floor, and upward speed
##   carried in from a dry jump is capped at the bob on the entry edge.
##   With Swim: no gravity, 8-way at the swim speed, and a surface jump that stays ballistic until the centre leaves the rect.

const WATER_GRAVITY := 0.35
const BOB_VELOCITY := 160.0
const SINK_CAP := 60.0
const WALK_SCALE := 0.6
const SURFACE_REACH := 24.0
const SUBMERGED_SECONDS := 1.0
## How fast the water slows an impulse (a hit, a tackle) on a swimmer, px/s per second.
const DRAG := 600.0

var in_water := false
var rect := Rect2()
var ballistic := false
var _clock := 0.0

## The bob's apex in px for a jump height in percent (the gate test's B): the bob velocity boosted like a jump, rising at the
## water's gravity.
static func bob_apex(jump_height_pct: float) -> float:
	return BOB_VELOCITY * BOB_VELOCITY * (jump_height_pct / 100.0) / (2.0 * 900.0 * WATER_GRAVITY)

func reset() -> void:
	in_water = false
	rect = Rect2()
	ballistic = false
	_clock = 0.0

## One physics step: where the centre is, the edges, and how many whole seconds passed in water.
func step(tree: SceneTree, centre: Vector2, delta: float) -> Dictionary:
	var node := DeepWater.at(tree, centre)
	var was := in_water
	in_water = node != null
	rect = node.world_rect() if node != null else Rect2()
	var out := {"entered": in_water and not was, "exited": was and not in_water, "submerged": 0}
	if not in_water:
		ballistic = false
		return out
	_clock += delta
	while _clock >= SUBMERGED_SECONDS:
		_clock -= SUBMERGED_SECONDS
		out["submerged"] += 1
	return out

## The frame's velocity. `velocity` is what player.gd computed dry (walk speed already in x, gravity added); this replaces
## it with the water's version. `dir` is the steering vector (a swimmer's input), `dashing` whether a hit, tackle or shock
## lock owns the body, `entered` the entry edge this frame.
func adjust(velocity: Vector2, grounded: bool, swims: bool, dir: Vector2, swim_speed: float, boost: float, dashing: bool,
		entered: bool, delta: float) -> Vector2:
	if not in_water:
		return velocity
	if swims:
		if ballistic:
			return velocity
		if dashing:
			return velocity.move_toward(Vector2.ZERO, DRAG * delta)
		return dir * swim_speed
	var v := velocity
	if not dashing:
		v.x *= WALK_SCALE
	if entered:
		v.y = maxf(v.y, -BOB_VELOCITY * boost)
	# the dry gravity player.gd added this frame is replaced by the water's: undo it and add the third
	if not grounded:
		v.y += 900.0 * delta * (WATER_GRAVITY - 1.0)
	v.y = minf(v.y, SINK_CAP)
	return v

## What a Jump press does in water: a new velocity, or null when it does nothing here.
func jump(velocity: Vector2, grounded: bool, swims: bool, boost: float, centre: Vector2) -> Variant:
	if not in_water:
		return null
	if swims:
		if centre.y - rect.position.y <= SURFACE_REACH:
			ballistic = true
			return Vector2(velocity.x, Player.JUMP_VELOCITY * boost)
		return null
	if grounded:
		return Vector2(velocity.x, -BOB_VELOCITY * boost)
	return null
