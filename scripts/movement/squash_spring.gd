class_name SquashSpring
extends RefCounted
## The slime's squash and stretch, as a damped spring on its sprite's scale. Vertical speed pulls the target toward a
## stretch; a landing kicks the spring into a squash that rebounds past rest and settles. Cosmetic only: it changes a
## sprite's scale, never a hit shape (those follow the art frame).

## The most the sprite stretches or squashes (a fraction), and the longest step the spring takes: a long frame runs
## the spring slow instead of letting it blow up.
const LIMIT := 0.22
const MAX_DT := 1.0 / 30.0
## Natural frequency (Hz) and damping ratio (under 1 overshoots).
const F := 3.5
const ZETA := 0.4

var _y := 0.0
var _v := 0.0

## Steps the spring toward the stretch for vertical speed `vy` (the faster, the longer).
func update(vy: float, dt: float) -> void:
	var step := minf(dt, MAX_DT)
	var target := clampf(absf(vy) / 400.0, 0.0, 1.0) * LIMIT
	var w := TAU * F
	_v += (w * w * (target - _y) - 2.0 * ZETA * w * _v) * step
	_y += _v * step

## A landing at `fall_speed` squashes the sprite, harder the faster it fell.
func land(fall_speed: float) -> void:
	_v += -clampf(fall_speed / 500.0, 0.0, 1.0) * LIMIT * 20.0

## Drops any squash or stretch at once (a bounce that lands as a ball, not a squash).
func calm() -> void:
	_y = 0.0
	_v = 0.0

## The sprite's scale, volume-preserving: taller is narrower.
func sprite_scale() -> Vector2:
	var s := clampf(_y, -LIMIT, LIMIT)
	return Vector2(1.0 / (1.0 + s), 1.0 + s)
