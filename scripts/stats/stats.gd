class_name Stats
extends RefCounted
## Actor stats: base + eat bonus (capped per run) + skill modifiers.
## Modifiers are keyed by source (skill id) so a level-up replaces rather than stacks.

const EAT_CAPS := {"max_hp": 10, "atk": 3, "def": 2, "spd": 20}
const DEFAULTS := {"max_hp": 0, "atk": 0, "def": 0, "spd": 100, "jump_height": 100,
	"slide_speed": 100, "predation_time": 100, "regen_interval": 0}

var _base := {}
var _eat := {}     # stat -> bonus
var _eaten := {}   # creature id -> count this run
var _mods := {}    # source id -> [{"stat", "op", "value"}]

func _init(base: Dictionary = {}) -> void:
	set_base(base)

func set_base(base: Dictionary) -> void:
	_base = DEFAULTS.duplicate()
	for key in base:
		_base[key] = int(base[key])

func apply_eat(creature: CreatureDef) -> void:
	var bonus: Dictionary = creature.eat_bonus
	if bonus.is_empty():
		return
	var n: int = int(_eaten.get(creature.id, 0)) + 1
	_eaten[creature.id] = n
	if n % int(bonus.get("per", 1)) != 0:
		return
	var stat: String = bonus["stat"]
	_eat[stat] = mini(int(EAT_CAPS.get(stat, 0)), int(_eat.get(stat, 0)) + int(bonus["amount"]))

func set_modifiers(source_id: String, mods: Array) -> void:
	if mods.is_empty():
		_mods.erase(source_id)
	else:
		_mods[source_id] = mods.duplicate(true)

func eat_bonus(key: String) -> int:
	return int(_eat.get(key, 0))

func base(key: String) -> int:
	return int(_base.get(key, 0))

## The part of get_stat() that comes from skill modifiers (for the status screen split).
func skill_bonus(key: String) -> int:
	return get_stat(key) - base(key) - eat_bonus(key)

func clear_modifiers() -> void:
	_mods.clear()

func get_stat(key: String) -> int:
	var value: int = int(_base.get(key, 0)) + int(_eat.get(key, 0))
	var override = null
	for source in _mods:
		for m in _mods[source]:
			if m["stat"] != key:
				continue
			if m["op"] == "set":
				override = int(m["value"])
			else:
				value += int(m["value"])
	return override if override != null else value

func reset_run() -> void:
	_eat.clear()
	_eaten.clear()
	_mods.clear()
