class_name CreatureDef
extends Resource
## One creature or terrain source. Content lives in res://data/creatures/.

@export var id: String = ""
@export var display_name: String = ""
## StatKeys -> int, e.g. {"max_hp": 2, "atk": 3, "def": 0, "spd": 140}
@export var stats: Dictionary = {}
## Essence -> units absorbed per eat, e.g. {"sound": 1, "flight": 1}
@export var essences: Dictionary = {}
## [{"id": String, "level": int}] skills this creature uses
@export var skills: Array = []
## {"stat": String, "amount": int, "per": int} or empty
@export var eat_bonus: Dictionary = {}
@export var predatable: bool = true
@export var appraisal_target: bool = true
## XP for downing this creature (and again for eating it).
@export var xp: int = 0
## The front block: a front tackle hurts but does not stun it. It also makes the creature a charger (the lizard, the crab, the crayfish,
## the drake); `charges` makes one without the block (the wolf).
@export var armored_charger: bool = false
## Hovers in a slow loop; no gravity while active or stunned (the moths).
@export var drifter: bool = false
## Lives in a water rect (confined to it) and is what Jolt stuns: the eels and the jelly.
@export var swimmer: bool = false
## A tackle skips it: the jelly.
@export var untackleable: bool = false
## The damage type of its contact hit: "physical", or "shock" for the eels and the jelly.
@export var contact_type: String = "physical"
## "" for none, "spear" for the lizardman (a spitter that throws a Spear).
@export var projectile: String = ""
## Drops a spore puff (the two moths).
@export var puffs: bool = false
## Alerts its packmates (same def id, within Enemy.PACK_RADIUS) when it sees the player: the wolves and the ants.
@export var pack: bool = false
## A charger with no armored front: a front tackle still stuns it (the wolf).
@export var charges: bool = false
## A charger whose "charge" is a ground slam you dodge by being airborne (the drake). Set with `armored_charger`.
@export var stomper: bool = false
