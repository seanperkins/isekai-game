class_name Events
extends RefCounted
## Event names emitted by the player to EventBus. All events are edge-triggered.

const JUMPED := "jumped"
const WALL_TOUCHED := "wall_touched"
const DAMAGED := "damaged"
const HP_LOW_ENTERED := "hp_low_entered"
const HP_LOW_EXITED := "hp_low_exited"
const STUNNED_ENEMY := "stunned_enemy"
const PREDATED := "predated"
const ABSORBED := "absorbed"
const INSPECTED := "inspected"
const SKILL_USED := "skill_used"
const SKILL_UNLOCKED := "skill_unlocked"
const SKILL_LEVELED := "skill_leveled"

## Queued by SkillRules itself; never counted and never emitted by gameplay.
const INTERNAL := [SKILL_UNLOCKED, SKILL_LEVELED]

const ALL := [JUMPED, WALL_TOUCHED, DAMAGED, HP_LOW_ENTERED, HP_LOW_EXITED, STUNNED_ENEMY,
	PREDATED, ABSORBED, INSPECTED, SKILL_USED, SKILL_UNLOCKED, SKILL_LEVELED]
