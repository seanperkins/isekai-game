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
