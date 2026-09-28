class_name SlimeState
extends RefCounted
## Which animation the slime plays. The first match wins, in the order of the spec's table.

const ALL := ["cover", "hurt", "rope", "wall", "tackle", "spread", "rise", "fall", "land", "run", "idle"]
## Horizontal speed (px/s) above which the slime counts as running.
const RUN_SPEED := 8.0

static func pick(eating: bool, hurt: bool, roped: bool, wall: bool, dashing: bool, spread: bool,
		on_floor: bool, vy: float, land_timer: float, speed: float) -> String:
	if eating:
		return "cover"
	if hurt:
		return "hurt"
	if roped:
		return "rope"
	if wall:
		return "wall"
	if dashing:
		return "tackle"
	if spread:
		return "spread"
	if not on_floor:
		return "rise" if vy < 0.0 else "fall"
	if land_timer > 0.0:
		return "land"
	if absf(speed) > RUN_SPEED:
		return "run"
	return "idle"
