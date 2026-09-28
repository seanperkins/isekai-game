class_name Progression
extends RefCounted
## Character level for the current run. XP comes from downing and eating creatures;
## each level-up grants one Evolution Point (EP).

signal leveled_up(level: int)

const BASE_XP := 10
const XP_STEP := 5

var level := 1
var xp := 0
var ep := 0

## XP needed to go from `from_level` to the next level: 10, 15, 20, ...
static func xp_to_next(from_level: int) -> int:
	return BASE_XP + XP_STEP * (from_level - 1)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		ep += 1
		leveled_up.emit(level)

func spend_ep(amount: int) -> bool:
	if amount > ep:
		return false
	ep -= amount
	return true
