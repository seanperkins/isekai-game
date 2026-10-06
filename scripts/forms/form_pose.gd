class_name FormPose
extends RefCounted
## How an animated form (clips built by tools/art/blender) is played by a body that goes at some speed: a walk plays as fast as the body really goes
## against the speed it was built for, so a planted foot stays planted whatever the speed, a run likewise against its own.

## The playback rate stays within these: a body creeping is not frozen and a rocket is not a blur.
const RATE_RANGE := Vector2(0.2, 4.0)
## A body is running when it goes faster than this many times its walk (the enemy's own ratio, scripts/enemies/enemy.gd).
const RUN_RATIO := 1.35
## A run clip is built for this many times the walk's speed (tools/art/blender: the goblin's WALK_SPEED_RUN).
const RUN_SPEED := 1.9

## How fast to play clip `state` for a body going `speed` px/s when the walk was built for `walk_speed`.
static func rate(state: String, speed: float, walk_speed: float) -> float:
	if speed <= 1.0:
		return 1.0
	match state:
		"walk":
			return clampf(speed / walk_speed, RATE_RANGE.x, RATE_RANGE.y)
		"run":
			return clampf(speed / (walk_speed * RUN_SPEED), RATE_RANGE.x, RATE_RANGE.y)
	return 1.0

static func running(speed: float, walk_speed: float) -> bool:
	return speed > walk_speed * RUN_RATIO
