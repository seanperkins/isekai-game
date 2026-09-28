class_name Rope
extends RefCounted
## A thread stuck to terrain. The slime swings on it as a pendulum: the rope never stretches
## past `length`, left/right pump the swing, up/down reel it in and out, Jump lets go.

const MIN_LENGTH := 16.0
const PUMP_ACCEL := 420.0
## Letting go always pops the slime up at least this fast, so a release can clear a ledge.
const RELEASE_LIFT := -160.0

var anchor: Vector2
var length: float
var max_length: float
var reel_speed: float
var release_boost: float

func _init(p_anchor: Vector2, from: Vector2, p_max_length: float, p_reel_speed: float, p_release_boost: float) -> void:
	anchor = p_anchor
	max_length = p_max_length
	reel_speed = p_reel_speed
	release_boost = p_release_boost
	length = clampf(from.distance_to(anchor), MIN_LENGTH, max_length)

## `axis` -1 reels in (up), +1 reels out (down).
func reel(axis: float, delta: float) -> void:
	length = clampf(length + axis * reel_speed * delta, MIN_LENGTH, max_length)

## The velocity with its outward part removed while the rope is taut.
func constrain_velocity(pos: Vector2, vel: Vector2) -> Vector2:
	var off := pos - anchor
	if off.length() < length - 0.5:
		return vel
	var radial := off.normalized()
	var outward := vel.dot(radial)
	return vel - radial * outward if outward > 0.0 else vel

## How far the body must move to get back onto the rope (zero while slack).
func correction(pos: Vector2) -> Vector2:
	var off := pos - anchor
	if off.length() <= length:
		return Vector2.ZERO
	return anchor + off.normalized() * length - pos

## Adds swing speed along the rope's tangent, toward the held direction.
func pump(pos: Vector2, vel: Vector2, dir_x: float, delta: float) -> Vector2:
	if is_zero_approx(dir_x):
		return vel
	var radial := (pos - anchor).normalized()
	var tangent := Vector2(-radial.y, radial.x)
	if tangent.x * dir_x < 0.0:
		tangent = -tangent
	return vel + tangent * absf(dir_x) * PUMP_ACCEL * delta

func release_velocity(vel: Vector2) -> Vector2:
	var v := vel * release_boost
	v.y = minf(v.y, RELEASE_LIFT)
	return v
