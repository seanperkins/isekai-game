class_name Progression
extends RefCounted
## Character level for the current run, in four stages. XP comes from downing and eating creatures;
## each level-up grants one Evolution Point (EP). A stage ends at LEVEL_CAP: extra XP is discarded until
## the body evolves (evolve_stage), which resets the level but keeps EP and the level bonuses.

signal leveled_up(level: int)

const BASE_XP := 10
const XP_STEP := 5
const LEVEL_CAP := 10
const MAX_STAGE := 4
## Each stage multiplies the level curve, rounded down per level: 270, 403, 540 and 673 XP a stage.
const STAGE_MULT := [1.0, 1.5, 2.0, 2.5]
## A repeat of a spawn point's down or eat pays this fraction of the creature's XP (rounded down).
const REPEAT_DIVISOR := 4

var level := 1
var xp := 0
var ep := 0
var stage := 1
## "<spawn key>:down" / "<spawn key>:eat" for every first-time reward already paid this run.
var claimed := {}

## XP needed to go from `from_level` to the next level in `p_stage`: 10, 15, 20, ... times the stage's multiplier.
static func xp_to_next(from_level: int, p_stage: int = 1) -> int:
	var m: float = STAGE_MULT[clampi(p_stage, 1, MAX_STAGE) - 1]
	return int(floor(float(BASE_XP + XP_STEP * (from_level - 1)) * m))

## XP for a whole stage: level 1 to the cap.
static func stage_total(p_stage: int) -> int:
	var total := 0
	for l in range(1, LEVEL_CAP):
		total += xp_to_next(l, p_stage)
	return total

func at_cap() -> bool:
	return level >= LEVEL_CAP

## The level cap is reached and there is a stage left: the body can evolve.
func can_evolve() -> bool:
	return at_cap() and stage < MAX_STAGE

func add_xp(amount: int) -> void:
	if at_cap():
		return  # XP stops at the cap and is discarded
	xp += amount
	while xp >= xp_to_next(level, stage):
		xp -= xp_to_next(level, stage)
		level += 1
		ep += 1
		leveled_up.emit(level)
		if at_cap():
			xp = 0
			break

## A rebirth kit's starting level: the level bonuses (one leveled_up per level) but no EP, no XP, stage 1.
func start_at(target: int) -> void:
	target = clampi(target, 1, LEVEL_CAP)
	var kept_ep := ep
	while level < target:
		level += 1
		leveled_up.emit(level)
	ep = kept_ep
	xp = 0

## Starts the next stage: level 1 again, EP and the (stat) level bonuses are kept.
func evolve_stage() -> void:
	if stage >= MAX_STAGE:
		return
	stage += 1
	level = 1
	xp = 0

## The XP a spawn point pays for a `kind` ("down" or "eat"): full the first time, then a quarter. Returns
## the XP actually added. A spawn point is only marked claimed when XP is added (at the cap it is not), so
## a kill at the cap keeps its first-time reward for after evolving. An empty key is untracked: always full.
func award(key: String, kind: String, amount: int) -> int:
	if key == "":
		add_xp(amount)
		return amount
	if at_cap():
		return 0
	var k := "%s:%s" % [key, kind]
	var paid := amount if not claimed.has(k) else int(floor(float(amount) / REPEAT_DIVISOR))
	claimed[k] = true
	add_xp(paid)
	return paid

func spend_ep(amount: int) -> bool:
	if amount > ep:
		return false
	ep -= amount
	return true
